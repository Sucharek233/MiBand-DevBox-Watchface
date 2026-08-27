local SensorInfo = {}

local lvgl = require("lvgl")

SensorInfo.PATH = "/dev/uorb"

SensorInfo.PREDEFINED = {
    -- info taken from mi band 10
    accel = {
        name = "Accelerometer",
        path = "sensor_accel0",
        props = {"x", "y", "z"}
    },
    gyro = {
        name = "Gyroscope",
        path = "sensor_gyro0",
        props = {"x", "y", "z"}
    },
    mag = {
        name = "Magnetometer",
        path = "sensor_mag_uncal0",
        props = {"x", "y", "z"}
    },
    light = {
        name = "Light Sensor",
        path = "sensor_light0",
        props = {"lx"}
    },
    comp = {
        name = "Compass",
        path = "algo_compass0",
        props = {"_", "°"}
    },
    tilt = {
        name = "Wrist Tilt",
        path = "algo_wrist_tilt0",
        props = {"_"}
    },
    -- info taken from emulator
    hrate = {
        name = "Heart Rate",
        path = "sensor_hrate0",
        props = {"bpm"}
    },
    temp = {
        name = "Ambient Temperature",
        path = "sensor_temp0",
        props = {"°C"}
    },
    prox = {
        name = "Proximity Sensor",
        path = "sensor_prox0",
        props = {"cm"}
    },
    baro = {
        name = "Barometer",
        path = "sensor_baro0",
        props = {"hPa"}
    },
    humi = {
        name = "Humidity Sensor",
        path = "sensor_humi0",
        props = {"%"}
    }
}

SensorInfo._checked = false

-- Returns flat array of all sensor nodes found in /dev/uorb
function SensorInfo.getAvailableSensors()
    local sensors = {}
    local dir = lvgl.fs.open_dir(SensorInfo.PATH)

    while true do
        local d = dir:read()
        if not d then break end
        table.insert(sensors, d)
    end

    dir:close()
    return sensors
end

function SensorInfo.getAvailablePredefinedSensors()
    if SensorInfo._checked then
        return SensorInfo.PREDEFINED
    end

    for _, sensor in pairs(SensorInfo.PREDEFINED) do
        local fullPath = SensorInfo.PATH .. "/" .. sensor.path
        sensor.available = FileOps.fileExists(fullPath)
    end

    SensorInfo._checked = true

    return SensorInfo.PREDEFINED
end

return SensorInfo