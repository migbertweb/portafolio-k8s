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
    
    echo "📁 Configurando permisos para directorios locales (no PVC)..."
    # Configurar permisos para directorios locales (no PVC)
    chmod -R 775 /var/www/bootstrap/cache 2>/dev/null || true
    chown -R www-data:www-data /var/www/bootstrap/cache 2>/dev/null || {
        echo "⚠️ Usando método alternativo para bootstrap/cache..."
        find /var/www/bootstrap/cache -type d -exec chmod 775 {} \; 2>/dev/null || true
        find /var/www/bootstrap/cache -type f -exec chmod 664 {} \; 2>/dev/null || true
    }
    
    echo "📁 Configurando permisos para PVC de storage..."
    # Para el PVC de storage, ser más cuidadoso con los permisos existentes
    # Solo cambiar permisos si es necesario, no propietario
    find /var/www/storage -type d -exec chmod 775 {} \; 2>/dev/null || true
    find /var/www/storage -type f -exec chmod 664 {} \; 2>/dev/null || true
    
    # Intentar cambiar propietario solo para archivos nuevos o si es posible
    echo "👤 Intentando cambiar propietario de archivos en PVC..."
    chown -R www-data:www-data /var/www/storage 2>/dev/null || {
        echo "⚠️ No se pudieron cambiar todos los propietarios del PVC (normal en volúmenes persistentes)"
        echo "ℹ️ Los archivos existentes mantendrán su propietario original"
    }
    
    # Verificar que los directorios críticos sean escribibles
    echo "🔍 Verificando permisos de escritura..."
    
    if [ ! -w "/var/www/bootstrap/cache" ]; then
        echo "❌ Error: /var/www/bootstrap/cache no es escribible"
        chmod 775 /var/www/bootstrap/cache 2>/dev/null || true
    else
        echo "✅ /var/www/bootstrap/cache es escribible"
    fi
    
    if [ ! -w "/var/www/storage/framework/cache" ]; then
        echo "❌ Error: /var/www/storage/framework/cache no es escribible"
        chmod 775 /var/www/storage/framework/cache 2>/dev/null || true
    else
        echo "✅ /var/www/storage/framework/cache es escribible"
    fi
    
    if [ ! -w "/var/www/storage/framework/sessions" ]; then
        echo "❌ Error: /var/www/storage/framework/sessions no es escribible"
        chmod 775 /var/www/storage/framework/sessions 2>/dev/null || true
    else
        echo "✅ /var/www/storage/framework/sessions es escribible"
    fi
    
    if [ ! -w "/var/www/storage/framework/views" ]; then
        echo "❌ Error: /var/www/storage/framework/views no es escribible"
        chmod 775 /var/www/storage/framework/views 2>/dev/null || true
    else
        echo "✅ /var/www/storage/framework/views es escribible"
    fi
    
    # Ejecutar script adicional de verificación de permisos
    if [ -f "/var/www/fix-permissions.sh" ]; then
        echo "🔧 Ejecutando verificación adicional de permisos..."
        bash /var/www/fix-permissions.sh
    fi
    
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
    
    # Limpiar cache con manejo de errores
    echo "🧹 Limpiando cache..."
    php artisan cache:clear || echo "⚠️ Error al limpiar cache"
    php artisan config:clear || echo "⚠️ Error al limpiar config"
    php artisan route:clear || echo "⚠️ Error al limpiar routes"
    php artisan view:clear || echo "⚠️ Error al limpiar views"
    
    # Optimizar para producción con manejo de errores
    echo "⚡ Optimizando para producción..."
    php artisan config:cache || echo "⚠️ Error al cachear config"
    php artisan route:cache || echo "⚠️ Error al cachear routes"
    php artisan view:cache || echo "⚠️ Error al cachear views"
    
    echo "✅ Laravel inicializado"
}

# Función para esperar base de datos
wait_for_database() {
    echo "🗄️ Verificando conexión a la base de datos..."
    until php -r "
        try {
            \$pdo = new PDO(
                'mysql:host=' . getenv('DB_HOST') . ';port=' . getenv('DB_PORT') . ';dbname=' . getenv('DB_DATABASE'),
                getenv('DB_USERNAME'),
                getenv('DB_PASSWORD'),
                [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
            );
            echo 'Database connection successful';
            exit(0);
        } catch (Exception \$e) {
            exit(1);
        }
    " 2>/dev/null; do
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