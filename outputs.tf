# Output Values for EKS Workshop VPC
# These outputs display important information after deployment

# VPC Information
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

# Subnet Information
output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (where EKS nodes will be deployed)"
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "Availability zones used"
  value       = local.azs
}

# Security Group Information
output "eks_cluster_security_group_id" {
  description = "Security group ID for EKS cluster"
  value       = aws_security_group.eks_cluster.id
}

output "eks_nodes_security_group_id" {
  description = "Security group ID for EKS worker nodes"
  value       = aws_security_group.eks_nodes.id
}

# Network Gateway Information
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.main.id
}

# Region Information
output "region" {
  description = "AWS region where resources are deployed"
  value       = var.region
}

# Summary Information
output "deployment_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    region              = var.region
    vpc_id              = aws_vpc.main.id
    availability_zones  = local.azs
    public_subnets      = length(aws_subnet.public)
    private_subnets     = length(aws_subnet.private)
    nat_gateways        = 1
  }
}

/*
# ============================================================================
# EKS OUTPUTS - Uncomment when EKS cluster is deployed (Phase 2)
# ============================================================================

# EKS Cluster Information
output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

# kubectl configuration command
output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
*/

/*
# ============================================================================
# NODE GROUP OUTPUTS - Uncomment when node group is deployed (Phase 3)
# ============================================================================

output "eks_node_groups" {
  description = "EKS managed node groups"
  value       = module.eks.eks_managed_node_groups
}
*/
