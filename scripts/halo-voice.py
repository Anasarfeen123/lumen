#!/usr/bin/env python3
"""halo-voice.py — Halo's ears and voice. Everything stays on this computer.

  halo-voice.py status                     JSON: what's installed {tts, stt, sttBin, model, voice}
  halo-voice.py listen [--max 20] [--lang en]
        Records from the default microphone until you stop talking (or SIGTERM:
        stop now and use what was said; SIGINT: cancel). Prints JSON lines:
        {"level": 0–1} while recording · {"speech": true} once you start ·
        {"state": "transcribing"} · then {"heard": "…"} or {"error": "…"}.
  halo-voice.py wake                      listen for "hey halo" (short bursts, whisper.cpp's smallest
                                          model, nothing kept): {"wake": true, "rest": "…"} each time
  halo-voice.py transcribe <audio file>   a long recording (a lecture) → text on stdout
  halo-voice.py say <rate> <voice-hint> <text>
        Speaks the text and exits when done (SIGTERM stops it). Prints
        {"env": [0–1 …], "step": 40} (loudness per 40 ms, for the lips) and
        {"play": true} the moment playback starts.
        Piper (scripts/halo-voice-setup.sh: its own environment in ~/.local/share/lumen/piper,
        voices in ~/.local/share/lumen/voices/) if present, else espeak-ng.
        voice-hint: "uk" (a British voice, for Jarvis) or "us".

Ears: ffmpeg (from the microphone through PipeWire) + whisper.cpp (the
whisper-cpp package) with a ggml model in ~/.local/share/lumen/whisper/.
Recordings live in $XDG_RUNTIME_DIR/lumen-voice (RAM, private) and are
deleted as soon as they're transcribed.
"""
import glob
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
DATA = os.path.join(os.environ.get("XDG_DATA_HOME") or HOME + "/.local/share", "lumen")
RUN = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "lumen-voice")


