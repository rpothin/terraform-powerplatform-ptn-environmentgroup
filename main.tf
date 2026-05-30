# ============================================================================
# ENVIRONMENT GROUP
# ============================================================================

resource "powerplatform_environment_group" "this" {
  display_name = var.name
  description  = var.description != null ? var.description : ""
}

# ============================================================================
# ENVIRONMENTS
# ============================================================================

module "environments" {
  source   = "rpothin/res-environment/powerplatform"
  for_each = var.environments

  environment = {
    display_name         = each.value.display_name
    location             = var.location
    environment_type     = each.value.environment_type
    environment_group_id = lower(powerplatform_environment_group.this.id)
  }

  managed_environment_enabled = false
  application_admin_id        = var.application_admin_id != null ? lower(var.application_admin_id) : null

  dataverse = each.value.dataverse == null ? null : {
    language_code     = try(each.value.dataverse.language_code, 1033)
    currency_code     = try(each.value.dataverse.currency_code, "USD")
    security_group_id = each.value.dataverse.security_group_id != null ? lower(each.value.dataverse.security_group_id) : "00000000-0000-0000-0000-000000000000"
  }

  depends_on = [powerplatform_environment_group.this]
}

# ============================================================================
# PROVISIONING BUFFER
# Power Platform environments need backend setup time before DLP and pipeline
# registration can reliably target them.
# ============================================================================

resource "time_sleep" "provisioning_buffer" {
  create_duration = "30s"

  triggers = {
    environment_ids = join(",", sort([for k, v in module.environments : v.environment_id]))
  }

  depends_on = [module.environments]
}

# ============================================================================
# DLP POLICY
# Scoped to all environments in this group.
# ============================================================================

module "dlp_policy" {
  source = "rpothin/res-dlppolicy/powerplatform"

  display_name                      = var.dlp_policy.display_name
  default_connectors_classification = local.dlp_default_classification
  environment_type                  = "OnlyEnvironments"
  environments                      = [for k, v in module.environments : lower(v.environment_id)]

  business_connectors        = var.dlp_policy.business_connectors
  custom_connectors_patterns = var.dlp_policy.custom_connectors_patterns

  depends_on = [time_sleep.provisioning_buffer]
}

# ============================================================================
# DEPLOYMENT PIPELINES
# One pipeline module instance per entry in var.pipelines.
# ============================================================================

module "pipelines" {
  source   = "rpothin/res-deploymentpipeline/powerplatform"
  for_each = var.pipelines

  dev_environment_key = each.value.dev_environment_key

  # Build the environments map for this specific pipeline: dev env + all stage envs.
  environments = {
    for env_key in toset(concat(
      [each.value.dev_environment_key],
      [for s in each.value.stages : s.environment_key]
      )) : env_key => {
      id   = lower(local.environment_ids[env_key])
      name = module.environments[env_key].environment_display_name
    }
  }

  pipeline_name        = "${var.name} - ${each.key}"
  pipeline_description = each.value.description

  pipeline_stages = [
    for stage in each.value.stages : {
      environment_key                = stage.environment_key
      description                    = stage.description
      require_preexport_approval     = stage.require_preexport_approval
      require_predeployment_approval = stage.require_predeployment_approval
      use_delegated_deployment       = stage.use_delegated_deployment
      deployment_spn_client_id       = stage.deployment_spn_client_id != null ? lower(stage.deployment_spn_client_id) : null
    }
  ]

  host_environment_id     = lower(var.host_environment_id)
  pipelines_host_url      = var.pipelines_host_url
  security_group_id       = var.security_group_id != null ? lower(var.security_group_id) : null
  lifecycle_state         = var.lifecycle_state
  validation_wait_seconds = var.pipeline_validation_wait_seconds

  depends_on = [time_sleep.provisioning_buffer]
}
