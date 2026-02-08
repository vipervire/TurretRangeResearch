-- Data Final Fixes - Runs after all other mods
-- Extends damage research technologies to include our turret variants
-- This ensures variants receive the same damage bonuses as base turrets

-- Problem: Damage technologies only target vanilla turret entities by name
-- Our variant turrets (gun-turret-ranged-1, etc.) are not included in the effects
-- Solution: Add turret-attack effects for our variants to all relevant technologies

local TURRET_CONFIG = {
    {
        base_name = "gun-turret",
        turret_type = "ammo-turret",
        max_level = 5,
        damage_techs = {
            "physical-projectile-damage",  -- Affects gun turrets
        }
    },
    {
        base_name = "laser-turret",
        turret_type = "electric-turret",
        max_level = 5,
        damage_techs = {
            "energy-weapons-damage",       -- Affects laser turrets
        }
    },
    {
        base_name = "flamethrower-turret",
        turret_type = "fluid-turret",
        max_level = 3,
        damage_techs = {
            "refined-flammables",          -- Affects flamethrower turrets
        }
    }
}

-- Add Space Age turrets if the DLC is installed
if data.raw["ammo-turret"]["rocket-turret"] then
    table.insert(TURRET_CONFIG, {
        base_name = "rocket-turret",
        turret_type = "ammo-turret",
        max_level = 5,
        damage_techs = {
            "stronger-explosives",         -- Affects rocket turrets
        }
    })
end

if data.raw["electric-turret"]["tesla-turret"] then
    table.insert(TURRET_CONFIG, {
        base_name = "tesla-turret",
        turret_type = "electric-turret",
        max_level = 5,
        damage_techs = {
            "energy-weapons-damage",       -- Affects tesla turrets
        }
    })
end

-- Function to add turret-attack effects for our variants to a technology
local function add_variant_effects(tech, variant_names, base_modifier)
    if not tech or not tech.effects then return end

    -- For each variant, add a turret-attack effect matching the base turret's modifier
    for _, variant_name in pairs(variant_names) do
        table.insert(tech.effects, {
            type = "turret-attack",
            turret_id = variant_name,
            modifier = base_modifier or 0.1  -- Default 10% increase
        })
    end
end

-- For each turret type, extend all relevant damage technologies
for _, config in pairs(TURRET_CONFIG) do
    -- Build list of variant names
    local variant_names = {}
    for level = 1, config.max_level do
        table.insert(variant_names, config.base_name .. "-ranged-" .. level)
    end

    -- Find and extend each damage technology
    for _, tech_prefix in pairs(config.damage_techs) do
        -- Check all possible levels (1-20 for infinite research)
        for level = 1, 20 do
            local tech_name = tech_prefix .. "-" .. level
            local tech = data.raw.technology[tech_name]

            if tech and tech.effects then
                -- Find the modifier value from existing effects
                local base_modifier = 0.1  -- Default
                for _, effect in pairs(tech.effects) do
                    if effect.type == "turret-attack" and effect.modifier then
                        base_modifier = effect.modifier
                        break
                    end
                end

                -- Add effects for our variants
                add_variant_effects(tech, variant_names, base_modifier)
            end
        end
    end
end
