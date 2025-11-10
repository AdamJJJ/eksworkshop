# Terraform Variables Configuration
# Modify these values according to your requirements

# AWS Region - Change this to deploy in a different region
region = "eu-central-1"

# Project name - Used for naming resources
project_name = "eks-workshop"

# Environment - Used for tagging
environment = "dev"

# VPC CIDR - Network range for your VPC
vpc_cidr = "10.0.0.0/16"

# Availability Zones - Leave empty for automatic selection of 2 AZs
availability_zones = []
