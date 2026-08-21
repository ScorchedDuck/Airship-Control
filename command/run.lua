local VERSIONS_PATH = "https://raw.githubusercontent.com/ScorchedDuck/Airship-Control/main/versions.json"
local DEFAULT_STARTUP_PATH = "https://raw.githubusercontent.com/ScorchedDuck/Airship-Control/main/startup.lua"

local VARS = "vars.json"
local DEFAULT_VARS = {
    currentStartupVersion = 0.00,
    hideErrors = false,
}

local vars

local startupDisk = peripheral.getName(peripheral.find("drive"))
local modem = peripheral.find("modem")
modem.open(100)

local function getVersions()
    local response = http.get(VERSIONS_PATH)
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

local function uploadStartup()
    local function downloadStartup()
        print("Downloading startup.lua from: " .. DEFAULT_STARTUP_PATH)

        if fs.exists("startup_download.lua") then
            fs.delete("startup_download.lua")
        end

        local response = http.get(DEFAULT_STARTUP_PATH)

        if not response then
            error("Couldn't download startup.lua")
        end

        local file = fs.open("startup_download.lua", "w")
        file.write(response.readAll())
        file.close()
        response.close()
    end

    downloadStartup()
    sleep(0.5)

    local mount = disk.getMountPath(startupDisk)
    if mount then
        print("Uploading startup.lua to drive: " .. startupDisk)
        if fs.exists(fs.combine(mount, "startup.lua")) then
            fs.delete(fs.combine(mount, "startup.lua"))
        end

        fs.copy("startup_download.lua", fs.combine(mount, "startup.lua"))
    else
        error("No disk in drive: " .. startupDisk)
    end

    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "computer" then
            peripheral.call(name, "reboot")
        end
    end
end

loadVars()

local versions = getVersions()

if versions.startup ~= vars.currentStartupVersion then
    print("New startup version available: " .. versions.startup)

    uploadStartup()

    vars.currentStartupVersion = versions.startup
elseif not fs.exists(fs.combine(disk.getMountPath(startupDisk), "startup.lua")) then
    print("No startup.lua found on disk")

    uploadStartup()

    vars.currentStartupVersion = versions.startup
else
    print("Startup is up to date")
end

updateVars()

local function modemLoop()
    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        if message and message.command == "reboot" then
            print("Rebooting...")
            os.reboot()
        end

        if message and message.command == "join" then
            print(message.body.name .. " joined")
        end

        if message and message.command == "error" and not vars.hideErrors then
            print(message.body.name .. " had an error - " .. message.body.text)
        end
    end
end

local function inputLoop()
    while true do
        print("Enter 'reboot' to reboot or 'hideErrors' to toggle error messages:")
        local input = read()
        if input == "reboot" then
            print("Rebooting...")
            modem.transmit(100, 0, {command = "reboot", body = {}})
            os.reboot()
        elseif input == "hideErrors" then
            vars.hideErrors = not vars.hideErrors
            updateVars()
            print("Hide errors set to: " .. tostring(vars.hideErrors))
        end
    end
end
