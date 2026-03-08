globalOptionsCache = {}
isPlayerCloseToMusic = false
disableMusic = false

function UpdatePlayerPositionInNUI()
    local pos = GetEntityCoords(PlayerPedId())
    SendNUIMessage({ status = "position", x = pos.x, y = pos.y, z = pos.z })
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

RegisterCommand("streamermode", function()
    disableMusic = not disableMusic
    if disableMusic then
        for k, _ in pairs(soundInfo) do
            SendNUIMessage({ status = "delete", name = k })
        end
        SendNUIMessage({ status = "muteAll" })
        TriggerEvent("chat:addMessage", { args = { "olisound", Config.Messages["streamer_on"] } })
    else
        TriggerEvent("chat:addMessage", { args = { "olisound", Config.Messages["streamer_off"] } })
    end
end, false)
