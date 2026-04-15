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

# Allow GitHub Actions to impersonate the service account
resource "google_service_account_iam_member" "github_actions_wif" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_repo}"
}