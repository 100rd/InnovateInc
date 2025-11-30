# ============================================================================
# General Configuration
# ============================================================================

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "opsfleet"
}

variable "owner" {
  description = "Owner or team responsible"
  type        = string
  default     = ""
}

variable "ticket" {
  description = "Ticket number or reference"
  type        = string
  default     = ""
}

variable "cost_center" {
  description = "Cost center code"
  type        = string
  default     = ""
}

# ============================================================================
# VPC Configuration
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of availability zones for the VPC"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets (cost optimization)"
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "enable_ipv6" {
  description = "Enable IPv6 for the VPC"
  type        = bool
  default     = false
}

variable "enable_private_dns" {
  description = "Enable private DNS for the VPC"
  type        = bool
  default     = false
}

# ============================================================================
# EKS Cluster Configuration
# ============================================================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "opsfleet-eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.34"
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to the cluster endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Enable private access to the cluster endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the EKS cluster endpoint publicly"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_cluster_encryption" {
  description = "Enable encryption for Kubernetes secrets"
  type        = bool
  default     = true
}

variable "cluster_enabled_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_log_retention_days" {
  description = "Number of days to retain cluster logs"
  type        = number
  default     = 90
}

# ============================================================================
# EKS Node Groups Configuration
# ============================================================================

variable "enable_spot_instances" {
  description = "Enable spot instances for node groups"
  type        = bool
  default     = false
}

variable "node_group_initial_config" {
  description = "Configuration for initial node group"
  type = object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = number
  })
  default = {
    instance_types = ["t3.micro"]
    min_size       = 2
    max_size       = 4
    desired_size   = 2
    disk_size      = 50
  }
}

variable "node_group_spot_config" {
  description = "Configuration for spot node group"
  type = object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = number
  })
  default = {
    instance_types = ["t3.micro"]
    min_size       = 0
    max_size       = 10
    desired_size   = 0
    disk_size      = 50
  }
}

# ============================================================================
# EKS Add-ons Configuration
# ============================================================================

variable "enable_cluster_addons" {
  description = "Enable EKS cluster add-ons"
  type        = bool
  default     = true
}

variable "addon_versions" {
  description = "Versions for EKS add-ons (leave null for latest)"
  type = object({
    vpc_cni            = string
    coredns            = string
    kube_proxy         = string
    aws_ebs_csi_driver = string
  })
  default = {
    vpc_cni            = null
    coredns            = null
    kube_proxy         = null
    aws_ebs_csi_driver = null
  }
}

# ============================================================================
# Karpenter Configuration
# ============================================================================

variable "enable_karpenter" {
  description = "Enable Karpenter for cluster autoscaling"
  type        = bool
  default     = true
}

variable "karpenter_version" {
  description = "Version of Karpenter to deploy"
  type        = string
  default     = "1.8.1"
}

variable "karpenter_enable_spot" {
  description = "Allow Karpenter to provision spot instances"
  type        = bool
  default     = false
}

variable "karpenter_cpu_limit" {
  description = "Maximum CPU cores that Karpenter can provision"
  type        = number
  default     = 1000
}

# ============================================================================
# Monitoring Configuration
# ============================================================================

variable "enable_cloudwatch_monitoring" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for EKS cluster"
  type        = bool
  default     = true
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms (leave empty to create new)"
  type        = string
  default     = ""
}

variable "alarm_email_endpoints" {
  description = "Email addresses to receive CloudWatch alarms"
  type        = list(string)
  default     = []
}

# ============================================================================
# Ingress Configuration
# ============================================================================

variable "enable_nginx_ingress" {
  description = "Enable NGINX ingress controller"
  type        = bool
  default     = true
}

variable "nginx_ingress_version" {
  description = "Version of NGINX ingress controller"
  type        = string
  default     = "4.11.3"
}

variable "nginx_use_nlb" {
  description = "Use NLB for NGINX ingress (vs ALB)"
  type        = bool
  default     = true
}

variable "nginx_nlb_internal" {
  description = "Make NLB internal (vs internet-facing)"
  type        = bool
  default     = false
}

# ============================================================================
# External DNS Configuration
# ============================================================================

variable "enable_external_dns" {
  description = "Enable external-dns for Route53 integration"
  type        = bool
  default     = true
}

variable "external_dns_version" {
  description = "Version of external-dns"
  type        = string
  default     = "1.15.0"
}

variable "external_dns_domain_filters" {
  description = "List of domains to manage with external-dns"
  type        = list(string)
  default     = []
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for external-dns"
  type        = string
  default     = ""
}

# ============================================================================
# Security Configuration
# ============================================================================

variable "enable_security_hub" {
  description = "Enable AWS Security Hub integration"
  type        = bool
  default     = true
}

variable "enable_pod_security_policy" {
  description = "Enable Pod Security Policy"
  type        = bool
  default     = true
}

variable "enable_falco" {
  description = "Enable Falco runtime security"
  type        = bool
  default     = true
}

variable "falco_version" {
  description = "Version of Falco"
  type        = string
  default     = "4.11.0"
}

# ============================================================================
# ArgoCD Configuration
# ============================================================================

variable "enable_argocd" {
  description = "Enable ArgoCD for GitOps"
  type        = bool
  default     = false
}

variable "argocd_version" {
  description = "Version of ArgoCD"
  type        = string
  default     = "7.7.5"
}

variable "argocd_admin_password" {
  description = "Admin password for ArgoCD (leave empty for auto-generated)"
  type        = string
  default     = ""
  sensitive   = true
}

# ============================================================================
# Resource Quotas Configuration
# ============================================================================

variable "enable_resource_quotas" {
  description = "Enable Kubernetes resource quotas"
  type        = bool
  default     = true
}

variable "default_namespace_quotas" {
  description = "Default resource quotas for namespaces"
  type = object({
    requests_cpu    = string
    requests_memory = string
    limits_cpu      = string
    limits_memory   = string
  })
  default = {
    requests_cpu    = "100"
    requests_memory = "200Gi"
    limits_cpu      = "200"
    limits_memory   = "400Gi"
  }
}

# ============================================================================
# S3 Backend Configuration
# ============================================================================

variable "state_bucket_prefix" {
  description = "Prefix for the S3 state bucket name"
  type        = string
  default     = "opsfleet-terraform-state"
}

variable "create_state_bucket" {
  description = "Create S3 bucket for Terraform state"
  type        = bool
  default     = true
}
