# ============================================================================
# Outputs
# ============================================================================

# Cluster Outputs
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "cluster_platform_version" {
  description = "EKS cluster platform version"
  value       = module.eks.cluster_platform_version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = module.eks.oidc_provider_arn
}

# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.natgw_ids
}

# Security Group Outputs
output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_primary_security_group_id" {
  description = "The cluster primary security group ID created by the EKS service"
  value       = module.eks.cluster_primary_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

# Node Group Outputs
output "eks_managed_node_groups" {
  description = "Map of EKS managed node groups"
  value       = module.eks.eks_managed_node_groups
  sensitive   = true
}

output "eks_managed_node_groups_autoscaling_group_names" {
  description = "List of the autoscaling group names"
  value       = module.eks.eks_managed_node_groups_autoscaling_group_names
}

# Karpenter Outputs
output "karpenter_irsa_role_arn" {
  description = "Karpenter IRSA role ARN"
  value       = try(module.karpenter[0].iam_role_arn, null)
}

output "karpenter_instance_profile_name" {
  description = "Karpenter node instance profile name"
  value       = try(module.karpenter[0].node_instance_profile_name, null)
}

output "karpenter_node_iam_role_name" {
  description = "Karpenter node IAM role name"
  value       = try(module.karpenter[0].node_iam_role_name, null)
}

output "karpenter_sqs_queue_name" {
  description = "Karpenter SQS queue name"
  value       = try(module.karpenter[0].queue_name, null)
}

# CloudWatch Outputs
output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for EKS cluster"
  value       = module.eks.cloudwatch_log_group_name
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch log group ARN for EKS cluster"
  value       = module.eks.cloudwatch_log_group_arn
}

output "cloudwatch_alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  value       = try(aws_sns_topic.cloudwatch_alarms[0].arn, var.alarm_sns_topic_arn, null)
}

# S3 State Bucket Output
output "terraform_state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  value       = try(aws_s3_bucket.terraform_state[0].id, local.state_bucket_name)
}

output "terraform_state_bucket_arn" {
  description = "S3 bucket ARN for Terraform state"
  value       = try(aws_s3_bucket.terraform_state[0].arn, null)
}

# Ingress Outputs
output "nginx_ingress_controller_loadbalancer" {
  description = "NGINX Ingress Controller Load Balancer hostname (if deployed)"
  value       = var.enable_nginx_ingress ? "Check with: kubectl get svc -n ingress-nginx" : null
}

# Configure kubectl command
output "configure_kubectl" {
  description = "Command to configure kubectl for the EKS cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

# Region and Account Info
output "aws_region" {
  description = "AWS region"
  value       = var.region
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

# Tags Output
output "common_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
}
