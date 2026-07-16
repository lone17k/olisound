globalOptionsCache = {}
isPlayerCloseToMusic = false
disableMusic = false

function UpdatePlayerPositionInNUI()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local camRot = GetGameplayCamRot(2)
    local z = math.rad(camRot.z)
    local x = math.rad(camRot.x)
    local num = math.abs(math.cos(x))
    
    local fx = -math.sin(z) * num
    local fy = math.cos(z) * num
    local fz = math.sin(x)
    
    SendNUIMessage({ 
        status = "position", 
        x = pos.x, y = pos.y, z = pos.z,
        fx = fx, fy = fy, fz = fz
    })
end

function CheckForCloseMusic()
    local playerPos = GetEntityCoords(PlayerPedId())
    isPlayerCloseToMusic = false
    for _, v in pairs(soundInfo) do
        if v.position and v.isDynamic then
            if #(v.position - playerPos) < v.distance + Config.distanceBeforeUpdatingPos then
                isPlayerCloseToMusic = true
                return
            end
        end
    end
end

CreateThread(function()
    local lastPos = vector3(0, 0, 0)
    local changedPosition = false
    while true do
        Wait(Config.RefreshTime)
        if not disableMusic and isPlayerCloseToMusic then
            local pos = GetEntityCoords(PlayerPedId())
            if #(lastPos - pos) >= 0.1 then
                lastPos = pos
                UpdatePlayerPositionInNUI()
            end
            if changedPosition then
                UpdatePlayerPositionInNUI()
                SendNUIMessage({ status = "unmuteAll" })
            end
            changedPosition = false
        else
            if not changedPosition then
                changedPosition = true
                SendNUIMessage({ status = "position", x = -900000, y = -900000, z = -900000 })
            end
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(500)
        CheckForCloseMusic()
    end
end)

CreateThread(function()
    Wait(1100)
    while true do
        Wait(1000)
        for _, v in pairs(soundInfo) do
            if v.playing or v.wasSilented then
                if v.timeStamp and v.maxDuration and v.timeStamp < v.maxDuration then
                    v.timeStamp = v.timeStamp + 1
                end
            end
        end
    end
end)

function PlayMusicFromCache(data)
    local cache = soundInfo[data.id]
    if not cache then return end
    cache.SkipEvents = true
    PlayUrlPosSilent(data.id, data.url, data.volume, data.position, data.loop)

    if cache.attachedToVehicle then
        SendNUIMessage({ status = "attachVehicle", name = data.id, attached = true })
    end

    onPlayStartSilent(data.id, function()
        if getInfo(data.id) and getInfo(data.id).maxDuration then
            setTimeStamp(data.id, data.timeStamp or 0)
        end
        Distance(data.id, data.distance)
    end)
end

CreateThread(function()
    local destroyedList = {}
    while true do
        Wait(500)
        local playerPos = GetEntityCoords(PlayerPedId())
        for k, v in pairs(soundInfo) do
            if v.position and v.isDynamic then
                local dist = #(v.position - playerPos)
                if dist < (v.distance + Config.distanceBeforeUpdatingPos) then
                    if not isPaused(v.id) and destroyedList[v.id] then
                        destroyedList[v.id] = nil
                        v.wasSilented = true
                        PlayMusicFromCache(v)
                    end
                else
                    if not destroyedList[v.id] then
                        destroyedList[v.id] = true
                        v.wasSilented = false
                        DestroySilent(v.id)
                    end
                end
            end
        end
    end
end)

local function ToggleStreamerMode(state, isFromEvent)
    local targetState
    if state ~= nil then
        targetState = state
    else
        targetState = not disableMusic
    end

    if disableMusic == targetState then
        return
    end

    disableMusic = targetState

    if not isFromEvent then
        TriggerEvent("xsound:streamerMode", disableMusic)
    end

    if disableMusic then
        for k, _ in pairs(soundInfo) do
            SendNUIMessage({ status = "delete", name = k })
        end
        SendNUIMessage({ status = "muteAll" })
        TriggerEvent("chat:addMessage", { args = { "olisound", Config.Messages["streamer_on"] } })
    else
        for k, v in pairs(soundInfo) do
            if v.playing then
                PlayMusicFromCache(v)
            end
        end
        TriggerEvent("chat:addMessage", { args = { "olisound", Config.Messages["streamer_off"] } })
    end
end

if Config.StreamerModeCommand and Config.StreamerModeCommand ~= "" then
    RegisterCommand(Config.StreamerModeCommand, function()
        ToggleStreamerMode()
    end, false)
end

-- Backwards compatibility with xSound
exports('streamerMode', ToggleStreamerMode)

