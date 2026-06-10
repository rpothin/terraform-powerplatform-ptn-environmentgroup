output "group_id" {
  description = "The GUID of the environment group."
  value       = module.this.group_id
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
  description = "Map of pipeline key → pipeline details."
  value       = module.this.pipelines
}

