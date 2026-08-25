return {
    name = "Network",

    init = function(self, ctx)
        self.ctx = ctx.ui
        self.role = ctx.role
        self.network = ctx.network

        self.collected = true
        self.next = 0
        self.current = {}
    end,

    draw = function(self)
        local ui = self.ctx

        if os.clock() >= self.next and not self.requestId then
            self.requestId = self.network.request("registered")
            self.next = os.clock() + 10
        end

        ui:clear(colors.black)

        ui:fill(
            1,
            1,
            ui.width,
            ui.height,
            colors.yellow
        )
    end,

    text = function(self)
        local ui = self.ctx

        local y = math.floor(ui.barHeight / 3) + 1

        ui:text(1, y, "Connected Computers:", colors.white)

        local data = self.network.get(self.requestId)

        if data then
            self.collected = true

            self.current = {}

            for name in pairs(data) do
                current[#current + 1] = name
            end
        end

        if self.current then
            for _, name in ipairs(self.current) do
                ui:text(2, y, name, colors.white)
                y = y + 1
            end
        end
    end,

    click = function(self, x, y)
        print(x, y)
    end
}
