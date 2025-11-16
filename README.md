# EKS Workshop - Phased Deployment Guide

> **⚠️ IMPORTANT WARNING ⚠️**
> 
> **This Terraform configuration is designed for TESTING and LEARNING purposes only.**
> 
> **DO NOT use this in production environments.** This setup prioritizes simplicity and cost-effectiveness for educational purposes and may not include all security, scalability, and reliability features required for production workloads.
> 
> For production deployments, please review AWS EKS best practices and implement additional security measures, monitoring, backup strategies, and high availability configurations.

This workshop will guide you through building a complete Amazon EKS (Elastic Kubernetes Service) infrastructure from scratch. We'll deploy in three phases to help you understand each component and how they work together.

## What You'll Build

By the end of this workshop, you'll have:
- A VPC with public and private subnets across 2 availability zones
- An EKS cluster running Kubernetes version 1.33
- A managed node group with worker nodes to run your applications
- All necessary networking, security, and IAM configurations

## Prerequisites

Before starting, ensure you have:
- AWS CLI installed on your machine
- Terraform installed (version 1.0 or later)
- An AWS account with appropriate permissions

## Step 1: Configure AWS Credentials

**What we're doing:** Setting up authentication so Terraform can create resources in your AWS account.

Choose one of the following methods to authenticate with AWS:

### Option A: AWS Configure (Access Keys)
```bash
aws configure
```
You'll be prompted to enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region name (e.g., eu-central-1)
- Default output format (json)

### Option B: AWS SSO
```bash
aws configure sso
```
Follow the prompts to:
- Enter your SSO start URL
- Select your AWS account and role
- Choose your default region

## Step 2: Verify AWS Configuration
```bash
aws sts get-caller-identity
```
This should return your account information if configured correctly.

## Step 3: Configure Region (Optional)

**What we're doing:** Choosing which AWS region to deploy your infrastructure in.

The default region is set to **eu-central-1** (Frankfurt). To change it:

1. Edit the `terraform.tfvars` file
2. Change the region value:
```hcl
region = "us-west-2"  # Change to your preferred region
```

**Why this matters:** Different regions have different availability zones, pricing, and compliance requirements.

---

## Phase 1: Deploy VPC Infrastructure

**What we're building:** The network foundation for your EKS cluster.

**Why we need this:** EKS clusters need a secure network environment with both public subnets (for load balancers) and private subnets (for worker nodes).

### Steps:

1. Navigate to your workshop directory where you downloaded the files

2. Initialize Terraform (downloads required providers):
```bash
terraform init
```

3. Review what will be created:
```bash
terraform plan
```

4. Deploy only the VPC infrastructure:
```bash
terraform apply -target=aws_vpc.main -target=aws_subnet.public -target=aws_subnet.private -target=aws_internet_gateway.main -target=aws_nat_gateway.main -target=aws_route_table.public -target=aws_route_table.private -target=aws_route_table_association.public -target=aws_route_table_association.private -target=aws_security_group.eks_cluster -target=aws_security_group.eks_nodes -target=aws_eip.nat
```
Type `yes` when prompted to confirm.

### ✅ Verify VPC Deployment in AWS Console:

1. **Go to AWS Console → VPC Dashboard**
2. **Check Your VPCs**: You should see `eks-workshop-vpc`
3. **Check Subnets**: You should see 4 subnets:
   - 2 public subnets (one per AZ)
   - 2 private subnets (one per AZ)
4. **Check Internet Gateways**: You should see `eks-workshop-igw`
5. **Check NAT Gateways**: You should see `eks-workshop-nat-gateway` in a public subnet
6. **Check Route Tables**: You should see public and private route tables with proper routes

### What Gets Created:
- **VPC**: Your isolated network environment (10.0.0.0/16)
- **Public Subnets**: For load balancers and NAT gateway (internet-accessible)
- **Private Subnets**: For EKS worker nodes (secure, no direct internet access)
- **Internet Gateway**: Allows public subnet resources to reach the internet
- **NAT Gateway**: Allows private subnet resources to reach internet for updates
- **Route Tables**: Define how traffic flows between subnets
- **Security Groups**: Firewall rules for EKS cluster and nodes

**What's Next:** With networking in place, we'll create the EKS control plane.

---

## Phase 2: Deploy EKS Cluster and Node Groups

**What we're building:** The Kubernetes control plane and worker nodes in one step.

**Why we use modules:** In real-world scenarios, you'll use Terraform modules instead of writing individual resources. Modules encapsulate best practices and handle complexity for you.

### Steps:

1. check `eks.tf`,and apply the change
```bash
terraform init
terraform apply
```

