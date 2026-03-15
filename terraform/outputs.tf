output "cloud_run_url" {
  description = "Public URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.app.uri
}

output "artifact_registry_image" {
  description = "Full image path in Artifact Registry"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repo}/${var.app_name}:latest"
}

output "service_account_email" {
  description = "Service account email used by GitHub Actions"
  value       = google_service_account.deployer.email
}

output "wif_provider" {
  description = "Workload Identity Provider resource name (use as WIF_PROVIDER secret in GitHub)"
  value       = google_iam_workload_identity_pool_provider.github.name
}
