import shutil, re
from pathlib import Path

ICON_DIR = Path("Contents/mods/HorseMod/common/media/textures/Item_head")
ORIGINAL_ICON_PATH = Path("Contents/mods/HorseMod/common/media/textures/Item_head/Head_Horse_Rotten.png")


SCRIPT_FILE = Path("Contents/mods/HorseMod/42/media/scripts/HorseMod/horse_body/bodyparts_horse.txt")


# for each file in every subfolder in the ICON_DIR
# copy the ORIGINAL_ICON_PATH to be named the same
# as each files with a suffix "Rotten" added at the end, before .png

for icon_file in ICON_DIR.rglob("*.png"):
    if icon_file.name == ORIGINAL_ICON_PATH.name:
        continue  # Skip the original icon file itself

    # Create the new filename with "Rotten" suffix
    new_icon_name = icon_file.stem + "Rotten" + icon_file.suffix
    new_icon_path = icon_file.parent / new_icon_name

    # Copy the original icon to the new path
    shutil.copy(ORIGINAL_ICON_PATH, new_icon_path)
    print(f"Copied {ORIGINAL_ICON_PATH} to {new_icon_path}")