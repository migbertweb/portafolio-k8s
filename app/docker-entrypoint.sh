#!/bin/bash
set -e

echo "🚀 Iniciando Laravel..."

# Ejecutar el script unificado de permisos
bash /var/www/fix-permissions.sh

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
    
    # Activar Flux si no está activado
    echo "🎨 Activando Flux..."
    php artisan flux:activate || echo "⚠️ Flux ya está activado o no se pudo activar"
    
    # Limpiar cache con manejo de errores
    # echo "🧹 Limpiando cache..."
    # php artisan cache:clear || echo "⚠️ Error al limpiar cache"
    # php artisan config:clear || echo "⚠️ Error al limpiar config"
    # php artisan route:clear || echo "⚠️ Error al limpiar routes"
    # php artisan view:clear || echo "⚠️ Error al limpiar views"
    
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
init_laravel

# Si es el primer despliegue, ejecutar migraciones
if [ "$RUN_MIGRATIONS" = "true" ]; then
    wait_for_database
    run_migrations
fi

echo "✅ Inicialización completada"

# Ejecutar el comando original
exec "$@" 