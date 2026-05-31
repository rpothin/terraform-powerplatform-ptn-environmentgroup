output "group_id" {
  description = "The GUID of the Power Platform environment group."
  value       = powerplatform_environment_group.this.id
}

output "group_display_name" {
  description = "The display name of the environment group (echoes var.name)."
  value       = var.name
}

output "environments" {
  description = <<DESCRIPTION
Map of slot key → environment details. This is the primary interface contract consumed by extension modules.

Each entry contains:
- `id`            - Power Platform environment ID (UUID)
- `display_name`  - Environment display name
- `type`          - Environment type ("Sandbox", "Trial", or "Production")
- `dataverse_url` - Dataverse organisation URL (null if no Dataverse was provisioned)
- `location`      - Power Platform region (echoes var.location)
DESCRIPTION
  value = {
    for k, v in module.environments : k => {
      id            = v.environment_id
      display_name  = v.environment_display_name
      type          = var.environments[k].environment_type
      dataverse_url = v.environment_url
      location      = var.location
    }
  }
}

output "pipelines" {
  description = <<DESCRIPTION
Map of pipeline key → pipeline details.

Each entry contains:
- `pipeline_id`                - Deployment pipeline record GUID
- `pipeline_name`              - Display name of the pipeline
- `deployment_stage_ids`       - Map of environment_key → deployment stage GUID (O(1) lookup)
- `deployment_environment_ids` - Map of environment_key → deployment environment GUID
- `ordered_stages`             - Ordered list of stages preserving the sequence from var.pipelines.
  Each entry: { environment_key, stage_id, deployment_environment_id }
  Use this when promotion order matters; maps are unordered in Terraform.
DESCRIPTION
  value = {
    for k, v in module.pipelines : k => {
      pipeline_id                = v.pipeline_id
      pipeline_name              = v.pipeline_name
      deployment_stage_ids       = v.deployment_stage_ids
      deployment_environment_ids = v.deployment_environment_ids
      ordered_stages = [
        for stage in var.pipelines[k].stages : {
          environment_key           = stage.environment_key
          stage_id                  = v.deployment_stage_ids[stage.environment_key]
          deployment_environment_id = v.deployment_environment_ids[stage.environment_key]
        }
      ]
    }
  }
}

output "dlp_policy_id" {
  description = "The GUID of the DLP policy scoped to all environments in this group."
  value       = module.dlp_policy.resource_id
}

output "workspace_name" {
  description = "The workspace name (echoes var.name). Semantic contract consumed by git-integration modules."
  value       = var.name
}

output "workspace_description" {
  description = "The workspace description (echoes var.description). Semantic contract consumed by git-integration modules."
  value       = var.description
}

output "tags" {
  description = "The metadata tags passed to this module (echoes var.tags). Power Platform resources do not natively support tags; this output surfaces the values for use by external systems or wrapper modules."
  value       = var.tags
}
