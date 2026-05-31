variable "name" {
  description = <<DESCRIPTION
Base name for the environment group and all environments.
Environments are named "{name} - {display_name}" as supplied in var.environments.
Must be 1–50 characters to leave room for display name suffixes.
DESCRIPTION
  type        = string
  nullable    = false

  validation {
    condition     = length(var.name) >= 1 && length(var.name) <= 50
    error_message = "name must be between 1 and 50 characters."
  }

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name must not be empty or contain only whitespace."
  }
}

variable "description" {
  description = "Optional description of the environment group. Consumed by downstream git-integration modules as workspace_description."
  type        = string
  default     = null
}

variable "location" {
  description = "Power Platform geographic region for all environments (e.g., 'unitedstates', 'europe'). Cannot be changed after creation without recreating all environments."
  type        = string
  nullable    = false

  validation {
    condition = contains([
      "unitedstates", "europe", "asia", "australia", "japan", "india",
      "canada", "southamerica", "unitedkingdom", "france", "germany",
      "switzerland", "norway", "korea", "southafrica", "uae", "singapore",
      "sweden"
    ], var.location)
    error_message = "location must be a valid Power Platform geographic region."
  }
}

variable "environments" {
  description = <<DESCRIPTION
Map of Power Platform environments to create. Map key is a stable slot identifier (e.g., "dev", "test", "prod").
Minimum 2 environments are required to support at least one pipeline (dev + one stage).

- `display_name`      - Full display name (3–64 chars, alphanumeric/spaces/hyphens/underscores).
- `environment_type`  - "Sandbox", "Trial", or "Production". Defaults to "Sandbox".
                        All three types support environment group membership.
                        Note: changing an existing environment's type (e.g., Sandbox → Production)
                        forces replacement of that environment.
- `dataverse`         - Dataverse configuration. Defaults to `{}` (Dataverse provisioned with English / USD).
                        Cannot be null — all environment group members require Dataverse.
                        Set individual fields to override defaults.
  - `language_code`     - LCID code (e.g., 1033 for English). Defaults to 1033.
  - `currency_code`     - ISO 4217 code (e.g., "USD"). Defaults to "USD".
  - `security_group_id` - Optional Entra ID group UUID for access control. The zero UUID disables
                          access restriction and is normalized by the module when omitted.
DESCRIPTION
  type = map(object({
    display_name     = string
    environment_type = optional(string, "Sandbox")
    dataverse = optional(object({
      language_code     = optional(number, 1033)
      currency_code     = optional(string, "USD")
      security_group_id = optional(string, null)
    }), {})
  }))
  nullable = false

  validation {
    condition     = length(var.environments) >= 2
    error_message = "At least 2 environments are required (one dev + at least one stage)."
  }

  validation {
    condition     = alltrue([for k, v in var.environments : contains(["Sandbox", "Trial", "Production"], v.environment_type)])
    error_message = "All environments must use environment_type 'Sandbox', 'Trial', or 'Production'."
  }

  validation {
    condition     = alltrue([for k, v in var.environments : v.dataverse != null])
    error_message = "All environments must have dataverse configuration (use dataverse = {} for defaults). All environment group members require Dataverse."
  }

  validation {
    condition = alltrue([
      for k, v in var.environments :
      v.dataverse == null || v.dataverse.security_group_id == null ||
      can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", v.dataverse.security_group_id))
    ])
    error_message = "Each environments[*].dataverse.security_group_id must be a valid UUID when provided."
  }

}

variable "dlp_policy" {
  description = <<DESCRIPTION
DLP policy to create and scope to all environments in this group.

- `display_name`              - Display name of the DLP policy (required).
- `default_connector_group`   - Fallback classification for unknown connectors: "NonBusiness", "Business", or "Blocked".
                                Defaults to "NonBusiness".
- `business_connectors`       - Set of connectors to classify as Business (sensitive-data permitted).
- `custom_connectors_patterns`- Custom connector host URL patterns and their classification.
DESCRIPTION
  type = object({
    display_name            = string
    default_connector_group = optional(string, "NonBusiness")
    business_connectors = optional(set(object({
      id                           = string
      default_action_rule_behavior = optional(string, "")
      action_rules = optional(list(object({
        action_id = string
        behavior  = string
      })), [])
      endpoint_rules = optional(list(object({
        order    = number
        endpoint = string
        behavior = string
      })), [])
    })), [])
    custom_connectors_patterns = optional(set(object({
      order            = number
      host_url_pattern = string
      data_group       = string
    })), [])
  })
  nullable = false

  validation {
    condition     = length(var.dlp_policy.display_name) > 0
    error_message = "dlp_policy.display_name must not be empty."
  }

  validation {
    condition     = contains(["NonBusiness", "Business", "Blocked"], var.dlp_policy.default_connector_group)
    error_message = "dlp_policy.default_connector_group must be one of: NonBusiness, Business, Blocked."
  }
}

