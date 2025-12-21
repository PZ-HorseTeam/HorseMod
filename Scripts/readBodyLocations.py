import os, re
import pandas as pd
from pprint import pprint

bodyLocationEunmFile = "bodyLocationEnum.java"

script_dir = os.path.dirname(os.path.abspath(__file__))

java_path = os.path.join(script_dir, bodyLocationEunmFile)

with open(java_path, 'r', encoding='utf-8') as file:
    java_content = file.readlines()

PATTERN = r'public static final ItemBodyLocation \w+ = registerBase\("(\w+)"\);'

body_locations = [] 
for line in java_content:
    match = re.search(PATTERN, line)
    if match:
        body_location = match.group(1)
        body_locations.append(body_location)


csv_path = os.path.join(script_dir, 'bodyLocations.txt')
df = pd.read_csv(csv_path, encoding='utf-8')

# Get existing body locations from CSV
existing_locations = set(df['bodyLocation'].tolist())

# Find missing locations
missing_locations = []
for location in body_locations:
    full_location = f"base:{location.lower()}"
    if full_location not in existing_locations:
        missing_locations.append({'bodyLocation': full_location, 'canEquip': ''})

# Add missing entries to dataframe
if missing_locations:
    missing_df = pd.DataFrame(missing_locations)
    df = pd.concat([df, missing_df], ignore_index=True)
    
    # Save updated CSV
    df.to_csv(csv_path, index=False, encoding='utf-8')
    print(f"Added {len(missing_locations)} missing entries to CSV")