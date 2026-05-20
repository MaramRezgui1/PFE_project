variable "project_id" {
  description = "ID du projet GCP"
  default     = "maram-pfe-495314"
}

variable "region" {
  description = "Région des ressources"
  default     = "europe-west9"
}

variable "credentials_file" {
  description = "Chemin vers le fichier JSON du service account GCP"
  default     = "~/.config/gcloud/terraform-deployer-key.json"
}

variable "github_repo" {
  description = "GitHub repository in the format owner/repo (e.g. maram/login-page-replicator)"
  type        = string
}

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service"
  type        = string
  default     = "login-page-app"
}