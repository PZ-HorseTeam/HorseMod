# make sure main branch is being uploaded
git checkout main
git pull

# store current folder
WORKSHOP_DIR=$(pwd)

MOD_TITLE="Horse Mod [B42/MP SOON]"
WORKSHOP_ID=3661336777
VISIBILITY=0
TAGS="Build 42,Animals,Items,Misc,Vehicles,Models"

# need to be in the steam uploader folder
cd "$STEAMUPLOADER"
./SteamUploader --appID 108600 --workshopID "$WORKSHOP_ID" --description "$WORKSHOP_DIR/Steam/description.bbcode" --patchNote "$WORKSHOP_DIR/Steam/patch_note.bbcode" -c "$WORKSHOP_DIR/Contents" --preview "$WORKSHOP_DIR/Steam/preview.gif" --title "$MOD_TITLE" --visibility "$VISIBILITY" --tags "$TAGS"

# return to original folder, needed bcs SteamUploader doesn't support paths outside of its own folder for now
cd $WORKSHOP_DIR