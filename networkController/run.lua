local BASE_PATH = "https://raw.githubusercontent.com/ScorchedDuck/Airship-Control/main/"

local disk = peripheral.find("drive")

local modem = peripheral.find("modem")
modem.open(100) -- command channel
modem.open(101) -- register channel
modem.open(102) -- monitor channel

local messageQueue = {}

local state = {
    registered = {}
}

local VARS = "vars.json"
local vars = {}

local function loadVars()
    if not fs.exists(VARS) or fs.getSize(VARS) == 0 then
        error("Vars file doesn't exist or is empty")
    else
        local file = fs.open(VARS, "r")
        vars = textutils.unserializeJSON(file.readAll())
        file.close()

        if not vars then
            error("Vars failed")
        end
    end
end


local function modemLoop()
    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        if message and message.command == "reboot" then
            print("Rebooting...")
            os.reboot()
        end
        messageQueue[#messageQueue + 1] = {
            message = message, 
            channel = channel, 
            replyChannel = replyChannel
        }
    end
end

local function process()
    while true do
        if #messageQueue > 0 then
            local messageData = table.remove(messageQueue, 1)
            local message = messageData.message
            local channel = messageData.channel
            local replyChannel = messageData.replyChannel

            if message and message.command == "ping" then
                modem.transmit(replyChannel, channel, {
                    command = "pong"
                }) 
                state.registered[message.body.name] = os.clock()

            elseif message and message.command == "fetch" then
                modem.transmit(replyChannel, channel, {
                    command = "return",
                    body = {
                        name = role,
                        text = state[message.body.text]
                    }
                }) 
            end
        else
            sleep(0.05)
        end
    end
end

local function removeDeadComputers()
    while true do
        local now = os.clock()

        for name, lastPing in pairs(state.registered) do
            if now - lastPing > 10 then
                state.registered[name] = nil
                print(name .. " timed out")
            end
        end

        sleep(1)
    end
end

local function monitor()
    modem.transmit(102, 0, {
        command = "monitor",
        role = ROLE
    })
    sleep(15)
end

loadVars()

parallel.waitForAny(
    modemLoop,
    process,
    removeDeadComputers,
    monitor
)
