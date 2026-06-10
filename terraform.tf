terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    powerplatform = {
      source  = "microsoft/power-platform"
      version = "~> 4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }
}
