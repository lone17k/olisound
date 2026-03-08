RegisterNUICallback("init", function(data, cb)
    SendNUIMessage({ status = "init", time = Config.RefreshTime })
    if cb then cb('ok') end
end)

RegisterNUICallback("data_status", function(data, cb)
    if soundInfo[data.id] then
        if data.type == "finished" then
            if not soundInfo[data.id].loop then soundInfo[data.id].playing = false end
            TriggerEvent("olisound:soundFinished", data.id)
            TriggerEvent("xSound:songStopPlaying", data.id)
        end
        if data.type == "maxDuration" then
            soundInfo[data.id].hasMaxTime = true
            soundInfo[data.id].maxDuration = data.time
        end
    end
    if cb then cb('ok') end
end)

RegisterNUICallback("events", function(data, cb)
    local id = data.id
    local t = data.type

    if t == "resetTimeStamp" and soundInfo[id] then
        soundInfo[id].timeStamp = 0
        soundInfo[id].maxDuration = data.time
        soundInfo[id].playing = true
    end

    if t == "onPlay" and globalOptionsCache[id] then
        if globalOptionsCache[id].onPlayStartSilent then
            globalOptionsCache[id].onPlayStartSilent(getInfo(id))
        end
        if globalOptionsCache[id].onPlayStart and not (soundInfo[id] and soundInfo[id].SkipEvents) then
            globalOptionsCache[id].onPlayStart(getInfo(id))
        end
        if soundInfo[id] then soundInfo[id].SkipEvents = nil end
    end

    if t == "onEnd" then
        if globalOptionsCache[id] and globalOptionsCache[id].onPlayEnd then
            globalOptionsCache[id].onPlayEnd(getInfo(id))
        end
        if soundInfo[id] then
            if soundInfo[id].loop then soundInfo[id].timeStamp = 0 end
            if soundInfo[id].destroyOnFinish and not soundInfo[id].loop then Destroy(id) end
        end
    end

    if t == "onLoading" and globalOptionsCache[id] and globalOptionsCache[id].onLoading then
        globalOptionsCache[id].onLoading(getInfo(id))
    end

    if cb then cb('ok') end
end)

local function handleStateSound(state, data)
    local id = data.soundId
    if state == "destroyOnFinish" and soundExists(id) then destroyOnFinish(id, data.value)
    elseif state == "timestamp" and soundExists(id) then setTimeStamp(id, data.time)
    elseif state == "play" then PlayUrl(id, data.url, data.volume, data.loop or false)
    elseif state == "playpos" then PlayUrlPos(id, data.url, data.volume, data.position, data.loop or false)
    elseif state == "position" and soundExists(id) then Position(id, data.position)
    elseif state == "distance" and soundExists(id) then Distance(id, data.distance)
    elseif state == "destroy" and soundExists(id) then Destroy(id)
    elseif state == "pause" and soundExists(id) then Pause(id)
    elseif state == "resume" and soundExists(id) then Resume(id)
    elseif state == "volume" and soundExists(id) then
        if isDynamic(id) then setVolumeMax(id, data.volume) else setVolume(id, data.volume) end
    end
end

RegisterNetEvent("olisound:stateSound", function(state, data) handleStateSound(state, data) end)
RegisterNetEvent("xsound:stateSound", function(state, data) handleStateSound(state, data) end)
