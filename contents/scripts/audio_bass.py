#!/usr/bin/env python3
"""Real-time 7-band PipeWire FFT bass analyzer for Plasma Island.

Captures 8 kHz mono PCM from @DEFAULT_MONITOR@ via `parec`, computes a
512-point Hann-windowed FFT every 32 ms (~31 FPS), emphasizes sub-bass and
kick frequencies (30-250 Hz) with asymmetric fast-attack / slow-decay physics,
and serves normalized band levels over a loopback-only HTTP endpoint.
"""

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import math
import os
import shutil
import signal
import struct
import subprocess
import sys
import threading
import time


SAMPLE_RATE = 8000
FFT_SIZE = 512          # 15.625 Hz/bin frequency resolution
HOP_SAMPLES = 256       # 32 ms hop (~31 FPS, 50% overlap)
HOP_BYTES = HOP_SAMPLES * 2
IDLE_TIMEOUT_SEC = 3.5

# Precompute Hann window & bit-reversed Cooley-Tukey FFT tables once at startup
HANN = [0.5 * (1.0 - math.cos(2.0 * math.pi * i / (FFT_SIZE - 1))) for i in range(FFT_SIZE)]
_BITS = FFT_SIZE.bit_length() - 1
REV = [int(f"{i:0{_BITS}b}"[::-1], 2) for i in range(FFT_SIZE)]
STAGES = []
_m = 2
while _m <= FFT_SIZE:
    _half = _m // 2
    _ang = -2.0 * math.pi / _m
    _tw = [(math.cos(_ang * k), math.sin(_ang * k)) for k in range(_half)]
    STAGES.append((_m, _half, _tw))
    _m *= 2

# 7 frequency bands (bin ranges at 15.625 Hz/bin) from heavy Bass (left) to Highs (right)
BAND_DEFS = [
    (2, 5, 1.45),     # 0: Sub-bass  (31-78 Hz)
    (5, 8, 1.32),     # 1: Kick      (78-125 Hz)
    (8, 13, 1.20),    # 2: Bassline  (125-203 Hz)
    (13, 22, 1.15),   # 3: Low-mid   (203-344 Hz)
    (22, 42, 1.12),   # 4: Mid       (344-656 Hz)
    (42, 85, 1.10),   # 5: Upper-mid (656-1328 Hz)
    (85, 185, 1.08),  # 6: Highs     (1328-2890 Hz)
]


