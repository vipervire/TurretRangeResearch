-- Turret Range Research - Control Script
-- Automatically upgrades turrets when research completes
-- Swaps turrets to ranged variants, preserving state (ammo, health, etc.)

-- ============================================================================
-- HARDCODED VANILLA TURRET CONFIGURATION
-- ============================================================================
local VANILLA_TURRET_CONFIG = {
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
    },
    ["rocket-turret"] = {
        type = "ammo-turret",
        tech_prefix = "rocket-turret-range",
        max_level = 5
    },
    ["tesla-turret"] = {
        type = "electric-turret",
        tech_prefix = "tesla-turret-range",
        max_level = 5
    }
}

-- Active configuration (merged from vanilla + custom + discovered)
local TURRET_CONFIG = {}

-- Custom turrets registered via remote interface
local CUSTOM_REGISTERED_TURRETS = {}

-- Auto-discovered modded turrets
local AUTO_DISCOVERED_TURRETS = {}

-- Build reverse lookup: variant name -> base name
local VARIANT_TO_BASE = {}

-- ============================================================================
-- AUTO-DISCOVERY AND CONFIGURATION MERGING
-- ============================================================================

-- Supported turret types for auto-discovery
local SUPPORTED_TURRET_TYPES = {
    ["ammo-turret"] = true,
    ["electric-turret"] = true,
    ["fluid-turret"] = true
}

-- Ammunition category to vanilla tech prefix mapping
-- Rocket turret range represents explosive/area-damage weapons
local AMMO_CATEGORY_TO_TECH = {
    ["bullet"] = "gun-turret-range",
    ["shotgun-shell"] = "gun-turret-range",
    ["rocket"] = "rocket-turret-range",           -- Explosive weapons
    ["explosive-rocket"] = "rocket-turret-range", -- Explosive weapons
    ["cannon-shell"] = "rocket-turret-range",     -- Explosive weapons (cannons are area damage)
}

-- Detect appropriate tech prefix based on turret's ammunition or attack type
local function detect_tech_prefix(turret_name, prototype, default_max_level)
    local turret_type = prototype.type

    -- For ammo turrets, check ammunition categories
    if turret_type == "ammo-turret" then
        if prototype.attack_parameters and prototype.attack_parameters.ammo_categories then
            -- Check each ammo category the turret accepts
            for _, ammo_category in pairs(prototype.attack_parameters.ammo_categories) do
                -- If we have a mapping for this ammo type, use vanilla research
                if AMMO_CATEGORY_TO_TECH[ammo_category.name] then
                    local vanilla_tech = AMMO_CATEGORY_TO_TECH[ammo_category.name]
                    -- Get max_level from the vanilla turret that uses this tech
                    for vanilla_name, vanilla_config in pairs(VANILLA_TURRET_CONFIG) do
                        if vanilla_config.tech_prefix == vanilla_tech then
                            return vanilla_tech, vanilla_config.max_level
                        end
                    end
                    return vanilla_tech, 5
                end
            end
        end
        -- Default ammo turrets to gun-turret-range if no specific mapping
        return "gun-turret-range", 5

    -- For electric turrets, distinguish between laser and tesla types
    elseif turret_type == "electric-turret" then
        -- Check if it's a tesla-type turret based on name
        local name_lower = turret_name:lower()

        -- Name-based detection for tesla turrets
        if name_lower:find("tesla") or name_lower:find("lightning") or name_lower:find("arc") then
            return "tesla-turret-range", 5
        end

        -- Default electric turrets to laser-turret-range
        return "laser-turret-range", 5

    -- For fluid turrets, default to flamethrower-turret-range
    elseif turret_type == "fluid-turret" then
        return "flamethrower-turret-range", 3
    end

    -- Fallback: use turret's own unique tech prefix
    return turret_name .. "-range", default_max_level
end

