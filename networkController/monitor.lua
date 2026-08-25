return {
    name = "Network",

    init = function(self, ctx)
        self.ctx = ctx.ui
        self.role = ctx.role
        self.network = ctx.network

        self.next = 0
        self.current = {}
    end,

    draw = function(self)
        local ui = self.ctx

        if os.clock() >= self.next then
            self.requestId = self.network.request("registered")
            self.next = os.clock() + 1
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

        local y = math.floor(ui.barHeight / 3) + 2

        ui:text(1, y, "Connected Computers:", colors.white)

        if self.requestId then
            local data = self.network.get(self.requestId)
        end

        if data then
            self.current = {}

            print("DATA:", textutils.serialize(data))

            for name in pairs(data) do
                self.current[#self.current + 1] = name
            end

            self.requestId = 0
        end

        if #self.current > 0 then
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
