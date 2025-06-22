### Stage 1: Build de dependencias y assets
FROM php:8.3-fpm-alpine AS build

# Instalar dependencias del sistema necesarias para build
RUN apk add --no-cache \
    git \
    curl \
    libpng-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    libxpm-dev \
    oniguruma-dev \
    libxml2-dev \
    zip \
    unzip \
    icu-dev \
    autoconf \
    g++ \
    make \
    bash \
    nodejs \
    npm

# Instalar extensiones PHP necesarias para Laravel y Redis
RUN docker-php-ext-install pdo pdo_mysql mbstring xml ctype bcmath intl
RUN pecl install redis \
    && docker-php-ext-enable redis

# Instalar Composer
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

# Copiar archivos necesarios para instalar dependencias
WORKDIR /var/www
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-scripts --no-autoloader

# Copiar archivos de Node.js para construir assets
COPY package.json package-lock.json* ./
RUN npm ci --only=production

# Copiar el resto del código fuente
COPY . .

# Construir assets de Vite
RUN npm run build

# Generar autoloader optimizado
RUN composer dump-autoload --optimize

# Crear directorios necesarios y configurar permisos
RUN mkdir -p /var/www/storage/framework/{cache,sessions,views} \
    && mkdir -p /var/www/storage/logs \
    && mkdir -p /var/www/bootstrap/cache \
    && chown -R www-data:www-data /var/www/storage \
    && chown -R www-data:www-data /var/www/bootstrap/cache \
    && chmod -R 775 /var/www/storage \
    && chmod -R 775 /var/www/bootstrap/cache

### Stage 2: Imagen final ligera
FROM php:8.3-fpm-alpine

# Instalar solo las dependencias mínimas necesarias
RUN apk add --no-cache \
    libpng-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    libxpm-dev \
    oniguruma-dev \
    libxml2-dev \
    icu-dev \
    autoconf \
    g++ \
    make \
    bash

# Instalar extensiones PHP necesarias para Laravel y Redis
RUN docker-php-ext-install pdo pdo_mysql mbstring xml ctype bcmath intl
RUN pecl install redis \
    && docker-php-ext-enable redis

# Copiar archivos de la aplicación desde el build stage
WORKDIR /var/www
COPY --from=build /var/www /var/www
COPY --from=build /usr/bin/composer /usr/bin/composer

# Copiar y configurar script de entrada
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Configurar permisos para Laravel
RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache

EXPOSE 9000

# Usar el script de entrada
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"] 