def out(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def stt_bin():
    for b in ("whisper-cli", "whisper-cpp"):
        p = shutil.which(b)
        if p:
            return p
    return ""


def stt_model():
    cands = []
    for d in (DATA + "/whisper", "/usr/share/whisper-cpp/models", "/usr/share/whisper.cpp/models", HOME + "/.cache/whisper"):
        cands += glob.glob(d + "/ggml-*.bin")
    # an English base/small model first: fast and accurate enough to talk to
    rank = lambda p: (0 if re.search(r"(base|small)\.en", p) else 1 if re.search(r"base|small", p) else 2, os.path.getsize(p))
    cands = [c for c in cands if os.path.getsize(c) > 1_000_000]
    return sorted(cands, key=rank)[0] if cands else ""


def wake_model():
    """The smallest model for the wake phrase (tiny.en if you have it)."""
    cands = []
    for d in (DATA + "/whisper", "/usr/share/whisper-cpp/models", "/usr/share/whisper.cpp/models", HOME + "/.cache/whisper"):
        cands += [c for c in glob.glob(d + "/ggml-*.bin") if os.path.getsize(c) > 1_000_000]
    return sorted(cands, key=os.path.getsize)[0] if cands else ""


def piper_voice(hint=""):
    """A Piper voice: British for "uk" (Jarvis), American otherwise, else any."""
    v = sorted(glob.glob(DATA + "/voices/*.onnx"))
    want = "en_GB" if hint == "uk" else "en_US"
    pick = [x for x in v if os.path.basename(x).startswith(want)]
    return (pick or v or [""])[0]


def piper_python():
    """Piper's own environment (scripts/halo-voice-setup.sh), else this Python if it has piper."""
    for py in (DATA + "/piper/bin/python", sys.executable):
        if os.access(py, os.X_OK):
            try:
                if subprocess.run([py, "-c", "import piper"], capture_output=True, timeout=8).returncode == 0:
                    return py
            except (OSError, subprocess.TimeoutExpired):
                pass
    return ""


def has_piper():
    return bool(piper_voice() and piper_python())


def cmd_status():
    tts = "piper" if has_piper() else "espeak" if shutil.which("espeak-ng") else ""
    b, m = stt_bin(), stt_model()
    out({"tts": tts, "voice": piper_voice(), "stt": bool(b and m and shutil.which("ffmpeg")),
         "sttBin": b, "model": m, "ffmpeg": bool(shutil.which("ffmpeg"))})


# ── listening ───────────────────────────────────────────────────────────────

def cmd_listen(args):
    maxs = 20.0
    lang = "en"
    if "--max" in args:
        maxs = float(args[args.index("--max") + 1])
    if "--lang" in args:
        lang = args[args.index("--lang") + 1]
    b, model = stt_bin(), stt_model()
    test = os.environ.get("HALO_VOICE_TEST", "")      # development: an ffmpeg lavfi source instead of the mic
    if (not b or not model) and not test:
        out({"error": "no-stt"})
        return
    os.makedirs(RUN, mode=0o700, exist_ok=True)
    wav = os.path.join(RUN, "heard-%d.wav" % os.getpid())
    stop = {"why": ""}
    signal.signal(signal.SIGTERM, lambda *_: stop.update(why="stop"))
    signal.signal(signal.SIGINT, lambda *_: stop.update(why="cancel"))
    ff = subprocess.Popen(
        ["ffmpeg", "-hide_banner", "-nostats", "-loglevel", "info", *(["-f", "lavfi", "-re", "-i", test] if test else ["-f", "pulse", "-i", "default"]),
         "-ac", "1", "-ar", "16000",
         "-af", "astats=metadata=1:reset=1,ametadata=mode=print:key=lavfi.astats.Overall.RMS_level",
         "-t", str(maxs), "-y", wav],
        stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, bufsize=1)
    # A simple voice detector on the loudness: learn the room's noise in the
    # first half second, speech is well above it, the end is a pause after speech.
    floor, samples, t, speech_at, quiet_since, loud_run = None, [], 0.0, None, None, 0
    last_emit = 0.0
    try:
        for line in ff.stderr:
            if stop["why"]:
                break
            m = re.search(r"pts_time:([\d.]+)", line)
            if m:
                t = float(m.group(1))
                continue
            m = re.search(r"RMS_level=(-?[\d.]+|-inf)", line)
            if not m:
                continue
            db = -90.0 if m.group(1) == "-inf" else float(m.group(1))
            if t < 0.5:
                samples.append(db)
                continue
            if floor is None:
                floor = min(-32.0, max(-62.0, (sorted(samples)[len(samples) // 2] if samples else -55.0)))
            loud = db > floor + 13
            loud_run = loud_run + 1 if loud else 0
            if speech_at is None and loud_run >= 3:
                speech_at = t
                out({"speech": True})
            if speech_at is not None:
                if db < floor + 7:
                    quiet_since = quiet_since if quiet_since is not None else t
                    if t - quiet_since >= 1.3 and t - speech_at > 0.6:
                        break
                else:
                    quiet_since = None
            elif t > 7.0:
                stop["why"] = "nothing"
                break
            if t - last_emit >= 0.06:
                last_emit = t
                out({"level": round(max(0.0, min(1.0, (db - floor) / 30)), 2)})
    finally:
        try:
            ff.stdin.write("q")
            ff.stdin.flush()
        except (BrokenPipeError, OSError, ValueError):
            pass
        try:
            ff.wait(timeout=3)
        except subprocess.TimeoutExpired:
            ff.kill()
    if stop["why"] == "cancel":
        _rm(wav)
        out({"error": "cancelled"})
        return
    if speech_at is None:
        _rm(wav)
        out({"error": "nothing"})
        return
    out({"state": "transcribing"})
    if test:
        _rm(wav)
        out({"heard": "test: speech from %.1fs" % speech_at})
        return
    threads = str(max(2, min(8, (os.cpu_count() or 4) // 2)))
    try:
        r = subprocess.run([b, "-m", model, "-f", wav, "-nt", "-np", "-l", lang, "-t", threads],
                           capture_output=True, text=True, timeout=90)
        text = r.stdout
    except (OSError, subprocess.TimeoutExpired) as e:
        text = ""
        out({"error": "whisper: " + str(e)})
    _rm(wav)
    text = re.sub(r"\[[^\]]*\]|\([^)]*\)", " ", text)       # [BLANK_AUDIO], (music)…
    text = re.sub(r"\s+", " ", text).strip()
    out({"heard": text} if text else {"error": "nothing"})


# ── the wake phrase ("hey halo") ────────────────────────────────────────────
# Listens in short bursts: the loudness is watched; only when someone speaks
# (a short burst, under 4 s) is it written to RAM, read by whisper.cpp's
# smallest model, and deleted at once. Prints {"wake": true, "rest": "…"}
# when the phrase starts the burst ("hey halo, what's my next class").

WAKE = re.compile(r"^\W*(?:hey|hi|okay|ok|yo)?[\s,]*(?:halo|hello halo|hey hello|hailo|helo|hayley|haylo)\b[\s,.!?]*(.*)$", re.I)


def burst(src_args, maxs=4.0):
    """One utterance: record until a short pause; None if nobody spoke."""
    os.makedirs(RUN, mode=0o700, exist_ok=True)
    wav = os.path.join(RUN, "wake-%d.wav" % os.getpid())
    ff = subprocess.Popen(["ffmpeg", "-hide_banner", "-nostats", "-loglevel", "info", *src_args, "-ac", "1", "-ar", "16000",
                           "-af", "astats=metadata=1:reset=1,ametadata=mode=print:key=lavfi.astats.Overall.RMS_level",
                           "-t", "30", "-y", wav], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, bufsize=1)
    floor, samples, t, speech_at, quiet_since, loud = None, [], 0.0, None, None, 0
    try:
        for line in ff.stderr:
            m = re.search(r"pts_time:([\d.]+)", line)
            if m:
                t = float(m.group(1))
                continue
            m = re.search(r"RMS_level=(-?[\d.]+|-inf)", line)
            if not m:
                continue
            db = -90.0 if m.group(1) == "-inf" else float(m.group(1))
            if floor is None:
                samples.append(db)
                if t < 0.4:
                    continue
                floor = min(-32.0, max(-62.0, sorted(samples)[len(samples) // 2]))
            loud = loud + 1 if db > floor + 13 else 0
            if speech_at is None:
                if loud >= 4:
                    speech_at = t
                elif t > 25:                         # restart now and then (the floor drifts)
                    break
                continue
            if db < floor + 7:
                quiet_since = quiet_since if quiet_since is not None else t
                if t - quiet_since >= 0.7:
                    break
            else:
                quiet_since = None
            if t - speech_at > maxs:
                break
    finally:
        try:
            ff.stdin.write("q")
            ff.stdin.flush()
        except (BrokenPipeError, OSError, ValueError):
            pass
        try:
            ff.wait(timeout=3)
        except subprocess.TimeoutExpired:
            ff.kill()
    if speech_at is None or t - speech_at > maxs + 1:
        _rm(wav)
        return None
    return wav


def cmd_wake():
    b, model = stt_bin(), wake_model()
    test = os.environ.get("HALO_VOICE_TEST", "")
    if (not b or not model) and not test:
        out({"error": "no-stt"})
        return
    stop = {"now": False}
    signal.signal(signal.SIGTERM, lambda *_: stop.update(now=True))
    src = ["-f", "lavfi", "-re", "-i", test] if test else ["-f", "pulse", "-i", "default"]
    out({"state": "listening"})
    while not stop["now"]:
        wav = burst(src)
        if stop["now"] or wav is None:
            if test:
                break
            continue
        if test:
            _rm(wav)
            out({"heard": "(test burst)"})
            break
        try:
            r = subprocess.run([b, "-m", model, "-f", wav, "-nt", "-np", "-l", "en", "-t", "2"], capture_output=True, text=True, timeout=30)
            text = re.sub(r"\[[^\]]*\]|\([^)]*\)", " ", r.stdout).strip()
        except (OSError, subprocess.TimeoutExpired):
            text = ""
        _rm(wav)
        m = WAKE.match(text)
        if m:
            out({"wake": True, "rest": m.group(1).strip()})


def _rm(p):
    try:
        os.remove(p)
    except OSError:
        pass


# ── speaking ────────────────────────────────────────────────────────────────

def envelope(wav, step_ms):
    """Loudness per step, 0–1 (16-bit mono or stereo wav)."""
    import array
    import wave
    try:
        with wave.open(wav) as w:
            rate, ch, width = w.getframerate(), w.getnchannels(), w.getsampwidth()
            if width != 2:
                return []
            data = array.array("h", w.readframes(w.getnframes()))
    except (OSError, wave.Error, EOFError):
        return []
    n = max(1, rate * step_ms // 1000) * ch
    vals = []
    for i in range(0, len(data), n):
        chunk = data[i:i + n]
        if not chunk:
            break
        vals.append((sum(x * x for x in chunk[::4]) / max(1, len(chunk[::4]))) ** 0.5)
    peak = max(vals) if vals else 0
    if peak <= 0:
        return [0] * len(vals)
    # a little compression: quiet syllables still move the lips
    return [round(min(1.0, (v / peak) ** 0.6), 2) for v in vals]


def cmd_say(rate, hint, text):
    text = text.strip()[:1200]
    if not text:
        return
    os.makedirs(RUN, mode=0o700, exist_ok=True)
    wav = os.path.join(RUN, "say-%d.wav" % os.getpid())
    procs = []

    def bye(*_):
        for p in procs:
            try:
                p.kill()
            except OSError:
                pass
        _rm(wav)
        sys.exit(0)
    signal.signal(signal.SIGTERM, bye)
    signal.signal(signal.SIGINT, bye)
    try:
        rate = max(0.6, min(1.6, float(rate)))
    except ValueError:
        rate = 1.0
    py = piper_python() if piper_voice() else ""
    if py:
        p = subprocess.Popen([py, "-m", "piper", "-m", piper_voice(hint), "-f", wav, "--length-scale", "%.2f" % (1 / rate)],
                             stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, text=True)
        procs.append(p)
        p.communicate(text)
    elif shutil.which("espeak-ng"):
        voice = "en-gb-x-rp" if hint == "uk" else "en-us"
        p = subprocess.Popen(["espeak-ng", "-v", voice, "-s", str(int(168 * rate)), "-p", "42", "-w", wav, text],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        procs.append(p)
        p.wait()
    else:
        return
    if os.path.exists(wav):
        # The mouth: how loud each 40 ms is, so Halo's lips move with the words
        out({"env": envelope(wav, 40), "step": 40})
        p = subprocess.Popen(["pw-play", "--volume", "0.8", wav], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        out({"play": True})
        procs.append(p)
        p.wait()
    _rm(wav)


def cmd_transcribe(path):
    """A long recording (a lecture) → text on stdout. Converted to 16 kHz WAV in RAM first."""
    b, model = stt_bin(), stt_model()
    if not b or not model:
        sys.stderr.write("no-stt\n")
        sys.exit(3)
    os.makedirs(RUN, mode=0o700, exist_ok=True)
    wav = os.path.join(RUN, "long-%d.wav" % os.getpid())
    try:
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", "16000", "-y", wav], check=True, timeout=600)
        threads = str(max(2, min(8, (os.cpu_count() or 4) - 2)))
        r = subprocess.run([b, "-m", model, "-f", wav, "-nt", "-np", "-l", "en", "-t", threads], capture_output=True, text=True, timeout=7200)
        text = re.sub(r"\[[^\]]*\]|\([^)]*\)", " ", r.stdout)
        sys.stdout.write(re.sub(r"[ \t]+", " ", text).strip() + "\n")
    except (OSError, subprocess.SubprocessError) as e:
        sys.stderr.write(str(e) + "\n")
        sys.exit(1)
    finally:
        _rm(wav)


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return
    if a[0] == "status":
        cmd_status()
    elif a[0] == "listen":
        cmd_listen(a[1:])
    elif a[0] == "wake":
        cmd_wake()
    elif a[0] == "transcribe" and len(a) >= 2:
        cmd_transcribe(a[1])
    elif a[0] == "say" and len(a) >= 4:
        cmd_say(a[1], a[2], " ".join(a[3:]))
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
