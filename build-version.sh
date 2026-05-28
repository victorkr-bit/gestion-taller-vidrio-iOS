#!/bin/bash
# Script para generar automáticamente el archivo de versión de la app

# Directorio base del proyecto
SRC_DIR="${SRCROOT}/gestion-taller-vidrio"
VERSION_FILE="${SRC_DIR}/Varios/Version.swift"

# Si no está definido SRCROOT (por si se ejecuta manualmente en terminal)
if [ -z "$SRCROOT" ]; then
    SRC_DIR="gestion-taller-vidrio"
    VERSION_FILE="${SRC_DIR}/Varios/Version.swift"
fi

# Obtener fecha en formato YY.MM.DD
VERSION_DATE=$(date "+%y.%m.%d")

# Obtener hash corto del commit actual de Git
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "dev")

# Escribir el nuevo contenido en Version.swift
cat << 'EOF' > "$VERSION_FILE"
// ESTE ARCHIVO ES AUTOGENERADO EN TIEMPO DE COMPILACIÓN. NO EDITAR DIRECTAMENTE.
import Foundation

struct AppVersion {
    static let version = "VERSION_DATE_PLACEHOLDER"
    static let gitHash = "GIT_HASH_PLACEHOLDER"
    static let fullVersion = "v\(version) (\(gitHash))"
}
EOF

# Reemplazar los placeholders en el archivo
sed -i '' "s/VERSION_DATE_PLACEHOLDER/${VERSION_DATE}/g" "$VERSION_FILE"
sed -i '' "s/GIT_HASH_PLACEHOLDER/${GIT_HASH}/g" "$VERSION_FILE"
