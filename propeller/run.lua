local modem = peripheral.find("modem")
modem.open(100) -- command channel
modem.open(102) -- monitor channel
modem.open(104) -- propeller channel

local state = {}

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

local function updateVars()
    local file = fs.open(VARS, "w")
    file.write(textutils.serializeJSON(vars))
    file.close()
end

local function modemLoop()
    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        if message and message.command == "reboot" then
            print("Rebooting...")
            os.reboot()
        end
        if message and message.command == "fetch" then
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
        if message and message.command == "propellers" and not vars.role:find("Commander") then
            local data = message.body.text
            if vars.role:find("fl") then
                state.thrust = data.motors.fl
            elseif vars.role:find("fr") then
                state.thrust = data.motors.fr
            elseif vars.role:find("bl") then
                state.thrust = data.motors.bl
            elseif vars.role:find("br") then
                state.thrust = data.motors.br
            end

            state.sails = data.sails
            state.targetHeight = data.targetHeight
        end
    end
end

local function registerLoop()
    while true do
        modem.transmit(101, 0, {command = "ping", body = {name = vars.role, computer = os.computerID()}})
        sleep(10)
    end
end

local function monitor()
    while true do
        modem.transmit(102, 0, {
            command = "monitor",
            role = "propeller"
        })
        sleep(10)
    end
end


local function propellerCommander()
    local function updatePID(pid, error, dt)
        pid.integral = pid.integral + error * dt
        local derivative = (error - pid.last_error) / dt

        local output = pid.P * error + pid.I * pid.integral + pid.D * derivative

        pid.last_error = error

        if output > 14 or output < -14 then
            pid.integral = pid.integral - error * dt
        end

        return output
    end

    local nextSave = 0

    state = {
        pose = {
            pos = nil,
            rot = {}
        },
        motors = {
            fl = 0,
            fr = 0,
            bl = 0,
            br = 0
        },
        sails = 48,
        targetHeight = 130,
        addedMass = 0,
        totalMass = 0,

        rollMultiplier = 1,
        pitchMultiplier = 1,
        swapPitchRoll = false
    }

    local PID = {
        pitch = {P = 35, I = 0.001, D = 1, integral = 0, last_error = 0},
        roll  = {P = 35, I = 0.001, D = 1, integral = 0, last_error = 0},
        height  = {P = 0.1, I = 0.001, D = 0.5, integral = 0, last_error = 0}
    }

    local targetPitch = 0
    local targetRoll = 0

    if vars.state then
        state = vars.state
    else
        vars.state = state
        updateVars()
    end

    local lastTime = os.clock()
    while true do
        local now = os.clock()
        local dt = now - lastTime
        lastTime = now
        state.totalMass = state.addedMass + sublevel.getMass()

        local pose = sublevel.getLogicalPose()
        state.pose.pos = pose.position
        state.pose.rot.pitch, state.pose.rot.yaw, state.pose.rot.roll = pose.orientation:toEuler()

        local pitchError = targetPitch - state.pose.rot.pitch
        local rollError  = targetRoll - state.pose.rot.roll
        local heightError = state.targetHeight - state.pose.pos.y

        local pitchOut = updatePID(PID.pitch, pitchError, dt) * state.pitchMultiplier
        local rollOut  = updatePID(PID.roll, rollError, dt) * state.rollMultiplier
        local heightOut  = updatePID(PID.height, heightError, dt) 

        local weight = state.totalMass * math.abs(aero.getGravity().y)

        weight = weight / 4

        state.motors.fl = weight + pitchOut + rollOut + heightOut
        state.motors.fr = weight + pitchOut - rollOut + heightOut
        state.motors.bl = weight - pitchOut + rollOut + heightOut
        state.motors.br = weight - pitchOut - rollOut + heightOut

        modem.transmit(104, 0, {
            command = "propellers",
            body = {
                name = vars.role,
                text = {
                    motors = state.motors,
                    sails = state.sails,
                    targetHeight = state.targetHeight
                }
            }
        })

        if os.clock() > nextSave then
            updateVars()
            nextSave = os.clock() + 10
        end
        sleep(0)
    end
end

local function propeller()
    local function calculateRPM()
        local position = vector.new(0, state.targetHeight, 0)
        local pressure = aero.getAirPressure(position)

        state.rpm =  state.thrust / (0.2 * (state.sails ^ 1.5) * pressure)

        if state.rpm < 0 then
            state.rpm = state.rpm * -1
        end
    end

    local speedContoller = peripheral.find("Create_RotationSpeedController")
    state = {
        thrust = 0,
        rpm = 0,
        sails = 1,
        targetHeight = 0
    }

    while true do
        calculateRPM()
        if state.rpm > 256 then
            state.rpm = 256
        elseif state.rpm < -256 then
            state.rpm = -256
        end

        if state.rpm ~= state.rpm then
            state.rpm = 0
        end
        speedContoller.setTargetSpeed(state.rpm)
        sleep(0)
    end
end

loadVars()

if vars.role == "propellerCommander" then
    parallel.waitForAll(
        propellerCommander,
        modemLoop,
        registerLoop,
        monitor
    )
else
    parallel.waitForAll(
        propeller,
        modemLoop,
        registerLoop
    )
end
