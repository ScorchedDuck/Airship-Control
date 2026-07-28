local VERSIONS_PATH = "https://raw.githubusercontent.com/ScorchedDuck/Airship-Control/main/versions.json"

local sensor = peripheral.find("optical_sensor")

local idBlock = sensor.getBlock()
local role

local function getVersions()
    local response = http.get(VERSIONS_PATH)
    if not response then
        error("Couldn't download versions.json")
    end

    local data = textutils.unserializeJSON(response.readAll())
    response.close()

    return data
end 

local versions = getVersions()

for name, data in ipairs(versions) do
    if name ~= "startup" then
        print(data.idBlock)
        if data.idBlock == idBlock then
            role = data
            break
        end
    end
end

if role then
    print("Got role: " .. role)
else 
    error("No role found for block: " .. idBlock)
end
