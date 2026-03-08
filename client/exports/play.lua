function getDefaultInfo()
    return {
        volume = 1.0,
        url = "",
        id = "",
        position = nil,
        distance = 10,
        playing = false,
        paused = false,
        loop = false,
        isDynamic = false,
        timeStamp = 0,
        maxDuration = 0,
        destroyOnFinish = true,
        attachedToVehicle = false,
        vehicleEntity = nil,
    }
end

function PlayUrl(name_, url_, volume_, loop_, options)
    if disableMusic then return end
    if soundInfo[name_] == nil then soundInfo[name_] = getDefaultInfo() end

    soundInfo[name_].volume = volume_
    soundInfo[name_].url = url_
    soundInfo[name_].id = name_
    soundInfo[name_].playing = true
    soundInfo[name_].loop = loop_ or false
    soundInfo[name_].isDynamic = false
    soundInfo[name_].hasMaxTime = false
    soundInfo[name_].destroyOnFinish = not (loop_ or false)

    globalOptionsCache[name_] = options or {}

    CheckForCloseMusic()
    UpdatePlayerPositionInNUI()
    SendNUIMessage({ status = "unmuteAll" })

    SendNUIMessage({
        status = "url",
        name = name_,
        url = url_,
        x = 0, y = 0, z = 0,
        dynamic = false,
        hasMaxTime = false,
        volume = volume_,
        loop = loop_ or false,
    })
end
exports('PlayUrl', PlayUrl)

function PlayUrlPos(name_, url_, volume_, pos, loop_, options)
    if disableMusic then return end
    if soundInfo[name_] == nil then soundInfo[name_] = getDefaultInfo() end

    soundInfo[name_].volume = volume_
    soundInfo[name_].url = url_
    soundInfo[name_].position = pos
    soundInfo[name_].id = name_
    soundInfo[name_].playing = true
    soundInfo[name_].loop = loop_ or false
    soundInfo[name_].isDynamic = true
    soundInfo[name_].hasMaxTime = false
    soundInfo[name_].destroyOnFinish = not (loop_ or false)

    globalOptionsCache[name_] = options or {}

    CheckForCloseMusic()

    if #(GetEntityCoords(PlayerPedId()) - pos) < soundInfo[name_].distance + Config.distanceBeforeUpdatingPos then
        UpdatePlayerPositionInNUI()
        SendNUIMessage({ status = "unmuteAll" })
    end

    SendNUIMessage({
        status = "url",
        name = name_,
        url = url_,
        x = pos.x, y = pos.y, z = pos.z,
        dynamic = true,
        hasMaxTime = false,
        volume = volume_,
        loop = loop_ or false,
    })
end
exports('PlayUrlPos', PlayUrlPos)

function PlayUrlVehicle(name_, url_, volume_, vehicle, loop_, options)
    if disableMusic then return end
    if not DoesEntityExist(vehicle) then return end

    local pos = GetEntityCoords(vehicle)

    if soundInfo[name_] == nil then soundInfo[name_] = getDefaultInfo() end

    soundInfo[name_].volume = volume_
    soundInfo[name_].url = url_
    soundInfo[name_].position = pos
    soundInfo[name_].id = name_
    soundInfo[name_].playing = true
    soundInfo[name_].loop = loop_ or false
    soundInfo[name_].isDynamic = true
    soundInfo[name_].hasMaxTime = false
    soundInfo[name_].destroyOnFinish = not (loop_ or false)
    soundInfo[name_].attachedToVehicle = true
    soundInfo[name_].vehicleEntity = vehicle

    globalOptionsCache[name_] = options or {}

    CheckForCloseMusic()

    if #(GetEntityCoords(PlayerPedId()) - pos) < soundInfo[name_].distance + Config.distanceBeforeUpdatingPos then
        UpdatePlayerPositionInNUI()
        SendNUIMessage({ status = "unmuteAll" })
    end

    SendNUIMessage({
        status = "url",
        name = name_,
        url = url_,
        x = pos.x, y = pos.y, z = pos.z,
        dynamic = true,
        hasMaxTime = false,
        volume = volume_,
        loop = loop_ or false,
    })

    SendNUIMessage({ status = "attachVehicle", name = name_, attached = true })
end
exports('PlayUrlVehicle', PlayUrlVehicle)

function PlayUrlPosSilent(name_, url_, volume_, pos, loop_)
    if disableMusic then return end
    SendNUIMessage({
        status = "url",
        name = name_,
        url = url_,
        x = pos.x, y = pos.y, z = pos.z,
        hasMaxTime = soundInfo[name_] and soundInfo[name_].hasMaxTime or false,
        dynamic = true,
        volume = volume_,
        loop = loop_ or false,
    })
end
