local isInVehicle = false
local currentVehicle = nil

local function isSameVehicle(veh1, veh2)
    if not DoesEntityExist(veh1) or not DoesEntityExist(veh2) then return false end
    if veh1 == veh2 then return true end
    if NetworkGetEntityIsNetworked(veh1) and NetworkGetEntityIsNetworked(veh2) then
        return NetworkGetNetworkIdFromEntity(veh1) == NetworkGetNetworkIdFromEntity(veh2)
    end
    return false
end

local function isAudioUnmuffled(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    local count = GetNumberOfVehicleDoors(vehicle)
    if count > 4 then count = 4 end
    for i = 0, count - 1 do
        if GetVehicleDoorAngleRatio(vehicle, i) > 0.1 then return true end
        if IsVehicleDoorDamaged(vehicle, i) then return true end
        if not IsVehicleWindowIntact(vehicle, i) then return true end
    end
    return false
end

CreateThread(function()
    if not Config.vehicleOcclusionEnabled then return end

    while true do
        Wait(250)
        local ped = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle(ped, false)

        if inVehicle then
            if not isInVehicle then
                isInVehicle = true
                currentVehicle = GetVehiclePedIsIn(ped, false)
            end
        else
            if isInVehicle then
                isInVehicle = false
                currentVehicle = nil
            end
        end

        for name, info in pairs(soundInfo) do
            if not info.playing then goto continue end
            if not info.attachedToVehicle then goto continue end

            local muffleEnabled = true
            local vehicleGain = Config.outsideVehicleVolume or 0.5
            local disablePanning = false
            local muffleFreq = Config.outsideVehicleMuffleFrequency

            if isInVehicle and currentVehicle and info.vehicleEntity then
                if isSameVehicle(info.vehicleEntity, currentVehicle) then
                    muffleEnabled = false
                    vehicleGain = Config.insideVehicleVolume or 1.0
                    disablePanning = true
                else
                    local unmuffled = isAudioUnmuffled(info.vehicleEntity)
                    muffleEnabled = not unmuffled
                    vehicleGain = Config.otherVehicleVolume or 0.4
                    muffleFreq = Config.occlusionFilterFrequency
                end
            elseif not isInVehicle then
                local unmuffled = isAudioUnmuffled(info.vehicleEntity)
                muffleEnabled = not unmuffled
                vehicleGain = Config.outsideVehicleVolume or 0.5
                muffleFreq = Config.outsideVehicleMuffleFrequency
            end

            if info.lastMuffleEnabled ~= muffleEnabled then
                info.lastMuffleEnabled = muffleEnabled
                SendNUIMessage({ status = "muffle", name = name, enabled = muffleEnabled, frequency = muffleFreq })
            end
            
            if info.lastVehicleGain ~= vehicleGain then
                info.lastVehicleGain = vehicleGain
                SendNUIMessage({ status = "vehicleGain", name = name, gain = vehicleGain })
            end
            
            if info.lastDisablePanning ~= disablePanning then
                info.lastDisablePanning = disablePanning
                SendNUIMessage({ status = "disablePanning", name = name, disabled = disablePanning })
            end

            ::continue::
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.RefreshTime)
        for name, info in pairs(soundInfo) do
            if info.vehicleEntity then
                if DoesEntityExist(info.vehicleEntity) then
                    if info.playing then
                        local pos = GetEntityCoords(info.vehicleEntity)
                        info.position = pos
                        SendNUIMessage({ status = "soundPosition", name = name, x = pos.x, y = pos.y, z = pos.z })
                    end
                else
                    Destroy(name)
                end
            elseif info.attachedEntity then
                if DoesEntityExist(info.attachedEntity) then
                    if info.playing then
                        local pos = GetEntityCoords(info.attachedEntity)
                        info.position = pos
                        SendNUIMessage({ status = "soundPosition", name = name, x = pos.x, y = pos.y, z = pos.z })
                    end
                else
                    Destroy(name)
                end
            end
        end
    end
end)