RegisterNetEvent('xsound:streamerMode')
AddEventHandler('xsound:streamerMode', function(status)
    ToggleStreamerMode(status, true)
end)

CreateThread(function()
    if not Config.objectOcclusionEnabled then return end
    
    while true do
        Wait(250)
        local hasPlayingSounds = false
        for _, v in pairs(soundInfo) do
            if v.playing and not v.attachedToVehicle then
                hasPlayingSounds = true
                break
            end
        end

        if hasPlayingSounds then
            local ped = PlayerPedId()
            local headPos = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
            
            for k, v in pairs(soundInfo) do
                if not v.playing then goto continue end
                if v.attachedToVehicle then goto continue end
                
                local targetPos = nil
                if v.attachedEntity and DoesEntityExist(v.attachedEntity) then
                    targetPos = GetEntityCoords(v.attachedEntity)
                elseif v.position then
                    targetPos = v.position
                end
                
                if targetPos then
                    local dist = #(headPos - targetPos)
                    if dist < (v.distance or Config.defaultDistance or 10.0) then
                        local rayHandle = StartShapeTestRay(headPos.x, headPos.y, headPos.z, targetPos.x, targetPos.y, targetPos.z, 17, ped, 0)
                        local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)
                        
                        local occluded = false
                        if hit == 1 then
                            if v.attachedEntity and entityHit == v.attachedEntity then
                                occluded = false
                            else
                                occluded = true
                            end
                        end
                        
                        if v.lastObjectMuffleEnabled ~= occluded then
                            v.lastObjectMuffleEnabled = occluded
                            SendNUIMessage({ status = "muffle", name = k, enabled = occluded, frequency = Config.objectOcclusionFrequency or 800 })
                            SendNUIMessage({ status = "vehicleGain", name = k, gain = occluded and (Config.otherVehicleVolume or 0.4) or 1.0 })
                        end
                    else
                        if v.lastObjectMuffleEnabled ~= false then
                            v.lastObjectMuffleEnabled = false
                            SendNUIMessage({ status = "muffle", name = k, enabled = false })
                            SendNUIMessage({ status = "vehicleGain", name = k, gain = 1.0 })
                        end
                    end
                else
                    if v.lastObjectMuffleEnabled ~= false then
                        v.lastObjectMuffleEnabled = false
                        SendNUIMessage({ status = "muffle", name = k, enabled = false })
                        SendNUIMessage({ status = "vehicleGain", name = k, gain = 1.0 })
                    end
                end
                
                ::continue::
            end
        end
    end
end)

if Config.debugOcclusion then
    local debugOcclusion = false
    local debugProp = nil

    RegisterCommand("debugocclusion", function()
        debugOcclusion = not debugOcclusion
        TriggerEvent("chat:addMessage", { args = { "olisound", "Object Occlusion Debug: " .. tostring(debugOcclusion) } })
        
        if debugOcclusion then
            -- Spawn debug prop and play music
            local model = GetHashKey("prop_boombox_01")
            RequestModel(model)
            while not HasModelLoaded(model) do Wait(0) end
            
            local ped = PlayerPedId()
            local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.0, 0.0)
            debugProp = CreateObject(model, pos.x, pos.y, pos.z, true, true, false)
            PlaceObjectOnGroundProperly(debugProp)
            
            exports.olisound:PlayUrlEntity('debug_sound', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', 1.0, debugProp, true)
            
            CreateThread(function()
                while debugOcclusion do
                    Wait(0)
                    local currentPed = PlayerPedId()
                    local headPos = GetPedBoneCoords(currentPed, 31086, 0.0, 0.0, 0.0)
                    
                    for k, v in pairs(soundInfo) do
                        if v.playing and not v.attachedToVehicle then
                            local targetPos = nil
                            if v.attachedEntity and DoesEntityExist(v.attachedEntity) then
                                targetPos = GetEntityCoords(v.attachedEntity)
                            elseif v.position then
                                targetPos = v.position
                            end
                            
                            if targetPos then
                                local dist = #(headPos - targetPos)
                                if dist < (v.distance or Config.defaultDistance or 10.0) then
                                    if v.lastObjectMuffleEnabled then
                                        -- Occluded: Red line
                                        DrawLine(headPos.x, headPos.y, headPos.z, targetPos.x, targetPos.y, targetPos.z, 255, 0, 0, 255)
                                    else
                                        -- Clear: Green line
                                        DrawLine(headPos.x, headPos.y, headPos.z, targetPos.x, targetPos.y, targetPos.z, 0, 255, 0, 255)
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        else
            -- Clean up
            exports.olisound:Destroy('debug_sound')
            if debugProp and DoesEntityExist(debugProp) then
                DeleteEntity(debugProp)
                debugProp = nil
            end
        end
    end, false)
end
