variable "name" {
  description = "Base name for the environment group and all resources. Used as prefix for display names."
  type        = string
  default     = "MyProject"
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

