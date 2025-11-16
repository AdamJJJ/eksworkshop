# EKS Auto Mode Cluster Configuration using Terraform Module
# This creates an EKS cluster with Auto Mode enabled for automatic compute, storage, and networking management

# EKS Auto Mode Cluster using the official module
module "eks_automode" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.37"

  # Basic cluster configuration
  cluster_name    = "${var.project_name}-auto-cluster"
  cluster_version = "1.34"

  # Network configuration - where to deploy the cluster
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  # Cluster endpoint access
  cluster_endpoint_public_access  = true   # Allow kubectl from internet
  cluster_endpoint_private_access = true   # Allow pods to reach API server

  # Enable Auto Mode - this is the key difference!
  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose", "system"]  # Auto Mode node pools
  }

  # Auto Mode requires additional IAM policies for the cluster role
  cluster_additional_security_group_ids = []
  
  # Add required Auto Mode policies to cluster role
  iam_role_additional_policies = {
    AmazonEKSComputePolicy        = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
    AmazonEKSBlockStoragePolicy   = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
    AmazonEKSLoadBalancingPolicy  = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
    AmazonEKSNetworkingPolicy     = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  }

  # Enable both API and ConfigMap authentication
  authentication_mode = "API_AND_CONFIG_MAP"
  
  # Grant current user admin access to the cluster
  enable_cluster_creator_admin_permissions = true

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # No managed node groups needed - Auto Mode handles compute automatically!
  # eks_managed_node_groups = {}  # Empty - Auto Mode replaces this

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-auto-cluster"
    Type = "AutoMode"
  })
}
