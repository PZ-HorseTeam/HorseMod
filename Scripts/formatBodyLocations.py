import pandas as pd
import os
import pyperclip

# Get the directory of the current script
script_dir = os.path.dirname(os.path.abspath(__file__))

## READ BODY LOCATIONS
# Path to the CSV file next to the script
csv_path = os.path.join(script_dir, 'bodyLocations.csv')

# Read the CSV file using pandas
df = pd.read_csv(csv_path, encoding='utf-8')

DATA_FORMAT = """    ---Table of allowed body locations to equip while mounted on a horse.
    ---@type table<string, boolean>
    allowedBodyLocations = {{
{bodyLocations}
    }},

    ---Table of allowed blood locations to equip while mounted on a horse.
    ---@type table<string, boolean>
    allowedBloodLocations = {{
{bloodLocations}
    }},"""
TABLE_LINE = '        ["{id}"] = {bool},'

# Format each row into Lua table format
bodyLocations = ""
for _, row in df.iterrows():
    bodyLocation = row['bodyLocation']
    canEquip = str(row['canEquip']).lower()
    formatted_line = TABLE_LINE.format(id=bodyLocation, bool=canEquip)
    bodyLocations += formatted_line + "\n"
bodyLocations = bodyLocations.rstrip()  # Remove trailing newline

## READ BLOOD LOCATIONS
# Path to the CSV file next to the script
csv_path = os.path.join(script_dir, 'bloodLocations.csv')

# Read the CSV file using pandas
df = pd.read_csv(csv_path, encoding='utf-8')

bloodLocations = ""
for _, row in df.iterrows():
    bloodLocation = row['bloodLocation']
    canEquip = str(row['canEquip']).lower()
    formatted_line = TABLE_LINE.format(id=bloodLocation, bool=canEquip)
    bloodLocations += formatted_line + "\n"
bloodLocations = bloodLocations.rstrip()  # Remove trailing newline

## FORMAT WHOLE DATA
bodyLocations = DATA_FORMAT.format(
    bodyLocations=bodyLocations,
    bloodLocations=bloodLocations
)

print(bodyLocations)
pyperclip.copy(bodyLocations)