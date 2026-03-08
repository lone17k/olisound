function onPlayStart(name, delegate)
    if not globalOptionsCache[name] then globalOptionsCache[name] = {} end
    globalOptionsCache[name].onPlayStart = delegate
end
exports('onPlayStart', onPlayStart)

function onPlayEnd(name, delegate)
    if not globalOptionsCache[name] then globalOptionsCache[name] = {} end
    globalOptionsCache[name].onPlayEnd = delegate
end
exports('onPlayEnd', onPlayEnd)

function onLoading(name, delegate)
    if not globalOptionsCache[name] then globalOptionsCache[name] = {} end
    globalOptionsCache[name].onLoading = delegate
end
exports('onLoading', onLoading)

function onPlayPause(name, delegate)
    if not globalOptionsCache[name] then globalOptionsCache[name] = {} end
    globalOptionsCache[name].onPlayPause = delegate
end
exports('onPlayPause', onPlayPause)

function onPlayResume(name, delegate)
    if not globalOptionsCache[name] then globalOptionsCache[name] = {} end
    globalOptionsCache[name].onPlayResume = delegate
end
exports('onPlayResume', onPlayResume)

function onPlayStartSilent(name, delegate)
    if not globalOptionsCache[name] then globalOptionsCache[name] = {} end
    globalOptionsCache[name].onPlayStartSilent = delegate
end
