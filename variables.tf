# Variables for EKS Workshop VPC Configuration

# AWS Region where resources will be created
# Default is eu-central-1, but can be changed in terraform.tfvars
variable "region" {
  description = "AWS region where the VPC and EKS cluster will be deployed"
  type        = string
  default     = "eu-central-1"
}

# Project name used for resource naming and tagging
variable "project_name" {
  description = "Name of the project, used for resource naming and tags"
  type        = string
  default     = "eks-workshop"
}

# Environment name (dev, staging, prod)
variable "environment" {
  description = "Environment name for resource tagging"
  type        = string
  default     = "dev"
}

# VPC CIDR block
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Availability Zones (will be automatically selected based on region)
variable "availability_zones" {
  description = "List of availability zones to use (leave empty for automatic selection)"
  type        = list(string)
  default     = []
}
