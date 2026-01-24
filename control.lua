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
    if not old_turret.valid then return nil end
    if old_turret.name == new_name then return old_turret end

    local surface = old_turret.surface
    local position = old_turret.position
    local force = old_turret.force

    -- Capture basic entity state
    local state = {
        direction = old_turret.direction,
        health_ratio = old_turret.health / old_turret.max_health,
        kills = old_turret.kills,
    }

    -- Dynamically capture optional properties that may exist
    -- (Quality DLC, other mods, etc.)
    local optional_properties = {
        "quality",           -- Quality DLC
        "orientation",       -- Rotation for turrets
        "active",           -- Enable/disable state
        "enable_logistics_while_moving",
        "last_user",        -- Player who placed it
        "bar",              -- Inventory bar limit
        "force_attack_parameters", -- Target selection settings
    }

    for _, prop in ipairs(optional_properties) do
        local success, value = pcall(function() return old_turret[prop] end)
        if success and value ~= nil then
            state[prop] = value
        end
    end

    -- Store inventory contents (ammo)
    state.stored_ammo = {}
    local ammo_inventory = old_turret.get_inventory(defines.inventory.turret_ammo)
    if ammo_inventory then
        for i = 1, #ammo_inventory do
            local stack = ammo_inventory[i]
            if stack.valid_for_read then
                state.stored_ammo[i] = {name = stack.name, count = stack.count, ammo = stack.ammo}
            end
        end
    end

    -- Store fluid contents (flamethrower turrets)
    state.stored_fluids = {}
    if old_turret.fluidbox then
        for i = 1, #old_turret.fluidbox do
            local fluid = old_turret.fluidbox[i]
            if fluid and fluid.amount and fluid.amount > 0 then
                state.stored_fluids[i] = fluid
            end
        end
    end

    -- Destroy old turret
    old_turret.destroy({raise_destroy = false})

    -- Build creation parameters dynamically
    local create_params = {
        name = new_name,
        position = position,
        force = force,
        direction = state.direction,
        raise_built = false
    }

    -- Add optional creation-time properties
    local creation_properties = {"quality", "player", "create_build_effect_smoke"}
    for _, prop in ipairs(creation_properties) do
        if state[prop] ~= nil then
            create_params[prop] = state[prop]
        end
    end

    local new_turret = surface.create_entity(create_params)

    if new_turret then
        -- Restore health ratio
        new_turret.health = new_turret.max_health * state.health_ratio

        -- Restore kills
        new_turret.kills = state.kills

        -- Restore optional settable properties
        local settable_properties = {"orientation", "active", "enable_logistics_while_moving", "bar", "force_attack_parameters"}
        for _, prop in ipairs(settable_properties) do
            if state[prop] ~= nil then
                pcall(function()
                    new_turret[prop] = state[prop]
                end)
            end
        end

        -- Restore ammo inventory
        local new_ammo_inventory = new_turret.get_inventory(defines.inventory.turret_ammo)
        if new_ammo_inventory then
            for i, ammo_data in pairs(state.stored_ammo) do
                if new_ammo_inventory[i] and ammo_data.count > 0 then
                    pcall(function()
                        new_ammo_inventory[i].set_stack({name = ammo_data.name, count = ammo_data.count, ammo = ammo_data.ammo})
                    end)
                end
            end
        end

        -- Restore fluid contents
        if new_turret.fluidbox then
            for i, fluid in pairs(state.stored_fluids) do
                if new_turret.fluidbox[i] and fluid.amount and fluid.amount > 0 then
                    pcall(function()
                        new_turret.fluidbox[i] = fluid
                    end)
                end
            end
        end
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

remote.add_interface("turret-range-research", {
    -- Get the current range bonus for a turret type
    get_range_bonus = function(force_name, base_turret_name)
        local force = game.forces[force_name]
        if not force then return 0 end
        
        local config = TURRET_CONFIG[base_turret_name]
        if not config then return 0 end
        
        local level = get_research_level(force, config.tech_prefix, config.max_level)
        return level * 3  -- 3 tiles per level
    end,
    
    -- Manually trigger upgrade check for a force
    refresh_force = function(force_name)
        local force = game.forces[force_name]
        if force then
            for base_name, _ in pairs(TURRET_CONFIG) do
                upgrade_turrets_for_force(force, base_name)
            end
        end
    end
})