-- Check if a turret already has its own range research technologies
local function has_own_range_research(turret_name, max_levels_to_check)
    max_levels_to_check = max_levels_to_check or 10
    local tech_prefix = turret_name .. "-range"

    -- Check if at least level 1 exists
    for level = 1, max_levels_to_check do
        local tech = prototypes.technology[tech_prefix .. "-" .. level]
        if tech then
            -- Found at least one level, count how many levels exist
            local found_max_level = level
            for check_level = level + 1, max_levels_to_check do
                if prototypes.technology[tech_prefix .. "-" .. check_level] then
                    found_max_level = check_level
                else
                    break
                end
            end
            return true, tech_prefix, found_max_level
        end
    end

    return false, nil, nil
end

-- Auto-discover modded turrets of supported types
local function auto_discover_turrets()
    local discovered = {}

    -- Get settings
    local enable_modded = settings.startup["turret-range-research-enable-modded-turrets"].value
    local enable_auto_discover = settings.startup["turret-range-research-auto-discover"].value
    local use_ammo_mapping = settings.startup["turret-range-research-use-ammo-mapping"].value
    local default_max_level = settings.startup["turret-range-research-default-max-level"].value

    if not enable_modded or not enable_auto_discover then
        return discovered
    end

    -- Scan all entity prototypes
    for name, prototype in pairs(prototypes.entity) do
        -- Skip if it's a vanilla turret (already hardcoded)
        if not VANILLA_TURRET_CONFIG[name] then
            -- Check if it's a supported turret type
            if SUPPORTED_TURRET_TYPES[prototype.type] then
                -- Skip our own ranged variants
                if not string.find(name, "-ranged%-") then
                    local tech_prefix, max_level

                    -- First, check if this turret already has its own range research
                    local has_own_tech, own_tech_prefix, own_max_level = has_own_range_research(name)

                    if has_own_tech then
                        -- Respect the existing range research
                        tech_prefix = own_tech_prefix
                        max_level = own_max_level
                    elseif use_ammo_mapping then
                        -- Detect appropriate tech prefix based on ammo type
                        tech_prefix, max_level = detect_tech_prefix(name, prototype, default_max_level)
                    else
                        -- Each turret gets its own unique research tree
                        tech_prefix = name .. "-range"
                        max_level = default_max_level
                    end

                    discovered[name] = {
                        type = prototype.type,
                        tech_prefix = tech_prefix,
                        max_level = max_level,
                        auto_discovered = true,
                        has_own_research = has_own_tech
                    }
                end
            end
        end
    end

    return discovered
end

