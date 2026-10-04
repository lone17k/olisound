-- ── Audio analysis (level / bass / 5 bands / beat / BPM) ─────────────────────
-- Opt-in per sound name. Once enabled it stays enabled for that name (also across
-- re-plays) until disabled. Taps the raw source before muffle/panning/volume, so
-- values describe the music itself, whatever the listener's distance.
-- Works for direct audio URLs AND YouTube (the YT <video> is hooked into Web Audio;
-- if FiveM ever blocks that, getAnalysis(name).supported becomes false and the
-- level getters return nil so callers can fall back to fixed BPM / TAP).

local analysisData = {}   -- name -> latest analysis snapshot
local beatHandlers = {}   -- name -> { fn, ... }
local wanted = {}

local STALE_MS = 1000

local function fresh(name_)
    local a = analysisData[name_]
    if a and a.supported and GetGameTimer() - (a.updatedAt or 0) < STALE_MS then return a end
end

function enableAnalysis(name_, enabled)
    if enabled == nil then enabled = true end
    wanted[name_] = enabled and true or nil
    if not enabled then analysisData[name_] = nil end
    SendNUIMessage({ status = "analysis", name = name_, enabled = enabled and true or false })
    return true
end
exports('enableAnalysis', enableAnalysis)

function disableAnalysis(name_) return enableAnalysis(name_, false) end
exports('disableAnalysis', disableAnalysis)

-- { supported, level, bass, bands, bpm, confidence, beatCount, lastBeat, updatedAt } or nil
function getAnalysis(name_)
    local a = analysisData[name_]
    if not a then return nil end
    return {
        supported  = a.supported,
        level      = a.level or 0.0,
        bass       = a.bass or 0.0,
        bands      = a.bands,
        bpm        = a.bpm or 0,
        confidence = a.confidence or 0.0,
        beatCount  = a.beats or 0,
        lastBeat   = a.lastBeat or 0,
        updatedAt  = a.updatedAt or 0,
    }
end
exports('getAnalysis', getAnalysis)

-- level, bass (0..1). nil when no fresh data (not playing / unsupported).
function getAudioLevel(name_)
    local a = fresh(name_)
    if a then return a.level or 0.0, a.bass or 0.0 end
    return nil
end
exports('getAudioLevel', getAudioLevel)

-- { sub, bass, lowmid, high, air, level } each 0..1 (auto-gained per band) or nil
function getAudioBands(name_)
    local a = fresh(name_)
    if not a or type(a.bands) ~= 'table' then return nil end
    local b = a.bands
    return { sub = b[1] or 0, bass = b[2] or 0, lowmid = b[3] or 0, high = b[4] or 0, air = b[5] or 0, level = a.level or 0 }
end
exports('getAudioBands', getAudioBands)

-- bpm, confidence. bpm 0 until ~4-6 s of music was heard.
function getBPM(name_)
    local a = analysisData[name_]
    if not a or not a.supported then return 0, 0.0 end
    return a.bpm or 0, a.confidence or 0.0
end
exports('getBPM', getBPM)

-- delegate(info) on every detected beat:
-- info = { name, bpm, confidence, strength, level, bass, beatCount }
function onBeat(name_, delegate)
    beatHandlers[name_] = beatHandlers[name_] or {}
    table.insert(beatHandlers[name_], delegate)
end
exports('onBeat', onBeat)

function clearBeatHandlers(name_) beatHandlers[name_] = nil end
exports('clearBeatHandlers', clearBeatHandlers)

RegisterNUICallback("analysis", function(data, cb)
    if cb then cb('ok') end
    local name = data and data.id
    if type(name) ~= 'string' or not wanted[name] then return end

    local a = analysisData[name] or {}
    a.supported = data.supported ~= false
    a.updatedAt = GetGameTimer()
    if a.supported then
        if data.level ~= nil then a.level = tonumber(data.level) or 0.0 end
        if data.bass ~= nil then a.bass = tonumber(data.bass) or 0.0 end
        if type(data.bands) == 'table' then a.bands = data.bands end
        a.bpm        = tonumber(data.bpm) or a.bpm or 0
        a.confidence = tonumber(data.confidence) or a.confidence or 0.0
        a.beats      = tonumber(data.beats) or a.beats or 0
    end
    analysisData[name] = a

    if data.type == 'beat' and a.supported then
        a.lastBeat = a.updatedAt
        local info = {
            name = name, bpm = a.bpm, confidence = a.confidence,
            strength = tonumber(data.strength) or 0.5,
            level = a.level or 0.0, bass = tonumber(data.bass) or a.bass or 0.0, beatCount = a.beats,
        }
        for _, fn in ipairs(beatHandlers[name] or {}) do
            local ok, err = pcall(fn, info)
            if not ok then print(("^1[olisound] onBeat handler error (%s): %s^7"):format(name, tostring(err))) end
        end
        TriggerEvent("olisound:beat", name, info)
    end
end)
