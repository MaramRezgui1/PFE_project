variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "sahar-pfe"
}

variable "project_number" {
  description = "GCP project number"
  type        = string
  default     = "94773365692"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "app_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "my-app"
}

variable "artifact_registry_repo" {
  description = "Artifact Registry repository name"
  type        = string
  default     = "my-repo"
}

variable "service_account_name" {
  description = "Service account name for deployments"
  type        = string
  default     = "cloud-run-deployer"
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format"
  type        = string
  default     = "saharhamraoui/login-page-replicator"
}

variable "wif_pool_id" {
  description = "Workload Identity Pool ID"
  type        = string
  default     = "github-pool"
}

variable "wif_provider_id" {
  description = "Workload Identity Provider ID"
  type        = string
  default     = "github-provider"
}
