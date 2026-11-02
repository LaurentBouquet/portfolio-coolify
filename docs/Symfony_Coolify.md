La méthode la plus simple consiste à connecter le dépôt Git du projet à Coolify, choisir le moteur de construction **Nixpacks**, ajouter une base de données privée, puis configurer les variables Symfony et le domaine HTTPS. Coolify documente directement cette configuration pour Symfony. [coolify](https://coolify.io/docs/applications/framework-examples/php/symfony)

Voici une procédure complète pour un VPS Debian, adaptée à un hébergement pédagogique. Les intitulés des menus peuvent varier légèrement selon la version de Coolify.

## 1. Préparer le VPS et les domaines

Vous devez disposer :

- d’un VPS Debian avec accès SSH et privilèges d’administration ;
- d’un dépôt Git contenant un projet Symfony fonctionnel ;
- d’un domaine ou sous-domaine pour l’application, par exemple `projet01.exemple.fr` ;
- idéalement, d’un autre sous-domaine pour l’administration : `coolify.exemple.fr`.

Coolify indique un minimum de 2 cœurs, 2 Go de RAM et 10 Go d’espace disponible pour son fonctionnement. Il faut ajouter les ressources nécessaires aux applications, bases de données et constructions d’images : ce minimum ne dimensionne donc pas un hébergement pour toute une promotion. Un serveur neuf est recommandé afin d’éviter les conflits. [coolify](https://coolify.io/docs/get-started/installation)

Dans la zone DNS, faites pointer les deux noms vers l’adresse IP publique du VPS :

```text
Type   Nom         Valeur
A      coolify     IP_PUBLIQUE_DU_VPS
A      projet01    IP_PUBLIQUE_DU_VPS
```

Le domaine de l’application doit atteindre le serveur sur lequel son proxy Coolify s’exécute. [coolify](https://coolify.io/docs/llms-full.txt)

### Préparer le pare-feu

Prévoyez les accès suivants :

| Port TCP | Usage | Exposition conseillée |
|---|---|---|
| 22, ou votre port SSH | Administration SSH | Restreint aux adresses autorisées |
| 80 | HTTP et validation des certificats | Public pour les sites publics |
| 443 | HTTPS | Public pour les sites publics |
| 8000 | Accès initial à Coolify | Temporairement, depuis votre adresse uniquement |
| 6001 et 6002 | Temps réel et terminal avec accès direct | Seulement si nécessaires pendant la configuration |

Une fois le tableau de bord accessible via son domaine et le proxy HTTPS, les accès publics directs aux ports `8000`, `6001` et `6002` peuvent être fermés. Coolify recommande le pare-feu réseau de l’hébergeur lorsqu’il est disponible. [coolify](https://coolify.io/docs/knowledge-base/server/firewall)

## 2. Installer et initialiser Coolify

Connectez-vous au VPS :

```bash
ssh root@IP_PUBLIQUE_DU_VPS
```

La commande officielle d’installation est :

```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

Elle exécute un script distant avec des privilèges élevés : utilisez-la sur le serveur prévu à cet effet, après avoir pris connaissance de la procédure officielle. [coolify](https://coolify.io/docs/get-started/installation)

À la fin de l’installation :

1. Ouvrez `http://IP_PUBLIQUE_DU_VPS:8000`.
2. Créez immédiatement le compte administrateur.
3. Configurez le domaine du tableau de bord, par exemple `https://coolify.exemple.fr`.
4. Vérifiez que l’accès HTTPS fonctionne avant de fermer les ports d’accès direct.
5. Sauvegardez le fichier `/data/coolify/source/.env` dans un emplacement sécurisé.

La création immédiate du compte est importante : la documentation avertit que la première personne atteignant la page d’inscription peut devenir administratrice de l’instance. Le fichier `.env` de Coolify contient notamment la clé nécessaire à la restauration de ses données chiffrées. [coolify](https://coolify.io/docs/get-started/installation)

## 3. Préparer le dépôt Symfony

Le dépôt doit contenir les fichiers nécessaires à une installation reproductible, notamment :

```text
mon-projet/
├── assets/                 # Selon le projet
├── bin/
│   └── console
├── config/
├── migrations/             # Si Doctrine Migrations est utilisé
├── public/
│   └── index.php
├── src/
├── templates/
├── composer.json
├── composer.lock
└── ...
```

Le déploiement Symfony comprend l’installation des dépendances, la configuration des secrets, 
la compilation éventuelle des ressources front-end, les migrations et la préparation du cache. 
La commande Composer recommandée en production est : [symfony](https://symfony.com/doc/current/deployment.html)

```bash
composer install --no-dev --optimize-autoloader
```

Points à vérifier avant de continuer :

- les dépendances nécessaires en production ne doivent pas être uniquement dans `require-dev` ;
- les valeurs sensibles de production seront renseignées dans Coolify, et non intégrées à l’image ;
- la compilation front-end doit correspondre à votre projet : AssetMapper, Encore ou une autre chaîne de compilation.

Coolify distingue les variables disponibles pendant la construction de celles accessibles au conteneur en fonctionnement ; 
ne rendez pas les secrets disponibles pendant la construction sans nécessité. [symfony](https://symfony.com/doc/current/deployment.html)

## 4. Créer le projet et la base de données

Dans Coolify :

1. Créez un projet, par exemple `Projet étudiant 01`.
2. Choisissez ou créez son environnement.
3. Ajoutez une ressource de type base de données : PostgreSQL ou MySQL, selon votre application.
4. Renseignez le nom de la base, l’utilisateur et un mot de passe propre à ce projet.
5. Démarrez la base.
6. Relevez la chaîne de connexion interne affichée par Coolify.

La documentation Symfony de Coolify prévoit la création préalable de la base depuis le tableau de bord, 
puis l’utilisation de sa chaîne de connexion dans les variables de l’application. [coolify](https://coolify.io/docs/applications/framework-examples/php/symfony)

Ne configurez pas de publication publique du port de la base pour ce scénario : 
l’application doit utiliser sa connexion interne. 
La publication d’un port hôte ouvre un chemin d’accès distinct du routage par domaine et proxy. [coolify](https://coolify.io/docs/knowledge-base/server/firewall)

### Attention à l’adresse de connexion

Ne recopiez pas aveuglément une URL contenant `127.0.0.1`. 
L’application et la base sont des ressources distinctes : 
utilisez le nom d’hôte interne fourni pour votre base et vérifiez leur connectivité réseau. 
Coolify fournit les informations de connexion à reporter dans l’application. [coolify](https://coolify.io/docs/applications/framework-examples/php/symfony)

Exemple indicatif :

```dotenv
DATABASE_URL=postgresql://utilisateur:MOT_DE_PASSE@HOTE_INTERNE:5432/nom_base?serverVersion=VERSION_REELLE&charset=utf8
```

Remplacez chaque valeur par celle de votre installation, notamment la version réelle du serveur.

## 5. Ajouter l’application depuis Git

Dans le même projet et environnement :

1. Cliquez sur l’ajout d’une ressource.
2. Sélectionnez une application issue d’un dépôt Git.
3. Choisissez le mode d’accès :
   - dépôt public ;
   - intégration Git pour un dépôt privé ;
   - clé de déploiement.
4. Renseignez le dépôt et la branche à déployer.
5. Vérifiez le dépôt.
6. Choisissez Nixpacks comme stratégie de construction.
7. Définissez le répertoire de base.

Coolify accepte les dépôts publics, les intégrations Git et les clés de déploiement. 
La procédure prévoit ensuite le choix de la stratégie de construction, du répertoire de base et du port interne. [coolify](https://coolify.io/docs/applications/coming-from-managed-platforms)

Pour un projet à la racine du dépôt :

```text
Base Directory : /
```

Pour un projet dans un sous-répertoire :

```text
Base Directory : /backend
```

Le répertoire de base indique à Nixpacks où inspecter l’application. [coolify](https://coolify.io/docs/applications/builds/nixpacks/deploy)

## 6. Renseigner les variables d’environnement

Dans la page `Environment Variables` de l’application, ajoutez :

```dotenv
APP_ENV=prod
APP_DEBUG=0
APP_SECRET=REMPLACER_PAR_UN_SECRET_ALEATOIRE
DATABASE_URL=REMPLACER_PAR_L_URL_INTERNE_DE_LA_BASE

NIXPACKS_PHP_ROOT_DIR=/app/public
NIXPACKS_PHP_FALLBACK_PATH=/index.php
```

Les deux variables `NIXPACKS_PHP_*`, ainsi que `APP_ENV` et `APP_SECRET`, font partie de la configuration Symfony documentée par Coolify. 
Le répertoire web à exposer est `/app/public`, et non la racine du projet. [coolify](https://coolify.io/docs/applications/framework-examples/php/symfony)

Vous pouvez générer un secret sur votre poste ou le serveur avec :

```bash
openssl rand -hex 32
```

Dans Coolify, vérifiez la portée des variables :

- `APP_ENV=prod` doit être cohérent pendant l’installation et au démarrage ;
- les variables `NIXPACKS_PHP_*` doivent être accessibles à la construction ;
- `APP_SECRET` et `DATABASE_URL` doivent être accessibles à l’exécution ;
- si un script Composer exécuté pendant la construction exige une variable, examinez ce besoin avant de lui exposer un secret de production.

Les portées « construction » et « exécution » sont distinctes dans Coolify. [next.coolify](https://next.coolify.io/docs/applications/configuration/environment-variables)

## 7. Configurer le port et le domaine HTTPS

Dans la configuration générale :

```text
Ports Exposes : 80
```

Dans les domaines, ajoutez :

```text
https://projet01.exemple.fr
```

La configuration Symfony/Nixpacks officielle utilise le port interne `80`. 
Coolify applique ensuite le routage du domaine vers le conteneur au moyen de son proxy. [coolify](https://coolify.io/docs/applications/framework-examples/php/symfony)

Il ne faut pas confondre :

- le port interne de l’application : `80` ;
- les ports publics du proxy : `80` et `443` ;
- une publication directe de port sur le VPS, qui n’est pas nécessaire ici.

Une publication de port hôte contourne le chemin d’accès par domaine du proxy Coolify. [coolify](https://coolify.io/docs/applications/how-applications-work)

## 8. Préparer les commandes de déploiement

### Dépendances et ressources front-end

Vérifiez dans les journaux de construction que les dépendances sont installées en mode production. 
Si vous personnalisez les commandes, conservez la logique recommandée par Symfony : [symfony](https://symfony.com/doc/current/deployment.html)

```bash
composer install --no-dev --optimize-autoloader
```

Ajoutez la compilation des ressources adaptée au projet. 

Évitez de recopier une commande front-end générique : 
les étapes diffèrent selon que le projet utilise AssetMapper, Encore ou une autre configuration. 
La compilation des ressources, lorsqu’elle est nécessaire, fait partie du déploiement Symfony. [symfony](https://symfony.com/doc/current/deployment.html)

### Migrations Doctrine

Pour une première installation, vous pouvez exécuter la migration depuis le terminal de l’application, après son démarrage :

```bash
php bin/console doctrine:migrations:migrate --no-interaction --env=prod
```

Coolify permet aussi de placer la commande dans le script de post-déploiement. 
Son exemple Symfony propose l’option `--all-or-nothing` ; 
vérifiez sa compatibilité avec votre moteur de base et vos migrations avant de l’ajouter. [coolify](https://coolify.io/docs/applications/framework-examples/php/symfony)

### Cache Symfony

Préparez le cache de production :

```bash
php bin/console cache:clear --env=prod --no-debug
```

La préparation du cache fait partie des étapes normales de déploiement Symfony. 
Pour automatiser ces commandes, adaptez leur emplacement afin qu’elles disposent des variables et de la connectivité nécessaires. [symfony](https://symfony.com/doc/current/deployment.html)

## 9. Configurer les proxys de confiance

L’application se trouve derrière le proxy de Coolify. 
Symfony doit reconnaître les informations transmises par ce proxy, notamment le protocole HTTPS et l’adresse du client. 
Sinon, il peut produire des URL ou redirections incorrectes. [symfony](https://symfony.com/doc/current/deployment/proxies.html)

Dans `config/packages/framework.yaml`, fusionnez cette configuration avec celle qui existe déjà :

```yaml
framework:
    trusted_proxies: '%env(TRUSTED_PROXIES)%'
    trusted_headers:
        - 'x-forwarded-for'
        - 'x-forwarded-proto'
        - 'x-forwarded-port'
```

Ajoutez dans Coolify :

```dotenv
TRUSTED_PROXIES=ADRESSE_OU_PLAGE_RESEAU_DU_PROXY
```

Déterminez l’adresse ou la plage réellement utilisée par le proxy pour joindre le conteneur. 
Ne supposez pas que l’IP publique du VPS est nécessairement l’adresse vue par Symfony. 
Limitez les proxys et les en-têtes approuvés à ceux de votre architecture ; 
Symfony insiste sur la restriction des accès si une configuration de confiance large est utilisée. [symfony](https://symfony.com/doc/current/deployment/proxies.html)

## 10. Ajouter du stockage persistant si nécessaire

Si les utilisateurs déposent des fichiers dans :

```text
/app/public/uploads
```

ajoutez un volume dans `Persistent Storage`, avec ce chemin comme destination.

Coolify remplace les conteneurs lors des déploiements : 
des fichiers stockés uniquement dans leur système de fichiers peuvent disparaître. 

Un volume conserve les données lors des remplacements normaux, 
mais ne constitue pas une sauvegarde contre la suppression, la corruption ou la perte du VPS. [coolify](https://coolify.io/docs/applications/how-applications-work)

Après avoir ajouté le volume :

1. Redéployez l’application.
2. Vérifiez les droits d’écriture.
3. Téléversez un fichier de test.
4. Redéployez à nouveau.
5. Vérifiez que le fichier est toujours accessible.

La documentation demande de vérifier que l’application peut lire et écrire les données du montage avant de s’y fier. [next.coolify](https://next.coolify.io/docs/applications/configuration/persistent-storage)

## 11. Déployer et vérifier

Cliquez sur `Deploy`, puis suivez les journaux. 
Coolify construit l’image et applique les variables, ports, réseaux, domaines et montages configurés avant de lancer le conteneur. [coolify](https://coolify.io/docs/applications/builds/dockerfile)

Effectuez ensuite ces contrôles :

| Vérification | Résultat attendu |
|---|---|
| Page d’accueil | Réponse correcte en HTTPS |
| Certificat | Valide pour le domaine |
| Connexion à la base | Lecture et écriture possibles |
| Migrations | Schéma à jour |
| Connexion utilisateur | Fonctionnelle, sans boucle de redirection |
| CSS et JavaScript | Chargés correctement |
| Téléversements | Conservés après redéploiement |
| Configuration de production | Pas de page de débogage exposée |

En cas d’échec, commencez par identifier la phase concernée : 
construction de l’image, démarrage du conteneur ou accès HTTP. 

Les réglages de ports, variables, santé et stockage se trouvent dans les pages de configuration de l’application. [coolify](https://coolify.io/docs/applications/configuration/overview)

## 12. Adapter l’installation à des étudiants

Pour votre contexte pédagogique, je préparerais un projet pilote servant de modèle, avec :

- un dépôt et une application par groupe ;
- un secret applicatif et des identifiants de base distincts ;
- un domaine par projet ;
- une configuration Nixpacks identique et documentée ;
- des droits étudiants limités aux ressources nécessaires ;
- des limites de ressources et des sauvegardes vérifiées avant l’ouverture générale.

Coolify dispose de réglages dédiés aux limites de ressources, aux variables, au stockage et aux opérations des applications ; 
ses permissions d’équipe doivent être testées avec un compte étudiant réel avant de généraliser le dispositif. [coolify](https://coolify.io/docs/applications/configuration/overview)

Enfin, sauvegardez séparément les bases, les fichiers téléversés et la configuration de Coolify, puis testez une restauration. 
La persistance Docker ne protège pas contre la perte du serveur, 
et les secrets d’installation de Coolify sont nécessaires à sa restauration. [coolify](https://coolify.io/docs/get-started/installation)

