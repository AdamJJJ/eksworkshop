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

### ✅ Verify VPC and S3 Deployment in AWS Console:

1. **Go to AWS Console → VPC Dashboard**
2. **Check Your VPCs**: You should see `eks-workshop-vpc`
3. **Check Subnets**: You should see 4 subnets:
   - 2 public subnets (one per AZ)
   - 2 private subnets (one per AZ)
4. **Check Internet Gateways**: You should see `eks-workshop-igw`
5. **Check NAT Gateways**: You should see `eks-workshop-nat-gateway` in a public subnet
6. **Check Route Tables**: You should see public and private route tables with proper routes
7. **Go to AWS Console → S3**
8. **Check S3 Bucket**: You should see `eks-workshop-assets-[random]` bucket with:
   - Public read access configured
   - `workshop-image.jpg` uploaded
   - Versioning enabled

### What Gets Created:
- **VPC**: Your isolated network environment (10.0.0.0/16)
- **Public Subnets**: For load balancers and NAT gateway (internet-accessible)
- **Private Subnets**: For EKS worker nodes (secure, no direct internet access)
- **Internet Gateway**: Allows public subnet resources to reach the internet
- **NAT Gateway**: Allows private subnet resources to reach internet for updates
- **Route Tables**: Define how traffic flows between subnets
- **Security Groups**: Firewall rules for EKS cluster and nodes
- **S3 Bucket**: Stores static assets with unique name `eks-workshop-assets-[random-id]`
- **Workshop Image**: Sample PNG file uploaded to S3 for web application testing
- **IAM Role**: For secure S3 access from Kubernetes pods (IRSA pattern)
- **IAM Policy**: Grants read-only access to the workshop S3 bucket

**What's Next:** With networking in place, we'll create the EKS control plane.

---

## Phase 2: Deploy EKS Cluster

**What we're building:** The Kubernetes control plane that manages your cluster.

**Why we use modules:** In real-world scenarios, you'll use Terraform modules instead of writing individual resources. Modules encapsulate best practices and handle complexity for you.

### Steps:

1. In `eks.tf`, uncomment the EKS cluster section:
   - Remove `/*` at the beginning of "PHASE 2: EKS CLUSTER" section
   - Remove `*/` at the end of that section

2. In `outputs.tf`, uncomment the EKS outputs section:
   - Remove `/*` and `*/` around "EKS OUTPUTS" section

3. Deploy the EKS cluster:
```bash
terraform init
terraform apply
```

### ✅ Verify EKS Cluster Deployment in AWS Console:

1. **Go to AWS Console → EKS → Clusters**
2. **Check Cluster Status**: You should see `eks-workshop-cluster` with status "Active"
3. **Check Access Tab**: Your IAM user should have cluster admin access automatically configured
4. **Check Cluster Details**:
   - Version: 1.33
   - Endpoint: Should show the API server URL
   - Networking: Should show your VPC and private subnets
4. **Check IAM Roles**: Go to IAM → Roles, look for `eks-workshop-cluster-cluster`
5. **Check CloudWatch**: Go to CloudWatch → Log groups, look for `/aws/eks/eks-workshop-cluster/cluster`

### What the Module Creates Behind the Scenes:
- **EKS Cluster**: Kubernetes version 1.33 control plane
- **IAM Role**: With AmazonEKSClusterPolicy attached
- **Security Groups**: For cluster communication
- **CloudWatch Logs**: For monitoring and troubleshooting
- **OIDC Provider**: For service account authentication
- **API Endpoint**: How you'll connect with kubectl

**What's Next:** The cluster is ready, but we need worker nodes to run applications.

---

## Phase 3: Deploy Managed Node Group

**What we're building:** Amazon EC2 instances that will run your Kubernetes workloads.

**Why modules are better:** The module automatically creates all required IAM roles, policies, and configurations following AWS best practices.

### Steps:

