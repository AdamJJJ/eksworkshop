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
- An EKS cluster running Kubernetes version 1.34
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

## Phase 4: Understanding EKS Auto Mode

**What is EKS Auto Mode:** Amazon EKS Auto Mode streamlines Kubernetes cluster management by automatically provisioning infrastructure, selecting optimal compute instances, dynamically scaling resources, and continually optimizing for costs while handling OS patching and AWS security integration.

**Key Benefits:**
- **Fully Automated Operations**: No need for specialized Kubernetes infrastructure knowledge
- **Automatic Compute Management**: Launches EC2 instances with Bottlerocket OS based on workload requirements
- **Built-in Best Practices**: Clusters are production-ready with AWS security and networking configurations
- **Reduced Operational Overhead**: AWS manages node lifecycle, upgrades, and security patches
- **Cost Optimization**: Automatically selects and scales optimal instance types

**How It Works:**
EKS Auto Mode deploys essential controllers for compute, networking, and storage in AWS-managed accounts while launching EC2 instances and EBS volumes in your account. Components that traditionally ran as Kubernetes DaemonSets (service discovery, load balancing, pod networking) now run as AWS-managed system processes.

**Shared Responsibility Evolution:**
AWS now handles the data plane portion including EC2 instance configuration, patching, and health management. You focus only on VPC configuration, cluster settings, and your application containers.

**Compare the Clusters:**
Your workshop deployed both traditional EKS (`eks-workshop-cluster`) and Auto Mode (`eks-workshop-auto-cluster`). The Auto Mode cluster requires no managed node groups - AWS automatically provisions compute as needed when you deploy applications.

**Learn More:**
🔗 [Under the Hood: Amazon EKS Auto Mode](https://aws.amazon.com/blogs/containers/under-the-hood-amazon-eks-auto-mode/)

### Testing Auto Mode Capabilities

**Test 1: Node Auto-Provisioning**
```bash
# Connect to Auto Mode cluster
aws eks update-kubeconfig --region eu-central-1 --name eks-workshop-auto-cluster

# Initially no nodes exist
kubectl get nodes
# Should show: No resources found

# Deploy a simple application to trigger node provisioning
kubectl run simple-test --image=nginx

# Watch node being automatically created (takes 2-3 minutes)
kubectl get nodes -w

# Verify pod is running on the auto-provisioned node
kubectl get pods simple-test -o wide
```

**Expected Results:**
- Node appears automatically when pod needs scheduling
- Node runs Bottlerocket OS with Kubernetes v1.34.0
- Pod transitions from Pending → Running once node is ready

**Test 2: Storage (EBS CSI) Auto-Provisioning**
```bash
# Create proper EBS storage class (Auto Mode provides EBS CSI functionality)
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: auto-ebs-sc
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.eks.amazonaws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
  encrypted: "true"
EOF

# Test storage functionality
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: auto-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: auto-ebs-sc
---
apiVersion: v1
kind: Pod
metadata:
  name: storage-test
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: auto-pvc
EOF

# Verify storage provisioning
kubectl get pvc auto-pvc
kubectl get pods storage-test
kubectl get pv
```

**Expected Results:**
- PVC Status: Bound
- Pod Status: Running  
- EBS Volume: Automatically provisioned with gp3, encrypted
- No visible EBS CSI driver pods (AWS-managed)

**Test 3: Auto Mode Components Verification**
```bash
# Check Auto Mode CRDs
kubectl get crd | grep eks.amazonaws.com

# Check Auto Mode node pools
kubectl get nodepools -A

# Verify storage classes
kubectl get storageclass
```

**Expected Output:**
```
# CRDs
cninodes.eks.amazonaws.com                      2025-11-16T21:39:32Z
ingressclassparams.eks.amazonaws.com            2025-11-16T21:39:27Z
nodeclasses.eks.amazonaws.com                   2025-11-16T21:39:40Z
nodediagnostics.eks.amazonaws.com               2025-11-16T21:39:41Z
targetgroupbindings.eks.amazonaws.com           2025-11-16T21:39:27Z

# Node Pools
NAME              NODECLASS   NODES   READY   AGE
general-purpose   default     1       True    15m
system            default     0       True    15m

# Storage Classes
NAME                    PROVISIONER               RECLAIM POLICY
auto-ebs-sc (default)   ebs.csi.eks.amazonaws.com Delete
gp2                     kubernetes.io/aws-ebs     Delete
```

**Key Insights:**
- **Hidden Infrastructure**: EBS CSI, Load Balancer Controller run as AWS-managed services
- **On-Demand Provisioning**: Nodes and storage created only when needed
- **Zero Operational Overhead**: No manual driver/controller installation required

**Test 4: ALB Ingress (Load Balancer) Auto-Provisioning**
```bash
# Step 1: Create IngressClassParams (AWS-specific ALB configuration)
kubectl apply -f - <<EOF
apiVersion: eks.amazonaws.com/v1
kind: IngressClassParams
metadata:
  name: alb
spec:
  scheme: internet-facing
EOF

# Step 2: Create IngressClass (tells EKS Auto Mode to handle ALB)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: alb
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: eks.amazonaws.com/alb
  parameters:
    apiGroup: eks.amazonaws.com
    kind: IngressClassParams
    name: alb
EOF

# Step 3: Create Ingress (triggers ALB creation)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-app-ingress
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /*
            pathType: ImplementationSpecific
            backend:
              service:
                name: web-app
                port:
                  number: 80
EOF

# Step 4: Check ALB creation and test
kubectl get ingress web-app-ingress
kubectl get ingress web-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test the ALB endpoint
curl -I http://$(kubectl get ingress web-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

**Expected Results:**
- ALB automatically created in AWS (visible in EC2 Console → Load Balancers)
- Ingress shows ADDRESS with ALB hostname
- HTTP 200 response from nginx application
- No manual AWS Load Balancer Controller installation needed

**Key Differences from Traditional EKS:**
- Uses `eks.amazonaws.com/alb` controller (not `ingress.k8s.aws/alb`)
- Requires `IngressClassParams` for AWS-specific configuration
- Auto Mode handles all ALB provisioning automatically

### Testing Auto Mode Capabilities

**Step 1: Connect to Auto Mode Cluster**
```bash
aws eks update-kubeconfig --region <your-region> --name eks-workshop-auto-cluster
kubectl get nodes
```
Initially, you should see no nodes - Auto Mode provisions them on-demand.

**Step 2: Deploy Test Application**
```bash
kubectl create deployment auto-test --image=nginx --replicas=3
kubectl expose deployment auto-test --port=80 --type=LoadBalancer
```

**Step 3: Watch Auto Mode in Action**
```bash
# Watch nodes being automatically created
kubectl get nodes -w

# Check Auto Mode node pools
kubectl get nodepools -A

# Verify pods are scheduled
kubectl get pods -o wide
```

**Step 4: Test Auto Scaling**
```bash
# Scale up to trigger more nodes
kubectl scale deployment auto-test --replicas=10

# Watch new nodes provision automatically
kubectl get nodes
```

**What You'll Observe:**
- Nodes appear automatically when pods need scheduling
- Optimal instance types selected based on workload requirements
- Load balancer created without additional configuration
- No manual node group management needed

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
