-- Turret Range Research - Settings
-- User preferences for modded turret support

data:extend({
    {
        type = "bool-setting",
        name = "turret-range-research-enable-modded-turrets",
        setting_type = "startup",
        default_value = true,
        order = "a"
    },
    {
        type = "bool-setting",
        name = "turret-range-research-auto-discover",
        setting_type = "startup",
        default_value = true,
        order = "b"
    },
    {
        type = "bool-setting",
        name = "turret-range-research-use-ammo-mapping",
        setting_type = "startup",
        default_value = true,
        order = "c"
    },
    {
        type = "int-setting",
        name = "turret-range-research-default-max-level",
        setting_type = "startup",
        default_value = 5,
        minimum_value = 1,
        maximum_value = 10,
        order = "d"
    }
})