variable "pipelines" {
  description = <<DESCRIPTION
Map of deployment pipelines to create. Map key is a stable pipeline identifier (e.g., "main", "solution-a").

- `dev_environment_key` - Key from var.environments for the developer/source environment.
- `stages`              - Ordered list of deployment stages (at least 1, max 6).
  - `environment_key`                - Key from var.environments for the target stage environment.
  - `description`                    - Optional stage description.
  - `require_preexport_approval`     - Require approval before export. Defaults to false.
  - `require_predeployment_approval` - Require approval before deploy. Defaults to false.
  - `use_delegated_deployment`       - Use a delegated service principal. Defaults to false.
  - `deployment_spn_client_id`       - Azure AD client ID for delegated deployment. Required when use_delegated_deployment = true.
- `description`         - Optional pipeline description.
DESCRIPTION
  type = map(object({
    dev_environment_key = string
    stages = list(object({
      environment_key                = string
      description                    = optional(string, null)
      require_preexport_approval     = optional(bool, false)
      require_predeployment_approval = optional(bool, false)
      use_delegated_deployment       = optional(bool, false)
      deployment_spn_client_id       = optional(string, null)
    }))
    description = optional(string, null)
  }))
  nullable = false

  validation {
    condition = alltrue([
      for pk, p in var.pipelines : (
        contains(keys(var.environments), p.dev_environment_key) &&
        alltrue([for s in p.stages : contains(keys(var.environments), s.environment_key)])
      )
    ])
    error_message = "All pipeline dev_environment_key and stages[*].environment_key values must match a key in var.environments."
  }

  validation {
    condition = alltrue([
      for pk, p in var.pipelines : length(p.stages) >= 1
    ])
    error_message = "Each pipeline must have at least 1 stage."
  }

  validation {
    condition = alltrue([
      for pk, p in var.pipelines : length(p.stages) <= 6
    ])
    error_message = "Each pipeline may have at most 6 stages."
  }

  validation {
    condition = alltrue([
      for pk, p in var.pipelines :
      length(p.stages) == length(toset([for s in p.stages : s.environment_key]))
    ])
    error_message = "Pipeline stages must reference unique environment keys within each pipeline."
  }
}

variable "host_environment_id" {
  description = "The Power Platform environment ID (UUID) of the Pipelines Host environment where deployment pipeline Dataverse records will be created."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.host_environment_id))
    error_message = "host_environment_id must be a valid UUID."
  }
}

variable "pipelines_host_url" {
  description = "The Dataverse API URL for the Pipelines Host environment (e.g., https://org.crm.dynamics.com). Required for pipeline OData REST operations."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^https://[a-zA-Z0-9][a-zA-Z0-9\\-\\.]+\\.[a-zA-Z]{2,}(/.*)?$", var.pipelines_host_url))
    error_message = "pipelines_host_url must be a valid HTTPS URL."
  }
}

variable "security_group_id" {
  description = "Optional Entra ID security group UUID. When provided, it is used to share all deployment pipelines with the group (grants Deployment Pipeline User role)."
  type        = string
  default     = null

  validation {
    condition     = var.security_group_id == null || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.security_group_id))
    error_message = "security_group_id must be a valid UUID when provided."
  }
}

variable "application_admin_id" {
  description = "Optional Azure AD application (client) ID of the service principal to assign as System Administrator in every environment. Null skips the assignment."
  type        = string
  default     = null

  validation {
    condition     = var.application_admin_id == null || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.application_admin_id))
    error_message = "application_admin_id must be a valid UUID when provided."
  }
}

variable "lifecycle_state" {
  description = "Desired lifecycle state for all pipeline records. Must be 'active' or 'inactive'."
  type        = string
  default     = "active"
  nullable    = false

  validation {
    condition     = contains(["active", "inactive"], var.lifecycle_state)
    error_message = "lifecycle_state must be either 'active' or 'inactive'."
  }
}

variable "tags" {
  description = "A map of metadata tags to associate with the module deployment. Not all Power Platform resources support tags natively; these are surfaced in outputs for use by external systems."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "pipeline_validation_wait_seconds" {
  description = "Seconds to wait after registering deployment environments in the Pipelines Host before checking their validation status. The Pipelines Host validates environments asynchronously; increase this value if your host is slow to validate. Set to 0 to skip the wait (useful in tests)."
  type        = number
  default     = 15
  nullable    = false

  validation {
    condition     = var.pipeline_validation_wait_seconds >= 0 && var.pipeline_validation_wait_seconds <= 600
    error_message = "pipeline_validation_wait_seconds must be between 0 and 600."
  }
}
