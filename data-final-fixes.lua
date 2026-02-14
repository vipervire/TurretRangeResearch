-- Data Final Fixes - Runs after all other mods
-- Extends damage research technologies to include our turret variants
-- This ensures variants receive the same damage bonuses as base turrets

-- Problem: Damage technologies only target vanilla turret entities by name
-- Our variant turrets (gun-turret-ranged-1, etc.) are not included in the effects
-- Solution: Add turret-attack effects for our variants to all relevant technologies

local RANGE_BONUS_PER_LEVEL = 3  -- Tiles of range per research level

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

-- ============================================================================
-- AUTO-DISCOVERY OF MODDED TURRETS
-- ============================================================================

local SUPPORTED_TURRET_TYPES = {
    ["ammo-turret"] = true,
    ["electric-turret"] = true,
    ["fluid-turret"] = true
}

-- Damage tech mapping by turret type (used for auto-discovered turrets)
local DEFAULT_DAMAGE_TECHS = {
    ["ammo-turret"] = {"physical-projectile-damage"},
    ["electric-turret"] = {"energy-weapons-damage"},
    ["fluid-turret"] = {"refined-flammables"}
}

-- Function to create variants for a turret config
local function create_turret_variants(config)
    local base = data.raw[config.turret_type] and data.raw[config.turret_type][config.base_name]
    if not base then
        log("Turret Range Research: Warning - turret '" .. config.base_name .. "' not found")
        return false
    end

    local replaceable_group = base.fast_replaceable_group or config.base_name

    for level = 1, config.max_level do
        -- Check if variant already exists (may have been created in data.lua)
        local variant_name = config.base_name .. "-ranged-" .. level
        if not data.raw[config.turret_type][variant_name] then
            local variant = table.deepcopy(base)
            variant.name = variant_name
            variant.localised_name = {"entity-name." .. config.base_name}
            variant.localised_description = {"entity-description." .. config.base_name}

            if variant.minable then
                variant.minable.result = config.base_name
            end

            if variant.attack_parameters then
                variant.attack_parameters.range = (base.attack_parameters.range or 20) + (level * RANGE_BONUS_PER_LEVEL)
            end

            variant.hidden = true
            variant.hidden_in_factoriopedia = true
            variant.fast_replaceable_group = replaceable_group
            variant.placeable_by = {item = config.base_name, count = 1}

            data:extend({variant})
        end
    end

    return true
end

-- Check settings
local enable_modded = settings.startup["turret-range-research-enable-modded-turrets"]
local enable_auto_discover = settings.startup["turret-range-research-auto-discover"]
local default_max_level = settings.startup["turret-range-research-default-max-level"]

-- Add registered modded turrets
if enable_modded and enable_modded.value then
    if turret_range_research_registrations then
        for _, config in pairs(turret_range_research_registrations) do
            log("Turret Range Research: Processing registered modded turret '" .. config.base_name .. "'")
            table.insert(TURRET_CONFIG, config)
        end
    end

    -- Auto-discover modded turrets
    if enable_auto_discover and enable_auto_discover.value then
        log("Turret Range Research: Auto-discovering modded turrets...")

        -- Build list of known turrets to avoid duplicates
        local known_turrets = {}
        for _, config in pairs(TURRET_CONFIG) do
            known_turrets[config.base_name] = true
        end

        -- Scan for modded turrets
        for turret_type, _ in pairs(SUPPORTED_TURRET_TYPES) do
            for name, prototype in pairs(data.raw[turret_type] or {}) do
                -- Skip if already known or if it's one of our variants
                if not known_turrets[name] and not string.find(name, "-ranged%-") then
                    log("Turret Range Research: Auto-discovered turret '" .. name .. "' of type '" .. turret_type .. "'")

                    local config = {
                        base_name = name,
                        turret_type = turret_type,
                        max_level = default_max_level and default_max_level.value or 5,
                        damage_techs = DEFAULT_DAMAGE_TECHS[turret_type] or {}
                    }

                    -- Create variants for auto-discovered turret
                    if create_turret_variants(config) then
                        table.insert(TURRET_CONFIG, config)
                    end
                end
            end
        end
    end
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
