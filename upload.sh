set -e

# script usage
VERSION="${1:?Usage: ./upload.sh <version> [gh-options]}"
shift || true

# store current folder
WORKSHOP_DIR=$(pwd)

# verify that the version is valid
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: Invalid version format. Expected format: X.Y or X.Y.Z"
    exit 1
fi

# verify the patch note exists
PATCH_NOTE_PATH="$WORKSHOP_DIR/Steam/patch_notes/$VERSION.bbcode"
if [[ ! -f "$PATCH_NOTE_PATH" ]]; then
    echo "Error: Patch note file '$PATCH_NOTE_PATH' does not exist."
    exit 1
fi

# make sure main branch is being uploaded
git checkout main
git pull


MOD_TITLE="Horse Mod [B42.20+/MP]"
WORKSHOP_ID=3661336777
VISIBILITY=0
TAGS="Build 42,Animals,Items,Misc,Vehicles,Models,Multiplayer"

# need to be in the steam uploader folder
cd "$STEAMUPLOADER"
./SteamUploader --appID 108600 --workshopID "$WORKSHOP_ID" \
    --description "$WORKSHOP_DIR/Steam/description.bbcode" \
    --patchNote "$PATCH_NOTE_PATH" \
    -c "$WORKSHOP_DIR/Contents" \
    --preview "$WORKSHOP_DIR/Steam/preview.gif" \
    --title "$MOD_TITLE" --visibility "$VISIBILITY" --tags "$TAGS"

# go to the contents folder and zip it for github release
cd "$WORKSHOP_DIR/Contents"

ARCHIVE="/tmp/release.zip"
zip -r "$ARCHIVE" mods

gh release create "$VERSION" "$ARCHIVE" \
    --notes "$VERSION" \
    "$@"

rm -f "$ARCHIVE"