local PIXEL_PATH = "https://raw.githubusercontent.com/9551-Dev/pixelbox_lite/refs/heads/master/pixelbox_lite.lua"
local BASE_PATH = "https://raw.githubusercontent.com/ScorchedDuck/Airship-Control/refs/heads/main/"

local monitor = peripheral.find("monitor")
monitor.setTextScale(0.5)
local monitorWidth, monitorHeight = monitor.getSize()

local modem = peripheral.find("modem")
modem.open(100)
modem.open(102) -- monitor channel
modem.open(103) -- monitor response

local computers = {}
local roles = {}
local selectedRole = nil

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
ctx.monitorWidth = monitorWidth
ctx.monitorHeight = monitorHeight

local barWidth = math.floor(ctx.width / 10)
if barWidth % 2 == 1 then 
    barWidth = barWidth - 1
end
local barHeight = 3

ctx.barHeight = barHeight

function ctx:clear(color)
    box:clear(colors.black)
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

local requestId = 0
local pendingRequests = {}

local network = {}

function network.request(info)
    requestId = requestId + 1

    local id = requestId

    pendingRequests[id] = {
        data = nil
    }

    modem.transmit(102, 103, {
        command = "fetch",
        body = {
            text = info,
            id = id
        }
    })

    return id
end

function network.get(id)
    local request = pendingRequests[id]

    if not request or not request.data then
        return nil
    end

    local data = request.data
    pendingRequests[id] = nil
    return data
end

local function loadModule(role)
    local url = BASE_PATH .. role .. "/monitor.lua?t=" .. os.clock()

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
                ui = ctx,
                network = network
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
    if y > barHeight then
        local computer = computers[selectedRole]

        if computer and computer.module and computer.module.click then
            computer.module:click(x, y)
        end
    end

    if #roles == 0 then
        return
    end

    if x <= barWidth then
        local currentIndex = 1

        for i, role in ipairs(roles) do
            if role == selectedRole then
                currentIndex = i
                break
            end
        end

        currentIndex = currentIndex - 1

        if currentIndex < 1 then
            currentIndex = #roles
        end

        selectedRole = roles[currentIndex]

    elseif x > ctx.width - barWidth then
        local currentIndex = 1

        for i, role in ipairs(roles) do
            if role == selectedRole then
                currentIndex = i
                break
            end
        end

        currentIndex = currentIndex + 1

        if currentIndex > #roles then
            currentIndex = 1
        end

        selectedRole = roles[currentIndex]
    end
end

local function draw()
    box:clear(colors.black)

    if selectedRole then
        local computer = computers[selectedRole]

        if computer and computer.module and computer.module.draw then
            computer.module:draw()
        end
    end

    ctx:fill(1, 1, barWidth, barHeight, colors.red)
    ctx:fill(barWidth + 1, 1, ctx.width - (barWidth * 2), barHeight, colors.gray)
    ctx:fill(ctx.width - barWidth + 1, 1, barWidth, barHeight, colors.red)

    box:render()

    if selectedRole then
        local computer = computers[selectedRole]

        if computer and computer.module and computer.module.draw then
            computer.module:text()
        end
    end

    if selectedRole and computers[selectedRole] then
        local name = computers[selectedRole].module.name
        monitor.setCursorPos(math.floor((monitorWidth - #name) / 2) + 1, 1)
        monitor.setTextColor(colors.white)
        monitor.setBackgroundColor(colors.gray)
        monitor.write(name)
    end
end


local function networkLoop()
    while true do
        local event, a, b, c, d, e = os.pullEvent()
        if event == "modem_message" then
            local channel = b
            local message = d

            if channel == 102 then
                handlePing(message)
            end

            if channel == 103 then
                if type(message) == "table" and message.command == "return" then
                    if pendingRequests[message.body.id] then
                        pendingRequests[message.body.id].data = message.body.text
                    end
                end
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
    local nextPing = os.clock()
    while true do
        removeOffline()
        if nextPing <= os.clock() then
            modem.transmit(101, 0, {command = "ping", body = {name = "monitor"}})
            nextPing = os.clock() + 10
        end
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
