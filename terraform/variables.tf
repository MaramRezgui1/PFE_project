variable "project_id" {
  description = "ID du projet GCP"
  default     = "maram-pfe"
}

variable "region" {
  description = "Région des ressources"
  default     = "europe-west9"
}

variable "credentials_file" {
  description = "Chemin vers le fichier JSON du service account GCP"
  default     = "~/.config/gcloud/application_default_credentials.json"
}

variable "github_repo" {
  description = "GitHub repository in the format owner/repo (e.g. maram/login-page-replicator)"
  type        = string
}
