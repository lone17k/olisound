/**
 * olisound — music analysis (levels, 5 bands, onsets, BPM)
 *
 * Taps each analysed SoundInstance at its inputNode (pre filter / volume /
 * distance), so lights react identically for every player regardless of where
 * they stand. Works for direct URLs and for YouTube once the <video> element
 * inside the YT iframe is hooked into Web Audio (see SoundInstance._ytTryHook).
 */

const OliAnalysis = (() => {
    const FRAME_MS = 20;           // analysis tick
    const REPORT_MS = 100;         // level report to Lua (10 Hz)
    const ENV_RATE = 100;          // onset envelope resample rate (Hz)
    const ENV_SECONDS = 6;         // tempo window (tempo changes followed in ~4-5 s)
    const BPM_MIN = 90, BPM_MAX = 180;   // one octave: slower/faster material reads as half/double
    const BANDS = [[20, 60], [60, 250], [250, 2000], [2000, 6000], [6000, 16000]];

    const active = new Map();      // name -> state
    let timer = null;

    function bin(an, hz) {
        return Math.max(0, Math.min(an.frequencyBinCount - 1,
            Math.round(hz / (an.context.sampleRate / 2) * an.frequencyBinCount)));
    }

    function attach(sound) {
        if (!sound || sound.destroyed || active.has(sound.name)) return;
        const an = sound.ctx.createAnalyser();
        an.fftSize = 2048;
        an.smoothingTimeConstant = 0.35;
        sound.inputNode.connect(an);
        const st = {
            sound, an,
            freq: new Uint8Array(an.frequencyBinCount),
            wave: new Float32Array(an.fftSize),
            bandBins: BANDS.map(([a, b]) => [bin(an, a), Math.max(bin(an, a), bin(an, b))]),
            kick: [bin(an, 40), bin(an, 150)],
            bandPeak: BANDS.map(() => 0.05),
            prevKick: 0,
            flux: [],              // recent flux values for adaptive threshold
            env: [],               // [t, flux] for tempo
            lastBeat: 0,
            beats: 0,
            unsupportedSent: false,
            lastReport: 0,
            lastTempo: 0,
            bpm: 0, confidence: 0,
            level: 0, bands: [0, 0, 0, 0, 0],
        };
        active.set(sound.name, st);
        if (!timer) timer = setInterval(tick, FRAME_MS);
    }

    function detach(name, inst) {
        const st = active.get(name);
        if (!st || (inst && st.sound !== inst)) return;
        try { st.sound.inputNode.disconnect(st.an); } catch (e) {}
        active.delete(name);
        if (!active.size && timer) { clearInterval(timer); timer = null; }
    }

    function estimateTempo(st, now) {
        const env = st.env;
        if (env.length < 50 || now - env[0][0] < 4) return;
        // resample onset envelope to fixed grid
        const t0 = env[0][0], n = Math.floor((now - t0) * ENV_RATE);
        const x = new Float32Array(n);
        let j = 0;
        for (let i = 0; i < n; i++) {
            const t = t0 + i / ENV_RATE;
            while (j < env.length - 2 && env[j + 1][0] < t) j++;
            const [ta, va] = env[j], [tb, vb] = env[j + 1] || env[j];
            x[i] = tb > ta ? va + (vb - va) * (t - ta) / (tb - ta) : va;
        }
        let mean = 0; for (let i = 0; i < n; i++) mean += x[i]; mean /= n;
        for (let i = 0; i < n; i++) x[i] -= mean;
        let e0 = 0; for (let i = 0; i < n; i++) e0 += x[i] * x[i];
        if (e0 <= 1e-9) return;

        const lagMin = Math.floor(ENV_RATE * 60 / BPM_MAX), lagMax = Math.ceil(ENV_RATE * 60 / BPM_MIN);
        const acf = new Float32Array(lagMax + 2);
        for (let L = lagMin - 1; L <= lagMax + 1; L++) {
            let s = 0; for (let i = L; i < n; i++) s += x[i] * x[i - L];
            acf[L] = s / (n - L);
        }
        let best = -1, bestScore = -Infinity, sum = 0, cnt = 0;
        for (let L = lagMin; L <= lagMax; L++) {
            const bpm = 60 * ENV_RATE / L;
            // mild log-gaussian prior around 120 BPM + reward for the double period
            const prior = Math.exp(-0.5 * Math.pow(Math.log2(bpm / 120) / 0.9, 2));
            const score = (acf[L] + 0.5 * (acf[2 * L] || 0)) * prior;
            sum += acf[L]; cnt++;
            if (score > bestScore) { bestScore = score; best = L; }
        }
        if (best < 0) return;
        // parabolic interpolation
        const a = acf[best - 1], b = acf[best], c = acf[best + 1];
        const d = (a - 2 * b + c) !== 0 ? 0.5 * (a - c) / (a - 2 * b + c) : 0;
        const bpm = 60 * ENV_RATE / (best + d);
        const avg = sum / cnt;
        const conf = Math.max(0, Math.min(1, (b - avg) / (e0 / n - avg + 1e-9) * 1.6));
        // smooth: jump only when the new estimate is confident or far off
        if (!st.bpm || Math.abs(bpm - st.bpm) > 3) st.bpm = bpm;
        else st.bpm = st.bpm * 0.8 + bpm * 0.2;
        st.confidence = st.confidence * 0.6 + conf * 0.4;
    }

    function tick() {
        const nowMs = performance.now();
        for (const [name, st] of active) {
            const s = st.sound;
            if (s.destroyed) { detach(name); continue; }
            if (!s.playing || s.paused) continue;
            // YT not routed through Web Audio → no data; stay silent so callers fall back to BPM/TAP
            if (s.isYoutube && !s.ytHooked) {
                if (s.ytHookFailed && !st.unsupportedSent) {
                    st.unsupportedSent = true;
                    s._post('analysis', { type: 'level', id: name, supported: false });
                }
                continue;
            }
            const now = s.ctx.currentTime;
            st.an.getByteFrequencyData(st.freq);
            st.an.getFloatTimeDomainData(st.wave);

            let rms = 0; for (let i = 0; i < st.wave.length; i++) rms += st.wave[i] * st.wave[i];
            st.level = Math.min(1, Math.sqrt(rms / st.wave.length) * 2.5);

            for (let k = 0; k < BANDS.length; k++) {
                const [a, b] = st.bandBins[k];
                let v = 0; for (let i = a; i <= b; i++) v += st.freq[i];
                v = v / ((b - a + 1) * 255);
                st.bandPeak[k] = Math.max(v, st.bandPeak[k] * 0.995, 0.05);   // auto gain
                st.bands[k] = Math.min(1, v / st.bandPeak[k]);
            }

            // onset: half-wave rectified flux of the kick band
            let kick = 0; for (let i = st.kick[0]; i <= st.kick[1]; i++) kick += st.freq[i];
            kick /= (st.kick[1] - st.kick[0] + 1) * 255;
            const flux = Math.max(0, kick - st.prevKick);
            st.prevKick = kick;
            st.env.push([now, flux]);
            while (st.env.length && now - st.env[0][0] > ENV_SECONDS) st.env.shift();
            st.flux.push(flux); if (st.flux.length > 50) st.flux.shift();

            let m = 0; for (const f of st.flux) m += f; m /= st.flux.length;
            let v2 = 0; for (const f of st.flux) v2 += (f - m) * (f - m);
            const thr = m + 1.5 * Math.sqrt(v2 / st.flux.length);
            const minGap = st.bpm && st.confidence > 0.5 ? (60 / st.bpm) * 0.6 : 0.25;
            if (flux > thr && flux > 0.02 && now - st.lastBeat > minGap) {
                st.lastBeat = now;
                st.beats++;
                s._post('analysis', {
                    type: 'beat', id: name, supported: true, beats: st.beats,
                    level: round(st.level),
                    strength: Math.min(1, flux / (thr * 2 + 1e-6)),
                    bpm: Math.round(st.bpm * 10) / 10, confidence: Math.round(st.confidence * 100) / 100,
                    bass: st.bands[1],
                });
            }

            if (nowMs - st.lastTempo > 1000) { st.lastTempo = nowMs; estimateTempo(st, now); }
            if (nowMs - st.lastReport > REPORT_MS) {
                st.lastReport = nowMs;
                s._post('analysis', {
                    type: 'level', id: name, supported: true, beats: st.beats,
                    level: round(st.level), bass: round(Math.max(st.bands[0], st.bands[1])),
                    bands: st.bands.map(round),
                    bpm: Math.round(st.bpm * 10) / 10, confidence: round(st.confidence),
                });
            }
        }
    }

    const round = (v) => Math.round(v * 1000) / 1000;

    return { attach, detach, isActive: (n) => active.has(n) };
})();
