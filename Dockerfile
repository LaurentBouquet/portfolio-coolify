FROM dunglas/frankenphp:1-php8.4

RUN install-php-extensions intl opcache pdo_mysql zip

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

ENV APP_ENV=prod \
    FRANKENPHP_CONFIG="worker ./public/index.php" \
    COMPOSER_ALLOW_SUPERUSER=1

WORKDIR /app
COPY . .

RUN composer install --no-dev --optimize-autoloader --no-scripts --no-interaction \
    && composer dump-env prod \
    && php bin/console importmap:install \
    && php bin/console asset-map:compile \
    && php bin/console cache:warmup \
    && mkdir -p var && chown -R www-data:www-data var

# Migrations puis démarrage du serveur
CMD ["sh", "-c", "php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration && frankenphp run --config /etc/caddy/Caddyfile --adapter caddyfile"]
