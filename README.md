# 🔊 olisound

**High-performance audio library for FiveM.** Built on the **Web Audio API** with zero external dependencies, vehicle-aware occlusion, and a rich effects pipeline.

## ⚡ Features

* **Web Audio API** — native browser audio, lower latency than HTML5 Audio libraries
* **YouTube Support** — auto-detects YouTube URLs and plays via IFrame API
* **Minimal dependencies** — only the YouTube IFrame API, no jQuery or Howler.js
* **Vehicle Occlusion** — dynamic muffling based on real-time door open/close states and broken window integrity
* **Object Occlusion** — raycast-based line-of-sight occlusion for entities (props, boomboxes) with volume attenuation
* **Entity Cleanup** — auto-destroys sounds when their attached vehicle or entity despawns
* **PlayUrlVehicle** — attach sounds to vehicles with automatic position tracking
* **Audio Effects** — fade in/out, distortion, playback rate, low-pass muffle
* **Non-blocking Fades** — gain scheduling instead of thread-blocking loops
* **3D Positional Audio** — distance-based volume with smooth falloff
* **Streamer Mode** — mute all external audio with a single command
* **Audio Analysis** — opt-in level, bass, 5 frequency bands, beat detection and BPM per sound (YouTube too)
* **Streaming Optimization** — auto-destroy/restore sounds beyond hearing range
* **Automatic Update Checker** — alerts you in the server console when a new version is available

## 📦 Installation

1. Place the `olisound` folder in your server's `resources` directory
2. Add `ensure olisound` to your `server.cfg`

## 🔄 xsound Compatibility

Since `olisound` features similar functionality to `xsound`, it can be used as a lightweight replacement for scripts that depend on it. To make `olisound` act as `xsound`, simply add the following line anywhere in your `olisound` `fxmanifest.lua`:

```lua
provides { 'xsound' }

```

## 📖 API Reference

### Playing Sound

#### Client

```lua
-- 2D sound (heard everywhere)
exports['olisound']:PlayUrl(name, url, volume, loop, options)

-- 3D positional sound
exports['olisound']:PlayUrlPos(name, url, volume, vector3, loop, options)

-- Vehicle sound (auto-follows vehicle, muffled when heard from outside)
exports['olisound']:PlayUrlVehicle(name, url, volume, vehicleEntity, loop, options)

-- Entity sound (auto-follows any ped, object, or prop entity)
exports['olisound']:PlayUrlEntity(name, url, volume, entity, loop, options)

```

All play functions accept direct audio URLs **and** YouTube URLs:

```lua
exports['olisound']:PlayUrl('music', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', 0.5, true)
exports['olisound']:PlayUrl('sfx', 'https://example.com/sound.mp3', 1.0)

```

**Options table:**

```lua
{
    onPlayStart = function(info) end,
    onPlayEnd = function(info) end,
    onLoading = function(info) end,
    onPlayPause = function(info) end,
    onPlayResume = function(info) end,
    onError = function(info) end,
    onTimestamp = function(time) end,
}

```

#### Server

```lua
-- source = player id, -1 = all players
exports['olisound']:PlayUrl(source, name, url, volume, loop)
exports['olisound']:PlayUrlPos(source, name, url, volume, vector3, loop)

```

---

### Sound Manipulation

#### Client

```lua
exports['olisound']:Position(name, vector3)
exports['olisound']:Distance(name, distance)
exports['olisound']:Destroy(name)
exports['olisound']:Pause(name)
exports['olisound']:Resume(name)
exports['olisound']:DestroyAll()
exports['olisound']:PauseAll()
exports['olisound']:ResumeAll()
exports['olisound']:setVolume(name, volume)            -- 0.0 - 1.0
exports['olisound']:setMasterVolume(volume)             -- 0.0 - 1.0 (global volume)
exports['olisound']:setVolumeMax(name, volume)          -- max volume for 3D
exports['olisound']:setTimeStamp(name, seconds)
exports['olisound']:setSoundURL(name, url)
exports['olisound']:crossfadeTo(name, newUrl, timeMs)
exports['olisound']:repeatSound(name)
exports['olisound']:destroyOnFinish(name, bool)
exports['olisound']:setSoundLoop(name, bool)
exports['olisound']:setSoundDynamic(name, bool)
exports['olisound']:attachSoundToVehicle(name, bool)

```

#### Server

