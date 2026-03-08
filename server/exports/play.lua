function PlayUrl(source, name_, url_, volume_, loop_)
    TriggerClientEvent("olisound:stateSound", source, "play", {
        soundId = name_, url = url_, volume = volume_, loop = loop_,
    })
end
exports('PlayUrl', PlayUrl)

function PlayUrlPos(source, name_, url_, volume_, pos, loop_)
    TriggerClientEvent("olisound:stateSound", source, "playpos", {
        soundId = name_, position = pos, url = url_, volume = volume_, loop = loop_,
    })
end
exports('PlayUrlPos', PlayUrlPos)
