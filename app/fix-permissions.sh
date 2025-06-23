#!/bin/bash

echo "🔧 Verificando y corrigiendo permisos..."

# Función para verificar y corregir permisos de un directorio
fix_directory_permissions() {
    local dir="$1"
    local user="$2"
    local group="$3"
    local perms="$4"
    local is_pvc="$5"
    
    if [ -d "$dir" ]; then
        echo "📁 Verificando $dir..."
        
        # Verificar si el directorio es escribible
        if [ ! -w "$dir" ]; then
            echo "⚠️ $dir no es escribible, corrigiendo..."
            chmod "$perms" "$dir" 2>/dev/null || true
        fi
        
        # Para PVC, ser más cuidadoso con el propietario
        if [ "$is_pvc" = "true" ]; then
            echo "🔄 Ajustando permisos para PVC (sin cambiar propietario)..."
            find "$dir" -type d -exec chmod "$perms" {} \; 2>/dev/null || true
            find "$dir" -type f -exec chmod 664 {} \; 2>/dev/null || true
            
            # Solo intentar cambiar propietario si es posible
            chown "$user:$group" "$dir" 2>/dev/null || {
                echo "ℹ️ No se pudo cambiar propietario de $dir (normal en PVC)"
            }
        else
            # Para directorios locales, cambiar propietario normalmente
            chown "$user:$group" "$dir" 2>/dev/null || {
                echo "⚠️ No se pudo cambiar propietario de $dir"
            }
            
            # Cambiar permisos recursivamente
            find "$dir" -type d -exec chmod "$perms" {} \; 2>/dev/null || true
            find "$dir" -type f -exec chmod 664 {} \; 2>/dev/null || true
        fi
        
        echo "✅ $dir configurado"
    else
        echo "❌ $dir no existe"
    fi
}

# Directorios locales (no PVC)
echo "🏠 Configurando directorios locales..."
fix_directory_permissions "/var/www/bootstrap/cache" "www-data" "www-data" "775" "false"
fix_directory_permissions "/var/www/public/build" "www-data" "www-data" "775" "false"

# Directorios en PVC
echo "💾 Configurando directorios en PVC..."
fix_directory_permissions "/var/www/storage" "www-data" "www-data" "775" "true"

# Verificar permisos específicos
echo "🔍 Verificando permisos críticos..."

# Verificar bootstrap/cache (local) - más agresivo
if [ -w "/var/www/bootstrap/cache" ]; then
    echo "✅ /var/www/bootstrap/cache es escribible"
else
    echo "❌ /var/www/bootstrap/cache NO es escribible"
    echo "🔧 Intentando corrección agresiva..."
    chmod -R 775 /var/www/bootstrap/cache 2>/dev/null || true
    chown -R www-data:www-data /var/www/bootstrap/cache 2>/dev/null || true
    
    # Verificar nuevamente
    if [ -w "/var/www/bootstrap/cache" ]; then
        echo "✅ /var/www/bootstrap/cache ahora es escribible"
    else
        echo "⚠️ /var/www/bootstrap/cache aún no es escribible (puede causar problemas)"
    fi
fi

# Verificar directorios en PVC
for dir in "cache" "sessions" "views"; do
    pvc_dir="/var/www/storage/framework/$dir"
    if [ -w "$pvc_dir" ]; then
        echo "✅ $pvc_dir es escribible"
    else
        echo "❌ $pvc_dir NO es escribible"
        chmod 775 "$pvc_dir" 2>/dev/null || true
    fi
done

# Verificar logs en PVC
if [ -w "/var/www/storage/logs" ]; then
    echo "✅ /var/www/storage/logs es escribible"
else
    echo "❌ /var/www/storage/logs NO es escribible"
    chmod 775 /var/www/storage/logs 2>/dev/null || true
fi

# Mostrar información sobre el PVC
echo "📊 Información del PVC:"
echo "   - Montado en: /var/www/storage"
echo "   - Tipo: PersistentVolumeClaim"
echo "   - Permisos: 775 para directorios, 664 para archivos"
echo "   - Propietario: Mantiene el original (puede variar)"

echo "✅ Verificación de permisos completada" 