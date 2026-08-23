return {
    name = "Network",

    init = function(self, ctx)
        self.ctx = ctx
    end,

    draw = function(self, box, width, height)
        box:clear()

        box:fill(1, 1, width, height, colors.black)

        box:text(2, 2, "Network Controller", colors.white)
        box:text(2, 4, "Status: ONLINE", colors.lime)
    end,

    click = function(self, x, y)
        -- Handle monitor clicks later
    end
}
