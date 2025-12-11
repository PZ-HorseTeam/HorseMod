# Style Guide
## Lua
### Indentation
Indentation must be 4 spaces. Tab characters must not be used. The indentation level is increased where a new scope starts or when a statement extends to multiple lines, and decreased when a scope or multiline statement ends.
### Conditionals
Conditionals must never be inlined:
```lua
if condition then
    doSomething()
end
```
#### Guard clauses
As an exception, guard clauses may be inlined:
```lua
if not condition then return end
```
### Function calls
All function calls must use the `fun()` syntax; they must not use the `fun ""` or `fun {}` syntaxes.
Function calls that are too long for a single line must have each argument placed on a new indented line.
```lua
longFunctionName(
    reallyLongParameters,
    thatProbablyGoOffscreen,
    someFunctionCallsInThereToo(),
    etc
)
```
### Require
Requires must use the `fun()` syntax, as all functions. Require paths must not include the `.lua` file extension. All files that create objects referenced by a file must be required, even if they are already guaranteed to load earlier.
### Type annotations
#### Functions
All functions must have full EmmyLua type annotations. Functions with no side effects must have a `@nodiscard` annotation, unless it is reasonable to assume that this will change in the future. A function with side effects must not have this annotation even if it serves little purpose to discard the return value. For these purposes, debug logging is not considered a side effect.
#### Variables
A variable must be type annotated at declaration if:
- It contains a table, and it is not initialised to the return value of a type annotated function.
- It can contain more than one type.
- It contains a discrete set of string literals.

In all other cases, variables do not have to be type annotated, but it is recommended to do so when it increases the readability of the code.

## Scripts
Indentation must be 4 spaces. Indentation level increases at the start of a block, and decreases at the end of a block. Tab characters must not be used: be careful when referencing Vanilla scripts that you do not copy in a tab character. Inline brackets must be used.
```
type id {
    ...
}
```

