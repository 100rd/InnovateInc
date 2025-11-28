# OpsFleet EKS Terraform Infrastructure

Production-ready Amazon EKS cluster infrastructure with comprehensive monitoring, security, and disaster recovery capabilities.

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Post-Deployment](#post-deployment)
- [Disaster Recovery Plan](#disaster-recovery-plan)
- [Monitoring & Alerts](#monitoring--alerts)
- [Security](#security)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)

## Features

### Infrastructure
- **VPC**: Multi-AZ VPC with public/private subnets, single NAT gateway for cost optimization
- **EKS Cluster**: Kubernetes 1.34 with managed node groups
- **Autoscaling**: Karpenter for intelligent cluster autoscaling (optional)
- **Storage**: GP3 EBS volumes with encryption, EBS CSI driver
- **Networking**: IPv6 support, VPC endpoints for AWS services

### High Availability
- Multi-AZ deployment across 3 availability zones
- HA node groups with min 2 nodes
- Spot instance support for cost optimization
- Karpenter for dynamic scaling

### Monitoring & Observability
- CloudWatch Container Insights
- CloudWatch alarms for CPU/memory
- SNS notifications
- Cluster and application logging

### Security
- AWS Security Hub integration
- Pod Security Standards
- Falco runtime security
- Encrypted EBS volumes and secrets
- IMDSv2 enforcement
- Private subnets for worker nodes

### Ingress & DNS
- NGINX Ingress Controller with NLB
- External-DNS for Route53 integration
- TLS support ready

### GitOps (Optional)
- ArgoCD for GitOps deployments

## Prerequisites

1. **Tools**:
   ```bash
   terraform >= 1.5.0
   aws-cli >= 2.0
   kubectl >= 1.28
   ```

2. **AWS Credentials**:
   ```bash
   aws configure
   # Or use environment variables
   export AWS_ACCESS_KEY_ID="your-key"
   export AWS_SECRET_ACCESS_KEY="your-secret"
   export AWS_DEFAULT_REGION="eu-central-1"
   ```

3. **Permissions**: IAM user/role with permissions to create:
   - VPC, Subnets, Route Tables, NAT Gateways
   - EKS Clusters, Node Groups
   - IAM Roles and Policies
   - S3 Buckets
   - CloudWatch Logs and Alarms
   - Security Groups

## Quick Start

### 1. Clone and Configure

```bash
cd terraform

# Copy example configuration
cp dev.tfvars terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

### 2. Create S3 State Bucket (First Time Only)

```bash
# Set create_state_bucket = true in terraform.tfvars
terraform apply -target=aws_s3_bucket.terraform_state

# Note the bucket name from output
terraform output terraform_state_bucket_name
```

### 3. Enable Remote State (Optional but Recommended)

```bash
# Edit main.tf and uncomment the backend "s3" block
# Update with your bucket name from previous step

terraform init -migrate-state
```

### 4. Deploy Infrastructure

```bash
# Validate configuration
./terraform-validate.sh

# Plan deployment
terraform plan -var-file=terraform.tfvars

# Apply (will take 15-20 minutes)
terraform apply -var-file=terraform.tfvars
```

### 5. Configure kubectl

```bash
# Get the command from output
terraform output configure_kubectl

# Execute it
aws eks update-kubeconfig --name opsfleet-eks-dev --region eu-central-1

# Verify
kubectl get nodes
```

## Configuration

### Environment-Specific Variables

Create separate `.tfvars` files for each environment:

```bash
dev.tfvars      # Development
staging.tfvars  # Staging
prod.tfvars     # Production
```

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `environment` | Environment name | `dev` |
| `cluster_version` | Kubernetes version | `1.34` |
| `single_nat_gateway` | Use single NAT (cost saving) | `true` |
| `enable_spot_instances` | Enable spot node group | `false` |
| `enable_karpenter` | Enable Karpenter autoscaler | `true` |
| `enable_cloudwatch_monitoring` | Enable Container Insights | `true` |
| `enable_nginx_ingress` | Deploy NGINX ingress | `true` |
| `enable_security_hub` | Enable Security Hub | `true` |
| `enable_falco` | Enable Falco security | `true` |

See `variables.tf` for complete list.

## Deployment

### Standard Deployment

```bash
terraform apply -var-file=dev.tfvars
```

### Targeted Deployment

```bash
# Deploy only VPC
terraform apply -target=module.vpc

# Deploy only EKS
terraform apply -target=module.eks

# Deploy only Karpenter
terraform apply -target=module.karpenter
```

### Destroy Infrastructure

```bash
# WARNING: This will delete everything
terraform destroy -var-file=dev.tfvars
```

## Post-Deployment

### 1. Verify Cluster

```bash
kubectl get nodes
kubectl get pods -A
kubectl get svc -A
```

### 2. Install Additional Tools

```bash
# Metrics Server (if not installed)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Kubernetes Dashboard (optional)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

### 3. Configure Ingress

```bash
# Get NLB hostname
kubectl get svc -n ingress-nginx

# Create DNS record pointing to NLB
```

### 4. Deploy Sample Application

```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=ClusterIP
kubectl create ingress nginx --class=nginx --rule="nginx.example.com/*=nginx:80"
```

## Disaster Recovery Plan

### Overview

This infrastructure supports multi-region DR with RTO < 4 hours and RPO < 15 minutes.

### DR Strategy: Pilot Light

- **Primary Region**: eu-central-1 (Frankfurt)
- **DR Region**: us-east-1 (N. Virginia)
- **Architecture**: Active-Passive with automated failover capability

### Backup Components

#### 1. Terraform State
- **Location**: S3 bucket with versioning
- **Backup**: Automatic S3 versioning + cross-region replication
- **Retention**: 90 days

#### 2. EKS Configuration
- **Location**: This Git repository
- **Backup**: Git commits + GitHub
- **Recovery**: `terraform apply` in DR region

#### 3. Application Data
- **Persistent Volumes**: Daily EBS snapshots
- **Databases**: Automated RDS snapshots (if applicable)
- **Object Storage**: S3 cross-region replication

#### 4. Secrets & ConfigMaps
- **Backup**: AWS Secrets Manager with replication
- **Alternative**: Sealed Secrets committed to Git

### DR Procedures

#### Failover to DR Region (RTO: 4 hours)

```bash
# 1. Clone infrastructure to DR region
cd terraform
cp prod.tfvars dr.tfvars

# 2. Update DR configuration
# Edit dr.tfvars:
#   - region = "us-east-1"
#   - cluster_name = "opsfleet-eks-dr"

# 3. Deploy DR infrastructure
terraform workspace new dr
terraform apply -var-file=dr.tfvars

# 4. Restore application data
# Restore EBS snapshots
aws ec2 copy-snapshot \
  --source-region eu-central-1 \
  --source-snapshot-id snap-xxx \
  --destination-region us-east-1

# 5. Deploy applications
kubectl apply -f applications/

# 6. Update DNS to point to DR region
# Update Route53 or external DNS

# 7. Verify functionality
./scripts/health-check.sh
```

#### Failback to Primary Region

```bash
# 1. Ensure primary region is healthy
terraform apply -var-file=prod.tfvars

# 2. Sync data from DR to primary
# Use application-specific sync procedures

# 3. Update DNS back to primary
# Update Route53

# 4. Decommission DR (optional)
terraform workspace select dr
terraform destroy -var-file=dr.tfvars
```

### Regular DR Testing

**Monthly DR Drill:**
1. Deploy to DR region
2. Restore latest backups
3. Run smoke tests
4. Document any issues
5. Destroy DR resources

**Automated Tests:**
```bash
# Add to CI/CD
./scripts/dr-test.sh
```

### Data Backup Schedule

| Component | Frequency | Retention | Location |
|-----------|-----------|-----------|----------|
| EBS Snapshots | Daily | 30 days | Cross-region |
| Terraform State | Continuous | 90 days | S3 versioning |
| Application Configs | On change | Unlimited | Git |
| Secrets | Continuous | 90 days | Secrets Manager |

## Monitoring & Alerts

### CloudWatch Dashboards

Access at: https://console.aws.amazon.com/cloudwatch/

- Cluster CPU utilization
- Cluster memory utilization
- Node count
- Pod count
- Failed pods

### Alarms

Configured alarms (if `enable_cloudwatch_alarms = true`):

1. **High CPU**: > 80% for 10 minutes
2. **High Memory**: > 80% for 10 minutes
3. **Node Not Ready**: Any node not ready for 5 minutes

Notifications sent to SNS topic (configure email in `alarm_email_endpoints`).

### Logs

```bash
# View cluster logs
aws logs tail /aws/eks/opsfleet-eks-cluster/cluster --follow

# View Container Insights
# Go to CloudWatch Console > Container Insights
```

## Security

### Security Best Practices Implemented

✅ Private subnets for worker nodes
✅ IMDSv2 enforced
✅ Encrypted EBS volumes
✅ Encrypted Kubernetes secrets
✅ Pod Security Standards
✅ Security Hub integration
✅ Falco runtime monitoring
✅ VPC endpoints for AWS services
✅ Minimal IAM permissions (IRSA)
✅ Security groups with least privilege

### Security Scanning

```bash
# Run security scan
tfsec .

# Check for compliance
checkov -d .
```

### Secrets Management

**DO NOT** commit secrets to Git. Use:
- AWS Secrets Manager
- Sealed Secrets
- External Secrets Operator

## Cost Optimization

### Current Cost Estimates (Monthly, Development)

- EKS Control Plane: $73
- EC2 Nodes (2x t3.medium): ~$60
- NAT Gateway (1x): ~$32
- Data Transfer: ~$20
- **Total**: ~$185/month

### Cost Optimization Tips

1. **Use Spot Instances**: Set `enable_spot_instances = true` (30-70% savings)
2. **Karpenter**: Enable for dynamic scaling
3. **Single NAT**: Already enabled for dev (`single_nat_gateway = true`)
4. **Instance Sizing**: Right-size node instance types
5. **Resource Quotas**: Enabled to prevent overprovisioning
6. **Auto-shutdown**: Schedule cluster shutdown for dev environments

### Cost Monitoring

```bash
# View cost breakdown
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Environment
```

## Troubleshooting

### Common Issues

#### 1. Circular Dependency on First Apply

**Issue**: Providers can't connect to cluster that doesn't exist yet

**Solution**: Already handled with conditional data sources. If you still see issues:
```bash
terraform apply -target=module.vpc
terraform apply -target=module.eks
terraform apply  # Full apply
```

#### 2. Karpenter Not Scheduling Pods

**Check**:
```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter
kubectl describe nodepools
```

**Common fixes**:
- Verify security group tags: `karpenter.sh/discovery`
- Check IAM roles
- Verify subnet tags

#### 3. Ingress Not Working

**Check**:
```bash
kubectl get svc -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

#### 4. Nodes Not Joining Cluster

**Check**:
```bash
# Check node IAM role
aws eks describe-cluster --name opsfleet-eks-cluster

# Check security groups
kubectl get nodes
aws ec2 describe-security-groups --group-ids sg-xxx
```

### Support

- **Documentation**: This README
- **Issues**: Create GitHub issue
- **Logs**: Check CloudWatch Logs

## Maintenance

### Updating Kubernetes Version

```bash
# 1. Update variable
# Edit terraform.tfvars: cluster_version = "1.35"

# 2. Apply update (will trigger rolling update)
terraform apply -var-file=terraform.tfvars

# 3. Update node groups (done automatically by EKS)

# 4. Verify
kubectl get nodes
```

### Updating Add-ons

Add-ons auto-update to latest compatible version. To specify versions:

```hcl
addon_versions = {
  vpc_cni            = "v1.16.0-eksbuild.1"
  coredns            = "v1.10.1-eksbuild.6"
  kube_proxy         = "v1.28.2-eksbuild.2"
  aws_ebs_csi_driver = "v1.26.0-eksbuild.1"
}
```

## Contributing

1. Create feature branch
2. Make changes
3. Run `./terraform-validate.sh`
4. Submit pull request

## License

Internal use only - OpsFleet

---

**Last Updated**: 2024-11-26
**Maintained By**: DevOps Team
**Version**: 1.0.0
