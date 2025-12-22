import re, pyperclip, os
from pprint import pprint
import pandas as pd

# # Read the console file
# with open(console_file, 'r') as f:
#     content = f.read()



script_dir = os.path.dirname(os.path.abspath(__file__))

csv_path = os.path.join(script_dir, 'timedActions.csv')

# Read the CSV file using pandas
df = pd.read_csv(csv_path, encoding='utf-8')

TIMEDACTION_TEMPLATE = """    ---Valid timed actions while horse riding.
    ---@type table<string, true>
    validActions = {{
{timedActions}
    }},"""


# Format the matches into Lua table format
DATA_FORMAT = '        ["{timedAction}"] = {bool},\n'
# DATA_FORMAT = '{timedAction}\n'

formatted_actions = ""
for _, row in df.iterrows():
    action = row['timedAction']
    canRun = row['canRun']
    if type(canRun) is bool and canRun is True:
        formatted_actions += DATA_FORMAT.format(timedAction=action, bool=str(canRun).lower())
formatted_actions = formatted_actions.rstrip()  # Remove trailing newline

format_table = TIMEDACTION_TEMPLATE.format(timedActions=formatted_actions)

print(format_table)
pyperclip.copy(format_table)


