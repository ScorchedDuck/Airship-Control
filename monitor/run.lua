local PIXEL_PATH = "https://raw.githubusercontent.com/9551-Dev/pixelbox_lite/refs/heads/master/pixelbox_lite.lua"
local BASE_PATH = "https://raw.githubusercontent.com/ScorchedDuck/Airship-Control/refs/heads/main/"

local monitor = peripheral.find("monitor")

local modem = peripheral.find("modem")
modem.open(100)
modem.open(102) -- monitor channel

local computers = {}

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
        end

    end
end

local function draw()
    box:clear(colors.black)

    for role, computer in pairs(computers) do
        local module = computer.module

        if module and module.draw then
            module:draw()
        end

        break
    end

    box:render()
end

local function networkLoop()
    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")

        if channel == 102 then
            handlePing(message)
        end
        if type(message) == "table" and message.command == "reboot" then
            os.reboot()
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
