# Integration tests — uses real provider, requires OIDC credentials.
#
# Prerequisites:
#   ARM_USE_OIDC=true
#   POWER_PLATFORM_TENANT_ID=<your-tenant-id>
#   POWER_PLATFORM_CLIENT_ID=<your-client-id>
#
# These tests create real resources against a Power Platform tenant.
# Resources are automatically destroyed after test completion.
#
# Required variables (set via .tfvars or TF_VAR_ environment variables):
#   host_environment_id — UUID of the Pipelines Host environment
#   pipelines_host_url  — Dataverse API URL of the Pipelines Host environment

run "creates_environment_group_with_two_environments" {
  command = apply

  variables {
    name     = "tftest-ptn-envgroup"
    location = "unitedstates"

    environments = {
      "dev" = {
        display_name     = "tftest-ptn-envgroup - Dev"
        environment_type = "Sandbox"
      }
      "prod" = {
        display_name     = "tftest-ptn-envgroup - Prod"
        environment_type = "Sandbox"
      }
    }

    dlp_policy = {
      display_name            = "tftest-ptn-envgroup - DLP"
      default_connector_group = "NonBusiness"
    }

    pipelines = {
      "main" = {
        dev_environment_key = "dev"
        stages              = [{ environment_key = "prod" }]
      }
    }
  }

  assert {
    condition     = output.group_id != ""
    error_message = "group_id should be a non-empty GUID after apply."
  }

  assert {
    condition     = output.group_display_name == "tftest-ptn-envgroup"
    error_message = "group_display_name should echo var.name."
  }

  assert {
    condition     = length(output.environments) == 2
    error_message = "Two environments should have been created."
  }

  assert {
    condition     = output.dlp_policy_id != ""
    error_message = "dlp_policy_id should be a non-empty GUID after apply."
  }

  assert {
    condition     = length(output.pipelines) == 1
    error_message = "One pipeline should have been created."
  }
}

