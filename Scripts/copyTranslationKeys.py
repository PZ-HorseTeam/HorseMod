import json
from pathlib import Path

TRANSLATIONS_DIR = Path("Contents/mods/HorseMod/common/media/lua/shared/Translate")

target_language = input("Chose language code to copy to (e.g. FR, RU, etc.) and press Enter:\n> ")

# list json files in the EN directory
en_dir = TRANSLATIONS_DIR / "EN"
json_files = list(en_dir.glob("*.json"))

for json_file in json_files:
    file_name = json_file.name
    with open(json_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    # create or open the corresponding file in the target language directory
    target_dir = TRANSLATIONS_DIR / target_language
    target_dir.mkdir(parents=True, exist_ok=True)
    target_file = target_dir / file_name
    if not target_file.exists():
        with open(target_file, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=4)
    else:
        with open(target_file, "r", encoding="utf-8") as f:
            target_data = json.load(f)

        # copy missing keys from the EN file to the target language file
        updated = False
        for key, value in data.items():
            if key not in target_data:
                target_data[key] = value
                updated = True

        # save the updated target language file if there were any changes
        if updated:
            with open(target_file, "w", encoding="utf-8") as f:
                json.dump(target_data, f, ensure_ascii=False, indent=4)