> **Note:** EKS cluster creation typically takes 10-15 minutes to complete.
> **Note:** Managed node group creation typically takes around 3 minutes to complete.

### ✅ Verify EKS Cluster Deployment in AWS Console:

1. **Go to AWS Console → EKS → Clusters**
2. **Check Cluster Status**: You should see `eks-workshop-cluster` with status "Active"
3. **Check Access Tab**: Your IAM user should have cluster admin access automatically configured
4. **Check Cluster Details**:
   - Version: 1.34
   - Endpoint: Should show the API server URL
   - Networking: Should show your VPC and private subnets
5. **Check Compute Tab**: You should see `eks-workshop-nodes` node group with status "Active"
6. **Check Node Group Details**:
   - Desired size: 2
   - Instance type: t3.medium
   - Subnets: Should show your private subnets
7. **Check EC2 Instances**: Go to EC2 → Instances, you should see 2 running instances:
   - Names like `eks-workshop-nodes-xxxxx`
   - Instance type: t3.medium
   - Located in private subnets (different AZs)
8. **Check IAM Roles**: Go to IAM → Roles, look for cluster and node roles
9. **Check CloudWatch**: Go to CloudWatch → Log groups, look for `/aws/eks/eks-workshop-cluster/cluster`

### What the Module Creates Behind the Scenes:
- **EKS Cluster**: Kubernetes version 1.34 control plane
- **Managed Node Group**: 2 EC2 instances (1 per availability zone)
- **IAM Roles**: With required policies automatically attached
- **Security Groups**: For cluster and node communication
- **CloudWatch Logs**: For monitoring and troubleshooting
- **OIDC Provider**: For service account authentication
- **Launch Template**: Defines node configuration
- **Auto Scaling Group**: Automatically replaces unhealthy nodes

**Instance Details:**
- Type: t3.medium (2 vCPU, 4GB RAM)
- AMI: Amazon Linux 2 optimized for EKS (automatically selected)
- Placement: Private subnets for security

**What's Next:** The cluster and nodes are ready for application deployment.

---

## Phase 3: Deploy and Test Applications

**What we're doing:** Testing your EKS cluster with real applications and AWS service integration.

### Step 1: Configure kubectl and Connect to Cluster

1. Configure kubectl to connect to your cluster:
```bash
aws eks update-kubeconfig --region <your-region> --name <cluster-name> 
```

2. Verify connection:
```bash
kubectl get nodes
```
You should see 2 nodes in "Ready" status.

### Step 2: Deploy Simple Web Application

**What we're testing:** Basic Kubernetes deployment and LoadBalancer service creation.

1. Deploy a simple nginx web server:
```bash
kubectl create deployment nginx-web --image=nginx
```

2. Expose it with a LoadBalancer (creates AWS Classic Load Balancer):
```bash
kubectl expose deployment nginx-web --port=80 --type=LoadBalancer --name=nginx-service
```

> **Note:** This creates a Classic Load Balancer (CLB). For Application Load Balancer (ALB), you would use Ingress resources with the AWS Load Balancer Controller. We're using CLB for simplicity in this workshop.

3. Check the service status:
```bash
kubectl get service nginx-service
```

4. **Check AWS Console for LoadBalancer**: 
   - Go to **EC2 → Load Balancers**
   - You should see a new **Classic Load Balancer** being created
   - Wait until the state shows "InService" (takes 2-3 minutes)
   - Note the DNS name - this is your public endpoint

5. Test your application:
```bash
# Get the LoadBalancer URL
kubectl get service nginx-service
# Copy the EXTERNAL-IP and open it in your browser
```

You should see the nginx welcome page!

---

## Next Steps: Advanced EKS Templates and Best Practices

This workshop taught you the fundamentals of EKS deployment. To explore more advanced patterns and learn production best practices:

**🔗 [AWS EKS Blueprints for Terraform](https://github.com/aws-ia/terraform-aws-eks-blueprints)**

**What you'll find there:**
- **Advanced templates** with comprehensive configurations
- **Add-on integrations** (monitoring, logging, autoscaling)
- **Multi-environment setups** (dev, staging, prod)
- **Advanced networking** configurations
- **GitOps patterns** and CI/CD integration
- **Security hardening** examples

**🔗 [AWS EKS Best Practices Guide](https://docs.aws.amazon.com/eks/latest/best-practices/introduction.html)**

**Essential reading for:**
- **Security best practices** for production workloads
- **Networking recommendations** and patterns
- **Monitoring and logging** strategies
- **Cost optimization** techniques
- **Reliability and availability** guidance
- **Performance tuning** recommendations

The blueprints provide ready-to-use templates, while the best practices guide helps you understand the "why" behind production-ready EKS deployments.
