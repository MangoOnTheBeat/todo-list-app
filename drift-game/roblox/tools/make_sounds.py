"""Synthesises Kaido Drift's sounds for Roblox (no samples used, so they're ours to upload).
Engine loops are exact multiples of the 4-cylinder firing cycle and filtered in the frequency
domain, so each file loops with no click. Output: sounds/*.ogg (mono, 44.1 kHz)."""
import numpy as np, subprocess, os, sys

SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else 'sounds'
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1989)

def spectral(x, gain_fn):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X * gain_fn(f), len(x))
def bandpass(f, lo, hi, q=1.0):
    return np.exp(-0.5 * (np.log(np.maximum(f, 1) / np.sqrt(lo * hi)) / (np.log(hi / lo) / 2 * q + 1e-9)) ** 2)
def lowpass(f, fc, order=2):
    return 1 / np.sqrt(1 + (f / fc) ** (2 * order))
def highpass(f, fc, order=2):
    return 1 / np.sqrt(1 + (fc / np.maximum(f, 1e-3)) ** (2 * order))
def peak(f, fc, gain_db, width_oct=0.6):
    return 1 + (10 ** (gain_db / 20) - 1) * np.exp(-0.5 * (np.log2(np.maximum(f, 1) / fc) / width_oct) ** 2)
def norm(x, peak_db=-1.5):
    return x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20)
def save(name, x):
    raw = os.path.join(OUT, name + '.f32')
    (np.clip(x, -1, 1).astype('<f4')).tofile(raw)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'f32le', '-ar', str(SR), '-ac', '1', '-i', raw,
                    '-c:a', 'libvorbis', '-q:a', '6', os.path.join(OUT, name + '.ogg')], check=True)
    os.remove(raw)

def engine(rpm, load, seconds=2.4, crackle=0.0):
    """4-cylinder inline engine at a fixed rpm. load 1 = full throttle, 0 = closed throttle."""
    cycle = 120.0 / rpm                       # one 4-stroke cycle = 2 revolutions
    k = max(1, round(seconds / cycle)); n = int(round(k * cycle * SR))
    n -= n % 2
    t_fire = cycle / 4
    imp = np.zeros(n)
    cyl_amp = [1.0, 0.86, 0.95, 0.80]        # uneven cylinders give the engine its character
    cyl_jit = [0.0, 0.004, -0.003, 0.002]
    for c in range(k * 4):
        cy = c % 4
        pos = int(round((c * t_fire + cyl_jit[cy] * t_fire) * SR)) % n
        imp[pos] += cyl_amp[cy] * (0.7 + 0.3 * load) * (1 + 0.05 * rng.standard_normal())
    # exhaust pulse: a few damped resonances of the manifold and pipe
    kl = int(0.045 * SR); tk = np.arange(kl) / SR
    kernel = np.zeros(kl)
    for fr, dec, amp in [(72, 0.020, 1.0), (145, 0.012, 0.7), (310, 0.007, 0.45 + 0.35 * load), (620, 0.004, 0.25 + 0.3 * load), (1250, 0.0025, 0.12 + 0.2 * load)]:
        kernel += amp * np.exp(-tk / dec) * np.sin(2 * np.pi * fr * (rpm / 4000) ** 0.25 * tk)
    k_full = np.zeros(n); k_full[:kl] = kernel
    exhaust = np.fft.irfft(np.fft.rfft(imp) * np.fft.rfft(k_full), n)  # circular: loops perfectly
    # intake roar: noise shaped by the firing envelope
    env = np.fft.irfft(np.fft.rfft(imp) * np.fft.rfft(np.pad(np.exp(-np.arange(int(0.01 * SR)) / (0.004 * SR)), (0, n - int(0.01 * SR)))), n)
    env = np.abs(env) / (np.max(np.abs(env)) + 1e-9)
    noise = spectral(rng.standard_normal(n), lambda f: bandpass(f, 300, 2600) * (0.3 + load))
    intake = noise * (0.25 + 0.75 * env) * (0.35 + 0.65 * load)
    # turbo whistle on load, rising with rpm (a whole number of cycles so it loops)
    wf = round(2200 + rpm * 0.35) ; wf = round(wf * n / SR) * SR / n
    whistle = 0.06 * load * (rpm / 7000) ** 1.5 * np.sin(2 * np.pi * wf * np.arange(n) / SR)
    # mechanical: crank harmonic
    hf = round(rpm / 60 * 2 * 4 * n / SR) * SR / n
    mech = 0.04 * np.sin(2 * np.pi * hf * np.arange(n) / SR)
    x = exhaust / (np.max(np.abs(exhaust)) + 1e-9) + 0.55 * intake / (np.max(np.abs(intake)) + 1e-9) + whistle + mech
    # decel crackle: random pops on closed throttle
    if crackle > 0:
        for _ in range(int(crackle * seconds * 6)):
            p = rng.integers(0, n - 2000); L = rng.integers(300, 1400)
            pop = rng.standard_normal(L) * np.exp(-np.arange(L) / (L / 4))
            x[p:p + L] += pop * rng.uniform(0.6, 1.4)
    x = np.tanh(1.6 * x) # saturation like a real exhaust note on a recording
    # tone: full-bodied lows, presence, closed throttle sounds muffled
    x = spectral(x, lambda f: highpass(f, 35) * peak(f, 110, 4) * peak(f, 2400, 2 * load - 1) * lowpass(f, 4500 + 6000 * load, 2))
    return norm(x)

