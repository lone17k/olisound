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

local function isDoorOpen(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    local count = GetNumberOfVehicleDoors(vehicle)
    if count > 4 then count = 4 end
    for i = 0, count - 1 do
        if GetVehicleDoorAngleRatio(vehicle, i) > 0.1 then return true end
        if IsVehicleDoorDamaged(vehicle, i) then return true end
    end
    return false
end

local function isWindowBroken(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    local count = GetNumberOfVehicleDoors(vehicle)
    if count > 4 then count = 4 end
    for i = 0, count - 1 do
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

            if isInVehicle and currentVehicle and info.vehicleEntity then
                if isSameVehicle(info.vehicleEntity, currentVehicle) then
                    SendNUIMessage({ status = "muffle", name = name, enabled = false })
                    SendNUIMessage({ status = "vehicleGain", name = name, gain = 1.0 })
                else
                    SendNUIMessage({ status = "muffle", name = name, enabled = true, frequency = Config.occlusionFilterFrequency })
                    SendNUIMessage({ status = "vehicleGain", name = name, gain = 0.4 })
                end
            elseif not isInVehicle then
                local vehicleOpen = false
                if info.vehicleEntity and DoesEntityExist(info.vehicleEntity) then
                    vehicleOpen = isDoorOpen(info.vehicleEntity) or isWindowBroken(info.vehicleEntity)
                end

                if vehicleOpen then
                    SendNUIMessage({ status = "muffle", name = name, enabled = false })
                    SendNUIMessage({ status = "vehicleGain", name = name, gain = 1.0 })
                else
                    SendNUIMessage({ status = "muffle", name = name, enabled = true, frequency = Config.outsideVehicleMuffleFrequency })
                    SendNUIMessage({ status = "vehicleGain", name = name, gain = 0.5 })
                end
            end

            ::continue::
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.RefreshTime)
        for name, info in pairs(soundInfo) do
            if info.vehicleEntity and DoesEntityExist(info.vehicleEntity) and info.playing then
                local pos = GetEntityCoords(info.vehicleEntity)
                info.position = pos
                SendNUIMessage({ status = "soundPosition", name = name, x = pos.x, y = pos.y, z = pos.z })
            end
        end
    end
end)
