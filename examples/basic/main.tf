# Registry source: derived from the repo name — strip the "terraform-powerplatform-" prefix.
# e.g. terraform-powerplatform-res-environment → rpothin/res-environment/powerplatform
# Set this during module initialization. No version pin — always resolves to latest.
module "this" {
  source = "rpothin/ptn-environmentgroup/powerplatform"

  name     = var.name
  location = var.location
}
