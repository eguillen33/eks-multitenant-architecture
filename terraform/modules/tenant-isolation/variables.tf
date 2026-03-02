variable "tenant_name" {
  description = "Unique identifier for the tenant (e.g., 'guillen-healthcare'). Used in resource naming and tagging"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.tenant_name))
    error_message = "Tenant name must be lowercase alphanumeric with hyphens only"
  }
}

variable "environment" {
  description = "Environment name (e.g., 'prod', 'staging')"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the tenant VPC (e.g., '10.1.0.0/16')"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block"
  }
}

variable "azs" {
  description = "List of availability zones to use (exactly 2)"
  type        = list(string)

  validation {
    condition     = length(var.azs) == 2
    error_message = "Exactly 2 availability zones must be specifie."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}