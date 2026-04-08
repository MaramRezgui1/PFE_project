# 🚀 Terraform Infrastructure - Login Page Replicator

## 📋 Vue d'ensemble

Ce dossier contient l'infrastructure as code (IaC) pour déployer l'application **Login Page Replicator** sur Google Cloud Platform (GCP) en utilisant Terraform.

## 🏗️ Architecture déployée

L'infrastructure crée automatiquement :

1. **VPC Network** (`maram-vpc`)
   - Réseau virtuel privé avec sous-réseaux automatiques
   - Isolation réseau pour les ressources

2. **Cluster GKE Autopilot** (`maram-cluster-terraform`)
   - Kubernetes managé sur GCP
   - Mode Autopilot (gestion automatique des nœuds)
   - Région : `europe-west9` (Paris)
   - Protection contre la suppression : désactivée (pour faciliter les tests)

## 📁 Fichiers Terraform

| Fichier | Description |
|---------|-------------|
| `providers.tf` | Configuration du provider Google Cloud |
| `variables.tf` | Variables d'entrée (project_id, region) |
| `main.tf` | Ressources principales (VPC, GKE) |
| `outputs.tf` | Valeurs de sortie après déploiement |
| `backend.tf` | Configuration du backend (stockage d'état) |
| `terraform.tfvars` | Valeurs des variables (ne pas commiter si sensible) |
| `deploy.ps1` | Script PowerShell d'automatisation |

## 🔧 Prérequis

### 1. Installation des outils

```bash
# Terraform
# Télécharger depuis : https://www.terraform.io/downloads

# Google Cloud SDK (gcloud)
# Installation Ubuntu/Debian :
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Vérifier les installations
terraform version
gcloud version
```

### 2. Configuration GCP

```bash
# Authentification
gcloud auth login
gcloud auth application-default login

# Configurer le projet
gcloud config set project maram-pfe

# Activer les APIs nécessaires
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

## 🚀 Déploiement

### Étape 1 : Initialisation

```bash
cd terraform
terraform init
```

Cette commande :
- Télécharge les providers nécessaires
- Initialise le backend
- Crée `.terraform.lock.hcl`

### Étape 2 : Planification

```bash
terraform plan
```

Affiche les ressources qui seront créées sans les déployer.

### Étape 3 : Application

```bash
terraform apply
```

Tape `yes` pour confirmer le déploiement.

### Étape 4 : Vérification

```bash
# Voir les outputs
terraform output

# Vérifier le cluster
gcloud container clusters list

# Obtenir les credentials kubectl
gcloud container clusters get-credentials maram-cluster-terraform --region=europe-west9
```

## 🔐 Résolution du problème d'authentification

### Erreur commune :
```
Error: could not find default credentials
```

### Solution :

```bash
# Méthode 1 : Application Default Credentials (Recommandée)
gcloud auth application-default login

# Méthode 2 : Service Account
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"

# Méthode 3 : Credentials dans provider (non recommandé pour la sécurité)
# Modifier providers.tf pour ajouter :
# credentials = file("path/to/key.json")
```

## 📊 Variables configurables

Dans `variables.tf` :

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `project_id` | ID du projet GCP | `maram-pfe` |
| `region` | Région de déploiement | `europe-west9` |

Pour modifier, créez/éditez `terraform.tfvars` :

```hcl
project_id = "mon-projet-gcp"
region     = "europe-west1"
```

## 🗑️ Suppression de l'infrastructure

```bash
# Supprimer toutes les ressources
terraform destroy

# Ou supprimer des ressources spécifiques
terraform destroy -target=google_container_cluster.primary
```

## 📝 Commandes utiles

```bash
# Voir l'état actuel
terraform show

# Lister les ressources
terraform state list

# Formater les fichiers
terraform fmt

# Valider la configuration
terraform validate

# Voir le plan détaillé
terraform plan -out=tfplan

# Appliquer un plan sauvegardé
terraform apply tfplan
```

## 💰 Estimation des coûts

- **VPC Network** : Gratuit
- **GKE Autopilot** : 
  - ~0.10$ par cluster-heure
  - ~74$ par mois pour un cluster actif 24/7
  - + coût des ressources CPU/RAM utilisées

💡 **Conseil** : Supprimez le cluster quand vous ne l'utilisez pas pour économiser.

## 🔒 Bonnes pratiques de sécurité

1. **Ne jamais commiter** :
   - `terraform.tfvars` avec des valeurs sensibles
   - Fichiers `*.tfstate` (utilisez un backend distant)
   - Clés de service account JSON

2. **Utiliser un backend distant** :
   ```hcl
   # backend.tf
   terraform {
     backend "gcs" {
       bucket = "mon-bucket-terraform-state"
       prefix = "terraform/state"
     }
   }
   ```

3. **Activer la protection** pour la production :
   ```hcl
   deletion_protection = true  # dans main.tf
   ```

## 🐛 Troubleshooting

### Problème : Quota insuffisant
```bash
# Vérifier les quotas
gcloud compute project-info describe --project=maram-pfe
```

### Problème : Région non disponible
```bash
# Lister les régions disponibles
gcloud compute regions list
```

### Problème : APIs non activées
```bash
# Réactiver toutes les APIs
gcloud services enable container.googleapis.com compute.googleapis.com
```

## 📚 Documentation officielle

- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GKE Autopilot](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

## 🎓 Informations PFE

- **Projet** : Login Page Replicator
- **Étudiant** : Maram
- **Cluster** : maram-cluster-terraform
- **VPC** : maram-vpc
- **Région** : europe-west9 (Paris)

---

**Créé avec ❤️ pour le Projet de Fin d'Études**
