output "workload_identity_provider" {
  description = "Full identifier of the Workload Identity Provider for GitHub Actions"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "service_account_email" {
  description = "Email of the GitHub Actions service account"
  value       = google_service_account.github_actions.email
}