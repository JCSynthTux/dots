-- Look and feel configuration

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 8,
        border_size = 2,
        extend_border_grab_area = 10,
        resize_on_border = true,
        col = {
            active_border = {
                colors = { CTP_LAVENDER, CTP_BLUE },
                angle = 45,
            },
            inactive_border = CTP_SURFACE2,
        },
    },
    group = {
        col = {
            border_active = CTP_GREEN,
            border_inactive = CTP_SURFACE2,
            border_locked_active = CTP_BLUE,
            border_locked_inactive = CTP_SURFACE2,
        },
        groupbar = {
            col = {
                active = CTP_GREEN,
                inactive = CTP_SURFACE2,
                locked_active = CTP_BLUE,
                locked_inactive = CTP_SURFACE2,
            },
        },
    },
    decoration = {
        dim_special = 0.3,
        rounding = 10,
        active_opacity = 1,
        inactive_opacity = 1,
        fullscreen_opacity = 1,
        shadow = {
            enabled = false,
        },
        blur = {
            enabled = false,
            size = 5,
            passes = 4,
            special = true,
        },
    },
})
