-- Turret Range Research - Control Script
-- Automatically upgrades turrets when research completes
-- Swaps turrets to ranged variants, preserving state (ammo, health, etc.)

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

-- Build reverse lookup: variant name -> base name
local VARIANT_TO_BASE = {}
for base_name, config in pairs(TURRET_CONFIG) do
    VARIANT_TO_BASE[base_name] = base_name
    for level = 1, config.max_level do
        VARIANT_TO_BASE[base_name .. "-ranged-" .. level] = base_name
    end
end

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

-- Get the appropriate turret variant name for a force's research level
local function get_turret_variant(base_name, force)
    local config = TURRET_CONFIG[base_name]
    if not config then return base_name end
    
    local level = get_research_level(force, config.tech_prefix, config.max_level)
    if level > 0 then
        return base_name .. "-ranged-" .. level
    end
    return base_name
end

-- Swap a turret to a different variant, preserving all state
local function swap_turret(old_turret, new_name)
    if not old_turret or not old_turret.valid then return nil end
    if old_turret.name == new_name then return old_turret end

    local surface = old_turret.surface
    if not surface or not surface.valid then return nil end

    local position = old_turret.position
    local force = old_turret.force

    -- Capture state that won't be automatically transferred by fast_replace
    local state = {
        direction = old_turret.direction,
        kills = old_turret.kills,  -- Kills counter needs manual restoration
    }

    -- Capture optional properties for creation or manual restoration
    -- fast_replace handles most state, but some properties need special handling
    local optional_properties = {
        "quality",                  -- Quality DLC (creation-time parameter)
        "orientation",              -- Turret rotation
        "force_attack_parameters",  -- Target selection settings
    }

    for _, prop in ipairs(optional_properties) do
        local success, value = pcall(function() return old_turret[prop] end)
        if success and value ~= nil then
            state[prop] = value
        end
    end

    -- Capture entity tags (used by some mods for custom data)
    state.entity_tags = {}
    pcall(function()
        if old_turret.entity_label then
            state.entity_label = old_turret.entity_label
        end
        -- Some mods use tags for custom data storage
        local tags = old_turret.tags
        if tags and next(tags) then
            state.entity_tags = tags
        end
    end)

    -- First verify the new turret prototype exists
    -- Wrapped in pcall for safety in case prototypes system has issues
    local prototype_exists = false
    pcall(function()
        if prototypes and prototypes.entity and prototypes.entity[new_name] then
            prototype_exists = true
        end
    end)

    if not prototype_exists then
        -- Log warning if prototype is missing (shouldn't happen in normal gameplay)
        if old_turret and old_turret.valid and old_turret.force then
            old_turret.force.print({"", "[color=yellow][Turret Range Warning][/color] Could not upgrade turret: prototype '", new_name, "' not found. Please report this issue."})
        end
        return nil
    end

    -- Verify old turret is still valid before attempting replacement
    if not old_turret.valid then
        return nil
    end

    -- Build creation parameters using fast_replace for upgrade-style replacement
    -- fast_replace = true tells the game to replace any entity at this position
    -- that shares the same fast_replaceable_group (like upgrading AM2 to AM3)
    -- This automatically preserves inventories, circuit connections, health, and most settings
    local create_params = {
        name = new_name,
        position = position,
        force = force,
        direction = state.direction,
        fast_replace = true,        -- Enable fast_replace mechanism
        spill = false,              -- Don't spill items if replacement fails
        raise_built = false
    }

    -- Add optional creation-time properties
    local creation_properties = {"quality", "player", "create_build_effect_smoke"}
    for _, prop in ipairs(creation_properties) do
        if state[prop] ~= nil then
            create_params[prop] = state[prop]
        end
    end

    -- Create the new turret using fast_replace (like upgrading AM2 to AM3)
    local new_turret = surface.create_entity(create_params)

    if not new_turret then
        -- Log warning if creation failed (turret is safe, just not upgraded)
        if force then
            force.print({"", "[color=yellow][Turret Range Warning][/color] Could not upgrade turret at (", position.x, ", ", position.y, ") to '", new_name, "'. Turret remains unchanged."})
        end
        return nil
    end

    if new_turret and new_turret.valid then
        -- fast_replace automatically handles:
        -- - Inventories (ammo, fluids)
        -- - Circuit connections
        -- - Control behavior (including circuit-controlled enable/disable)
        -- - Health ratio
        -- - Direction
        -- - Force
        -- - Active state (controlled by circuit conditions)

        -- Restore kills counter (not transferred by fast_replace)
        pcall(function()
            new_turret.kills = state.kills
        end)

        -- Restore optional properties that may not transfer automatically
        local settable_properties = {"orientation", "force_attack_parameters"}
        for _, prop in ipairs(settable_properties) do
            if state[prop] ~= nil then
                pcall(function()
                    new_turret[prop] = state[prop]
                end)
            end
        end

        -- Restore entity tags and labels (for mod compatibility)
        pcall(function()
            if state.entity_label then
                new_turret.entity_label = state.entity_label
            end
            if state.entity_tags and next(state.entity_tags) then
                new_turret.tags = state.entity_tags
            end
        end)

        -- Raise custom event for mod compatibility
        -- Other mods can listen to this to know when we've upgraded a turret
        pcall(function()
            script.raise_event(defines.events.script_raised_built, {
                entity = new_turret,
                mod_name = script.mod_name
            })
        end)
    end

    return new_turret
end

-- Upgrade all turrets of a type for a force
local function upgrade_turrets_for_force(force, base_name)
    local config = TURRET_CONFIG[base_name]
    if not config then return end
    
    local target_name = get_turret_variant(base_name, force)
    local upgraded_count = 0
    
    -- Build list of all variant names to search for
    local search_names = {base_name}
    for level = 1, config.max_level do
        table.insert(search_names, base_name .. "-ranged-" .. level)
    end
    
    -- Find and upgrade all turrets on all surfaces
    for _, surface in pairs(game.surfaces) do
        for _, name in pairs(search_names) do
            if name ~= target_name then
                local turrets = surface.find_entities_filtered{
                    name = name,
                    force = force
                }
                for _, turret in pairs(turrets) do
                    if swap_turret(turret, target_name) then
                        upgraded_count = upgraded_count + 1
                    end
                end
            end
        end
    end
    
    return upgraded_count
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- When research completes, upgrade all relevant turrets
local function on_research_finished(event)
    local tech = event.research
    local force = tech.force
    
    -- Check if this is one of our range technologies
    for base_name, config in pairs(TURRET_CONFIG) do
        if string.find(tech.name, config.tech_prefix, 1, true) then
            local count = upgrade_turrets_for_force(force, base_name)
            local level = get_research_level(force, config.tech_prefix, config.max_level)
            
            -- Notify the force
            local turret_display = base_name:gsub("-", " ")
            force.print({"", "[color=green][Turret Range][/color] All ", turret_display, "s upgraded! Range bonus: +", level * 3, " tiles (", count, " turrets upgraded)"})
            return
        end
    end
end

-- When a turret is built, swap it to the appropriate variant
local function on_turret_built(event)
    local entity = event.entity or event.destination
    if not entity or not entity.valid then return end
    
    local base_name = VARIANT_TO_BASE[entity.name]
    if not base_name then return end
    
    local target = get_turret_variant(base_name, entity.force)
    if entity.name ~= target then
        swap_turret(entity, target)
    end
end

-- Initialize storage and upgrade existing turrets
local function on_init()
    -- Upgrade existing turrets for all forces
    for _, force in pairs(game.forces) do
        for base_name, _ in pairs(TURRET_CONFIG) do
            upgrade_turrets_for_force(force, base_name)
        end
    end
end

-- Handle configuration changes (mod updates)
local function on_configuration_changed(data)
    -- Re-check all turrets when mod configuration changes
    for _, force in pairs(game.forces) do
        for base_name, _ in pairs(TURRET_CONFIG) do
            upgrade_turrets_for_force(force, base_name)
        end
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
--
-- MOD COMPATIBILITY NOTES:
-- This mod uses fast_replace to swap turrets, which means:
-- 1. Entity references become invalid when a turret is upgraded
-- 2. We raise script_raised_built after replacement (other mods can listen to this)
-- 3. Entity tags, labels, and most properties are preserved
-- 4. Circuit connections and control behavior are preserved
--
-- If your mod stores references to turret entities:
-- - Listen to script_raised_built events from "turret-range-research"
-- - Use the remote interface below to check if an entity is our variant
-- - Re-query entities after research completes
--
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
        return level * 3  -- 3 tiles per level
    end,

    -- Manually trigger upgrade check for a force
    -- Useful for other mods that need to refresh turrets
    -- force_name: string - name of the force to refresh
    refresh_force = function(force_name)
        local force = game.forces[force_name]
        if force then
            for base_name, _ in pairs(TURRET_CONFIG) do
                upgrade_turrets_for_force(force, base_name)
            end
        end
    end,

    -- Check if an entity is one of our turret variants
    -- entity_name: string - the entity prototype name
    -- Returns: string or nil - base turret name if it's our variant, nil otherwise
    is_turret_variant = function(entity_name)
        return VARIANT_TO_BASE[entity_name]
    end,

    -- Get the appropriate variant name for a base turret and force
    -- base_turret_name: string - "gun-turret", "laser-turret", or "flamethrower-turret"
    -- force_name: string - name of the force
    -- Returns: string - the variant name that should be used
    get_variant_for_force = function(base_turret_name, force_name)
        local force = game.forces[force_name]
        if not force then return base_turret_name end
        return get_turret_variant(base_turret_name, force)
    end
})