def skid(seconds=3.0):
    n = int(seconds * SR)
    base = spectral(rng.standard_normal(n), lambda f: bandpass(f, 700, 1500, 0.6) + 0.4 * bandpass(f, 1800, 3400, 0.6) + 0.15 * bandpass(f, 3500, 6500))
    # rubber judder: slow random amplitude and pitch wobble (periodic over the loop)
    mod = spectral(rng.standard_normal(n), lambda f: lowpass(f, 12, 2))
    mod = 0.75 + 0.25 * mod / (np.max(np.abs(mod)) + 1e-9)
    tone = sum(a * np.sin(2 * np.pi * round(fr * seconds) / seconds * np.arange(n) / SR) for fr, a in [(1050, 0.5), (2100, 0.25), (3150, 0.12)])
    x = base / (np.max(np.abs(base)) + 1e-9) * 0.8 + tone * 0.35
    return norm(np.tanh(1.3 * x * mod))

def blowoff(seconds=0.9):
    n = int(seconds * SR); t = np.arange(n) / SR
    hiss = spectral(rng.standard_normal(n), lambda f: highpass(f, 1800, 2) * lowpass(f, 9000, 2))
    env = np.minimum(t / 0.01, 1) * np.exp(-t / 0.18)
    flutter = 1 - 0.55 * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (28 - 14 * t) * t))) * np.exp(-t / 0.4)  # "tu-tu-tu" compressor surge
    chirp = 0.25 * np.sin(2 * np.pi * (3200 - 1800 * t) * t) * np.exp(-t / 0.12)
    return norm((hiss / (np.max(np.abs(hiss)) + 1e-9) * flutter + chirp) * env, -3)

def wind(seconds=4.0):
    n = int(seconds * SR)
    x = spectral(rng.standard_normal(n), lambda f: lowpass(f, 500, 2) * highpass(f, 60) + 0.3 * bandpass(f, 800, 1600))
    gust = spectral(rng.standard_normal(n), lambda f: lowpass(f, 0.8, 2)); gust = 0.7 + 0.3 * gust / (np.max(np.abs(gust)) + 1e-9)
    return norm(x * gust, -4)

def limiter(seconds=0.24):
    # one bang of the rev limiter cutting ignition
    return norm(engine(7600, 1.0, seconds) * np.r_[np.ones(int(SR * seconds * 0.6)), np.linspace(1, 0.1, int(SR * seconds) - int(SR * seconds * 0.6))][: len(engine(7600, 1.0, seconds))])

save('kaido_engine_low', engine(1800, 1.0))
save('kaido_engine_mid', engine(4200, 1.0))
save('kaido_engine_high', engine(7000, 1.0))
save('kaido_engine_off', engine(3500, 0.05, crackle=1.0))
save('kaido_skid', skid())
save('kaido_blowoff', blowoff())
save('kaido_wind', wind())
print('ok', sorted(os.listdir(OUT)))
