# VPC Configuration for EKS Workshop
# This file creates a complete VPC infrastructure for EKS deployment

# Configure the AWS Provider
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure AWS Provider with the specified region
provider "aws" {
  region = var.region
}

# Get available availability zones in the current region
# This automatically selects AZs based on the region you choose
data "aws_availability_zones" "available" {
  state = "available"
}

# Local values for consistent resource naming and configuration
locals {
  # Select first 2 availability zones from the region
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)
  
  # Common tags applied to all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Workshop    = "EKS-VPC-Setup"
  }
}

# Create the main VPC
# This is the virtual network where all our resources will live
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # Required for EKS
  enable_dns_support   = true  # Required for EKS

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

# Create Internet Gateway
# This allows resources in public subnets to access the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

# Create Public Subnets (one in each AZ)
# These subnets will host resources that need direct internet access
resource "aws_subnet" "public" {
  count = length(local.azs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true  # Auto-assign public IPs

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-${local.azs[count.index]}"
    Type = "Public"
    # EKS requires this tag for public subnets
    "kubernetes.io/role/elb" = "1"
  })
}

# Create Private Subnets (one in each AZ)
# These subnets will host EKS worker nodes and other private resources
resource "aws_subnet" "private" {
  count = length(local.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-${local.azs[count.index]}"
    Type = "Private"
    # EKS requires this tag for private subnets
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# Create Elastic IP for NAT Gateway
# NAT Gateway needs a static public IP address
resource "aws_eip" "nat" {
  domain = "vpc"
  
  # Ensure the internet gateway is created before the EIP
  depends_on = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-eip"
  })
}

# Create NAT Gateway in the first public subnet
# This allows private subnet resources to access the internet for updates
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-gateway"
  })

  # Ensure the internet gateway is created before the NAT gateway
  depends_on = [aws_internet_gateway.main]
}

# Create Route Table for Public Subnets
# This defines how traffic flows from public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Route all traffic (0.0.0.0/0) to the Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-rt"
    Type = "Public"
  })
}

# Create Route Table for Private Subnets
# This defines how traffic flows from private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # Route all traffic (0.0.0.0/0) to the NAT Gateway
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-rt"
    Type = "Private"
  })
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Security Group for EKS Cluster
# This will be used by the EKS cluster control plane
resource "aws_security_group" "eks_cluster" {
  name_prefix = "${var.project_name}-eks-cluster-"
  vpc_id      = aws_vpc.main.id

  # Allow HTTPS traffic from anywhere (required for EKS API)
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-eks-cluster-sg"
  })
}

# Security Group for EKS Node Groups
# This will be used by the EKS worker nodes
resource "aws_security_group" "eks_nodes" {
  name_prefix = "${var.project_name}-eks-nodes-"
  vpc_id      = aws_vpc.main.id

  # Allow nodes to communicate with each other
  ingress {
    description = "Node to node communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # Allow pods to communicate with the cluster API Server
  ingress {
    description     = "Cluster API to node groups"
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-eks-nodes-sg"
  })
}
