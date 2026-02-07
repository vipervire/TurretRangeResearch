-- Turret Range Research - Control Script (Runtime Modification Approach)
-- Applies range bonuses directly to turret entities at runtime
-- This provides better mod compatibility without hidden variant entities

local RANGE_BONUS_PER_LEVEL = 3  -- Tiles of range per research level

local TURRET_CONFIG = {
    ["gun-turret"] = {
        type = "ammo-turret",
        tech_prefix = "gun-turret-range",
        max_level = 5
    },
    ["laser-turret"] = {
        type = "electric-turret",
        tech_prefix = "laser-turret-range",
        max_level = 5
    },
    ["flamethrower-turret"] = {
        type = "fluid-turret",
        tech_prefix = "flamethrower-turret-range",
        max_level = 3
    }
}

-- Get the current research level for a turret type
local function get_research_level(force, tech_prefix, max_level)
    for level = max_level, 1, -1 do
        local tech = force.technologies[tech_prefix .. "-" .. level]
        if tech and tech.researched then
            return level
        end
    end
    return 0
end

-- Determine which turret family a turret belongs to based on type and optionally name
local function get_turret_family(entity)
    local affect_modded = settings.startup["turret-range-affect-modded-turrets"].value

    -- Check by entity type
    if entity.type == "ammo-turret" then
        if affect_modded then
            -- Affect ALL ammo turrets
            return "gun-turret", TURRET_CONFIG["gun-turret"]
        else
            -- Only affect vanilla gun-turret
            if entity.name == "gun-turret" then
                return "gun-turret", TURRET_CONFIG["gun-turret"]
            end
        end
    elseif entity.type == "electric-turret" then
        if affect_modded then
            -- Affect ALL electric turrets
            return "laser-turret", TURRET_CONFIG["laser-turret"]
        else
            -- Only affect vanilla laser-turret
            if entity.name == "laser-turret" then
                return "laser-turret", TURRET_CONFIG["laser-turret"]
            end
        end
    elseif entity.type == "fluid-turret" then
        if affect_modded then
            -- Affect ALL fluid turrets
            return "flamethrower-turret", TURRET_CONFIG["flamethrower-turret"]
        else
            -- Only affect vanilla flamethrower-turret
            if entity.name == "flamethrower-turret" then
                return "flamethrower-turret", TURRET_CONFIG["flamethrower-turret"]
            end
        end
    end

    return nil, nil
end

-- Get the base range for a turret (stored when first seen)
local function get_base_range(entity)
    if not global.turret_base_ranges then
        global.turret_base_ranges = {}
    end

    local turret_id = entity.unit_number
    if not turret_id then return nil end

    -- If we haven't seen this turret before, store its current range as base
    if not global.turret_base_ranges[turret_id] then
        if entity.attack_parameters and entity.attack_parameters.range then
            global.turret_base_ranges[turret_id] = entity.attack_parameters.range
        end
    end

    return global.turret_base_ranges[turret_id]
end

-- Apply range bonus to a turret based on research level
local function apply_range_bonus(entity)
    if not entity or not entity.valid then return false end
    if not entity.attack_parameters then return false end

    local family_name, config = get_turret_family(entity)
    if not family_name or not config then return false end

    -- Get base range (what the turret started with)
    local base_range = get_base_range(entity)
    if not base_range then return false end

    -- Get research level
    local level = get_research_level(entity.force, config.tech_prefix, config.max_level)

    -- Apply bonus
    local new_range = base_range + (level * RANGE_BONUS_PER_LEVEL)
    entity.attack_parameters.range = new_range

    return true
end

-- Update all turrets for a force
local function update_all_turrets_for_force(force)
    local updated_count = 0

    for _, surface in pairs(game.surfaces) do
        -- Find all turrets of each type
        for family_name, config in pairs(TURRET_CONFIG) do
            local turrets = surface.find_entities_filtered{
                type = config.type,
                force = force
            }

            for _, turret in pairs(turrets) do
                if apply_range_bonus(turret) then
                    updated_count = updated_count + 1
                end
            end
        end
    end

    return updated_count
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- When research completes, update all turrets
local function on_research_finished(event)
    local tech = event.research
    local force = tech.force

    -- Check if this is one of our range technologies
    for base_name, config in pairs(TURRET_CONFIG) do
        if string.find(tech.name, config.tech_prefix, 1, true) then
            local count = update_all_turrets_for_force(force)
            local level = get_research_level(force, config.tech_prefix, config.max_level)

            -- Notify the force
            local turret_display = base_name:gsub("-", " ")
            force.print({"", "[color=green][Turret Range][/color] Range bonus updated for ", turret_display, "s: +", level * RANGE_BONUS_PER_LEVEL, " tiles (", count, " turrets updated)"})
            return
        end
    end
end

-- When a turret is built, apply range bonus
local function on_turret_built(event)
    local entity = event.entity or event.destination
    if not entity or not entity.valid then return end

    apply_range_bonus(entity)
end