-- Rebuild TURRET_CONFIG by merging all sources
local function rebuild_turret_config()
    TURRET_CONFIG = {}

    -- Start with vanilla turrets (always included)
    for name, config in pairs(VANILLA_TURRET_CONFIG) do
        TURRET_CONFIG[name] = config
    end

    -- Add custom registered turrets if modded turrets are enabled
    local enable_modded = settings.startup["turret-range-research-enable-modded-turrets"].value
    if enable_modded then
        for name, config in pairs(CUSTOM_REGISTERED_TURRETS) do
            TURRET_CONFIG[name] = config
        end

        -- Add auto-discovered turrets
        for name, config in pairs(AUTO_DISCOVERED_TURRETS) do
            -- Don't override custom registered or vanilla turrets
            if not TURRET_CONFIG[name] then
                TURRET_CONFIG[name] = config
            end
        end
    end

    -- Rebuild VARIANT_TO_BASE lookup
    VARIANT_TO_BASE = {}
    for base_name, config in pairs(TURRET_CONFIG) do
        VARIANT_TO_BASE[base_name] = base_name
        for level = 1, config.max_level do
            VARIANT_TO_BASE[base_name .. "-ranged-" .. level] = base_name
        end
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
        damage_dealt = old_turret.damage_dealt,  -- Damage dealt needs manual restoration
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
            old_turret.force.print({"", "[color=yellow][Turret Range Warning][/color] ", {"mod-message.turret-range-research-prototype-missing", new_name}})
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
            force.print({"", "[color=yellow][Turret Range Warning][/color] ", {"mod-message.turret-range-research-upgrade-failed", position.x, position.y, new_name}})
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

        -- Restore kills counter and damage dealt (not transferred by fast_replace)
        pcall(function()
            new_turret.kills = state.kills
            new_turret.damage_dealt = state.damage_dealt
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

    -- Build list of all variant names to search for (excluding the target)
    local search_names = {}
    if base_name ~= target_name then
        table.insert(search_names, base_name)
    end
    for level = 1, config.max_level do
        local variant_name = base_name .. "-ranged-" .. level
        if variant_name ~= target_name then
            table.insert(search_names, variant_name)
        end
    end

    -- Performance optimization: single find_entities_filtered call per surface
    -- This is much faster than multiple calls, especially on large maps
    if #search_names > 0 then
        for _, surface in pairs(game.surfaces) do
            local turrets = surface.find_entities_filtered{
                name = search_names,  -- Can pass array of names
                force = force
            }
            for _, turret in pairs(turrets) do
                if swap_turret(turret, target_name) then
                    upgraded_count = upgraded_count + 1
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

            -- Only notify if turrets were actually upgraded
            if count > 0 then
                local turret_display = base_name:gsub("-", " ")
                force.print({"", "[color=green][Turret Range][/color] ", {"mod-message.turret-range-research-upgrade-complete", turret_display, level * 3, count}})
            end
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
    -- Auto-discover modded turrets
    AUTO_DISCOVERED_TURRETS = auto_discover_turrets()

    -- Rebuild configuration from all sources
    rebuild_turret_config()

    -- Upgrade existing turrets for all forces
    for _, force in pairs(game.forces) do
        for base_name, _ in pairs(TURRET_CONFIG) do
            upgrade_turrets_for_force(force, base_name)
        end
    end
end

-- Handle configuration changes (mod updates)
local function on_configuration_changed(data)
    -- Re-discover turrets (mod list may have changed)
    AUTO_DISCOVERED_TURRETS = auto_discover_turrets()

    -- Rebuild configuration from all sources
    rebuild_turret_config()

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
script.on_event(defines.events.script_raised_revive, on_turret_built, turret_filters)
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
    -- base_turret_name: string - "gun-turret", "laser-turret", "flamethrower-turret", "rocket-turret", or "tesla-turret"
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
    -- base_turret_name: string - "gun-turret", "laser-turret", "flamethrower-turret", "rocket-turret", or "tesla-turret"
    -- force_name: string - name of the force
    -- Returns: string - the variant name that should be used
    get_variant_for_force = function(base_turret_name, force_name)
        local force = game.forces[force_name]
        if not force then return base_turret_name end
        return get_turret_variant(base_turret_name, force)
    end,

    -- ========================================================================
    -- MODDED TURRET REGISTRATION
    -- ========================================================================
    -- Register a modded turret to be supported by this mod
    -- config: table with the following fields:
    --   - base_name: string (required) - The base entity name (e.g., "plasma-turret")
    --   - type: string (required) - Turret type: "ammo-turret", "electric-turret", or "fluid-turret"
    --   - tech_prefix: string (required) - Technology name prefix (e.g., "plasma-turret-range")
    --   - max_level: number (optional) - Maximum research level (default: 5)
    -- Example:
    --   remote.call("turret-range-research", "register_modded_turret", {
    --       base_name = "plasma-turret",
    --       type = "electric-turret",
    --       tech_prefix = "plasma-turret-range",
    --       max_level = 5
    --   })
    register_modded_turret = function(config)
        if not config or not config.base_name or not config.type or not config.tech_prefix then
            error("register_modded_turret requires base_name, type, and tech_prefix")
        end

        -- Validate turret type
        if not SUPPORTED_TURRET_TYPES[config.type] then
            error("Invalid turret type: " .. config.type .. ". Must be ammo-turret, electric-turret, or fluid-turret")
        end

        -- Set defaults
        config.max_level = config.max_level or 5

        -- Store the registration
        CUSTOM_REGISTERED_TURRETS[config.base_name] = {
            type = config.type,
            tech_prefix = config.tech_prefix,
            max_level = config.max_level
        }

        -- Rebuild configuration
        rebuild_turret_config()

        return true
    end,

    -- Get list of all supported turrets (vanilla + custom + discovered)
    -- Returns: table - map of base_name -> config
    get_all_turrets = function()
        return TURRET_CONFIG
    end,

    -- Get list of auto-discovered turrets
    -- Returns: table - map of base_name -> config
    get_discovered_turrets = function()
        return AUTO_DISCOVERED_TURRETS
    end
})
