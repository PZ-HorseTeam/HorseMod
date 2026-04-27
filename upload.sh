set -e

# script usage
VERSION="${1:?Usage: ./upload.sh <version> [gh-options]}"
shift || true

# need to be in the steam uploader folder
SteamUploader upload --patchnote "$WORKSHOP_DIR/Steam/patch_notes/$VERSION.bbcode"

# github release
cd Contents
ARCHIVE="/tmp/release.zip"
zip -r "$ARCHIVE" mods

gh release create "$VERSION" "$ARCHIVE" \
    --notes "$VERSION" \
    "$@"

rm -f "$ARCHIVE"