function fadeIn(name, time, volume_)
    if not soundExists(name) then return end
    if isDynamic(name) then
        setVolumeMax(name, 0)
        setVolume(name, 0)
    else
        setVolume(name, 0)
    end
    SendNUIMessage({ status = "fadeIn", name = name, duration = time, targetVolume = volume_ })
    SetTimeout(time + 100, function()
        if soundExists(name) then
            if isDynamic(name) then setVolumeMax(name, volume_) end
            soundInfo[name].volume = volume_
        end
    end)
end
exports('fadeIn', fadeIn)

function fadeOut(name, time)
    if not soundExists(name) then return end
    SendNUIMessage({ status = "fadeOut", name = name, duration = time })
    SetTimeout(time + 100, function()
        if soundExists(name) then
            if isDynamic(name) then setVolumeMax(name, 0) end
            soundInfo[name].volume = 0
        end
    end)
end
exports('fadeOut', fadeOut)

function setMuffled(name, enabled, frequency)
    if not soundExists(name) then return end
    SendNUIMessage({
        status = "muffle",
        name = name,
        enabled = enabled,
        frequency = frequency or Config.occlusionFilterFrequency,
    })
end
exports('setMuffled', setMuffled)

function setDistortion(name, amount)
    if not soundExists(name) then return end
    SendNUIMessage({ status = "distortion", name = name, amount = amount })
end
exports('setDistortion', setDistortion)

function setPlaybackRate(name, rate)
    if not soundExists(name) then return end
    SendNUIMessage({ status = "playbackRate", name = name, rate = rate })
end
exports('setPlaybackRate', setPlaybackRate)
