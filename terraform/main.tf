# 0. Enable required Google Cloud APIs
resource "google_project_service" "required" {
  for_each = toset([
    "container.googleapis.com",           # GKE
    "artifactregistry.googleapis.com",    # Artifact Registry
    "iap.googleapis.com",                 # Identity-Aware Proxy
    "iam.googleapis.com",                 # IAM
    "cloudresourcemanager.googleapis.com", # Cloud Resource Manager
    "run.googleapis.com",                 # Cloud Run
    "servicenetworking.googleapis.com",   # Service Networking
  ])

  service            = each.value
  disable_on_destroy = false
}

# 1. Création du réseau VPC
resource "google_compute_network" "vpc_network" {
  name                    = "maram-vpc"
  auto_create_subnetworks = false
}

# 2. Sous-réseau avec secondary ranges (obligatoire pour GKE Autopilot VPC-native)
resource "google_compute_subnetwork" "subnetwork" {
  name          = "maram-subnet"
  ip_cidr_range = "10.0.0.0/22"
  region        = var.region
  network       = google_compute_network.vpc_network.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.4.0.0/14"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.8.0.0/20"
  }
}

# 3. Création du Cluster GKE Autopilot
resource "google_container_cluster" "primary" {
  name     = "maram-cluster-terraform"
  location = var.region

  # Active le mode Autopilot
  enable_autopilot = true

  network    = google_compute_network.vpc_network.name
  subnetwork = google_compute_subnetwork.subnetwork.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Optionnel : suppression de la protection contre la suppression pour un PFE
  deletion_protection = false
}

# 4. Service Account for GitHub Actions CI/CD
resource "google_service_account" "github_actions" {
  account_id   = "github-actions-cicd"
  display_name = "GitHub Actions CI/CD"
  description  = "Service account used by GitHub Actions for CI/CD pipeline"
}

# Grant Artifact Registry Writer to push Docker images
resource "google_project_iam_member" "github_actions_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Grant GKE Developer to deploy to the cluster
resource "google_project_iam_member" "github_actions_gke_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# 5. Workload Identity Federation for GitHub Actions (keyless auth)
resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Workload Identity Pool for GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Allow GitHub Actions to impersonate the CD service account via WIF
resource "google_service_account_iam_member" "github_actions_wif" {
  service_account_id = google_service_account.github_actions_cd.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_repo}"
}

# ── GKE App Service Account ───────────────────────────────────────────────────
# Used by pods in the `app` namespace to pull images from Artifact Registry
# via Workload Identity (no static keys).

resource "google_service_account" "gke_app" {
  account_id   = "gke-app-sa"
  display_name = "GKE App Service Account"
}

resource "google_project_iam_member" "artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_app.email}"
}

data "google_project" "current" {
  project_id = var.project_id
}

# GKE image pulls are performed by cluster runtime identities, not pod workload identity.
# Autopilot commonly uses these service accounts to fetch Artifact Registry tokens.
resource "google_project_iam_member" "artifact_reader_node_sa" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

# Required for non-degraded GKE node operations when using the default node SA.
resource "google_project_iam_member" "gke_default_node_sa" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "artifact_reader_gke_service_agent" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:service-${data.google_project.current.number}@container-engine-robot.iam.gserviceaccount.com"
}

# Workload Identity binding: pod SA `app/gke-app-sa` → GCP SA `gke-app-sa`
resource "google_service_account_iam_member" "wi_binding" {
  service_account_id = google_service_account.gke_app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[app/gke-app-sa]"

  depends_on = [google_container_cluster.primary]
}

# Workload Identity binding: `testing/playwright-runner` KSA → same GCP SA
# Needed so Playwright Jobs in the `testing` namespace can pull from Artifact Registry.
resource "google_service_account_iam_member" "wi_binding_testing" {
  service_account_id = google_service_account.gke_app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[testing/playwright-runner]"

  depends_on = [google_container_cluster.primary]
}

# ── GitHub Actions Service Account ────────────────────────────────────────────
# Used by GitHub Actions CI/CD to: push Docker images, deploy to Cloud Run,
# and get GKE credentials to apply k8s manifests / run Playwright jobs.

resource "google_service_account" "github_actions_cd" {
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions CI/CD Service Account"
}

# Push images to Artifact Registry
resource "google_project_iam_member" "github_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions_cd.email}"
}

# Enable/disable GCP APIs from CI (gcloud services enable)
resource "google_project_iam_member" "github_service_usage_admin" {
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageAdmin"
  member  = "serviceAccount:${google_service_account.github_actions_cd.email}"
}

# Get GKE credentials (needed for kubectl / Playwright Job)
resource "google_project_iam_member" "github_gke_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.github_actions_cd.email}"
}

# Deploy to Cloud Run
resource "google_project_iam_member" "github_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.github_actions_cd.email}"
}

# Allow SA to act as itself (required for Cloud Run deployments)
resource "google_service_account_iam_member" "github_sa_user" {
  service_account_id = google_service_account.github_actions_cd.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_actions_cd.email}"
}

# Allow GitHub Actions SA to act as the default compute SA (Cloud Run runtime identity)
resource "google_service_account_iam_member" "github_actas_compute_sa" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${data.google_project.current.number}-compute@developer.gserviceaccount.com"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_actions_cd.email}"
}

# Allow unauthenticated access to Cloud Run (public URL)
# Note: apply after the service exists, or Terraform will error if the service is missing.
# Uncomment this after creating the Cloud Run service
# resource "google_cloud_run_service_iam_member" "cloud_run_public_invoker" {
#   project  = var.project_id
#   location = var.region
#   service  = var.cloud_run_service_name
#
#   role   = "roles/run.invoker"
#   member = "allUsers"
#
#   depends_on = [google_project_service.required]
# }
