-- Made by .lone17 with ❤️
Config = {}

Config.RefreshTime = 200
Config.distanceBeforeUpdatingPos = 40

Config.vehicleOcclusionEnabled = true
Config.occlusionFilterFrequency = 800
Config.outsideVehicleMuffleFrequency = 600

-- Volume Modifiers (1.0 = 100%, 0.5 = 50%)
Config.insideVehicleVolume = 1.0     -- Volume when you are inside the vehicle playing the music
Config.otherVehicleVolume = 0.4      -- Volume of other vehicles' music when you are also inside a vehicle
Config.outsideVehicleVolume = 0.5    -- Volume of vehicle music when you are on foot outside

-- Streamer Mode
Config.StreamerModeCommand = "streamermode" -- The chat command to toggle streamer mode. If you use xsound, set this to the same command to sync them!

Config.Messages = {
    ["streamer_on"]  = "Streamer mode enabled. All external audio is muted.",
    ["streamer_off"] = "Streamer mode disabled. Audio is now active.",
    ["no_permission"] = "You do not have permission to use this command.",
}
