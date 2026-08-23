return {
    name = "Network",

    init = function(self, ctx)
        self.ctx = ctx.ui
        self.role = ctx.role
    end,

    draw = function(self)
        local ui = self.ctx

        ui:clear(colors.black)

        ui:fill(
            1,
            1,
            ui.width,
            ui.height,
            colors.yellow
        )

        -- text will go here once we implement ui:text()
    end,

    click = function(self, x, y)
        -- Handle monitor clicks later
    end
}
