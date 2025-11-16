# EKS Workshop - Phased Deployment Guide

> **⚠️ IMPORTANT WARNING ⚠️**
> 
> **This Terraform configuration is designed for TESTING and LEARNING purposes only.**
> 
> **DO NOT use this in production environments.** This setup prioritizes simplicity and cost-effectiveness for educational purposes and may not include all security, scalability, and reliability features required for production workloads.
> 
> For production deployments, please review AWS EKS best practices and implement additional security measures, monitoring, backup strategies, and high availability configurations.

This workshop will guide you through building a complete Amazon EKS (Elastic Kubernetes Service) infrastructure from scratch. We'll deploy in four phases to help you understand each component and how they work together.

## What You'll Build

By the end of this workshop, you'll have:
- A VPC with public and private subnets across 2 availability zones
- **Two EKS clusters** running Kubernetes version 1.34:
  - **Traditional EKS cluster** with managed node groups
  - **EKS Auto Mode cluster** with automatic compute management
- A managed node group with worker nodes for the traditional cluster
- All necessary networking, security, and IAM configurations
- Hands-on comparison between traditional EKS and Auto Mode approaches

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

---

## Phase 2: Deploy EKS Clusters (Managed Node Groups + Auto Mode)

**What we're building:** Two different types of EKS clusters to compare managed node group operations vs. Auto Mode capabilities.

**Why deploy both:** This allows you to understand the differences between EKS with managed node groups (where you manage scaling and instance types) and EKS Auto Mode (where AWS automatically handles compute with Karpenter-like capabilities and integrated services).

### Steps:

1. **Initialize and apply:**
```bash
terraform init
terraform apply
```

> **Note:** Both EKS clusters creation typically takes 10-15 minutes to complete.
> **Note:** Only the managed node group cluster will have pre-provisioned nodes - Auto Mode provisions compute on-demand.

### ✅ Verify Both EKS Clusters in AWS Console:

**EKS with Managed Node Groups (`eks-workshop-cluster`):**
1. **Go to AWS Console → EKS → Clusters**
2. **Check Cluster Status**: You should see `eks-workshop-cluster` with status "Active"
3. **Check Compute Tab**: You should see `eks-workshop-nodes` node group with status "Active"
4. **Check EC2 Instances**: Go to EC2 → Instances, you should see 2 running instances

**EKS Auto Mode Cluster (`eks-workshop-auto-cluster`):**
1. **Check Cluster Status**: You should see `eks-workshop-auto-cluster` with status "Active"
2. **Check Compute Tab**: You should see "Auto Mode" enabled with node pools
3. **Check EC2 Instances**: Initially no instances (Auto Mode creates them on-demand)

---

## Phase 3: Deploy and Test Applications on Both Clusters

**What we're doing:** Testing both EKS clusters with real applications to compare traditional vs. Auto Mode operations.

### Step 1: Test EKS with Managed Node Groups

1. **Configure kubectl for managed node group cluster:**
```bash
aws eks update-kubeconfig --region eu-central-1 --name eks-workshop-cluster
```
> **Note:** Change `eu-central-1` to your region if you modified it in `terraform.tfvars`

2. **Verify connection:**
```bash
kubectl get nodes
```
You should see 2 nodes in "Ready" status.

3. **Deploy nginx application:**
```bash
kubectl create deployment nginx-managed --image=nginx
kubectl expose deployment nginx-managed --port=80 --type=LoadBalancer --name=nginx-managed-service
```

4. **Check the service and get the LoadBalancer URL:**
```bash
kubectl get service nginx-managed-service
```
> **Note:** Wait 3-5 minutes for the LoadBalancer to be ready, then copy the EXTERNAL-IP and browse to it in your web browser to see the nginx welcome page.

### Step 2: Test EKS Auto Mode Cluster

1. **Switch to Auto Mode cluster:**
```bash
aws eks update-kubeconfig --region eu-central-1 --name eks-workshop-auto-cluster
```
> **Note:** Change `eu-central-1` to your region if you modified it in `terraform.tfvars`

2. **Initially no nodes exist:**
```bash
kubectl get nodes
# Should show: No resources found
```

3. **Deploy nginx to trigger node provisioning:**
```bash
kubectl create deployment nginx-automode --image=nginx
kubectl expose deployment nginx-automode --port=80 --type=LoadBalancer --name=nginx-automode-service
```

4. **Watch Auto Mode in action:**
```bash
# Watch nodes being automatically created (takes 2-3 minutes)
kubectl get nodes -w

# Check Auto Mode node pools
kubectl get nodepools -A

# Verify pod is running
kubectl get pods -o wide
```

### Step 3: Compare Both Clusters

