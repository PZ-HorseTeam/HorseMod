# to be used with https://github.com/SimKDT/Steam-Uploader-rs

set -e

# script usage
VERSION="${1:?Usage: ./upload-rs.sh <version> [gh-options]}"
shift || true

# verify that the version is valid
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: Invalid version format. Expected format: X.Y or X.Y.Z"
    exit 1
fi

# verify the patch note exists
PATCH_NOTE_PATH="./Steam/patch_notes/$VERSION.bbcode"
if [[ ! -f "$PATCH_NOTE_PATH" ]]; then
    echo "Error: Patch note file '$PATCH_NOTE_PATH' does not exist."
    exit 1
fi

# make sure main branch is being uploaded
git checkout main
git pull

# verify that the SteamUploader binary is available
if ! command -v SteamUploader &> /dev/null; then
    echo "Error: SteamUploader binary not found. Please ensure it is installed and in your PATH."
    exit 1
fi

SteamUploader upload --patchnote "$PATCH_NOTE_PATH"

# github release
cd Contents
ARCHIVE="/tmp/release.zip"
zip -r "$ARCHIVE" mods

gh release create "$VERSION" "$ARCHIVE" \
    --notes "$VERSION" \
    "$@"

rm -f "$ARCHIVE"