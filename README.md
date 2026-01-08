# Batmobile (explorer/navigator)
#### V1.0.1
## Description
Batmobile itself does not do anything, but it provides other plugins to utilize it for exploring and path finding.
For exploration:
    - it normalizes coordinate system to 0.5 accuracy
    - it uses DFS and closests direction to previous target to choose exploration target
    - it passes the target to A* pathfinder to find the best route to target

Batmobile also handles any traversals in game if move command is given.

## Settings
- Toggle Drawings -- toggle to draw path, backtrack and status
- Use movement spells -- toggle to use movement spell as part of movement or not
- Reset Batmobile -- keybind to reset visited, frontier, backtrack, path and retries

### Movement spells
- checkboxes for movement spells available to your class. requires "Use movement spells" to be toggled on.

### Debug
- Toggle Explorer -- toggle to freeroam with explorer
- Logging -- set log level

## Example integrations
TBD (Arkham Asylum is integrated, so check there in the mean time)

## Changelog
### V1.0.1
Added debug section
Added toggle explorer to debug section
Moved logging to debug section

### V1.0.0
Initial release

### V0.0.1 - V0.0.13
Beta test

## To do
- expose settings that can be configurable

## Credits
In no particular order, the following have provided help in various form:
- Zewx
- Pinguu
- NotNeer
- Letrico
- SupraDad13
- Lanvi
- RadicalDadical55
- Diobyte