1. In `eks.tf`, the node group is already configured within the main EKS module
   - No need to uncomment separate sections - it's built-in now

2. In `outputs.tf`, uncomment the node group outputs section:
   - Remove `/*` and `*/` around "NODE GROUP OUTPUTS" section

3. Deploy the worker nodes:
```bash
terraform init
terraform apply
```

### ✅ Verify Node Group Deployment in AWS Console:

1. **Go to AWS Console → EKS → Clusters → eks-workshop-cluster**
2. **Check Compute Tab**: You should see `eks-workshop-nodes` node group with status "Active"
3. **Check Node Group Details**:
   - Desired size: 2
   - Instance type: t3.medium
   - Subnets: Should show your private subnets
4. **Check EC2 Instances**: Go to EC2 → Instances, you should see 2 running instances:
   - Names like `eks-workshop-nodes-xxxxx`
   - Instance type: t3.medium
   - Located in private subnets (different AZs)
5. **Check Auto Scaling Groups**: Go to EC2 → Auto Scaling Groups, look for `eks-workshop-nodes-xxxxx`
6. **Check IAM Roles**: Go to IAM → Roles, look for `eks-workshop-eks-nodes-role`

### What the Module Creates Behind the Scenes:
- **Managed Node Group**: 2 EC2 instances (1 per availability zone)
- **IAM Role**: With these policies automatically attached:
  - AmazonEKSWorkerNodePolicy
  - AmazonEKS_CNI_Policy
  - AmazonEC2ContainerRegistryReadOnly
- **Launch Template**: Defines node configuration
- **Auto Scaling Group**: Automatically replaces unhealthy nodes
- **Security Groups**: For node-to-node and node-to-cluster communication

**Instance Details:**
- Type: t3.medium (2 vCPU, 4GB RAM)
- AMI: Amazon Linux 2 optimized for EKS (automatically selected)
- Placement: Private subnets for security

---

## Phase 4: Deploy and Test Applications

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

3. Wait for LoadBalancer to be created (takes 2-3 minutes):
```bash
kubectl get service nginx-service --watch
```
Wait until you see an EXTERNAL-IP (not `<pending>`).

4. **Check AWS Console**: 
   - Go to EC2 → Load Balancers
   - You should see a new **Classic Load Balancer** being created
   - Note the DNS name - this is your public endpoint

5. Test your application:
```bash
# Get the LoadBalancer URL
kubectl get service nginx-service
# Copy the EXTERNAL-IP and open it in your browser
```

You should see the nginx welcome page!

### Step 3: Create Custom HTML Application

**What we're building:** A custom webpage using the existing nginx deployment.

1. **Get the S3 bucket name from Terraform outputs**:
```bash
terraform output s3_bucket_name
terraform output workshop_image_url
```

2. **Create your custom HTML file** using the `sample-webpage.html` template:
   - Copy `sample-webpage.html` to `index.html`
   - Replace `PROJECT_NAME-assets-RANDOM_ID` with your actual bucket name from step 1
   - Replace `REGION` with your AWS region (eu-central-1)

3. **Update the existing nginx deployment with your custom HTML**:
```bash
# Create ConfigMap with your custom HTML
kubectl create configmap html-content --from-file=index.html

# Update the existing nginx deployment to use the ConfigMap
kubectl patch deployment nginx-web -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "nginx",
          "image": "nginx",
          "volumeMounts": [{
            "name": "html-content",
            "mountPath": "/usr/share/nginx/html"
          }]
        }],
        "volumes": [{
          "name": "html-content",
          "configMap": {
            "name": "html-content"
          }
        }]
      }
    }
  }
}'
```

4. **Test your updated application**:
```bash
kubectl get service nginx-service
# Open the EXTERNAL-IP in browser - you should see your custom HTML with S3 integration
```

### Step 4: Demonstrate IRSA (IAM Roles for Service Accounts)

**What we're learning:** How to securely access AWS services from Kubernetes pods using IRSA.

