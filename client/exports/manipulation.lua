function Distance(name_, distance_)
    if not soundExists(name_) then return end
    SendNUIMessage({ status = "distance", name = name_, distance = distance_ })
    soundInfo[name_].distance = distance_
end
exports('Distance', Distance)

function Position(name_, pos)
    if not soundExists(name_) then return end
    SendNUIMessage({ status = "soundPosition", name = name_, x = pos.x, y = pos.y, z = pos.z })
    soundInfo[name_].position = pos
    soundInfo[name_].id = name_
end
exports('Position', Position)

function Destroy(name_)
    SendNUIMessage({ status = "delete", name = name_ })
    if globalOptionsCache[name_] and globalOptionsCache[name_].onPlayEnd then
        globalOptionsCache[name_].onPlayEnd(getInfo(name_))
    end
    soundInfo[name_] = nil
    globalOptionsCache[name_] = nil
end
exports('Destroy', Destroy)

function DestroySilent(name_)
    SendNUIMessage({ status = "delete", name = name_ })
end

function Resume(name_)
    if not soundExists(name_) then return end
    SendNUIMessage({ status = "resume", name = name_ })
    soundInfo[name_].playing = true
    soundInfo[name_].paused = false
    if globalOptionsCache[name_] and globalOptionsCache[name_].onPlayResume then
        globalOptionsCache[name_].onPlayResume(getInfo(name_))
    end
end
exports('Resume', Resume)

function Pause(name_)
    if not soundExists(name_) then return end
    SendNUIMessage({ status = "pause", name = name_ })
    soundInfo[name_].playing = false
    soundInfo[name_].paused = true
    if globalOptionsCache[name_] and globalOptionsCache[name_].onPlayPause then
        globalOptionsCache[name_].onPlayPause(getInfo(name_))
    end
end
exports('Pause', Pause)

function setVolume(name_, vol)
    if not soundExists(name_) then return end
    SendNUIMessage({ status = "volume", volume = vol, name = name_ })
    soundInfo[name_].volume = vol
end
exports('setVolume', setVolume)

function setVolumeMax(name_, vol)
    if not soundExists(name_) then return end
    SendNUIMessage({ status = "max_volume", volume = vol, name = name_ })
    soundInfo[name_].volume = vol
end
exports('setVolumeMax', setVolumeMax)

function setTimeStamp(name_, timestamp)
    if not soundExists(name_) then return end
    soundInfo[name_].timeStamp = timestamp
    SendNUIMessage({ name = name_, status = "timestamp", timestamp = timestamp })
end
exports('setTimeStamp', setTimeStamp)

function destroyOnFinish(id, bool)
    if not soundExists(id) then return end
    soundInfo[id].destroyOnFinish = bool
end
exports('destroyOnFinish', destroyOnFinish)

function setSoundLoop(name_, value)
    if not soundExists(name_) then return end
    SendNUIMessage({ status = "loop", name = name_, loop = value })
    soundInfo[name_].loop = value
end
exports('setSoundLoop', setSoundLoop)

function repeatSound(name_)
    if not soundExists(name_) then return end
    SendNUIMessage({ status = "repeat", name = name_ })
end
exports('repeatSound', repeatSound)

function setSoundDynamic(name_, bool)
    if not soundExists(name_) then return end
    soundInfo[name_].isDynamic = bool
    SendNUIMessage({ status = "changedynamic", name = name_, bool = bool })
end
exports('setSoundDynamic', setSoundDynamic)

function setSoundURL(name_, url)
    if not soundExists(name_) then return end
    soundInfo[name_].url = url
    SendNUIMessage({ status = "changeurl", hasMaxTime = false, name = name_, url = url })
end
exports('setSoundURL', setSoundURL)

function attachSoundToVehicle(name_, attached)
    if not soundExists(name_) then return end
    soundInfo[name_].attachedToVehicle = attached
    SendNUIMessage({ status = "attachVehicle", name = name_, attached = attached })
end
exports('attachSoundToVehicle', attachSoundToVehicle)
