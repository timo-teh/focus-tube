#!/bin/bash

set -euo pipefail

# Construit une application macOS et un DMG à partir d'un package Swift.
#
# Utilisation :
#   bash Scripts/build-release.sh 1.0.0
#
# Nécessite macOS, Xcode et les outils de build associés.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
    echo "Erreur : indique une version, par exemple :"
    echo "  bash Scripts/build-release.sh 1.0.0"
    exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Erreur : la version doit être au format MAJEUR.MINEUR.CORRECTIF."
    echo "Exemple : 1.0.0"
    exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Erreur : ce script doit être exécuté sur macOS."
    exit 1
fi

if [[ ! -f "$ROOT_DIR/Package.swift" ]]; then
    echo "Erreur : Package.swift est introuvable à la racine du dépôt."
    echo "Adapte ce script si le projet utilise un .xcodeproj."
    exit 1
fi

EXECUTABLE_NAME="FocusTube"
BUNDLE_IDENTIFIER="com.focustube.app"
APP_NAME="Focus Tube"

DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_PATH/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DMG_PATH="$DIST_DIR/FocusTube.dmg"

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/focustube-dmg.XXXXXX")"

cleanup() {
    rm -rf "$STAGING_DIR"
}

trap cleanup EXIT

echo "==> Vérification de Xcode"
xcodebuild -version

echo "==> Construction universelle Release"
export MACOSX_DEPLOYMENT_TARGET="13.0"

swift build \
    -c release \
    --product "$EXECUTABLE_NAME" \
    --arch arm64 \
    --arch x86_64

echo "==> Recherche du répertoire des binaires"

BIN_DIR="$(
    swift build \
        -c release \
        --product "$EXECUTABLE_NAME" \
        --arch arm64 \
        --arch x86_64 \
        --show-bin-path
)"

BUILT_EXECUTABLE="$BIN_DIR/$EXECUTABLE_NAME"

if [[ ! -f "$BUILT_EXECUTABLE" ]]; then
    echo "Erreur : exécutable introuvable : $BUILT_EXECUTABLE"
    echo "Vérifie le nom du produit dans Package.swift."
    exit 1
fi

echo "==> Vérification des architectures"
lipo -verify_arch arm64 "$BUILT_EXECUTABLE"
lipo -verify_arch x86_64 "$BUILT_EXECUTABLE"

echo "==> Création du bundle .app"

mkdir -p "$DIST_DIR"

# Ces chemins sont des sorties de build, pas des données utilisateur.
rm -rf "$APP_PATH"
rm -f "$DMG_PATH"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$BUILT_EXECUTABLE" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod 755 "$MACOS_DIR/$EXECUTABLE_NAME"

if [[ -f "$ROOT_DIR/Resources/Info.plist" ]]; then
    sed "s/__VERSION__/$VERSION/g" "$ROOT_DIR/Resources/Info.plist" > "$CONTENTS_DIR/Info.plist"
else
    cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>fr</string>

    <key>CFBundleDisplayName</key>
    <string>Focus Tube</string>

    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>

    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_IDENTIFIER</string>

    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>

    <key>CFBundleName</key>
    <string>Focus Tube</string>

    <key>CFBundlePackageType</key>
    <string>APPL</string>

    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>

    <key>CFBundleVersion</key>
    <string>$VERSION</string>

    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>

    <key>NSHighResolutionCapable</key>
    <true/>

    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF
fi

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

echo "==> Signature ad-hoc du bundle .app"
codesign --force --deep --sign - "$APP_PATH"

echo "==> Copie des bundles de ressources Swift Package Manager"

find "$BIN_DIR" \
    -maxdepth 1 \
    -type d \
    -name "*.bundle" \
    -exec cp -R {} "$RESOURCES_DIR/" \;

echo "==> Vérification du bundle"

plutil -lint "$CONTENTS_DIR/Info.plist"
lipo -info "$MACOS_DIR/$EXECUTABLE_NAME"

echo "==> Préparation du DMG"

cp -R "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "Focus Tube" \
    -srcfolder "$STAGING_DIR" \
    -format UDZO \
    -ov \
    "$DMG_PATH"

echo
echo "Terminé."
echo "Application : $APP_PATH"
echo "Image disque : $DMG_PATH"
echo
echo "Cette version n'est pas signée avec Developer ID ni notariée."
echo "Gatekeeper peut afficher un avertissement ou bloquer son ouverture."
