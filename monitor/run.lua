local PIXEL_PATH = "https://raw.githubusercontent.com/9551-Dev/pixelbox_lite/refs/heads/master/pixelbox_lite.lua"
local BASE_PATH = "https://raw.githubusercontent.com/ScorchedDuck/Airship-Control/refs/heads/main/"

local monitor = peripheral.find("monitor")

local modem = peripheral.find("modem")
modem.open(100)
modem.open(102) -- monitor channel

local computers = {}
local roles = {}
local selected = nil

local function downloadPixelBox()
    local response = http.get(PIXEL_PATH)
    
    if not response then
        error("Couldn't download pixelbox_lite.lua")
    end

    local data = response.readAll()
    response.close()

    if data == "" then
        error("Data empty")
    end

    local file = fs.open("pixelbox.lua", "w")
    file.write(data)
    file.close()
end

if not fs.exists("pixelbox.lua") then
    downloadPixelBox()
end
local pixelbox = dofile("pixelbox.lua")

local box = pixelbox.new(monitor)

local ctx = {}

ctx.width = box.width
ctx.height = box.height

function ctx:clear(color)
    box:clear(color)
end

function ctx:setPixel(x, y, color)
    box.canvas[y][x] = color
end

function ctx:fill(x, y, width, height, color)
    for py = y, y + height - 1 do
        for px = x, x + width - 1 do
            box.canvas[py][px] = color
        end
    end
end

function ctx:text(x, y, text, color)
    monitor.setCursorPos(x, y)
    monitor.setTextColor(color or colors.white)
    monitor.write(text)
end

local function loadModule(role)
    local url = BASE_PATH .. role .. "/monitor.lua"

    local response = http.get(url)

    if not response then
        print("Couldn't download " .. role .. "/monitor.lua")
        return nil
    end

    local code = response.readAll()
    response.close()

    if code == "" then
        print(role .. "/monitor.lua is empty")
        return nil
    end

    local fn, err = load(code, url, "t")

    if not fn then
        print("Failed to load " .. role .. ": " .. err)
        return nil
    end

    local ok, module = pcall(fn)

    if not ok then
        print("Failed to initialise " .. role .. ": " .. module)
        return nil
    end

    if type(module) ~= "table" then
        print(role .. "/monitor.lua didn't return a table")
        return nil
    end

    module.id = role

    return module
end

local function handlePing(message)
    if type(message) ~= "table" then
        return
    end

    if message.command ~= "monitor" then
        return
    end

    if not message.role then
        return
    end

    local role = message.role
    local computer = computers[role]

    if not selectedRole then
        selectedRole = role
    end

    if not computer then
        print("Discovered monitor: " .. role)

        local module = loadModule(role)

        if not module then
            return
        end

        computer = {
            lastSeen = os.clock(),
            module = module
        }

        computers[role] = computer
        table.insert(roles, role)
        table.sort(roles)

        if computer.module.init then
            computer.module:init({
                role = role,
                ui = ctx
            })
        end
    else
        computer.lastSeen = os.clock()
    end
end

local function removeOffline()
    local now = os.clock()

    for role, computer in pairs(computers) do
        if now - computer.lastSeen > 30 then
            print("Monitor offline: " .. role)

            computers[role] = nil

            for i, r in ipairs(roles) do
                if r == role then
                    table.remove(roles, i)
                    break
                end
            end

            table.sort(roles)

            if selectedRole == role then
                selectedRole = nil

                for newRole in pairs(computers) do
                    selectedRole = newRole
                    break
                end
            end
        end
    end
end

local function handleTouch(x, y)
    -- Top bar is rows 1-2
    if y > 2 then
        return
    end

    local currentX = 1

    for role, computer in pairs(computers) do
        local width = #role + 2

        if x >= currentX and x < currentX + width then
            selectedRole = role
            return
        end

        currentX = currentX + width
    end
end

local function draw()
    box:clear(colors.black)

    ctx:fill(
        1,
        1,
        ctx.width,
        2,
        colors.gray
    )

    local x = 1

    for _, role in ipairs(roles) do
        local computer = computers[role]
        local width = #role + 2
        local color = colors.lightGray

        if role == selectedRole then
            color = colors.blue
        end

        ctx:fill(
            x,
            1,
            width,
            2,
            color
        )

        ctx:text(
            x + 1,
            1,
            role,
            colors.white
        )

        x = x + width
    end

    if selectedRole then
        local computer = computers[selectedRole]

        if computer and computer.module and computer.module.draw then
            computer.module:draw()
        end
    end

    box:render()
end


local function networkLoop()
    while true do
        local event, a, b, c, d, e = os.pullEvent()

        if event == "modem_message" then
            local channel = b
            local message = e

            if channel == 102 then
                handlePing(message)
            end

            if type(message) == "table" and message.command == "reboot" then
                os.reboot()
            end

        elseif event == "monitor_touch" then
            local side = a
            local x = b
            local y = c

            if side == monitor then
                handleTouch(x, y)
            end
        end
    end
end

local function maintenanceLoop()
    while true do
        removeOffline()
        sleep(1)
    end
end

local function renderLoop()
    while true do
        draw()
        sleep(0.1)
    end
end


parallel.waitForAll(
    networkLoop,
    maintenanceLoop,
    renderLoop
)
