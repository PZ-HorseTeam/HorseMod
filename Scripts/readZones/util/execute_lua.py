from pathlib import Path
from lupa import LuaRuntime

def run_files(lua_files: list[Path]):
    """
    Run multiple Lua files in order.

    Args:
        lua_files (list[Path]): A list of paths to Lua files to be executed.

    Raises:
        FileNotFoundError: If any of the specified Lua files do not exist.

    Returns:
        tuple[LuaRuntime, dict[str, object]]: The runtime and returned module
            values keyed by Lua file stem.
    """

    # create a Lua runtime
    lua = LuaRuntime(unpack_returned_tuples=True)
    modules = {}

    # execute each file in order
    for lua_file in lua_files:
        lua_file = Path(lua_file)
        if lua_file.exists():
            with open(lua_file, 'r', encoding='utf-8') as f:
                lua_code = f.read()
                module = lua.execute(lua_code)
                if module is not None:
                    modules[lua_file.stem] = module
            print(f"Loaded: {lua_file.name}")
        else:
            raise FileNotFoundError(f"File not found: {lua_file}")

    return lua, modules


