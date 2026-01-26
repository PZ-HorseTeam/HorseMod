# store current folder
WORKSHOP_DIR=$(pwd)

MOD_TITLE="Horse mod [B42/MP SOON]"
WORKSHOP_ID=3525515977 # TEST MOD ID, NEEDS TO BE REPLACED FOR RELEASE
VISIBILITY=3 # UNLISTED, SWAP TO 0 FOR RELEASE
TAGS="Build 42,Animals,Items,Misc,Vehicles,Models"

# need to be in the steam uploader folder
cd "$STEAMUPLOADER"
./SteamUploader --appID 108600 --workshopID "$WORKSHOP_ID" --description "$WORKSHOP_DIR/description.bbcode" --patchNote "$WORKSHOP_DIR/patch_note.bbcode" -c "$WORKSHOP_DIR/Contents" --preview "$WORKSHOP_DIR/Mod preview/preview.gif" --title "$MOD_TITLE" --visibility "$VISIBILITY" --tags "$TAGS"

# return to original folder, needed bcs SteamUploader doesn't support paths outside of its own folder for now
cd $WORKSHOP_DIR