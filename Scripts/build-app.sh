#!/usr/bin/env bash
# Compile Focus Tube en binaire universel (arm64 + x86_64), assemble le bundle
# FocusTube.app, le signe ad hoc et produit un .zip prêt pour GitHub Releases.
#
# Usage : ./Scripts/build-app.sh [version]
# Exemple : ./Scripts/build-app.sh 1.0.0

set -euo pipefail

APP_NAME="FocusTube"
VERSION="${1:-0.0.0}"
OUT_DIR="dist"

# Se placer à la racine du dépôt quel que soit l'endroit d'où le script est lancé.
cd "$(dirname "$0")/.."

echo "==> Compilation universelle (arm64 + x86_64) en mode release…"
swift build -c release --arch arm64 --arch x86_64 --product "$APP_NAME"

BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
BINARY="$BIN_DIR/$APP_NAME"

if [[ ! -f "$BINARY" ]]; then
    echo "Erreur : binaire introuvable à $BINARY" >&2
    exit 1
fi

APP="$OUT_DIR/$APP_NAME.app"
echo "==> Assemblage du bundle ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BINARY" "$APP/Contents/MacOS/$APP_NAME"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Signature ad hoc (sans compte développeur)…"
codesign --force --deep --sign - "$APP"

echo "==> Vérification des architectures :"
lipo -info "$APP/Contents/MacOS/$APP_NAME"

ZIP_NAME="$APP_NAME-$VERSION-macOS.zip"
echo "==> Création de $OUT_DIR/${ZIP_NAME}…"
(cd "$OUT_DIR" && rm -f "$ZIP_NAME" && ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_NAME")

echo "==> Terminé : $OUT_DIR/$ZIP_NAME"
