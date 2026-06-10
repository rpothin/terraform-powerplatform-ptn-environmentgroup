module "this" {
  source = "rpothin/ptn-environmentgroup/powerplatform"

  name     = var.name
  location = var.location

  environments = {
    "dev" = {
      display_name     = "${var.name} - Dev"
      environment_type = "Sandbox"
      dataverse        = {}
    }
    "uat" = {
      display_name     = "${var.name} - UAT"
      environment_type = "Sandbox"
      dataverse        = {}
    }
  }

  dlp_policy = {
    display_name            = "${var.name} - DLP Policy"
    default_connector_group = "NonBusiness"
  }

  pipelines = {
    "main" = {
      dev_environment_key = "dev"
      stages = [
        {
          environment_key                = "uat"
          require_predeployment_approval = true
        }
      ]
    }
  }

  host_environment_id = var.host_environment_id
  pipelines_host_url  = var.pipelines_host_url
}

