import os
import pandas as pd

# # Read the console file
# with open(console_file, 'r') as f:
#     content = f.read()



script_dir = os.path.dirname(os.path.abspath(__file__))

csv_path = os.path.join(script_dir, '..', 'Data', 'timedActions.csv')

# Read the CSV file using pandas
df = pd.read_csv(csv_path, encoding='utf-8')

TIMEDACTION_TEMPLATE = """---AUTOMATICALLY GENERATED FROM script/formatTimedActionBlocker.py
---
---Holds the data of the timed actions to allow while mounted on a horse.
local ActionBlocker = {{
    ---Valid timed actions while horse riding.
    ---@type table<string, true>
    validActions = {{
{timedActions}
    }},
}}

return ActionBlocker"""


# Format the matches into Lua table format
DATA_FORMAT = '        ["{timedAction}"] = {bool},\n'
# DATA_FORMAT = '{timedAction}\n'

formatted_actions = ""
df = df.sort_values(by=['timedAction'])
for _, row in df.iterrows():
    action = row['timedAction']
    canRun = row['canRun']
    if type(canRun) is bool and canRun is True:
        formatted_actions += DATA_FORMAT.format(timedAction=action, bool=str(canRun).lower())
formatted_actions = formatted_actions.rstrip()  # Remove trailing newline

format_table = TIMEDACTION_TEMPLATE.format(timedActions=formatted_actions)

print(f"\033[33m{format_table}\033[0m")

output_path = os.path.join(
    script_dir, 
    '..', 
    'Contents',
    'mods',
    'HorseMod',
    '42',
    'media',
    'lua',
    'shared',
    'HorseMod',
    'patches',
    'ActionBlocker.lua'
)

with open(output_path, 'w', encoding='utf-8') as f:
    f.write(format_table)
    print(f"Wrote to \033[36m{output_path}\033[0m")