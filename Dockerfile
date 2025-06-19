# ─────────────────────────────────────────────
# STAGE 1: COMPOSER - instala dependencias PHP sin scripts
# ─────────────────────────────────────────────
FROM composer:2.8 AS composer-deps
WORKDIR /app

# Copiar composer.json y lock (mejor caching)
COPY app/composer.json app/composer.lock ./

# Instalar dependencias PHP sin ejecutar scripts de artisan
RUN composer install --no-dev --no-scripts --optimize-autoloader --ignore-platform-reqs

# Copiar el resto de la app (incluye artisan)
COPY app/ ./

# Ejecutar scripts post-install como package:discover
RUN composer run-script post-autoload-dump

# ─────────────────────────────────────────────
# STAGE 2: NODE - compila los assets frontend
# ─────────────────────────────────────────────
FROM node:22-alpine AS frontend
WORKDIR /app

# Copiar solo lo necesario para npm
COPY app/package.json app/package-lock.json vite.config.js ./
COPY app/resources ./resources

# Instalar dependencias y compilar assets
RUN npm install && npm run build

# ─────────────────────────────────────────────
# STAGE 3: RUNTIME - PHP 8.4 con solo lo necesario
# ─────────────────────────────────────────────
FROM php:8.4-fpm-alpine AS runtime
WORKDIR /var/www

# Instalar dependencias de sistema mínimas
RUN apk add --no-cache libpng libzip oniguruma \
    && docker-php-ext-install pdo pdo_mysql mbstring zip exif pcntl bcmath \
    && pecl install redis && docker-php-ext-enable redis

# Copiar app completa desde composer
COPY --from=composer-deps /app /var/www

# Copiar los assets compilados desde node
COPY --from=frontend /app/public /var/www/public

# Permisos correctos para Laravel
RUN chown -R www-data:www-data /var/www \
    && find storage bootstrap/cache -type d -exec chmod 755 {} \; \
    && find storage bootstrap/cache -type f -exec chmod 644 {} \;

# Exponer el puerto usado por PHP-FPM
EXPOSE 9000

# Comando por defecto
CMD ["php-fpm"]
