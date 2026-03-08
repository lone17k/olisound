function Position(source, name_, pos)
    TriggerClientEvent("olisound:stateSound", source, "position", { soundId = name_, position = pos })
end
exports('Position', Position)

function Distance(source, name_, distance_)
    TriggerClientEvent("olisound:stateSound", source, "distance", { soundId = name_, distance = distance_ })
end
exports('Distance', Distance)

function Destroy(source, name_)
    TriggerClientEvent("olisound:stateSound", source, "destroy", { soundId = name_ })
end
exports('Destroy', Destroy)

function Pause(source, name_)
    TriggerClientEvent("olisound:stateSound", source, "pause", { soundId = name_ })
end
exports('Pause', Pause)

function Resume(source, name_)
    TriggerClientEvent("olisound:stateSound", source, "resume", { soundId = name_ })
end
exports('Resume', Resume)

function setVolume(source, name_, vol)
    TriggerClientEvent("olisound:stateSound", source, "volume", { soundId = name_, volume = vol })
end
exports('setVolume', setVolume)

function setVolumeMax(source, name_, vol)
    TriggerClientEvent("olisound:stateSound", source, "volume", { soundId = name_, volume = vol })
end
exports('setVolumeMax', setVolumeMax)

function setTimeStamp(source, name_, time_)
    TriggerClientEvent("olisound:stateSound", source, "timestamp", { soundId = name_, time = time_ })
end
exports('setTimeStamp', setTimeStamp)

function destroyOnFinish(source, id, bool)
    TriggerClientEvent("olisound:stateSound", source, "destroyOnFinish", { soundId = id, value = bool })
end
exports('destroyOnFinish', destroyOnFinish)
