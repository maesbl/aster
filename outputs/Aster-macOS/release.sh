#!/bin/zsh
set -eu
PROJECT_DIR="${0:A:h}"
OUTPUT_DIR="${PROJECT_DIR:h}"
STAGING="$(mktemp -d "${OUTPUT_DIR:h}/work/aster-release.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
export ASTER_ARCHS="arm64 x86_64"
export ASTER_APP_DIR="$STAGING/Aster.app"
zsh "$PROJECT_DIR/build.sh"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist")
KIND="preview"
if [[ -n "${ASTER_DEVELOPER_ID:-}" ]]; then
  [[ -n "${ASTER_NOTARY_PROFILE:-}" ]] || { echo 'Falta ASTER_NOTARY_PROFILE: el perfil de notaría guardado en el Llavero.' >&2; exit 1; }
  ditto -c -k --keepParent "$ASTER_APP_DIR" "$STAGING/Aster-notarize.zip"
  xcrun notarytool submit "$STAGING/Aster-notarize.zip" --keychain-profile "$ASTER_NOTARY_PROFILE" --wait
  xcrun stapler staple "$ASTER_APP_DIR"
  xcrun stapler validate "$ASTER_APP_DIR"
  spctl --assess --type execute "$ASTER_APP_DIR"
  KIND="release"
fi
mkdir "$STAGING/Disk"
ditto "$ASTER_APP_DIR" "$STAGING/Disk/Aster.app"
ln -s /Applications "$STAGING/Disk/Applications"
cp "$PROJECT_DIR/INSTALAR.md" "$STAGING/Disk/LEEME.md"
hdiutil create -volname "Aster $VERSION" -srcfolder "$STAGING/Disk" -ov -format UDZO "$OUTPUT_DIR/Aster-$VERSION-$KIND-universal.dmg"
if [[ "$KIND" == "release" ]]; then
  codesign --sign "$ASTER_DEVELOPER_ID" --timestamp "$OUTPUT_DIR/Aster-$VERSION-$KIND-universal.dmg"
  xcrun notarytool submit "$OUTPUT_DIR/Aster-$VERSION-$KIND-universal.dmg" --keychain-profile "$ASTER_NOTARY_PROFILE" --wait
  xcrun stapler staple "$OUTPUT_DIR/Aster-$VERSION-$KIND-universal.dmg"
fi
codesign --verify --strict "$ASTER_APP_DIR"
ditto "$ASTER_APP_DIR" "$OUTPUT_DIR/Aster.app"
rm -f "$OUTPUT_DIR/Aster.app/Contents/Resources/connection.json"
codesign --verify --strict "$OUTPUT_DIR/Aster.app"
shasum -a 256 "$OUTPUT_DIR/Aster-$VERSION-$KIND-universal.dmg" > "$OUTPUT_DIR/Aster-$VERSION-$KIND-universal.dmg.sha256"
echo "Paquete $KIND preparado; arm64 y x86_64."