1. **Create Kubernetes Service Account with IRSA annotation**:
```bash
kubectl create serviceaccount s3-access-sa
kubectl annotate serviceaccount s3-access-sa eks.amazonaws.com/role-arn=$(terraform output -raw s3_access_role_arn)
```

2. **Update the existing nginx deployment to use the Service Account**:
```bash
kubectl patch deployment nginx-web -p '{"spec":{"template":{"spec":{"serviceAccountName":"s3-access-sa"}}}}'
```

3. **Verify the deployment is using IRSA**:
```bash
# Check that pods are using the service account
kubectl get pods -l app=nginx-web -o jsonpath='{.items[0].spec.serviceAccountName}'

# Test S3 access from within the nginx pod
kubectl exec -it deployment/nginx-web -- /bin/bash
```

4. **Inside the nginx pod, test S3 access**:
```bash
# Install AWS CLI (if not present)
apt update && apt install -y awscli

# List all buckets (should work with IRSA)
aws s3 ls

# List your workshop bucket contents (replace with your actual bucket name)
aws s3 ls s3://YOUR-BUCKET-NAME/

exit
```

**Note:** Get your bucket name first with `terraform output s3_bucket_name` before running the pod commands.

**What this demonstrates:**
- ✅ **Secure access**: No AWS credentials stored in pods
- ✅ **Least privilege**: Only read access to specific S3 bucket
- ✅ **Automatic**: AWS SDK automatically uses IRSA credentials
- ❌ **Write blocked**: Upload fails due to limited permissions

### What You've Accomplished

✅ **VPC with proper networking** (public/private subnets, NAT gateway)  
✅ **EKS cluster** running Kubernetes 1.33  
✅ **Worker nodes** distributed across availability zones  
✅ **LoadBalancer integration** with AWS Classic Load Balancer  
✅ **Custom web application** with ConfigMaps using existing nginx deployment  
✅ **S3 integration** for static content hosting (private bucket with proper security)  
✅ **Real-world application deployment** using kubectl

**What's Next:** Your EKS cluster is fully functional! You can now deploy more complex applications, set up monitoring, implement CI/CD pipelines, or explore advanced Kubernetes features.

---

## Troubleshooting

**Common Issues and Solutions:**

### Phase 1 - VPC Issues:
- **Error: "availability zone not supported"**: Change region in terraform.tfvars
- **Error: "insufficient capacity"**: Try different region or wait and retry

### Phase 2 - EKS Cluster Issues:
- **Cluster stuck in "Creating"**: Normal, takes 15-20 minutes
- **Error: "AccessDenied"**: Check AWS credentials and permissions
- **Error: "subnet not found"**: Ensure Phase 1 completed successfully

### Phase 3 - Node Group Issues:
- **Nodes not joining**: Check security groups and subnet routing
- **"NodeCreationFailure"**: Check EC2 service limits in your region
- **Nodes in "NotReady"**: Wait 5-10 minutes for initialization

### Phase 4 - Application Issues:
- **LoadBalancer stuck in "Pending"**: Check AWS Load Balancer Controller installation
- **S3 access denied**: Verify bucket policy and bucket name in YAML
- **Can't access application**: Check security groups allow HTTP traffic

### General AWS Issues:
- **Region mismatch**: Ensure AWS CLI and terraform.tfvars use same region
- **Permission errors**: Verify your AWS user has EKS, EC2, VPC, and S3 permissions
- **Resource limits**: Some regions have limits on EKS clusters or EC2 instances

**Getting Help:**
- Check CloudWatch logs for EKS cluster issues
- Use `kubectl describe` commands for Kubernetes troubleshooting
- Review Terraform state with `terraform show`
- Check AWS service health dashboard for regional issues

## Cleanup

To avoid ongoing charges, destroy resources when done:
```bash
terraform destroy
```

**Important:** This will delete everything created in this workshop.

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
