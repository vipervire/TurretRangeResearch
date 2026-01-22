# Turret Range Research

A Factorio 2.0 and Space Age compatible mod that adds research to increase turret attack range. Works just like Artillery Shell Range research - completing the research automatically upgrades ALL existing turrets of that type.

## Features

- **Gun Turret Range (5 levels)**: Each level adds +3 tiles of range (max +15)
- **Laser Turret Range (5 levels)**: Each level adds +3 tiles of range (max +15)
- **Flamethrower Turret Range (3 levels)**: Each level adds +3 tiles of range (max +9)

## How It Works

When you complete a turret range research:
1. **All existing turrets** of that type are instantly upgraded
2. **All newly placed turrets** automatically have the upgraded range
3. No new items or recipes - your turrets just get better!

This works identically to vanilla Artillery Shell Range research.

## Research Requirements

### Gun Turret Range
| Level | Science Packs | Research Time |
|-------|--------------|---------------|
| 1-2 | Automation, Logistics, Military | 40-50s |
| 3-4 | + Chemical | 60-70s |
| 5 | + Utility | 80s |

### Laser Turret Range
| Level | Science Packs | Research Time |
|-------|--------------|---------------|
| 1-2 | Automation, Logistics, Military, Chemical | 55-65s |
| 3-4 | + Utility | 75-85s |
| 5 | + Space (Space Age) | 95s |

### Flamethrower Turret Range
| Level | Science Packs | Research Time |
|-------|--------------|---------------|
| 1-2 | Automation, Logistics, Military, Chemical | 50-60s |
| 3 | + Utility | 70s |

## Installation

1. Download the mod zip file
2. Place in your Factorio mods folder:
   - Windows: `%APPDATA%\Factorio\mods\`
   - Linux: `~/.factorio/mods/`
   - Mac: `~/Library/Application Support/factorio/mods/`
3. Enable the mod in the Factorio mod menu

## Compatibility

- Factorio 2.0+
- Space Age expansion (optional - enables space science tier for laser turrets)
- Safe to add to existing saves - turrets will be upgraded based on completed research
- Should be compatible with most other mods

## Technical Details

The mod creates hidden turret variants with increased range and seamlessly swaps turrets when research completes. From the player's perspective, it appears as a direct stat upgrade. Turret health, ammunition, fluids, and kill counts are all preserved during the upgrade.

## Remote Interface

Other mods can interact with this mod:
```lua
-- Get range bonus (in tiles) for a turret type
local bonus = remote.call("turret-range-research", "get_range_bonus", "player", "gun-turret")

-- Force recalculation of all turrets
remote.call("turret-range-research", "refresh_all_turrets")
```

## Version History

### 1.0.0
- Initial release
- Gun turret, laser turret, and flamethrower turret range research
- Automatic upgrade system (like artillery range)

## License

MIT License - Feel free to modify and redistribute.
