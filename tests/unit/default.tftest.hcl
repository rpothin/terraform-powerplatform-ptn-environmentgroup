# Unit tests — uses mock providers, no credentials required.
# Both powerplatform and time providers are mocked.

mock_provider "powerplatform" {
  mock_resource "powerplatform_environment_group" {
    defaults = {
      id = "a1b2c3d4-0000-0000-0000-000000000001"
    }
  }

  # Mock environment ID so it is known at plan time. Without this, the
  # pipeline module's for_each (conditioned on a data source that filters
  # by environment ID) would receive "known after apply" keys and fail.
  mock_resource "powerplatform_environment" {
    defaults = {
      id = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
    }
  }

  # The res-deploymentpipeline module queries Dataverse for root business unit lookup
  # and for environment validation status. These mocks satisfy both data sources when
  # the pipeline module is instantiated in unit tests.
  mock_data "powerplatform_data_records" {
    defaults = {
      rows = [{
        businessunitid          = "22222222-2222-2222-2222-222222222222"
        deploymentenvironmentid = "11111111-1111-1111-1111-111111111111"
        validationstatus        = "200000001"
      }]
    }
  }

  mock_data "powerplatform_security_roles" {
    defaults = {
      security_roles = []
    }
  }
  # Note: powerplatform_connectors is mocked with empty defaults (no keys) so
  # the mock framework provides an empty list for connectors (the zero value).
  # This makes the DLP check block condition evaluatable during command = plan:
  # setsubtract({}, toset([])) == {} → length == 0 → true → check passes.
  # Providing connectors = [] or connectors = [{...}] causes a "found tuple"
  # type error because mock defaults don't coerce HCL tuple literals to list.
  mock_data "powerplatform_connectors" {
    defaults = {}
  }
}

mock_provider "time" {}

# ---------------------------------------------------------------------------
# Shared variable defaults reused across test runs.
# ---------------------------------------------------------------------------

variables {
  name     = "TestGroup"
  location = "unitedstates"

  environments = {
    "dev" = {
      display_name     = "TestGroup - Dev"
      environment_type = "Sandbox"
      dataverse        = {}
    }
    "uat" = {
      display_name     = "TestGroup - UAT"
      environment_type = "Sandbox"
      dataverse        = {}
    }
  }

  dlp_policy = {
    display_name            = "TestGroup - DLP"
    default_connector_group = "NonBusiness"
  }

  host_environment_id              = "a1b2c3d4-1111-1111-1111-000000000001"
  pipelines_host_url               = "https://org.crm.dynamics.com"
  pipeline_validation_wait_seconds = 0

  # Default: no pipelines so the 22 validation tests run without pipeline module overhead.
  # A separate run block below tests the happy path with a non-empty pipelines map.
  pipelines = {}
}

# ---------------------------------------------------------------------------
# Happy-path: plan succeeds with valid minimal inputs
# ---------------------------------------------------------------------------

run "plan_succeeds_with_valid_inputs" {
  command = apply

  assert {
    condition     = var.name == "TestGroup"
    error_message = "name variable should be set correctly."
  }

  assert {
    condition     = output.group_display_name == "TestGroup"
    error_message = "group_display_name output should echo var.name."
  }

  assert {
    condition     = output.workspace_name == "TestGroup"
    error_message = "workspace_name output should echo var.name."
  }

  assert {
    condition     = output.workspace_description == null
    error_message = "workspace_description should be null when not provided."
  }

  assert {
    condition     = length(output.environments) == 2
    error_message = "environments output should contain one entry per input environment."
  }

  assert {
    condition     = output.pipelines == {}
    error_message = "pipelines output should be empty when no pipelines are configured."
  }
}

# ---------------------------------------------------------------------------
# var.name validations
# ---------------------------------------------------------------------------

run "rejects_empty_name" {
  command = plan

  variables {
    name = ""
  }

  expect_failures = [var.name]
}

run "rejects_whitespace_only_name" {
  command = plan

  variables {
    name = "   "
  }

  expect_failures = [var.name]
}

run "rejects_name_over_50_chars" {
  command = plan

  variables {
    name = "12345678901234567890123456789012345678901234567890X"
  }

  expect_failures = [var.name]
}

