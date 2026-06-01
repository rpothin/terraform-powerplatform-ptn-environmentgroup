module "this" {
  source = "rpothin/ptn-environmentgroup/powerplatform"

  name        = var.name
  description = var.description
  location    = var.location

  # Four environments: two dev streams, one shared test, one production.
  environments = {
    "dev-frontend" = {
      display_name     = "${var.name} - Dev Frontend"
      environment_type = "Sandbox"
      dataverse = {
        security_group_id = var.dev_security_group_id
      }
    }
    "dev-backend" = {
      display_name     = "${var.name} - Dev Backend"
      environment_type = "Sandbox"
      dataverse = {
        security_group_id = var.dev_security_group_id
      }
    }
    "test" = {
      display_name     = "${var.name} - Test"
      environment_type = "Sandbox"
      dataverse        = {}
    }
    "prod" = {
      display_name     = "${var.name} - Prod"
      environment_type = "Production"
      dataverse        = {}
    }
  }

  dlp_policy = {
    display_name            = "${var.name} - DLP Policy"
    default_connector_group = "NonBusiness"
    business_connectors     = []
    custom_connectors_patterns = [
      {
        order            = 1
        host_url_pattern = "https://*.crm.dynamics.com"
        data_group       = "General"
      }
    ]
  }

  # Two independent pipelines: one per development stream
  pipelines = {
    "frontend" = {
      dev_environment_key = "dev-frontend"
      description         = "Frontend solution deployment pipeline"
      stages = [
        {
          environment_key = "test"
        },
        {
          environment_key                = "prod"
          require_predeployment_approval = true
        }
      ]
    }
    "backend" = {
      dev_environment_key = "dev-backend"
      description         = "Backend solution deployment pipeline"
      stages = [
        {
          environment_key = "test"
        },
        {
          environment_key                = "prod"
          require_predeployment_approval = true
        }
      ]
    }
  }

  host_environment_id  = var.host_environment_id
  pipelines_host_url   = var.pipelines_host_url
  security_group_id    = var.security_group_id
  application_admin_id = var.application_admin_id
  lifecycle_state      = var.lifecycle_state
  tags                 = var.tags
}

