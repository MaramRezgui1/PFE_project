output "service_account_email" {
  description = "Email of the GitHub Actions service account"
  value       = google_service_account.github_actions.email
}

output "github_actions_cd_service_account_email" {
  description = "Email of the GitHub Actions CI/CD service account"
  value       = google_service_account.github_actions_cd.email
}

# ── Values needed for GitHub Secrets ──────────────────────────────────────────

output "wif_provider" {
  description = "Workload Identity Federation provider (use as GitHub Secret WIF_PROVIDER)"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "wif_service_account" {
  description = "Service account email for WIF (use as GitHub Secret WIF_SERVICE_ACCOUNT)"
  value       = google_service_account.github_actions_cd.email
}