run "accepts_name_exactly_50_chars" {
  command = apply

  variables {
    name = "12345678901234567890123456789012345678901234567890"
  }

  assert {
    condition     = length(var.name) == 50
    error_message = "50-character name should be accepted."
  }
}

# ---------------------------------------------------------------------------
# var.location validations
# ---------------------------------------------------------------------------

run "rejects_invalid_location" {
  command = plan

  variables {
    location = "mars"
  }

  expect_failures = [var.location]
}

run "accepts_sweden_location" {
  command = apply

  variables {
    location = "sweden"
  }

  assert {
    condition     = var.location == "sweden"
    error_message = "sweden should be a valid location."
  }
}

# ---------------------------------------------------------------------------
# var.environments validations
# ---------------------------------------------------------------------------

run "rejects_single_environment" {
  command = plan

  variables {
    environments = {
      "dev" = { display_name = "Only Dev", environment_type = "Sandbox", dataverse = {} }
    }
  }

  expect_failures = [var.environments]
}

run "rejects_invalid_environment_type" {
  command = plan

  variables {
    environments = {
      "dev"  = { display_name = "Dev", environment_type = "Sandbox", dataverse = {} }
      "test" = { display_name = "Test", environment_type = "Developer" }
    }
  }

  expect_failures = [var.environments]
}

run "rejects_malformed_dataverse_security_group_id" {
  command = plan

  variables {
    environments = {
      "dev" = {
        display_name = "Dev"
        dataverse    = { security_group_id = "not-a-uuid" }
      }
      "uat" = { display_name = "UAT", dataverse = {} }
    }
  }

  expect_failures = [var.environments]
}

# ---------------------------------------------------------------------------
# var.dlp_policy validations
# ---------------------------------------------------------------------------

run "rejects_empty_dlp_display_name" {
  command = plan

  variables {
    dlp_policy = {
      display_name            = ""
      default_connector_group = "NonBusiness"
    }
  }

  expect_failures = [var.dlp_policy]
}

run "rejects_invalid_dlp_default_connector_group" {
  command = plan

  variables {
    dlp_policy = {
      display_name            = "My DLP"
      default_connector_group = "NonBusiness-Invalid"
    }
  }

  expect_failures = [var.dlp_policy]
}

# ---------------------------------------------------------------------------
# var.pipelines validations
# ---------------------------------------------------------------------------

run "rejects_pipeline_with_unknown_dev_env_key" {
  command = plan

  # Cross-variable validation (var.pipelines checks var.environments keys) causes
  # plan to continue after expect_failures suppresses the error. Override the DLP
  # module to prevent its check block from being evaluated during the continued plan.
  override_module {
    target  = module.dlp_policy
    outputs = { resource_id = "00000000-0000-0000-0000-000000000000" }
  }

  variables {
    pipelines = {
      "main" = {
        dev_environment_key = "nonexistent"
        stages              = [{ environment_key = "uat" }]
      }
    }
  }

  expect_failures = [var.pipelines]
}

run "rejects_pipeline_stage_with_unknown_env_key" {
  command = plan

  # Same cross-variable validation issue as above — override DLP module.
  override_module {
    target  = module.dlp_policy
    outputs = { resource_id = "00000000-0000-0000-0000-000000000000" }
  }

  variables {
    pipelines = {
      "main" = {
        dev_environment_key = "dev"
        stages              = [{ environment_key = "staging" }]
      }
    }
  }

  expect_failures = [var.pipelines]
}

run "rejects_pipeline_with_zero_stages" {
  command = plan

  override_module {
    target  = module.dlp_policy
    outputs = { resource_id = "00000000-0000-0000-0000-000000000000" }
  }

  variables {
    pipelines = {
      "main" = {
        dev_environment_key = "dev"
        stages              = []
      }
    }
  }

  expect_failures = [var.pipelines]
}

run "rejects_pipeline_with_duplicate_stage_env_keys" {
  command = plan

  override_module {
    target  = module.dlp_policy
    outputs = { resource_id = "00000000-0000-0000-0000-000000000000" }
  }

  variables {
    pipelines = {
      "main" = {
        dev_environment_key = "dev"
        stages = [
          { environment_key = "uat" },
          { environment_key = "uat" }
        ]
      }
    }
  }

  expect_failures = [var.pipelines]
}

# ---------------------------------------------------------------------------
# var.host_environment_id validation
# ---------------------------------------------------------------------------

