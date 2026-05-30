locals {
  # Map of slot key → environment ID, resolved at apply time.
  # Used as argument values only — never as for_each keys — so unknown-until-apply is safe.
  environment_ids = {
    for k, v in module.environments : k => v.environment_id
  }

  # Translate the ptn-module's friendly connector group names to the values
  # expected by res-dlppolicy (which inherits the provider's internal naming).
  dlp_default_classification = {
    "NonBusiness" = "General"
    "Business"    = "Confidential"
    "Blocked"     = "Blocked"
  }[var.dlp_policy.default_connector_group]
}
