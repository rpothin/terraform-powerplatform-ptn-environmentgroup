output "group_id" {
  description = "The GUID of the environment group."
  value       = module.this.group_id
}

output "group_display_name" {
  description = "The display name of the environment group."
  value       = module.this.group_display_name
}

output "environments" {
  description = "Map of slot key → environment details."
  value       = module.this.environments
}

output "dlp_policy_id" {
  description = "The GUID of the DLP policy."
  value       = module.this.dlp_policy_id
}

output "pipelines" {
  description = "Map of pipeline key → pipeline details including ordered stages."
  value       = module.this.pipelines
}

output "workspace_name" {
  description = "The workspace name. Semantic contract consumed by git-integration modules."
  value       = module.this.workspace_name
}

