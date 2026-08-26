local modem = peripheral.find("modem")
modem.open(100) -- command channel
modem.open(101) -- register channel
modem.open(102) -- monitor channel

local messageQueue = {}

local state = {
    registered = {
        os.computerID() = {
            name = "networkController",
            time = 0
        }
    }
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
                state.registered[message.body.computer] = {time = os.clock(), name = message.body.name}

            elseif message and message.command == "fetch" then
                local requested = message.body.text

                if state[requested] then
                    modem.transmit(replyChannel, channel, {
                        command = "return",
                        body = {
                            name = vars.role,
                            text = state[requested],
                            id = message.body.id
                        }
                    })
                end
            end
        else
            sleep(0.05)
        end
    end
end

local function removeDeadComputers()
    while true do
        local now = os.clock()

        for id, data in pairs(state.registered) do
            if now - data.time > 15 and data.name ~= "networkController" then
                state.registered[id] = nil
                print(data.name .. " timed out")
            end
        end

        sleep(1)
    end
end

local function monitor()
    while true do
        modem.transmit(102, 0, {
            command = "monitor",
            role = vars.role
        })
        sleep(10)
    end
end

loadVars()

parallel.waitForAny(
    modemLoop,
    process,
    removeDeadComputers,
    monitor
)
