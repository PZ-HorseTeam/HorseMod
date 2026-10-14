"""
Generates the pzmap links to the horse zones corners to easily verify them
"""

from pathlib import Path

from util.execute_lua import run_files

CURRENT_FOLDER = Path(__file__).parent
MAP_SOFT_LINK = "https://pzmap.org" # add ?XxY for specific coords

lua_files = [
    CURRENT_FOLDER / "stubs.lua",
    CURRENT_FOLDER / "../../Contents/mods/HorseMod/42/media/lua/server/HorseMod/HorseZones.lua"
]

lua, modules = run_files(lua_files)
horse_zones = modules["HorseZones"]

links = []
for zone, data in horse_zones.zones.items():
    x1 = data["x1"]
    y1 = data["y1"]
    x2 = data["x2"]
    y2 = data["y2"]
    name = data["name"]

    print(f"Zone: {zone}, Name: {name}, Coordinates: ({x1}, {y1}) to ({x2}, {y2})")
    links.append(f"{name}".ljust(15) + f"{MAP_SOFT_LINK}?area={x1}x{y1}-{x2}x{y2}")

OUTPUT_FILE = CURRENT_FOLDER / "zone_links.txt"
with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
    for link in links:
        f.write(link + "\n")