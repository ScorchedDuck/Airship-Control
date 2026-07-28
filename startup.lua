local VERSIONS_PATH = "https://raw.githubusercontent.com/ScorchedDuck/Airship-Control/main/versions.json"

local sensor = peripheral.find("optical_sensor")

local idBlock = sensor.getBlock()

print(idBlock)
