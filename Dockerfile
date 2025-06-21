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
COPY --from=composer-deps /app/vendor ./vendor
COPY app/package.json app/package-lock.json app/vite.config.js ./
COPY app/resources ./resources

# Instalar dependencias y compilar assets
RUN npm ci --only=production && npm run build

# ─────────────────────────────────────────────
# STAGE 3: RUNTIME - PHP 8.4 con solo lo necesario
# ─────────────────────────────────────────────
FROM php:8.4-fpm-alpine AS runtime

# Crear usuario no-root para seguridad
RUN addgroup -g 1000 laravel && \
    adduser -u 1000 -G laravel -s /bin/sh -D laravel

# Instalar dependencias de sistema mínimas
RUN apk add --no-cache \
    libzip-dev \
    libpng-dev \
    zip \
    git \
    autoconf \
    build-base \
    oniguruma-dev \
    && docker-php-ext-install pdo pdo_mysql mbstring zip exif pcntl bcmath \
    && pecl install redis && docker-php-ext-enable redis \
    && apk del autoconf build-base

# Configurar PHP-FPM para K8s
RUN echo "php_admin_flag[log_errors] = on" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "php_admin_value[error_log] = /proc/self/fd/2" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "catch_workers_output = yes" >> /usr/local/etc/php-fpm.d/www.conf && \
    echo "decorate_workers_output = no" >> /usr/local/etc/php-fpm.d/www.conf

# Configurar PHP para K8s
RUN echo "log_errors = On" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "error_log = /proc/self/fd/2" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

WORKDIR /var/www

# Copiar app completa desde composer
COPY --from=composer-deps /app /var/www

# Copiar los assets compilados desde node
COPY --from=frontend /app/public /var/www/public

# Crear directorios necesarios y establecer permisos
RUN mkdir -p /var/www/storage/logs /var/www/storage/framework/cache /var/www/storage/framework/sessions /var/www/storage/framework/views /var/www/bootstrap/cache && \
    chown -R laravel:laravel /var/www && \
    chmod -R 755 /var/www/storage /var/www/bootstrap/cache

# Health check para K8s
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD php -r "echo 'OK';" || exit 1

# Cambiar al usuario no-root
USER laravel

# Exponer el puerto usado por PHP-FPM
EXPOSE 9000

# Comando por defecto
CMD ["php-fpm"]
