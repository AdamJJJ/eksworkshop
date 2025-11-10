# EKS Cluster Configuration using Terraform Modules
# This is the real-world approach - modules handle complexity for you


# ============================================================================
# PHASE 2: EKS CLUSTER - Uncomment this section for Phase 2
# ============================================================================

# EKS Cluster Module
# This module creates everything needed for an EKS cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  # Basic cluster configuration
  cluster_name    = "${var.project_name}-cluster"
  cluster_version = "1.33"

  # Network configuration - where to deploy the cluster
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  # Cluster endpoint access
  cluster_endpoint_public_access  = true   # Allow kubectl from internet
  cluster_endpoint_private_access = true   # Allow pods to reach API server

  # What this module creates behind the scenes:
  # - IAM role for EKS cluster with AmazonEKSClusterPolicy
  # - EKS cluster in your private subnets
  # - Security groups for cluster communication
  # - CloudWatch log group for cluster logs
  # - OIDC identity provider for service accounts

  # EKS Managed Node Groups - uncomment for Phase 3
  eks_managed_node_groups = {
    workshop_nodes = {
      name = "${var.project_name}-nodes"
      
      instance_types = ["t3.medium"]
      
      min_size     = length(local.azs)
      max_size     = length(local.azs) * 2
      desired_size = length(local.azs)
      
      subnet_ids = aws_subnet.private[*].id
      
      tags = local.common_tags
    }
  }

  # Enable both API and ConfigMap authentication
  authentication_mode = "API_AND_CONFIG_MAP"
  
  # Grant current user admin access to the cluster
  enable_cluster_creator_admin_permissions = true

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  tags = local.common_tags
}



# ============================================================================
# PHASE 3: Node groups are now configured within the main EKS module above
# ============================================================================

