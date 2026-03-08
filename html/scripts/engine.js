/**
 * olisound — Web Audio API Engine
 * FiveM NUI audio engine with YouTube support
 */

let audioCtx = null;
let ytApiReady = false;
let ytReadyQueue = [];
let instanceCounter = 0;

function getAudioContext() {
    if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    if (audioCtx.state === 'suspended') audioCtx.resume();
    return audioCtx;
}

function onYouTubeIframeAPIReady() {
    ytApiReady = true;
    ytReadyQueue.forEach(fn => fn());
    ytReadyQueue = [];
}

function extractYoutubeId(url) {
    if (!url) return '';
    let match = url.match(/[?&]v=([^&#]{11})/);
    if (match) return match[1];
    match = url.match(/youtu\.be\/([^&#?]{11})/);
    if (match) return match[1];
    match = url.match(/embed\/([^&#?]{11})/);
    if (match) return match[1];
    return '';
}

// ─── SoundInstance ───────────────────────────────────────────────────────────

class SoundInstance {
    constructor(name, url, volume, dynamic, position, loop) {
        this.name = name;
        this.url = url.replace(/<[^>]*>?/gm, '').trim();
        this.volume = Math.max(0, Math.min(1, volume));
        this.maxVolume = this.volume;
        this.dynamic = dynamic;
        this.position = position || [0, 0, 0];
        this.loop = loop || false;
        this.distance = 10;
        this.loaded = false;
        this.playing = false;
        this.paused = false;
        this.destroyed = false;
        this.hasMaxTime = false;
        this.maxDuration = 0;
        this.muffled = false;
        this.attachedToVehicle = false;
        this.vehicleGainMultiplier = 1.0;

        this.isYoutube = false;
        this.ytPlayer = null;
        this.ytReady = false;
        this.ytDivId = 'yt_' + instanceCounter++;
        this.ytPollTimer = null;

        this.ctx = getAudioContext();
        this._buildAudioGraph();
        this._fadeTimer = null;
    }

    _buildAudioGraph() {
        this.filterNode = this.ctx.createBiquadFilter();
        this.filterNode.type = 'lowpass';
        this.filterNode.frequency.value = 22050;
        this.filterNode.Q.value = 0.7;

        this.distortionNode = this.ctx.createWaveShaper();
        this.distortionNode.oversample = '4x';

        this.gainNode = this.ctx.createGain();
        this.gainNode.gain.value = this.dynamic ? 0 : this.volume;

        this.filterNode.connect(this.distortionNode);
        this.distortionNode.connect(this.gainNode);
        this.gainNode.connect(this.ctx.destination);

        this.audio = null;
        this.sourceNode = null;
    }

    // ── Lifecycle ──

    create() {
        if (this.destroyed) return;
        const ytId = extractYoutubeId(this.url);

        if (ytId) {
            this.isYoutube = true;
            this._createYoutube(ytId);
        } else {
            this.isYoutube = false;
            this._createAudio();
        }
    }

    _createAudio() {
        this.audio = new Audio();
        this.audio.crossOrigin = 'anonymous';
        this.audio.preload = 'auto';
        this.audio.loop = this.loop;

        this.audio.addEventListener('canplaythrough', () => {
            if (!this.loaded && !this.destroyed) {
                this.loaded = true;
                this._post('events', { type: 'onLoading', id: this.name });
            }
        }, { once: true });

        this.audio.addEventListener('playing', () => {
            if (this.destroyed) return;
            this.playing = true;
            this.paused = false;
            if (!this.hasMaxTime && isFinite(this.audio.duration)) {
                this.hasMaxTime = true;
                this.maxDuration = this.audio.duration;
                this._post('data_status', { type: 'maxDuration', id: this.name, time: this.maxDuration });
            }
            this._post('events', { type: 'onPlay', id: this.name });
        }, { once: true });

        this.audio.addEventListener('ended', () => {
            if (this.destroyed) return;
            if (this.loop) {
                this._post('events', { type: 'resetTimeStamp', id: this.name, time: this.maxDuration });
            } else {
                this.playing = false;
                this._post('data_status', { type: 'finished', id: this.name });
                this._post('events', { type: 'onEnd', id: this.name });
            }
        });

        this.audio.addEventListener('error', () => {});

        this.audio.src = this.url;
        this.sourceNode = this.ctx.createMediaElementSource(this.audio);
        this.sourceNode.connect(this.filterNode);
        this.audio.load();
    }

    _createYoutube(videoId) {
        const container = document.getElementById('yt-container');
        const div = document.createElement('div');
        div.id = this.ytDivId;
        div.style.cssText = 'width:0;height:0;overflow:hidden;position:absolute;';
        container.appendChild(div);

        const initPlayer = () => {
            if (this.destroyed) return;
            this.ytPlayer = new YT.Player(this.ytDivId, {
                width: '1', height: '1',
                videoId: videoId,
                host: 'https://www.youtube-nocookie.com',
                playerVars: {
                    autoplay: 0,
                    controls: 0,
                    origin: window.location.origin,
                    widget_referrer: window.location.href,
                },
                events: {
                    onReady: (e) => {
                        if (this.destroyed) return;
                        this.ytReady = true;
                        this.loaded = true;
                        e.target.unMute();
                        e.target.setVolume(0);
                        e.target.playVideo();

                        const dur = e.target.getDuration();
                        if (dur > 0) {
                            this.hasMaxTime = true;
                            this.maxDuration = dur;
                            this._post('data_status', { type: 'maxDuration', id: this.name, time: dur });
                        }

                        this._post('events', { type: 'onLoading', id: this.name });
                        this._post('events', { type: 'onPlay', id: this.name });
                        this.playing = true;
                        this._ytApplyVolume();

                        this.ytPollTimer = setInterval(() => this._ytPollState(), 500);
                    },
                    onStateChange: (e) => {
                        if (e.data === YT.PlayerState.ENDED) {
                            if (this.loop) {
                                this.ytPlayer.seekTo(0);
                                this.ytPlayer.playVideo();
                                this._post('events', { type: 'resetTimeStamp', id: this.name, time: this.maxDuration });
                            } else {
                                this.playing = false;
                                this._post('data_status', { type: 'finished', id: this.name });
                                this._post('events', { type: 'onEnd', id: this.name });
                            }
                        }
                    },
                },
            });
        };

        if (ytApiReady) initPlayer();
        else ytReadyQueue.push(initPlayer);
    }

    _ytPollState() {
        if (this.destroyed || !this.ytReady) return;
        this._ytApplyVolume();
    }

    _ytApplyVolume() {
        if (!this.ytReady || !this.ytPlayer) return;
        const vol = this.dynamic ? 0 : this.volume;
        const gain = this.gainNode.gain.value;
        this.ytPlayer.setVolume(Math.round(gain * 100));
    }

    play() {
        if (this.destroyed) return;
        if (this.isYoutube) {
            if (this.ytReady && this.ytPlayer) this.ytPlayer.playVideo();
        } else if (this.audio) {
            const p = this.audio.play();
            if (p) p.catch(() => setTimeout(() => {
                if (!this.destroyed && this.audio) this.audio.play().catch(() => {});
            }, 100));
        }
    }

    pause() {
        if (this.destroyed) return;
        if (this.isYoutube && this.ytReady && this.ytPlayer) {
            this.ytPlayer.pauseVideo();
        } else if (this.audio) {
            this.audio.pause();
        }
        this.playing = false;
        this.paused = true;
    }

    resume() {
        if (this.destroyed) return;
        if (this.isYoutube && this.ytReady && this.ytPlayer) {
            this.ytPlayer.playVideo();
        } else if (this.audio) {
            this.audio.play().catch(() => {});
        }
        this.playing = true;
        this.paused = false;
    }

    destroy() {
        this.destroyed = true;
        this.playing = false;
        if (this._fadeTimer) { clearInterval(this._fadeTimer); this._fadeTimer = null; }
        if (this.ytPollTimer) { clearInterval(this.ytPollTimer); this.ytPollTimer = null; }

        if (this.isYoutube && this.ytPlayer) {
            try {
                if (typeof this.ytPlayer.stopVideo === 'function') this.ytPlayer.stopVideo();
                if (typeof this.ytPlayer.destroy === 'function') this.ytPlayer.destroy();
            } catch (e) {}
            this.ytPlayer = null;
            this.ytReady = false;
            const el = document.getElementById(this.ytDivId);
            if (el) el.remove();
        }

        if (this.audio) { this.audio.pause(); this.audio.removeAttribute('src'); this.audio.load(); }
        try { this.sourceNode?.disconnect(); } catch (e) {}
        try { this.filterNode?.disconnect(); } catch (e) {}
        try { this.distortionNode?.disconnect(); } catch (e) {}
        try { this.gainNode?.disconnect(); } catch (e) {}
        this.audio = null;
        this.sourceNode = null;
    }

    // ── Volume ──

    setVolume(vol) {
        this.volume = Math.max(0, Math.min(1, vol));
        if (this.maxVolume < 0) this.maxVolume = this.volume;
        this._applyGain(this.volume);
    }

    setMaxVolume(vol) {
        this.maxVolume = Math.max(0, Math.min(1, vol));
    }

    updateVolumeByDistance(playerPos) {
        if (!this.dynamic || this.destroyed) return;
        const dist = this._dist(playerPos, this.position);
        if (dist >= this.distance) { this._applyGain(0); return; }
        const ratio = 1 - (dist / this.distance);
        this._applyGain(Math.max(0, this.maxVolume * ratio));
    }

    setVehicleGain(multiplier) {
        this.vehicleGainMultiplier = Math.max(0, Math.min(1, multiplier));
        if (this.isYoutube && this.ytReady && this.ytPlayer) this._ytApplyVolume();
    }

    _applyGain(vol) {
        if (this.destroyed) return;
        const finalVol = vol * this.vehicleGainMultiplier;
        try { this.gainNode.gain.setTargetAtTime(finalVol, this.ctx.currentTime, 0.03); }
        catch (e) { this.gainNode.gain.value = finalVol; }
        if (this.isYoutube && this.ytReady && this.ytPlayer) {
            this.ytPlayer.setVolume(Math.round(finalVol * 100));
        }
    }

    // ── Position / Distance ──

    setPosition(x, y, z) { this.position = [x, y, z]; }
    setDistance(dist) { this.distance = dist; }

    setDynamic(val) {
        this.dynamic = val;
        if (!val) this._applyGain(this.volume);
    }

    // ── Timestamp ──

    setTimeStamp(time) {
        if (this.isYoutube && this.ytReady && this.ytPlayer) {
            this.ytPlayer.seekTo(time, true);
        } else if (this.audio) {
            try { this.audio.currentTime = time; } catch (e) {}
        }
    }

    getTimeStamp() {
        if (this.isYoutube && this.ytReady && this.ytPlayer) return this.ytPlayer.getCurrentTime() || 0;
        return this.audio?.currentTime || 0;
    }

    getMaxDuration() {
        if (this.isYoutube && this.ytReady && this.ytPlayer) return this.ytPlayer.getDuration() || this.maxDuration;
        return (this.audio && isFinite(this.audio.duration)) ? this.audio.duration : this.maxDuration;
    }

    // ── Loop / URL / Repeat ──

    setLoop(val) {
        this.loop = val;
        if (!this.isYoutube && this.audio) this.audio.loop = val;
    }

    setUrl(url) {
        const wasPlaying = this.playing;
        this.url = url.replace(/<[^>]*>?/gm, '').trim();
        this.loaded = false;
        this.hasMaxTime = false;

        if (this.isYoutube) {
            this._destroyYoutube();
        }

        const ytId = extractYoutubeId(this.url);
        if (ytId) {
            this.isYoutube = true;
            this._createYoutube(ytId);
        } else {
            this.isYoutube = false;
            if (this.audio) {
                this.audio.pause();
                this.audio.src = this.url;
                this.audio.load();
                if (wasPlaying) this.play();
            }
        }
    }

    _destroyYoutube() {
        if (this.ytPollTimer) { clearInterval(this.ytPollTimer); this.ytPollTimer = null; }
        if (this.ytPlayer) {
            try {
                if (typeof this.ytPlayer.stopVideo === 'function') this.ytPlayer.stopVideo();
                if (typeof this.ytPlayer.destroy === 'function') this.ytPlayer.destroy();
            } catch (e) {}
            this.ytPlayer = null;
            this.ytReady = false;
        }
        const el = document.getElementById(this.ytDivId);
        if (el) el.remove();
    }

    repeat() {
        if (this.isYoutube && this.ytReady && this.ytPlayer) {
            this.ytPlayer.seekTo(0);
            this.ytPlayer.playVideo();
        } else if (this.audio) {
            this.audio.currentTime = 0;
            this.play();
        }
    }

    // ── Effects: Fade ──

    fadeIn(durationMs, targetVolume) {
        if (this.destroyed) return;
        if (this._fadeTimer) clearInterval(this._fadeTimer);
        const target = Math.max(0, Math.min(1, targetVolume));
        const steps = Math.max(1, Math.floor(durationMs / 50));
        const inc = target / steps;
        let step = 0;
        this._applyGain(0);
        if (this.dynamic) this.maxVolume = 0;

        this._fadeTimer = setInterval(() => {
            step++;
            const v = Math.min(target, inc * step);
            if (this.dynamic) { this.maxVolume = v; } else { this._applyGain(v); this.volume = v; }
            if (step >= steps) {
                clearInterval(this._fadeTimer); this._fadeTimer = null;
                if (this.dynamic) this.maxVolume = target; else { this._applyGain(target); this.volume = target; }
            }
        }, 50);
    }

    fadeOut(durationMs) {
        if (this.destroyed) return;
        if (this._fadeTimer) clearInterval(this._fadeTimer);
        const start = this.dynamic ? this.maxVolume : this.volume;
        const steps = Math.max(1, Math.floor(durationMs / 50));
        const dec = start / steps;
        let step = 0;

        this._fadeTimer = setInterval(() => {
            step++;
            const v = Math.max(0, start - dec * step);
            if (this.dynamic) { this.maxVolume = v; } else { this._applyGain(v); this.volume = v; }
            if (step >= steps) {
                clearInterval(this._fadeTimer); this._fadeTimer = null;
                if (this.dynamic) this.maxVolume = 0; else { this._applyGain(0); this.volume = 0; }
            }
        }, 50);
    }

    // ── Effects: Muffle ──

    setMuffled(enabled, frequency) {
        this.muffled = enabled;
        const freq = enabled ? (frequency || 800) : 22050;
        const q = enabled ? 2.5 : 0.7;
        try {
            this.filterNode.frequency.setTargetAtTime(freq, this.ctx.currentTime, 0.15);
            this.filterNode.Q.setTargetAtTime(q, this.ctx.currentTime, 0.15);
        } catch (e) {
            this.filterNode.frequency.value = freq;
            this.filterNode.Q.value = q;
        }
    }

    // ── Effects: Distortion ──

    setDistortion(amount) {
        if (amount <= 0) { this.distortionNode.curve = null; return; }
        const samples = 44100;
        const curve = new Float32Array(samples);
        const k = Math.max(0, Math.min(1, amount)) * 100;
        for (let i = 0; i < samples; i++) {
            const x = (i * 2) / samples - 1;
            curve[i] = ((3 + k) * x * 20 * (Math.PI / 180)) / (Math.PI + k * Math.abs(x));
        }
        this.distortionNode.curve = curve;
    }

    // ── Effects: Playback Rate ──

    setPlaybackRate(rate) {
        if (!this.isYoutube && this.audio) {
            this.audio.playbackRate = Math.max(0.25, Math.min(4, rate));
        } else if (this.isYoutube && this.ytReady && this.ytPlayer) {
            this.ytPlayer.setPlaybackRate(Math.max(0.25, Math.min(2, rate)));
        }
    }

    // ── Mute/Unmute ──

    mute() { this._applyGain(0); }
    unmute() { if (!this.dynamic) this._applyGain(this.volume); }

    // ── Helpers ──

    _dist(a, b) {
        const dx = a[0] - b[0], dy = a[1] - b[1], dz = a[2] - b[2];
        return Math.sqrt(dx * dx + dy * dy + dz * dz);
    }

    _post(endpoint, data) {
        fetch(`https://olisound/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        }).catch(() => {});
    }
}


// ─── SoundManager ────────────────────────────────────────────────────────────

const soundManager = {
    sounds: {},
    playerPos: [-900000, -900000, -900000],
    isAllMuted: false,
    volumeTimer: null,
    refreshTime: 200,

    init(refreshTime) {
        this.refreshTime = refreshTime || 200;
        if (this.volumeTimer) clearInterval(this.volumeTimer);
        this.volumeTimer = setInterval(() => this.updateDynamicVolumes(), this.refreshTime);
    },

    get(name) { return this.sounds[name] || null; },

    createAndPlay(name, url, volume, dynamic, position, loop) {
        if (this.sounds[name]) { this.sounds[name].destroy(); delete this.sounds[name]; }
        const s = new SoundInstance(name, url, volume, dynamic, position, loop);
        this.sounds[name] = s;
        s.create();
        s.play();
        return s;
    },

    remove(name) {
        const s = this.sounds[name];
        if (s) { s.destroy(); delete this.sounds[name]; }
    },

    setPlayerPosition(x, y, z) { this.playerPos = [x, y, z]; },

    updateDynamicVolumes() {
        if (this.isAllMuted) return;
        for (const n in this.sounds) {
            const s = this.sounds[n];
            if (s && s.dynamic && !s.destroyed && s.loaded) s.updateVolumeByDistance(this.playerPos);
        }
    },

    muteAll() {
        this.isAllMuted = true;
        for (const n in this.sounds) { const s = this.sounds[n]; if (s?.dynamic) s.mute(); }
    },

    unmuteAll() {
        this.isAllMuted = false;
        this.updateDynamicVolumes();
    },

    setMuffledAll(enabled, frequency) {
        for (const n in this.sounds) {
            const s = this.sounds[n];
            if (s && s.dynamic && !s.destroyed) s.setMuffled(enabled, frequency);
        }
    },

    setMuffledVehicleSounds(enabled, frequency) {
        for (const n in this.sounds) {
            const s = this.sounds[n];
            if (s && s.attachedToVehicle && !s.destroyed) s.setMuffled(enabled, frequency);
        }
    },
};


// ─── NUI Listener ────────────────────────────────────────────────────────────

fetch('https://olisound/init', { method: 'POST' }).catch(() => {});

window.addEventListener('message', function (event) {
    const d = event.data;
    if (!d?.status) return;
    let s;

    switch (d.status) {
        case 'init':
            soundManager.init(d.time);
            break;

        case 'position':
            soundManager.setPlayerPosition(d.x, d.y, d.z);
            break;

        case 'url':
            soundManager.createAndPlay(d.name, d.url, d.volume, d.dynamic, [d.x, d.y, d.z], d.loop);
            break;

        case 'volume':
            s = soundManager.get(d.name);
            if (s) { s.setVolume(d.volume); s.setMaxVolume(d.volume); }
            break;

        case 'max_volume':
            s = soundManager.get(d.name);
            if (s) s.setMaxVolume(d.volume);
            break;

        case 'distance':
            s = soundManager.get(d.name);
            if (s) s.setDistance(d.distance);
            break;

        case 'soundPosition':
            s = soundManager.get(d.name);
            if (s) s.setPosition(d.x, d.y, d.z);
            break;

        case 'pause':
            s = soundManager.get(d.name);
            if (s) s.pause();
            break;

        case 'resume':
            s = soundManager.get(d.name);
            if (s) s.resume();
            break;

        case 'delete':
            soundManager.remove(d.name);
            break;

        case 'timestamp':
            s = soundManager.get(d.name);
            if (s) s.setTimeStamp(d.timestamp);
            break;

        case 'loop':
            s = soundManager.get(d.name);
            if (s) s.setLoop(d.loop);
            break;

        case 'repeat':
            s = soundManager.get(d.name);
            if (s) s.repeat();
            break;

        case 'changeurl':
            s = soundManager.get(d.name);
            if (s) s.setUrl(d.url);
            break;

        case 'changedynamic':
            s = soundManager.get(d.name);
            if (s) { s.setDynamic(d.bool); if (!d.bool) s.unmute(); }
            break;

        case 'fadeIn':
            s = soundManager.get(d.name);
            if (s) s.fadeIn(d.duration, d.targetVolume);
            break;

        case 'fadeOut':
            s = soundManager.get(d.name);
            if (s) s.fadeOut(d.duration);
            break;

        case 'muffle':
            if (d.name) {
                s = soundManager.get(d.name);
                if (s) s.setMuffled(d.enabled, d.frequency);
            } else {
                soundManager.setMuffledAll(d.enabled, d.frequency);
            }
            break;

        case 'muffleVehicle':
            soundManager.setMuffledVehicleSounds(d.enabled, d.frequency);
            break;

        case 'attachVehicle':
            s = soundManager.get(d.name);
            if (s) s.attachedToVehicle = d.attached;
            break;

        case 'vehicleGain':
            s = soundManager.get(d.name);
            if (s) { s.setVehicleGain(d.gain); s.updateVolumeByDistance(soundManager.playerPos); }
            break;

        case 'distortion':
            s = soundManager.get(d.name);
            if (s) s.setDistortion(d.amount);
            break;

        case 'playbackRate':
            s = soundManager.get(d.name);
            if (s) s.setPlaybackRate(d.rate);
            break;

        case 'muteAll':
            soundManager.muteAll();
            break;

        case 'unmuteAll':
            soundManager.unmuteAll();
            break;
    }
});
