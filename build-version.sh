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

# Generar el contenido nuevo en un temporal
TMP_FILE=$(mktemp)
cat << 'EOF' > "$TMP_FILE"
// ESTE ARCHIVO ES AUTOGENERADO EN TIEMPO DE COMPILACIÓN. NO EDITAR DIRECTAMENTE.
import Foundation

struct AppVersion {
    static let version = "VERSION_DATE_PLACEHOLDER"
    static let gitHash = "GIT_HASH_PLACEHOLDER"
    static let fullVersion = "v\(version) (\(gitHash))"
}
EOF

# Reemplazar los placeholders en el temporal
sed -i '' "s/VERSION_DATE_PLACEHOLDER/${VERSION_DATE}/g" "$TMP_FILE"
sed -i '' "s/GIT_HASH_PLACEHOLDER/${GIT_HASH}/g" "$TMP_FILE"

# Escribir SOLO si el contenido cambió. Reescribir siempre toca el mtime del
# archivo fuente y, durante SwiftUI Previews (rebuild continuo), genera un loop
# infinito de rebuild/reindex. Comparar primero lo evita.
if [ ! -f "$VERSION_FILE" ] || ! cmp -s "$TMP_FILE" "$VERSION_FILE"; then
    mv "$TMP_FILE" "$VERSION_FILE"
else
    rm -f "$TMP_FILE"
fi
