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
| 1-2 | Automation, Logistics, Military | 60s |
| 3-4 | + Chemical | 60s |
| 5 | + Utility | 60s |

### Laser Turret Range
| Level | Science Packs | Research Time |
|-------|--------------|---------------|
| 1-2 | Automation, Logistics, Military, Chemical | 60s |
| 3-4 | + Utility | 60s |
| 5 | + Space (Space Age) | 60s |

### Flamethrower Turret Range
| Level | Science Packs | Research Time |
|-------|--------------|---------------|
| 1-2 | Automation, Logistics, Military, Chemical | 60s |
| 3 | + Utility | 60s |

## Installation

1. Download the mod zip file
2. Place in your Factorio mods folder:
   - Windows: `%APPDATA%\Factorio\mods\`
   - Linux: `~/.factorio/mods/`
   - Mac: `~/Library/Application Support/factorio/mods/`
3. Enable the mod in the Factorio mod menu

## Compatibility

- **Factorio 2.0+** required
- **Space Age expansion** (optional) - enables space science tier for laser turrets
- **Quality DLC** (optional) - fully supported, quality tiers are preserved
- Safe to add to existing saves - turrets will be upgraded based on completed research
- Compatible with most other mods

### Preserved During Upgrade
- ✅ Quality tier (Quality DLC)
- ✅ Ammunition/fluids
- ✅ Health and damage state
- ✅ Circuit network connections
- ✅ Circuit/logistic conditions
- ✅ Target selection settings
- ✅ Kill counter
- ✅ Entity labels and tags

## Technical Details

The mod creates hidden turret variants with increased range and uses Factorio's `fast_replace` mechanism (similar to upgrading assembling machines) to seamlessly swap turrets when research completes. From the player's perspective, it appears as a direct stat upgrade.

**For Mod Developers:**
- Turret entity references become invalid when upgraded (old entity is replaced with new entity)
- The mod raises `script_raised_built` events after turret replacement
- Entity tags and labels are preserved
- Use the remote interface below to check if an entity is a turret variant

## Remote Interface

Other mods can interact with this mod through the remote interface:

```lua
-- Get range bonus (in tiles) for a turret type
-- Returns: number (tiles of bonus)
local bonus = remote.call("turret-range-research", "get_range_bonus", "player", "gun-turret")

-- Manually trigger upgrade check for a force
remote.call("turret-range-research", "refresh_force", "player")

-- Check if an entity is one of our turret variants
-- Returns: base turret name (string) or nil
local base = remote.call("turret-range-research", "is_turret_variant", "gun-turret-ranged-3")
-- Returns: "gun-turret"

-- Get the correct variant name for a force's research level
-- Returns: string (entity name)
local variant = remote.call("turret-range-research", "get_variant_for_force", "gun-turret", "player")
-- Returns: "gun-turret-ranged-2" (if level 2 is researched)
```

## License

MIT License - Feel free to modify and redistribute.
