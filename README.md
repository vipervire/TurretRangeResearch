# Turret Range Research

A Factorio 2.0 and Space Age compatible mod that adds research to increase turret attack range. Works just like Artillery Shell Range research - completing the research automatically upgrades ALL existing turrets of that type.

## Features

- **Gun Turret Range (5 levels)**: Each level adds +3 tiles of range (max +15)
- **Laser Turret Range (5 levels)**: Each level adds +3 tiles of range (max +15)
- **Flamethrower Turret Range (3 levels)**: Each level adds +3 tiles of range (max +9)
- **Space Age Support**: Rocket and Tesla turrets (5 levels each)
- **Modded Turret Support**: Automatically supports modded turrets or allows explicit registration

## How It Works

When you complete a turret range research:
1. **All existing turrets** of that type are instantly upgraded
2. **All newly placed turrets** automatically have the upgraded range
3. No new items or recipes - your turrets just get better!

This works identically to vanilla Artillery Shell Range research.

## Modded Turret Support

This mod can automatically support modded turrets! You have two options:

### Auto-Discovery (Easiest)
By default, the mod automatically discovers and supports any modded turrets of compatible types (ammo-turret, electric-turret, fluid-turret).

**Priority System:**
Auto-discovery respects existing range research to avoid conflicts:
1. **Existing range research** - If a turret already has technologies like `plasma-turret-range-1`, those are used (highest priority)
2. **Ammo-based mapping** - If no existing research, map to vanilla research by ammo type (if enabled)
3. **Unique research tree** - If ammo mapping is disabled, each turret gets its own tree

**Intelligent Ammo-Based Mapping:**
Auto-discovered turrets are mapped to vanilla research based on their ammunition type:
- **Bullet/Shotgun turrets** → Use `gun-turret-range` research (direct-fire projectiles)
- **Explosive turrets** (Rockets/Cannons) → Use `rocket-turret-range` research (area-damage weapons)
- **Electric turrets** → Use `laser-turret-range` or `tesla-turret-range` research
  - Tesla-like turrets (name contains "tesla", "lightning", or "arc") → `tesla-turret-range`
  - All other electric turrets → `laser-turret-range`
- **Fluid turrets** → Use `flamethrower-turret-range` research

This means modded turrets benefit from vanilla research automatically! For example, a modded heavy rocket turret will upgrade when you research rocket-turret-range, and a "plasma tesla cannon" will upgrade with tesla-turret-range.

**Mod Settings:**
- **Enable modded turret support**: Master toggle for modded turret features (default: enabled)
- **Auto-discover modded turrets**: Automatically detect and support compatible modded turrets (default: enabled)
- **Map modded turrets to vanilla research by ammo type**: Share vanilla research based on ammo type (default: enabled). Disable to give each modded turret its own separate research tree.
- **Default max research level for modded turrets**: Maximum research level when NOT using ammo mapping (default: 5)

### Explicit Registration (For Mod Authors)

Other mod authors can explicitly register their turrets for full support:

**Option 1: Data Stage Registration (for creating technologies)**
In your `data.lua` or `data-updates.lua`:
```lua
-- Ensure the global table exists
if not turret_range_research_registrations then
    turret_range_research_registrations = {}
end

-- Register your turret
table.insert(turret_range_research_registrations, {
    base_name = "plasma-turret",          -- Your turret entity name
    turret_type = "electric-turret",      -- ammo-turret, electric-turret, or fluid-turret
    max_level = 5,                        -- Number of research levels
    tech_prefix = "plasma-turret-range",  -- Technology name prefix
    damage_techs = {"energy-weapons-damage"}  -- Optional: damage techs that should affect variants
})
```

**Option 2: Runtime Registration**
In your `control.lua` during `on_init`:
```lua
script.on_init(function()
    remote.call("turret-range-research", "register_modded_turret", {
        base_name = "plasma-turret",
        type = "electric-turret",
        tech_prefix = "plasma-turret-range",
        max_level = 5
    })
end)
```

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

-- Register a modded turret (runtime)
remote.call("turret-range-research", "register_modded_turret", {
    base_name = "plasma-turret",
    type = "electric-turret",
    tech_prefix = "plasma-turret-range",
    max_level = 5
})

-- Get all supported turrets (vanilla + custom + discovered)
-- Returns: table of base_name -> config
local all_turrets = remote.call("turret-range-research", "get_all_turrets")

-- Get list of auto-discovered turrets
-- Returns: table of base_name -> config
local discovered = remote.call("turret-range-research", "get_discovered_turrets")
```

## License

MIT License - Feel free to modify and redistribute.
