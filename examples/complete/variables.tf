variable "name" {
  description = "Base name for the environment group. Used as prefix for all display names."
  type        = string
  default     = "CustomerPortal"
}

variable "description" {
  description = "Optional description of the environment group."
  type        = string
  default     = "Customer Portal - multi-solution ALM environment group"
}

variable "location" {
  description = "Power Platform geographic region for all environments."
  type        = string
  default     = "unitedstates"
}

variable "host_environment_id" {
  description = "UUID of the Pipelines Host environment."
  type        = string
}

variable "pipelines_host_url" {
  description = "Dataverse API URL of the Pipelines Host environment."
  type        = string
}

variable "security_group_id" {
  description = "Optional Entra ID security group UUID for pipeline sharing access."
  type        = string
  default     = null
}

variable "dev_security_group_id" {
  description = "Optional Entra ID security group UUID to restrict access to development environments."
  type        = string
  default     = null
}

variable "application_admin_id" {
  description = "Optional Azure AD service principal UUID for environment admin role."
  type        = string
  default     = null
}

variable "lifecycle_state" {
  description = "Lifecycle state for all pipeline records: 'active' or 'inactive'."
  type        = string
  default     = "active"
}

variable "tags" {
  description = "Metadata tags for the deployment."
  type        = map(string)
  default = {
    environment = "development"
    project     = "customer-portal"
    managed_by  = "terraform"
  }
}

