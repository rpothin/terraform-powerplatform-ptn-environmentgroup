# Integration tests — uses real provider, requires OIDC credentials.
#
# Prerequisites:
#   POWER_PLATFORM_USE_OIDC=true
#   POWER_PLATFORM_TENANT_ID=<your-tenant-id>
#   POWER_PLATFORM_CLIENT_ID=<your-client-id>
#
# These tests create real resources against a Power Platform tenant.
# Resources are automatically destroyed after test completion.
#
# Required variables (set via .tfvars or TF_VAR_ environment variables):
#   host_environment_id — UUID of the Pipelines Host environment
#   pipelines_host_url  — Dataverse API URL of the Pipelines Host environment
#
# Tenant requirements:
#   - Managed Environments premium licensing (required for environment group membership
#     with managed_environment_enabled = true; see res-environment Troubleshooting).
#   - Power Platform Pipelines solution installed in the Pipelines Host environment.

variables {
  # Use per-run timestamps so Dataverse domain names do not collide with prior CI runs.
  name     = format("tftest-ptn-envgroup-%s", formatdate("YYYYMMDDhhmmss", timestamp()))
  location = "unitedstates"

  environments = {
    "dev" = {
      display_name     = format("tfdev%s", substr(md5(timestamp()), 0, 6))
      environment_type = "Sandbox"
      dataverse        = {}
    }
    "prod" = {
      display_name     = format("tfprd%s", substr(md5(timestamp()), 0, 6))
      environment_type = "Sandbox"
      dataverse        = {}
    }
  }

  dlp_policy = {
    display_name            = format("tftest-ptn-envgroup-dlp-%s", formatdate("YYYYMMDDhhmmss", timestamp()))
    default_connector_group = "NonBusiness"
  }
}

run "creates_environment_group_with_environments_dlp_and_pipeline" {
  command = apply

  variables {
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
    condition     = startswith(output.group_display_name, "tftest-ptn-envgroup-")
    error_message = "group_display_name should include the integration test prefix."
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

  assert {
    condition     = output.pipelines["main"].pipeline_id != ""
    error_message = "pipelines[main].pipeline_id should be a non-empty GUID after apply."
  }

  assert {
    condition     = length(output.pipelines["main"].ordered_stages) == 1
    error_message = "pipelines[main] should have one ordered stage."
  }
}
