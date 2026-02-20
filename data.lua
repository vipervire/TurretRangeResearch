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

-- Add Space Age turrets if the DLC is installed
if data.raw["ammo-turret"]["rocket-turret"] then
    table.insert(TURRET_CONFIG, {
        base_name = "rocket-turret",
        turret_type = "ammo-turret",
        max_level = 5,
        tech_prefix = "rocket-turret-range"
    })
end

if data.raw["electric-turret"]["tesla-turret"] then
    table.insert(TURRET_CONFIG, {
        base_name = "tesla-turret",
        turret_type = "electric-turret",
        max_level = 5,
        tech_prefix = "tesla-turret-range"
    })
end

-- ============================================================================
-- CREATE HIDDEN TURRET VARIANTS
-- These are identical to base turrets but with increased range
-- They use the same localised name so players see them as the same turret
-- ============================================================================

for _, config in pairs(TURRET_CONFIG) do
    local base = data.raw[config.turret_type] and data.raw[config.turret_type][config.base_name]
    if base then
        -- Get the base turret's fast_replaceable_group (use existing or default to base_name)
        -- This ensures compatibility with mods that modify turret upgrade chains (like Bob's Warfare)
        local replaceable_group = base.fast_replaceable_group or config.base_name

        for level = 1, config.max_level do
            local variant = table.deepcopy(base)
            variant.name = config.base_name .. "-ranged-" .. level

            -- Keep the same localised name as the base turret (invisible to player)
            variant.localised_name = {"entity-name." .. config.base_name}
            variant.localised_description = {"entity-description." .. config.base_name}

            -- Mining returns the base item
            if variant.minable then
                variant.minable.result = config.base_name
            end

            -- Modify the attack range directly in the deep-copied attack_parameters
            if variant.attack_parameters then
                variant.attack_parameters.range = (base.attack_parameters.range or 20) + (level * RANGE_BONUS_PER_LEVEL)
            end

            -- Hide from player (not in crafting menu, not selectable separately)
            variant.hidden = true
            variant.hidden_in_factoriopedia = true

            -- Use same fast_replaceable_group as base turret for seamless swapping
            -- This MUST match the base turret's group for fast_replace to work
            variant.fast_replaceable_group = replaceable_group

            -- Copy the placeable_by so robots can work with them
            variant.placeable_by = {item = config.base_name, count = 1}

            data:extend({variant})
        end
    end
end

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

-- Rocket Turret Range Research (Space Age only)
if data.raw["ammo-turret"]["rocket-turret"] then
    for level = 1, 5 do
        local prerequisites = {}
        if level == 1 then
            -- Check if rocket-turret technology exists, otherwise use a fallback
            if data.raw.technology["rocket-turret"] then
                prerequisites = {"rocket-turret", "military-science-pack", "utility-science-pack"}
            else
                -- Fallback: use just utility science if the tech doesn't exist
                prerequisites = {"military-science-pack", "utility-science-pack"}
            end
        elseif level == 3 then
            -- First level requiring space science
            prerequisites = {"rocket-turret-range-" .. (level - 1)}
            if data.raw.tool["space-science-pack"] then
                table.insert(prerequisites, "space-science-pack")
            end
        else
            prerequisites = {"rocket-turret-range-" .. (level - 1)}
        end

        local ingredients = {
            {"automation-science-pack", 1},
            {"logistic-science-pack", 1},
            {"military-science-pack", 1},
            {"chemical-science-pack", 1},
            {"utility-science-pack", 1}
        }
        if level >= 3 and data.raw.tool["space-science-pack"] then
            table.insert(ingredients, {"space-science-pack", 1})
        end

        data:extend({{
            type = "technology",
            name = "rocket-turret-range-" .. level,
            icon = "__space-age__/graphics/technology/rocket-turret.png",
            icon_size = 256,
            effects = {
                {
                    type = "nothing",
                    effect_description = {"technology-effect.turret-range-bonus", "+" .. (level * RANGE_BONUS_PER_LEVEL)}
                }
            },
            prerequisites = prerequisites,
            unit = {
                count = 200 * level,
                ingredients = ingredients,
                time = 60
            },
            upgrade = true
        }})
    end
end

-- Tesla Turret Range Research (Space Age only)
if data.raw["electric-turret"]["tesla-turret"] then
    for level = 1, 5 do
        local prerequisites = {}
        if level == 1 then
            -- Tesla turret is unlocked by "tesla-weapons" technology
            if data.raw.technology["tesla-weapons"] then
                prerequisites = {"tesla-weapons", "military-science-pack", "utility-science-pack"}
            else
                -- Fallback if Space Age isn't installed
                prerequisites = {"military-science-pack", "utility-science-pack"}
            end
        elseif level == 3 then
            -- First level requiring space science
            prerequisites = {"tesla-turret-range-" .. (level - 1)}
            if data.raw.tool["space-science-pack"] then
                table.insert(prerequisites, "space-science-pack")
            end
        else
            prerequisites = {"tesla-turret-range-" .. (level - 1)}
        end

        local ingredients = {
            {"automation-science-pack", 1},
            {"logistic-science-pack", 1},
            {"military-science-pack", 1},
            {"chemical-science-pack", 1},
            {"utility-science-pack", 1}
        }
        if level >= 3 and data.raw.tool["space-science-pack"] then
            table.insert(ingredients, {"space-science-pack", 1})
        end

        data:extend({{
            type = "technology",
            name = "tesla-turret-range-" .. level,
            icon = "__space-age__/graphics/technology/tesla-weapons.png",
            icon_size = 256,
            effects = {
                {
                    type = "nothing",
                    effect_description = {"technology-effect.turret-range-bonus", "+" .. (level * RANGE_BONUS_PER_LEVEL)}
                }
            },
            prerequisites = prerequisites,
            unit = {
                count = 200 * level,
                ingredients = ingredients,
                time = 60
            },
            upgrade = true
        }})
    end
end
