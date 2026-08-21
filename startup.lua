local PATH = "https://raw.githubusercontent.com/ScorchedDuck/Airship-Control/main"

local sensor = peripheral.find("optical_sensor")
local modem = peripheral.find("modem")
modem.open(100)

local idBlock = sensor.getBlock()
local role

local VARS = "vars.json"
local DEFAULT_VARS = {currentVersion = 0.00}
local vars



local function getVersions()
    local response = http.get(PATH .. "/versions.json")
    if not response then
        error("Couldn't download versions.json")
    end

    local data = textutils.unserializeJSON(response.readAll())
    response.close()

    return data
end 

local function loadVars()
    if not fs.exists(VARS) or fs.getSize(VARS) == 0 then
        print("Using default vars")

        vars = DEFAULT_VARS

        local file = fs.open(VARS, "w")
        file.write(textutils.serializeJSON(vars))
        file.close()
    else
        print("Loading vars file")

        local file = fs.open(VARS, "r")
        vars = textutils.unserializeJSON(file.readAll())
        file.close()

        if not vars then
            print("Vars failed")

            vars = DEFAULT_VARS

            local f = fs.open(VARS, "w")
            f.write(textutils.serializeJSON(vars))
            f.close()
        end
    end
end

local function updateVars()
    local file = fs.open(VARS, "w")
    file.write(textutils.serializeJSON(vars))
    file.close()
end

local function getScript(role)
    local response = http.get(PATH .. "/" .. role .. "/run.lua")
    if not response then
        print("Couldn't download ".. PATH .. "/" .. role .. "/run.lua - entering reboot loop")
        modem.transmit(100, 0, {
            command = "error", 
            body = {
                name = role, 
                text = "Couldn't download ".. PATH .. "/" .. role .. "/run.lua"
            }
        })
        while true do
            local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
            if message and message.command == "reboot" then
                print("Rebooting...")
                os.reboot()
            end
        end
    end

    if fs.exists("run.lua") then
        fs.delete("run.lua")
    end

    local file = fs.open("run.lua", "w")
    file.write(response.readAll())
    file.close()
    response.close()
end 

local versions = getVersions()

loadVars()

for name, data in pairs(versions) do
    if name ~= "startup" and data.idBlock == idBlock then
        role = name
        onlineVersion = data.version
        break
    end
end

if not role or not onlineVersion then
    error("Something failed for role or version")
end

if onlineVersion ~= vars.currentVersion then
    print("New version available: " .. onlineVersion)
    
    getScript(role)
    vars.currentVersion = onlineVersion
    updateVars()
end

modem.transmit(100, 0, {command = "join", body = {name = role, text = ""}})

print("Running " .. role .. " script")
shell.run("run.lua")

modem.transmit(100, 0, {command = "error", body = {name = role, text = "Run script failed"}})

print("Something went wrong, entering reboot loop")

while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    if message and message.command == "reboot" then
        print("Rebooting...")
        os.reboot()
    end
end
