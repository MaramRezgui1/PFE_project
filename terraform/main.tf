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