terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.88.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
}
