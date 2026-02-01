-- Turret Range Research
-- Compatible with Factorio 2.0 and Space Age
-- Research upgrades ALL turrets automatically (like artillery shell range)

local RANGE_BONUS_PER_LEVEL = 3  -- Tiles of range per research level

-- Configuration table (shared with control.lua via settings)
local TURRET_CONFIG = {
    {
        base_name = "gun-turret",
        turret_type = "ammo-turret",
        max_level = 5,
        tech_prefix = "gun-turret-range"
    },
    {
        base_name = "laser-turret",
        turret_type = "electric-turret",
        max_level = 5,
        tech_prefix = "laser-turret-range"
    },
    {
        base_name = "flamethrower-turret",
        turret_type = "fluid-turret",
        max_level = 3,
        tech_prefix = "flamethrower-turret-range"
    }
}

-- ============================================================================
-- RUNTIME RANGE MODIFICATION
-- Range bonuses are applied at runtime directly to turret entities
-- This provides better mod compatibility and eliminates hidden entities
-- ============================================================================
-- Note: Range modification is handled in control.lua

-- ============================================================================
-- TECHNOLOGY DEFINITIONS
-- ============================================================================

-- Gun Turret Range Research
for level = 1, 5 do
    local prerequisites = {}
    if level == 1 then
        prerequisites = {"gun-turret", "military-science-pack"}
    elseif level == 3 then
        -- First level requiring chemical science
        prerequisites = {"gun-turret-range-" .. (level - 1), "chemical-science-pack"}
    elseif level == 5 then
        -- First level requiring utility science
        prerequisites = {"gun-turret-range-" .. (level - 1), "utility-science-pack"}
    else
        prerequisites = {"gun-turret-range-" .. (level - 1)}
    end
    
    local ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"military-science-pack", 1}
    }
    if level >= 3 then table.insert(ingredients, {"chemical-science-pack", 1}) end
    if level >= 5 then table.insert(ingredients, {"utility-science-pack", 1}) end
    
    data:extend({{
        type = "technology",
        name = "gun-turret-range-" .. level,
        icon = "__base__/graphics/technology/gun-turret.png",
        icon_size = 256,
        effects = {
            {
                type = "nothing",
                effect_description = {"technology-effect.turret-range-bonus", "+" .. (level * RANGE_BONUS_PER_LEVEL)}
            }
        },
        prerequisites = prerequisites,
        unit = {
            count = 100 * level,
            ingredients = ingredients,
            time = 60
        },
        upgrade = true
    }})
end

-- Laser Turret Range Research
for level = 1, 5 do
    local prerequisites = {}
    if level == 1 then
        -- Laser turret already requires chemical science, so include it
        prerequisites = {"laser-turret", "military-science-pack", "chemical-science-pack"}
    elseif level == 3 then
        -- First level requiring utility science
        prerequisites = {"laser-turret-range-" .. (level - 1), "utility-science-pack"}
    elseif level == 5 then
        -- First level requiring space science (if Space Age DLC is installed)
        prerequisites = {"laser-turret-range-" .. (level - 1)}
        if data.raw.tool["space-science-pack"] then
            table.insert(prerequisites, "space-science-pack")
        else
            table.insert(prerequisites, "utility-science-pack")
        end
    else
        prerequisites = {"laser-turret-range-" .. (level - 1)}
    end

    local ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"military-science-pack", 1},
        {"chemical-science-pack", 1}
    }
    if level >= 3 then table.insert(ingredients, {"utility-science-pack", 1}) end
    -- Only add space science if Space Age DLC is installed
    if level >= 5 and data.raw.tool["space-science-pack"] then
        table.insert(ingredients, {"space-science-pack", 1})
    end
    
    data:extend({{
        type = "technology",
        name = "laser-turret-range-" .. level,
        icon = "__base__/graphics/technology/laser-turret.png",
        icon_size = 256,
        effects = {
            {
                type = "nothing",
                effect_description = {"technology-effect.turret-range-bonus", "+" .. (level * RANGE_BONUS_PER_LEVEL)}
            }
        },
        prerequisites = prerequisites,
        unit = {
            count = 150 * level,
            ingredients = ingredients,
            time = 60
        },
        upgrade = true
    }})
end

-- Flamethrower Turret Range Research
for level = 1, 3 do
    local prerequisites = {}
    if level == 1 then
        -- Flamethrower requires chemical science
        prerequisites = {"flamethrower", "military-science-pack", "chemical-science-pack"}
    elseif level == 3 then
        -- First level requiring utility science
        prerequisites = {"flamethrower-turret-range-" .. (level - 1), "utility-science-pack"}
    else
        prerequisites = {"flamethrower-turret-range-" .. (level - 1)}
    end
    
    local ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"military-science-pack", 1},
        {"chemical-science-pack", 1}
    }
    if level >= 3 then table.insert(ingredients, {"utility-science-pack", 1}) end
    
    data:extend({{
        type = "technology",
        name = "flamethrower-turret-range-" .. level,
        icon = "__base__/graphics/technology/flamethrower.png",
        icon_size = 256,
        effects = {
            {
                type = "nothing",
                effect_description = {"technology-effect.turret-range-bonus", "+" .. (level * RANGE_BONUS_PER_LEVEL)}
            }
        },
        prerequisites = prerequisites,
        unit = {
            count = 125 * level,
            ingredients = ingredients,
            time = 60
        },
        upgrade = true
    }})
end
