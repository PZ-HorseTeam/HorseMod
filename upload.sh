set -e

# script usage
VERSION="${1:?Usage: ./upload.sh <version> [gh-options]}"
shift || true

# make sure main branch is being uploaded
git checkout main
git pull

# store current folder
WORKSHOP_DIR=$(pwd)

MOD_TITLE="Horse Mod [B42.14+/MP SOON]"
WORKSHOP_ID=3661336777
VISIBILITY=0
TAGS="Build 42,Animals,Items,Misc,Vehicles,Models"

# need to be in the steam uploader folder
cd "$STEAMUPLOADER"
./SteamUploader --appID 108600 --workshopID "$WORKSHOP_ID" \
    --description "$WORKSHOP_DIR/Steam/description.bbcode" \
    --patchNote "$WORKSHOP_DIR/Steam/patch_notes/$VERSION.bbcode" \
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