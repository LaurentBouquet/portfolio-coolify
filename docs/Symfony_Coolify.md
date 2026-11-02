

Dans Coolify,  
comment créer une ressource de type "Public repository" 
à partir d'un dépôt Github qui contient un projet Symfony 8.1 
avec son fichier Docker compose (compose.yaml à la racine du projet Symfony) 
et pouvoir spécifier son sous-domaine ?

## Procédure dans Coolify

1. **Projet** → choisir l'environnement (ex. *production*) → **+ New Resource**.

2. Choisir **Public Repository**.

3. Saisir l'URL du dépôt dans l'unique champ **Repository URL (https://)** :
   `https://github.com/LaurentBouquet/portfolio-coolify`, puis valider (**Check repository**).

4. Sur l'écran suivant, renseigner la configuration de la ressource :

   - **Build Pack** : **Docker Compose**
   - **Branch** : `main`
   - **Base Directory** : `/`
   - **Docker Compose Location** : `/compose.yaml`

5. Cliquer sur **Continue** : la ressource est créée et ouverte sur sa page **Configuration**.

## Définir le sous-domaine

1. Dans la ressource, onglet **Configuration**, le champ **Domains** apparaît pour chaque service du compose
   (ex. service `php` : `https://portfolio.mondomaine.fr`).

   Si le conteneur n'écoute pas sur le port 80, ajouter le port : `https://portfolio.mondomaine.fr:8080`.

2. Coolify génère le routage Traefik et le certificat Let's Encrypt.

3. DNS : créer un enregistrement **A** `portfolio` pointant vers l'IP du serveur Coolify.

## Adapter le projet

Le `compose.yaml` actuel ne contient que la base PostgreSQL : il faut ajouter un service web pour déployer l'application.

### 1. Service web (`compose.yaml`)

Ajouter un service web (ici FrankenPHP) construit depuis un `Dockerfile`, et remplacer le contenu de `compose.yaml` par :

   ```yaml
   services:
     php:
       build: .
       restart: unless-stopped
       environment:
         APP_ENV: prod
         APP_SECRET: ${APP_SECRET}
         DATABASE_URL: postgresql://${POSTGRES_USER:-app}:${POSTGRES_PASSWORD}@database:5432/${POSTGRES_DB:-app}?serverVersion=16&charset=utf8
         # Caddy écoute en HTTP sur le port 80 : le HTTPS est géré par Traefik (Coolify)
         SERVER_NAME: :80
       depends_on:
         database:
           condition: service_healthy

     database:
       image: postgres:${POSTGRES_VERSION:-16}-alpine
       restart: unless-stopped
       environment:
         POSTGRES_DB: ${POSTGRES_DB:-app}
         POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
         POSTGRES_USER: ${POSTGRES_USER:-app}
       healthcheck:
         test: ["CMD", "pg_isready", "-d", "${POSTGRES_DB:-app}", "-U", "${POSTGRES_USER:-app}"]
         timeout: 5s
         retries: 5
         start_period: 60s
       volumes:
         - database_data:/var/lib/postgresql/data:rw

   volumes:
     database_data:
   ```
Aucun `ports:` n'est publié : Coolify route le trafic vers le port 80 du service `php` via Traefik.

Le service `php` apparaît alors dans le champ **Domains** (ex. `https://portfolio.mondomaine.fr`).

### 2. `Dockerfile`

À créer à la racine du projet :

   ```dockerfile
   FROM dunglas/frankenphp:1-php8.4

   RUN install-php-extensions intl opcache pdo_pgsql zip

   COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

   ENV APP_ENV=prod \
       APP_RUNTIME=Runtime\\FrankenPhpSymfony\\Runtime \
       FRANKENPHP_CONFIG="worker ./public/index.php" \
       COMPOSER_ALLOW_SUPERUSER=1

   WORKDIR /app
   COPY . .

   RUN composer install --no-dev --optimize-autoloader --no-scripts --no-interaction \
       && composer dump-env prod \
       && php bin/console asset-map:compile \
       && php bin/console cache:warmup \
       && mkdir -p var && chown -R www-data:www-data var

   # Migrations puis démarrage du serveur
   CMD ["sh", "-c", "php bin/console doctrine:migrations:migrate --no-interaction && frankenphp run --config /etc/caddy/Caddyfile --adapter caddyfile"]
   ```
Le runtime FrankenPHP nécessite `composer require runtime/frankenphp-symfony`. Sans ce paquet, retirer `APP_RUNTIME` et `FRANKENPHP_CONFIG`.

Ajouter aussi un `.dockerignore` (`vendor/`, `var/`, `.git/`, `.env.local`).

### 3. `compose.override.yaml`

Ne pas l'utiliser en production (réglages de dev uniquement). Il reste dans le dépôt : Docker Compose le charge automatiquement en local, mais pas Coolify, qui n'utilise que le fichier indiqué dans **Docker Compose Location**.

### 4. Variables d'environnement

Définir `APP_SECRET`, `POSTGRES_PASSWORD`, etc. dans l'onglet *Environment Variables* de Coolify.

### 5. Migrations

Déjà exécutées au démarrage par le `CMD` du `Dockerfile` ci-dessus.

### 6. Trusted proxies

Sans cette configuration, Symfony ne tient pas compte des en-têtes `X-Forwarded-*` envoyés par Traefik et génère des URL en `http`.

Dans `config/packages/framework.yaml`, sous `framework:` :

   ```yaml
   framework:
       trusted_proxies: '%env(TRUSTED_PROXIES)%'
       trusted_headers: ['x-forwarded-for', 'x-forwarded-host', 'x-forwarded-proto', 'x-forwarded-port', 'x-forwarded-prefix']
   ```

Puis définir la variable d'environnement (Coolify, ou `environment:` du service `php`) :

   ```
   TRUSTED_PROXIES=REMOTE_ADDR
   ```

`REMOTE_ADDR` est un mot-clé spécial de Symfony : il fait confiance à l'adresse IP qui se connecte directement au conteneur, donc à Traefik. Cela convient car le conteneur n'est joignable que via le proxy de Coolify (aucun `ports:` publié).

Pour restreindre davantage, on peut lister des plages d'IP, par exemple `TRUSTED_PROXIES=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16`.

**En local aussi** : `%env(TRUSTED_PROXIES)%` exige que la variable existe, sinon Symfony lève une erreur `Environment variable not found: "TRUSTED_PROXIES"` au démarrage. Il faut donc la définir dans `.env` (valeur par défaut, committée), avec une valeur vide car il n'y a pas de proxy en local :

   ```
   TRUSTED_PROXIES=
   ```

En production, la valeur `REMOTE_ADDR` définie dans Coolify (ou dans `environment:` du service `php`) prend le dessus sur celle de `.env`. Si besoin, une valeur locale spécifique se met dans `.env.local` (non committé).