def compute_fft_magnitudes(ring: list) -> list:
    re = [ring[REV[i]] * HANN[REV[i]] for i in range(FFT_SIZE)]
    im = [0.0] * FFT_SIZE
    for m, half, tw in STAGES:
        for start in range(0, FFT_SIZE, m):
            for k in range(half):
                wr, wi = tw[k]
                i1 = start + k
                i2 = i1 + half
                tr = wr * re[i2] - wi * im[i2]
                ti = wr * im[i2] + wi * re[i2]
                re[i2] = re[i1] - tr
                im[i2] = im[i1] - ti
                re[i1] += tr
                im[i1] += ti
    return [math.hypot(re[k], im[k]) for k in range(FFT_SIZE // 2)]


class BassState:
    def __init__(self):
        self.lock = threading.Lock()
        self.bands = [0.0] * len(BAND_DEFS)
        self.last_poll = time.monotonic()
        self.stop_event = threading.Event()
        self.parec_proc = None

    def snapshot(self) -> str:
        with self.lock:
            self.last_poll = time.monotonic()
            vals = ",".join(f"{v:.3f}" for v in self.bands)
            return f'{{"bands":[{vals}]}}'


def pid_alive(pid: int) -> bool:
    if pid <= 1:
        return True
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def audio_loop(state: BassState):
    parec_bin = shutil.which("parec")
    if not parec_bin:
        state.stop_event.set()
        return

    cmd = [
        parec_bin,
        "--latency-msec=25",
        "-d", "@DEFAULT_MONITOR@",
        f"--rate={SAMPLE_RATE}",
        "--channels=1",
        "--format=s16le",
    ]
    ring = [0.0] * FFT_SIZE
    smooth = [0.0] * len(BAND_DEFS)
    band_peaks = [0.25] * len(BAND_DEFS)
    prev_ratios = [0.0] * len(BAND_DEFS)
    ref_peak = 0.8
    retries = 0

    while not state.stop_event.is_set():
        try:
            proc = subprocess.Popen(
                cmd,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
            )
        except OSError:
            state.stop_event.set()
            return

        state.parec_proc = proc
        unpack_fmt = f"<{HOP_SAMPLES}h"
        try:
            while not state.stop_event.is_set():
                raw = proc.stdout.read(HOP_BYTES)
                if not raw or len(raw) < HOP_BYTES:
                    break

                retries = 0
                hop = [s / 32768.0 for s in struct.unpack(unpack_fmt, raw)]
                ring = ring[HOP_SAMPLES:] + hop

                # Noise gate: keep true digital silence at 0 without lifting background hiss
                frame_rms = math.sqrt(sum(x * x for x in hop) / HOP_SAMPLES)
                if frame_rms < 0.0008:
                    for i in range(len(BAND_DEFS)):
                        smooth[i] *= 0.72
                    with state.lock:
                        state.bands = list(smooth)
                    continue

                mag = compute_fft_magnitudes(ring)

                raw_bands = []
                frame_max = 0.0
                for idx_b, (lo, hi, weight) in enumerate(BAND_DEFS):
                    # Combine band RMS and peak bin energy so narrow mid/vocal notes stay lively
                    sq = 0.0
                    pk = 0.0
                    for b in range(lo, hi):
                        m_val = mag[b]
                        sq += m_val * m_val
                        if m_val > pk:
                            pk = m_val
                    rms_band = math.sqrt(sq / max(1, hi - lo))
                    val = (rms_band * 0.55 + pk * 0.45) * weight if idx_b >= 2 else math.sqrt(sq / math.sqrt(hi - lo)) * weight
                    raw_bands.append(val)
                    if val > frame_max:
                        frame_max = val

                # Blend global AGC with strong per-band AGC so center & mid frequencies react vividly
                ref_peak = max(ref_peak * 0.993, frame_max, 0.14)

                for i, val in enumerate(raw_bands):
                    min_floor = 0.11 if i <= 1 else 0.045
                    band_peaks[i] = max(band_peaks[i] * 0.991, val, min_floor)
                    if i == 0:
                        denom = 0.62 * ref_peak + 0.38 * band_peaks[i]
                    elif i == 1:
                        denom = 0.40 * ref_peak + 0.60 * band_peaks[i]
                    else:
                        denom = 0.22 * ref_peak + 0.78 * band_peaks[i]
                    ratio = min(1.0, val / max(1e-6, denom))

                    flux = max(0.0, ratio - prev_ratios[i])
                    prev_ratios[i] = ratio

                    # Balanced bass punch and crisp mid sensitivity without saturating ceiling
                    if i <= 1:
                        shaped = min(1.0, (ratio ** 1.32) + flux * 0.72)
                    else:
                        shaped = min(1.0, (ratio ** 1.00) + flux * 0.65)

                    # Fast attack (0.86), snappy decay (0.24)
                    alpha = 0.86 if shaped > smooth[i] else 0.24
                    smooth[i] += alpha * (shaped - smooth[i])

                with state.lock:
                    state.bands = list(smooth)
        finally:
            try:
                proc.terminate()
                proc.wait(timeout=0.5)
            except Exception:
                try:
                    proc.kill()
                except Exception:
                    pass

        if state.stop_event.is_set() or retries >= 5:
            break
        retries += 1
        time.sleep(0.4)


def make_handler(state: BassState, server_ref: list):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            return

        def do_GET(self):
            if self.path == "/stop":
                self.send_response(200)
                self.end_headers()
                state.stop_event.set()
                if state.parec_proc:
                    try:
                        state.parec_proc.terminate()
                    except Exception:
                        pass
                threading.Thread(target=server_ref[0].shutdown, daemon=True).start()
                return

            payload = state.snapshot().encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(payload)

    return Handler


def run_worker(ppid: int):
    if not shutil.which("parec"):
        print("NOPAREC", flush=True)
        return

    state = BassState()
    server_ref = []
    server = ThreadingHTTPServer(("127.0.0.1", 0), make_handler(state, server_ref))
    server.daemon_threads = True
    server_ref.append(server)

    port = server.server_address[1]
    print(f"PORT:{port}", flush=True)
    try:
        sys.stdout.close()
    except Exception:
        pass

    def watchdog():
        while not state.stop_event.is_set():
            time.sleep(0.5)
            idle = (time.monotonic() - state.last_poll) > IDLE_TIMEOUT_SEC
            if idle or not pid_alive(ppid):
                state.stop_event.set()
                if state.parec_proc:
                    try:
                        state.parec_proc.terminate()
                    except Exception:
                        pass
                try:
                    server.shutdown()
                except Exception:
                    pass
                break

    threading.Thread(target=watchdog, daemon=True).start()
    threading.Thread(target=audio_loop, args=(state,), daemon=True).start()

    try:
        server.serve_forever()
    finally:
        state.stop_event.set()
        if state.parec_proc:
            try:
                state.parec_proc.terminate()
            except Exception:
                pass
        server.server_close()


def spawn_daemon(ppid: int):
    proc = subprocess.Popen(
        [sys.executable, os.path.abspath(__file__), "--worker", "--ppid", str(ppid)],
        start_new_session=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    line = proc.stdout.readline().strip() if proc.stdout else ""
    if proc.stdout:
        proc.stdout.close()
    if line:
        print(line, flush=True)


def main():
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    parser = argparse.ArgumentParser()
    parser.add_argument("--worker", action="store_true")
    parser.add_argument("--ppid", type=int, default=0)
    args = parser.parse_args()

    if args.worker:
        run_worker(args.ppid)
    else:
        spawn_daemon(args.ppid)


if __name__ == "__main__":
    main()