run "rejects_invalid_host_environment_id" {
  command = plan

  override_module {
    target  = module.dlp_policy
    outputs = { resource_id = "00000000-0000-0000-0000-000000000000" }
  }

  variables {
    host_environment_id = "not-a-uuid"
  }

  expect_failures = [var.host_environment_id]
}

# ---------------------------------------------------------------------------
# var.pipelines_host_url validation
# ---------------------------------------------------------------------------

run "rejects_http_pipelines_host_url" {
  command = plan

  override_module {
    target  = module.dlp_policy
    outputs = { resource_id = "00000000-0000-0000-0000-000000000000" }
  }

  variables {
    pipelines_host_url = "http://org.crm.dynamics.com"
  }

  expect_failures = [var.pipelines_host_url]
}

# ---------------------------------------------------------------------------
# var.security_group_id validation
# ---------------------------------------------------------------------------

run "rejects_malformed_security_group_id" {
  command = plan

  override_module {
    target  = module.dlp_policy
    outputs = { resource_id = "00000000-0000-0000-0000-000000000000" }
  }

  variables {
    security_group_id = "not-a-uuid"
  }

  expect_failures = [var.security_group_id]
}

run "accepts_null_security_group_id" {
  command = apply

  variables {
    security_group_id = null
  }

  assert {
    condition     = var.security_group_id == null
    error_message = "null security_group_id should be accepted."
  }
}

# ---------------------------------------------------------------------------
# var.lifecycle_state validation
# ---------------------------------------------------------------------------

run "rejects_invalid_lifecycle_state" {
  command = plan

  override_module {
    target  = module.dlp_policy
    outputs = { resource_id = "00000000-0000-0000-0000-000000000000" }
  }

  variables {
    lifecycle_state = "deleted"
  }

  expect_failures = [var.lifecycle_state]
}

# ---------------------------------------------------------------------------
# Output assertions
# ---------------------------------------------------------------------------

run "workspace_description_echoes_variable" {
  command = apply

  variables {
    description = "My workspace description"
  }

  assert {
    condition     = output.workspace_description == "My workspace description"
    error_message = "workspace_description should echo var.description."
  }
}

# ---------------------------------------------------------------------------
# var.environments environment_type validations
# ---------------------------------------------------------------------------

run "accepts_production_environment_type" {
  command = apply

  variables {
    environments = {
      "dev" = { display_name = "Dev", environment_type = "Sandbox", dataverse = {} }
      "prod" = {
        display_name     = "Prod"
        environment_type = "Production"
        dataverse        = { security_group_id = "cccccccc-cccc-cccc-cccc-cccccccccccc" }
      }
    }
  }

  assert {
    condition     = var.environments["prod"].environment_type == "Production"
    error_message = "Production environment_type should be accepted."
  }
}

# ---------------------------------------------------------------------------
# Pipeline happy-path
# ---------------------------------------------------------------------------

run "plan_succeeds_with_pipeline" {
  # override_module isolates the pipeline child module for unit testing: bypasses the
  # local-exec sleep provisioner (Unix-only) and avoids needing a real Pipelines Host.
  # This validates that a non-empty pipelines map produces correct output structure.
  command = apply

  variables {
    pipelines = {
      "main" = {
        dev_environment_key = "dev"
        stages              = [{ environment_key = "uat" }]
      }
    }
  }

  override_module {
    target = module.pipelines["main"]
    outputs = {
      pipeline_id                = "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee"
      pipeline_name              = "TestGroup - main"
      deployment_stage_ids       = { "uat" = "ffffffff-ffff-ffff-ffff-ffffffffffff" }
      deployment_environment_ids = { "uat" = "gggggggg-gggg-gggg-gggg-gggggggggggg" }
    }
  }

  assert {
    condition     = length(output.pipelines) == 1
    error_message = "pipelines output should contain one entry."
  }

  assert {
    condition     = contains(keys(output.pipelines), "main")
    error_message = "pipelines output should contain the 'main' pipeline key."
  }

  assert {
    condition     = output.pipelines["main"].pipeline_id == "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee"
    error_message = "pipeline_id should match the mocked value."
  }

  assert {
    condition     = length(output.pipelines["main"].ordered_stages) == 1
    error_message = "ordered_stages should have one entry matching the single stage."
  }
}

