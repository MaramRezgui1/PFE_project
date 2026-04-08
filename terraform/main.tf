# 1. Création du réseau VPC
resource "google_compute_network" "vpc_network" {
  name                    = "maram-vpc"
  auto_create_subnetworks = true
}

# 2. Création du Cluster GKE Autopilot
resource "google_container_cluster" "primary" {
  name     = "maram-cluster-terraform"
  location = var.region

  # Active le mode Autopilot
  enable_autopilot = true

  network    = google_compute_network.vpc_network.name

  # Optionnel : suppression de la protection contre la suppression pour un PFE
  deletion_protection = false
}