```lua
exports['olisound']:Position(source, name, vector3)
exports['olisound']:Distance(source, name, distance)
exports['olisound']:Destroy(source, name)
exports['olisound']:Pause(source, name)
exports['olisound']:Resume(source, name)
exports['olisound']:setVolume(source, name, volume)
exports['olisound']:setVolumeMax(source, name, volume)
exports['olisound']:setTimeStamp(source, name, seconds)
exports['olisound']:destroyOnFinish(source, name, bool)
exports['olisound']:setSoundLoop(source, name, bool)
exports['olisound']:repeatSound(source, name)

```

---

### Effects

```lua
exports['olisound']:fadeIn(name, timeMs, targetVolume)
exports['olisound']:fadeOut(name, timeMs)
exports['olisound']:setMuffled(name, enabled, frequency)     -- low-pass filter
exports['olisound']:setDistortion(name, amount)               -- 0.0 - 1.0
exports['olisound']:setPlaybackRate(name, rate)               -- 0.25 - 4.0
exports['olisound']:setReverb(name, amount)                   -- 0.0 - 1.0 (wet/dry mix)

```

---

### Getting Info

```lua
exports['olisound']:soundExists(name)                -- bool
exports['olisound']:isPlaying(name)                   -- bool
exports['olisound']:isPaused(name)                    -- bool
exports['olisound']:isLooped(name)                    -- bool
exports['olisound']:isDynamic(name)                   -- bool
exports['olisound']:getDistance(name)                  -- number
exports['olisound']:getVolume(name)                   -- number (0.0 - 1.0)
exports['olisound']:getPosition(name)                 -- vector3 or nil
exports['olisound']:getTimeStamp(name)                -- number (seconds, cached)
exports['olisound']:getLiveTimestamp(name)            -- triggers onTimestamp callback with live JS time
exports['olisound']:getMaxDuration(name)              -- number (seconds)
exports['olisound']:getLink(name)                     -- string (url)
exports['olisound']:getInfo(name)                     -- table
exports['olisound']:getAllAudioInfo()                  -- table (all sounds)
exports['olisound']:isPlayerInStreamerMode()           -- bool
exports['olisound']:isPlayerCloseToAnySound()         -- bool
exports['olisound']:isSoundAttachedToVehicle(name)    -- bool
exports['olisound']:getVehicleEntity(name)            -- entity handle or nil
exports['olisound']:getEntity(name)                   -- attached entity handle (ped/object/vehicle)

```

---

### Audio Analysis (level / bass / bands / beat / BPM)