**EKS with Managed Node Groups:**
- ✅ Nodes pre-provisioned and always running
- ✅ Predictable capacity and performance
- ❌ Paying for unused capacity
- ❌ Manual node group scaling and management required

**EKS Auto Mode:**
- ✅ Nodes created only when needed (Karpenter-like behavior)
- ✅ Optimal instance types selected automatically
- ✅ Built-in AWS service integration (EBS CSI, Load Balancer Controller)
- ✅ No manual node management
- ✅ Fast node provisioning with Karpenter-like capabilities

### Step 4: Test Auto Scaling (Auto Mode)

```bash
# Scale up to trigger more nodes
kubectl scale deployment nginx-automode --replicas=5

# Watch new nodes provision automatically
kubectl get nodes
kubectl get pods -o wide
```

**What You'll Observe:**
- Auto Mode automatically provisions additional nodes as needed
- Optimal instance types selected based on workload requirements
- No manual intervention required for scaling

---

## Phase 4: Advanced Auto Mode Features and Storage Testing

**What we're exploring:** Advanced Auto Mode capabilities including automatic storage provisioning, ingress management, and system-level features.

**Why this matters:** Understanding how Auto Mode handles complex scenarios that traditionally required manual configuration.

### Test 1: Automatic EBS Storage Provisioning

**What we're testing:** Auto Mode's built-in EBS CSI driver functionality.

```bash
# Ensure you're connected to Auto Mode cluster
aws eks update-kubeconfig --region <your-region> --name eks-workshop-auto-cluster

# Create storage class (Auto Mode provides EBS CSI automatically)
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

# Verify automatic provisioning
kubectl get pvc auto-pvc
kubectl get pods storage-test
kubectl get pv
```

**Expected Results:**
- ✅ PVC Status: Bound (automatically)
- ✅ EBS Volume: Created with gp3, encrypted
- ✅ No manual EBS CSI driver installation needed

### Test 2: Auto Mode System Components

```bash
# Check Auto Mode CRDs (Custom Resource Definitions)
kubectl get crd | grep eks.amazonaws.com

# Check Auto Mode node pools
kubectl get nodepools -A

# Verify storage classes
kubectl get storageclass

# Check for AWS-managed components (should be minimal)
kubectl get pods -A | grep -E "(ebs-csi|aws-load-balancer)"
```

**Key Insights:**
- **Hidden Infrastructure**: EBS CSI, networking components run as AWS-managed services
- **Minimal Cluster Overhead**: Fewer system pods compared to traditional EKS
- **Automatic CRD Management**: Auto Mode CRDs appear automatically

### Test 3: ALB Ingress (Load Balancer) Auto-Provisioning

**What we're testing:** Auto Mode's built-in AWS Load Balancer Controller functionality.

```bash
# Ensure you're connected to Auto Mode cluster
aws eks update-kubeconfig --region eu-central-1 --name eks-workshop-auto-cluster

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

# Step 3: Create a service for our nginx deployment
kubectl expose deployment nginx-automode --port=80 --name=nginx-automode-svc

# Step 4: Create Ingress (triggers ALB creation)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-automode-svc
                port:
                  number: 80
EOF

# Step 5: Check ALB creation and test
kubectl get ingress nginx-ingress
kubectl get ingress nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test the ALB endpoint (wait 3-5 minutes for ALB to be ready)
curl -I http://$(kubectl get ingress nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

**Expected Results:**
- ✅ ALB automatically created in AWS (visible in EC2 Console → Load Balancers)
- ✅ Ingress shows ADDRESS with ALB hostname
- ✅ HTTP 200 response from nginx application
- ✅ No manual AWS Load Balancer Controller installation needed

**Key Differences from Traditional EKS:**
- Uses `eks.amazonaws.com/alb` controller (not `ingress.k8s.aws/alb`)
- Requires `IngressClassParams` for AWS-specific configuration
- Auto Mode handles all ALB provisioning automatically

### Key Takeaways

**Auto Mode Advantages:**
- ✅ **Zero Infrastructure Management**: No node groups, drivers, or controllers to manage
- ✅ **Automatic Optimization**: Optimal instance selection and resource utilization
- ✅ **Built-in Best Practices**: Security, networking, and storage configured automatically
- ✅ **Built-in AWS Services**: EBS CSI, ALB Controller included automatically

**When to Use Auto Mode:**
- New applications without legacy constraints
- Teams wanting to focus on applications, not infrastructure
- Cost-sensitive workloads with variable demand
- Rapid prototyping and development environments

**When to Use Managed Node Groups:**
- Existing applications with specific node requirements
- Need for custom AMIs or specialized configurations
- Predictable workloads requiring consistent capacity
- Advanced networking or security customizations

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
