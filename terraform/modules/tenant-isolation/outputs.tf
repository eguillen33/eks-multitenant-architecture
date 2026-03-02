output "vpc_id" {
  description = "ID of the tenant VPC"
  value       = aws_vpc.tenant.id
}

output "vpc_cidr" {
  description = "CIDR block of the tenant VPC"
  value       = aws_vpc.tenant.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets (for EKS nodes)"
  value       = aws_subnet.private[*].id
}

output "data_subnet_ids" {
  description = "IDs of data subnets (for RDS, isolated from internet)"
  value       = aws_subnet.data[*].id
}

output "eks_nodes_security_group_id" {
  description = "Security group ID for EKS worker nodes"
  value       = aws_security_group.eks_nodes.id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS instances"
  value       = aws_security_group.rds.id
}

output "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "tenant_admin_role_arn" {
  description = "ARN of the tenant admin IAM role (for aws-auth ConfigMap)"
  value       = aws_iam_role.tenant_admin.arn
}

output "nat_gateway_ips" {
  description = "Elastic IPs of NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}