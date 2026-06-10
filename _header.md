# ptn-environmentgroup

[![Terraform Registry](https://img.shields.io/badge/Terraform-Registry-blue.svg)](https://registry.terraform.io/modules/rpothin/ptn-environmentgroup/powerplatform)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A **pattern module** that creates a fully governed, ALM-ready Power Platform environment group in a single declaration:

- **Environment group container** (`powerplatform_environment_group`)
- **N environments** — one per entry in `var.environments`, each auto-joined to the group
- **DLP policy** — scoped to all environments in the group
- **M deployment pipelines** — one per entry in `var.pipelines`, supporting multi-solution architectures

The module enforces a 30-second provisioning buffer between environment creation and DLP/pipeline registration to work around Power Platform backend setup latency.