-- Initialize global data structure
local function initialize_globals()
    -- Ensure global table exists (needed when adding mod to existing save)
    global = global or {}
    global.turret_base_ranges = global.turret_base_ranges or {}
end

-- Initialize global data
local function on_init()
    initialize_globals()

    -- Update all existing turrets
    for _, force in pairs(game.forces) do
        update_all_turrets_for_force(force)
    end
end

-- Check if a turret name is from the old variant system
local function is_old_variant(name)
    return string.find(name, "%-ranged%-") ~= nil
end

-- Get the base turret name from a variant name
local function get_base_name_from_variant(variant_name)
    -- "gun-turret-ranged-5" -> "gun-turret"
    return variant_name:match("(.+)%-ranged%-%d+")
end

-- Handle configuration changes (mod updates)
local function on_configuration_changed(data)
    -- Initialize globals first (needed when adding mod to existing save)
    initialize_globals()

    -- Check if we're upgrading from version 1.x to 2.x
    local old_version = data.mod_changes and data.mod_changes["turret-range-research"] and
                        data.mod_changes["turret-range-research"].old_version
    local migrating_from_v1 = old_version and string.sub(old_version, 1, 2) == "1."

    if migrating_from_v1 then
        game.print("[color=yellow][Turret Range Research][/color] Migrating from v1.x to v2.0 - Converting turrets to runtime system...")

        -- Clear stored ranges for fresh start
        global.turret_base_ranges = {}

        -- For each force, detect old variant turrets and fix their ranges
        for _, force in pairs(game.forces) do
            for _, surface in pairs(game.surfaces) do
                -- Find all turret types
                for family_name, config in pairs(TURRET_CONFIG) do
                    local turrets = surface.find_entities_filtered{
                        type = config.type,
                        force = force
                    }

                    for _, turret in pairs(turrets) do
                        if turret.valid and turret.attack_parameters then
                            -- Get current research level
                            local turret_family, turret_config = get_turret_family(turret)
                            if turret_family and turret_config then
                                -- Get the BASE turret's prototype range (not variant's range)
                                -- Base ranges: gun=18, laser=24, flamethrower=30
                                local base_turret_proto = prototypes.entity[family_name]
                                local base_range = base_turret_proto and
                                                  base_turret_proto.attack_parameters and
                                                  base_turret_proto.attack_parameters.range

                                if not base_range then
                                    -- Fallback to known base ranges if prototype lookup fails
                                    if family_name == "gun-turret" then
                                        base_range = 18
                                    elseif family_name == "laser-turret" then
                                        base_range = 24
                                    elseif family_name == "flamethrower-turret" then
                                        base_range = 30
                                    else
                                        base_range = turret.attack_parameters.range
                                    end
                                end

                                local level = get_research_level(force, turret_config.tech_prefix, turret_config.max_level)
                                local expected_bonus = level * RANGE_BONUS_PER_LEVEL

                                -- Store the base range
                                if turret.unit_number then
                                    global.turret_base_ranges[turret.unit_number] = base_range
                                end

                                -- Apply correct range
                                turret.attack_parameters.range = base_range + expected_bonus
                            end
                        end
                    end
                end
            end
        end

        game.print("[color=green][Turret Range Research][/color] Migration complete! All turrets converted to runtime system.")
    end

    -- Re-check all turrets when mod configuration changes
    for _, force in pairs(game.forces) do
        update_all_turrets_for_force(force)
    end
end

-- ============================================================================
-- REGISTER EVENTS
-- ============================================================================

script.on_init(on_init)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_research_finished, on_research_finished)

-- Register build events for all turret types
local turret_filters = {
    {filter = "type", type = "ammo-turret"},
    {filter = "type", type = "electric-turret"},
    {filter = "type", type = "fluid-turret"}
}

script.on_event(defines.events.on_built_entity, on_turret_built, turret_filters)
script.on_event(defines.events.on_robot_built_entity, on_turret_built, turret_filters)
script.on_event(defines.events.script_raised_built, on_turret_built, turret_filters)
script.on_event(defines.events.on_entity_cloned, on_turret_built, turret_filters)

-- ============================================================================
-- REMOTE INTERFACE (for other mods)
-- ============================================================================

remote.add_interface("turret-range-research", {
    -- Get the current range bonus for a turret type
    -- force_name: string - name of the force
    -- base_turret_name: string - "gun-turret", "laser-turret", or "flamethrower-turret"
    -- Returns: number - tiles of range bonus (0 if no research)
    get_range_bonus = function(force_name, base_turret_name)
        local force = game.forces[force_name]
        if not force then return 0 end

        local config = TURRET_CONFIG[base_turret_name]
        if not config then return 0 end

        local level = get_research_level(force, config.tech_prefix, config.max_level)
        return level * RANGE_BONUS_PER_LEVEL
    end,

    -- Manually trigger update for all turrets of a force
    -- Useful for other mods that need to refresh turrets
    -- force_name: string - name of the force to refresh
    refresh_force = function(force_name)
        local force = game.forces[force_name]
        if force then
            return update_all_turrets_for_force(force)
        end
        return 0
    end
})
