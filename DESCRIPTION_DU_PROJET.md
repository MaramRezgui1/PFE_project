# 📋 Description du Projet - Login Page Replicator

## 🎯 Qu'est-ce que c'est ?

Ce projet est une **réplique d'interface de connexion pour Sopra HR 4YOU**, une application de gestion des ressources humaines. Il simule l'expérience d'authentification et l'accès à un tableau de bord employé.

## 🛠️ Technologies Utilisées

### Frontend
- **React 18** - Framework JavaScript pour l'interface utilisateur
- **TypeScript** - Typage statique pour un code plus robuste
- **Vite** - Outil de build ultra-rapide
- **Tailwind CSS** - Framework CSS utilitaire pour le styling
- **shadcn/ui** - Bibliothèque de composants UI modernes et accessibles
- **React Router** - Navigation entre les pages

### Outils de Développement
- **ESLint** - Linting du code
- **Vitest** - Tests unitaires
- **React Query** - Gestion des états et des requêtes

### Déploiement
- **Docker** - Conteneurisation de l'application
- **Nginx** - Serveur web pour servir l'application en production
- **Terraform** - Infrastructure as Code (déploiement cloud)

## 📁 Structure du Projet

### Pages Principales
1. **Page de Connexion (/)** - `src/pages/Index.tsx`
   - Interface de login élégante avec gradient violet/rose
   - Formulaire avec identifiant et mot de passe
   - Sélection de langue (FR, EN, DE, ES)
   - Lien "Mot de passe oublié"

2. **Tableau de Bord (/dashboard)** - `src/pages/Dashboard.tsx`
   - Informations utilisateur
   - Solde de congés
   - Tâches à traiter
   - Absences

3. **Page 404** - `src/pages/NotFound.tsx`
   - Page d'erreur pour les routes inexistantes

### Composants Clés
- **LoginCard** - Carte de connexion avec logo Sopra HR
- **SopraLogo** - Logo de l'entreprise
- **AuthContext** - Gestion de l'authentification

## 🔐 Système d'Authentification

### Fonctionnement
- **Authentification mock** : Les utilisateurs sont définis dans les variables d'environnement
- Format : `VITE_MOCK_USERS` contient un JSON avec les utilisateurs
- Chaque utilisateur a :
  - Un identifiant (`id`)
  - Un mot de passe (`password`)
  - Un nom complet (`name`)
  - Un nombre de dossiers (`folderCount`)

### Flux d'Authentification
1. L'utilisateur entre son identifiant et mot de passe
2. Le système vérifie les credentials contre la liste des utilisateurs mock
3. Si succès → redirection vers `/dashboard`
4. Si échec → toast d'erreur

## 🎨 Design et Interface

### Palette de Couleurs
- **Fond principal** : Gradient violet/rose foncé
- **Carte de login** : Fond clair avec ombres
- **Accents** : Violet Sopra caractéristique
- **Rouge Sopra** : Pour les champs obligatoires (*)

### Caractéristiques UX
- Design responsive
- Animation de visibilité du mot de passe (œil)
- Validation des formulaires
- Toast notifications pour les erreurs
- Interface multilingue

## 🚀 Utilisation

### Développement Local
```powershell
# Installation des dépendances
npm install

# Lancement en mode développement
npm run dev

# Tests
npm test
```

### Production
```powershell
# Build pour production
npm run build

# Preview de la build
npm preview
```

### Docker
```powershell
# Construction de l'image
docker build -t login-page-replicator .

# Lancement du conteneur
docker run -p 8080:8080 login-page-replicator
```

## 📦 Fonctionnalités Implémentées

✅ Page de connexion répliquée fidèlement  
✅ Authentification avec utilisateurs mock  
✅ Tableau de bord employé  
✅ Gestion des sessions utilisateur  
✅ Sélection de langue  
✅ Design responsive  
✅ Navigation entre pages  
✅ Messages d'erreur  
✅ Déploiement Docker  
✅ Infrastructure Terraform  

## 🎓 Utilité du Projet

### Contexte : Projet PFE (Projet de Fin d'Études)

Ce projet semble être un **prototype ou une démonstration** pour :

1. **Apprentissage des technologies modernes**
   - React avec TypeScript
   - Design system (shadcn/ui)
   - DevOps (Docker, Terraform)

2. **Démonstration de compétences**
   - Réplication d'interface professionnelle
   - Architecture frontend moderne
   - Bonnes pratiques de développement

3. **Portfolio**
   - Projet concret à présenter
   - Montre la maîtrise du stack React/TypeScript
   - Démontre les capacités en UI/UX

4. **Formation**
   - Comprendre les flux d'authentification
   - Gestion d'état avec Context API
   - Routing et navigation

## ⚠️ Notes Importantes

- **Projet de démonstration uniquement** - Ne pas utiliser en production réelle
- **Authentification mock** - Pas de sécurité réelle
- **Pas de backend** - Tout est côté client
- Les credentials sont en clair dans les variables d'environnement

## 🔒 Sécurité

Le projet inclut :
- Correction de CVE (Common Vulnerabilities and Exposures) dans Dockerfile
- Dépendances à jour
- Bonnes pratiques de conteneurisation

## 📝 Conclusion

Il s'agit d'un **projet éducatif de haute qualité** qui réplique fidèlement l'interface Sopra HR 4YOU pour démontrer des compétences en développement frontend moderne. Le projet est bien structuré, utilise des technologies actuelles et suit les bonnes pratiques de l'industrie.
