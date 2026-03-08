# 🔊 olisound

**High-performance audio library for FiveM.** Built on the **Web Audio API** with zero external dependencies, vehicle-aware occlusion, and a rich effects pipeline.

## ⚡ Features

* **Web Audio API** — native browser audio, lower latency than HTML5 Audio libraries
* **YouTube Support** — auto-detects YouTube URLs and plays via IFrame API
* **Minimal dependencies** — only the YouTube IFrame API, no jQuery or Howler.js
* **Vehicle Occlusion** — realistic muffling based on door state and window integrity
* **PlayUrlVehicle** — attach sounds to vehicles with automatic position tracking
* **Audio Effects** — fade in/out, distortion, playback rate, low-pass muffle
* **Non-blocking Fades** — gain scheduling instead of thread-blocking loops
* **3D Positional Audio** — distance-based volume with smooth falloff
* **Streamer Mode** — mute all external audio with a single command
* **Streaming Optimization** — auto-destroy/restore sounds beyond hearing range

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
exports['olisound']:setVolume(name, volume)            -- 0.0 - 1.0
exports['olisound']:setVolumeMax(name, volume)          -- max volume for 3D
exports['olisound']:setTimeStamp(name, seconds)
exports['olisound']:setSoundURL(name, url)
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

```

---

### Effects

```lua
exports['olisound']:fadeIn(name, timeMs, targetVolume)
exports['olisound']:fadeOut(name, timeMs)
exports['olisound']:setMuffled(name, enabled, frequency)     -- low-pass filter
exports['olisound']:setDistortion(name, amount)               -- 0.0 - 1.0
exports['olisound']:setPlaybackRate(name, rate)               -- 0.25 - 4.0

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
exports['olisound']:getTimeStamp(name)                -- number (seconds)
exports['olisound']:getMaxDuration(name)              -- number (seconds)
exports['olisound']:getLink(name)                     -- string (url)
exports['olisound']:getInfo(name)                     -- table
exports['olisound']:getAllAudioInfo()                  -- table (all sounds)
exports['olisound']:isPlayerInStreamerMode()           -- bool
exports['olisound']:isPlayerCloseToAnySound()         -- bool
exports['olisound']:isSoundAttachedToVehicle(name)    -- bool
exports['olisound']:getVehicleEntity(name)            -- entity handle or nil

```

---

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

| Listener Position | Doors & Windows | Audio |
| --- | --- | --- |
| Inside the same vehicle | Any state | **Full clear audio** |
| Outside the vehicle | All closed | **Muffled** (low-pass filtered) |
| Outside the vehicle | Any door open | **Clear audio** |
| Outside the vehicle | Any window broken | **Clear audio** |
| Inside a different vehicle | All closed | **Double muffled** |

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
Config.outsideVehicleMuffleFrequency = 1200 -- muffle for car sounds heard from outside

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
| `/streamermode` | Toggle streamer mode (mutes all external audio) |

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
│       └── effects.lua
└── server/
    └── exports/
        ├── play.lua
        └── manipulation.lua

```

## 🤝 Bug Reports & Contributing

Found a bug or have an idea for a new feature? Feel free to open an issue or submit a pull request on the GitHub repository. All contributions to help improve the library are highly appreciated!

## 📄 License

MIT