Opt-in per sound. Taps the raw source before muffle, panning and volume, so the
values describe the music itself, whatever the listener's distance. Works for direct
audio URLs (mp3/ogg/radio streams) **and YouTube**: the `<video>` inside the YouTube
iframe is routed into Web Audio (FiveM's CEF allows reading the iframe DOM). As a
bonus, YouTube then gets the same low-pass/muffle, reverb and 3D panning as direct URLs.
If the iframe DOM is ever unreachable, YouTube falls back to plain `setVolume()`,
`getAnalysis(name).supported` is `false` and the level getters return `nil`.

```lua
exports['olisound']:enableAnalysis(name)            -- stays on for this name (re-plays too)
exports['olisound']:disableAnalysis(name)

local level, bass = exports['olisound']:getAudioLevel(name)  -- 0..1 each, nil = no data
local bands = exports['olisound']:getAudioBands(name)
-- { sub, bass, lowmid, high, air, level } each 0..1 (auto-gained per band), nil = no data
local bpm, confidence = exports['olisound']:getBPM(name)     -- bpm 0 until ~4-6 s of music
-- BPM is reported in the 90–180 range (slower/faster material at half/double tempo);
-- tempo changes inside a continuous mix are followed in ~4–5 s.
local a = exports['olisound']:getAnalysis(name)
-- { supported, level, bass, bands, bpm, confidence, beatCount, lastBeat (GetGameTimer), updatedAt }

exports['olisound']:onBeat(name, function(info)
    -- info = { name, bpm, confidence, strength, level, bass, beatCount }
end)

-- or, without exports:
AddEventHandler('olisound:beat', function(name, info) end)
```

Cost: one 2048-point FFT every 20 ms per analysed sound in the NUI; updates reach Lua
at 10 Hz plus one message per detected beat.

### Events

```lua
exports['olisound']:onPlayStart(name, function(info) end)
exports['olisound']:onPlayEnd(name, function(info) end)
exports['olisound']:onLoading(name, function(info) end)
exports['olisound']:onPlayPause(name, function(info) end)
exports['olisound']:onPlayResume(name, function(info) end)

```

---

## 🚗 Vehicle Sound System

`PlayUrlVehicle` creates a sound that is bound to a vehicle entity. The sound automatically follows the vehicle's position and the occlusion system handles muffling based on the vehicle's physical state.

### How it works

### How it works

| Listener Position | Doors & Windows | Audio | Directional Panning |
| --- | --- | --- | --- |
| Inside the same vehicle | Any state | **Clear (100% volume)** | Disabled (Centered Stereo) |
| Outside the vehicle | All closed & intact | **Muffled (50% volume)** | Enabled (True 3D Audio) |
| Outside the vehicle | Door open or window broken | **Clear (100% volume)** | Enabled (True 3D Audio) |
| Inside a different vehicle | Closed/Intact (Target Veh) | **Double muffled (40% volume)**| Enabled (True 3D Audio) |
| Inside a different vehicle | Open/Broken (Target Veh) | **Clear (100% volume)** | Enabled (True 3D Audio) |

> Note: Directional panning is disabled when inside the vehicle to prevent intense left-right panning while driving and moving the camera. Sounds automatically unmuffle if a door opens or a window is shattered. Sounds are also auto-deleted if the vehicle or entity despawns.

### Usage

```lua
local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

-- Play a car radio
exports['olisound']:PlayUrlVehicle('car_radio', 'https://example.com/song.mp3', 0.8, vehicle, true)

-- Set hearing distance
exports['olisound']:Distance('car_radio', 25)

```

### Configuration

```lua
Config.vehicleOcclusionEnabled = true
Config.occlusionFilterFrequency = 800       -- muffle for sounds heard from inside car
Config.outsideVehicleMuffleFrequency = 600  -- muffle for car sounds heard from outside

Config.objectOcclusionEnabled = true        -- line-of-sight occlusion for props/entities
Config.objectOcclusionFrequency = 800

-- Volume Modifiers (1.0 = 100%, 0.5 = 50%)
Config.insideVehicleVolume = 1.0     -- Volume when you are inside the vehicle playing the music
Config.otherVehicleVolume = 0.4      -- Volume of other vehicles' music when you are also inside a vehicle
Config.outsideVehicleVolume = 0.5    -- Volume of vehicle music when you are on foot outside

```

---

## 🎛️ Effects Examples

```lua
-- Fade in over 3 seconds
exports['olisound']:PlayUrl('ambience', url, 0.0, true)
exports['olisound']:fadeIn('ambience', 3000, 0.6)

-- Fade out over 2 seconds
exports['olisound']:fadeOut('ambience', 2000)

-- Distortion (radio static)
exports['olisound']:setDistortion('radio', 0.3)

-- Slow-mo effect
exports['olisound']:setPlaybackRate('music', 0.5)

-- Speed up
exports['olisound']:setPlaybackRate('music', 2.0)

-- Manual muffle
exports['olisound']:setMuffled('sound', true, 600)

```

---

## 🎮 Commands

| Command | Description |
| --- | --- |
| `/[streamermode]` | Toggle streamer mode (mutes all external audio). Configurable in `config.lua` |
| `/debugocclusion` | Spawns a boombox and draws real-time line-of-sight occlusion raycasts. |

*Note: If `xsound` streamer mode is activated via export or event, `olisound` will automatically sync and mute its audio as well.*

---

## 📁 Structure

```
olisound/
├── fxmanifest.lua
├── config.lua
├── html/
│   ├── index.html
│   └── scripts/engine.js
├── client/
│   ├── main.lua
│   ├── events.lua
│   ├── vehicle.lua
│   └── exports/
│       ├── info.lua
│       ├── play.lua
│       ├── manipulation.lua
│       ├── events.lua
│       ├── effects.lua
│       └── analysis.lua
└── server/
    └── exports/
        ├── play.lua
        └── manipulation.lua

```

## 🤝 Bug Reports & Contributing

Found a bug or have an idea for a new feature? Feel free to open an issue or submit a pull request on the GitHub repository. All contributions to help improve the library are highly appreciated!

## 📄 License

MIT
