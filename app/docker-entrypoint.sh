#!/bin/bash
set -e

echo "🚀 Iniciando Laravel..."

# Función para configurar permisos de forma segura
setup_permissions() {
    echo "🔐 Configurando permisos..."
    
    # Crear directorios si no existen
    mkdir -p /var/www/storage/framework/{cache,sessions,views} 2>/dev/null || true
    mkdir -p /var/www/storage/logs 2>/dev/null || true
    mkdir -p /var/www/bootstrap/cache 2>/dev/null || true
    
    # Intentar cambiar permisos de forma segura
    find /var/www/storage -type d -exec chmod 775 {} \; 2>/dev/null || true
    find /var/www/storage -type f -exec chmod 664 {} \; 2>/dev/null || true
    find /var/www/bootstrap/cache -type d -exec chmod 775 {} \; 2>/dev/null || true
    find /var/www/bootstrap/cache -type f -exec chmod 664 {} \; 2>/dev/null || true
    
    # Intentar cambiar propietario de forma segura
    chown -R www-data:www-data /var/www/storage 2>/dev/null || echo "⚠️ No se pudieron cambiar todos los propietarios de storage"
    chown -R www-data:www-data /var/www/bootstrap/cache 2>/dev/null || echo "⚠️ No se pudieron cambiar todos los propietarios de bootstrap/cache"
    
    echo "✅ Permisos configurados"
}

# Función para verificar assets
check_assets() {
    echo "📦 Verificando assets de Vite..."
    
    if [ ! -f "/var/www/public/build/manifest.json" ]; then
        echo "❌ manifest.json no encontrado. Reconstruyendo assets..."
        npm run build
    fi
    
    # Verificar que existan archivos CSS y JS
    if ! ls /var/www/public/build/assets/app-*.css >/dev/null 2>&1 || ! ls /var/www/public/build/assets/app-*.js >/dev/null 2>&1; then
        echo "❌ Assets de Vite incompletos. Reconstruyendo..."
        npm run build
    fi
    
    echo "✅ Assets verificados correctamente"
}

# Función para inicializar Laravel
init_laravel() {
    echo "🔧 Inicializando Laravel..."
    
    # Generar APP_KEY si no existe
    if [ -z "$APP_KEY" ] || [ "$APP_KEY" = "" ]; then
        echo "🔑 Generando nueva APP_KEY..."
        php artisan key:generate --force
        echo "✅ APP_KEY generada correctamente"
    else
        echo "🔑 APP_KEY ya configurada"
    fi
    
    # Limpiar cache
    php artisan cache:clear
    php artisan config:clear
    php artisan route:clear
    php artisan view:clear
    
    # Optimizar para producción
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
    
    echo "✅ Laravel inicializado"
}

# Función para esperar base de datos
wait_for_database() {
    echo "🗄️ Verificando conexión a la base de datos..."
    until php artisan tinker --execute="DB::connection()->getPdo();" 2>/dev/null; do
        echo "⏳ Esperando conexión a la base de datos..."
        sleep 5
    done
    echo "✅ Conexión a la base de datos establecida"
}

# Función para ejecutar migraciones
run_migrations() {
    echo "📊 Ejecutando migraciones..."
    php artisan migrate --force
    echo "✅ Migraciones completadas"
}

# Ejecutar funciones
setup_permissions
check_assets
init_laravel

# Si es el primer despliegue, ejecutar migraciones
if [ "$RUN_MIGRATIONS" = "true" ]; then
    wait_for_database
    run_migrations
fi

echo "✅ Inicialización completada"

# Ejecutar el comando original
exec "$@" 