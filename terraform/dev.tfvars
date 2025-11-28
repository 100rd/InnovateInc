# ============================================================================
# Development Environment Configuration
# ============================================================================

# General Configuration
region      = "eu-central-1"
environment = "dev"
project     = "opsfleet"
owner       = "DevOps Team"
ticket      = ""
cost_center = "engineering"

# VPC Configuration
vpc_cidr           = "10.0.0.0/16"
azs                = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
single_nat_gateway = true # Cost optimization for dev
enable_ipv6        = false
enable_private_dns = false

# EKS Cluster Configuration
cluster_name    = "opsfleet-eks-dev"
cluster_version = "1.34"

# Public endpoint restricted to your current IP (SECURITY FIX APPLIED!)
cluster_endpoint_public_access_cidrs = ["84.40.153.98/32"] # Your current IP - update if it changes

cluster_enabled_log_types  = ["api", "audit", "authenticator", "controllerManager", "scheduler"] # All logs enabled!
cluster_log_retention_days = 7 # Shorter retention for dev

# Node Groups Configuration
enable_spot_instances = false # Disable spot for dev stability

node_group_initial_config = {
  instance_types = ["t3.micro"]  # Free tier: 1 vCPU, 1GB RAM (750 hours/month)
  min_size       = 1             # Keep costs low
  max_size       = 2
  desired_size   = 1
  disk_size      = 20            # Within 30GB free tier limit
  # NOTE: t3.micro is tight - disable Karpenter controller to save resources
  # System pods need ~800MB, leaving ~200MB for workloads
}

node_group_spot_config = {
  instance_types = ["t3.medium", "t3a.medium"]
  min_size       = 0
  max_size       = 5
  desired_size   = 0
  disk_size      = 50
}

# Add-ons
enable_cluster_addons = true

# Karpenter Configuration
enable_karpenter      = true  # ✅ Enabled for x86/ARM64 autoscaling
karpenter_enable_spot = true  # ✅ Use spot instances for cost savings
karpenter_cpu_limit   = 10    # ✅ Low limit for free tier (only provisions when needed)

# Monitoring Configuration
enable_cloudwatch_monitoring = true
enable_cloudwatch_alarms     = false # Disabled for dev

alarm_email_endpoints = []

# Ingress Configuration
enable_nginx_ingress = true
nginx_use_nlb        = true
nginx_nlb_internal   = false

# External DNS Configuration
enable_external_dns         = false # Disabled for dev
external_dns_domain_filters = []
route53_zone_id             = ""

# Security Configuration
enable_security_hub        = false # Disabled for dev to reduce costs
enable_pod_security_policy = true
enable_falco               = false # Disabled for dev

# ArgoCD Configuration
enable_argocd = false # Enable if needed

# Resource Quotas
enable_resource_quotas = true

default_namespace_quotas = {
  requests_cpu    = "50"
  requests_memory = "100Gi"
  limits_cpu      = "100"
  limits_memory   = "200Gi"
}

# S3 Backend
state_bucket_prefix = "opsfleet-terraform-state"
create_state_bucket = false  # ✅ Bucket already created and state migrated to S3
