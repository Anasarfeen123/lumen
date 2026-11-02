#!/usr/bin/env python3
"""halo-voice.py — Halo's ears and voice. Everything stays on this computer.

  halo-voice.py status                     JSON: what's installed {tts, stt, sttBin, model, voice}
  halo-voice.py listen [--max 20] [--lang en]
        Records from the default microphone until you stop talking (or SIGTERM:
        stop now and use what was said; SIGINT: cancel). Prints JSON lines:
        {"ready": true} once the mic is recording · {"level": 0–1} while recording · {"speech": true} once you start ·
        {"state": "transcribing"} · then {"heard": "…"} or {"error": "…"}.
  halo-voice.py serve                     keep whisper-server warm (the model in memory) until SIGTERM;
                                          listen then shows {"partial": "…"} words while you speak
  halo-voice.py wake                      listen for "hey halo" (short bursts, whisper.cpp's smallest
                                          model, nothing kept): {"wake": true, "rest": "…"} each time
  halo-voice.py transcribe <audio file>   a long recording (a lecture) → text on stdout
  halo-voice.py captions                  live captions of what's playing (the speakers, not the
                                          mic): {"caption": text} every few seconds until SIGTERM
  halo-voice.py say <rate> <voice-hint> <text>
        Speaks the text and exits when done (SIGTERM stops it). Prints
        {"env": [0–1 …], "step": 40} (loudness per 40 ms, for the lips) and
        {"play": true} the moment playback starts.
        Piper (scripts/halo-voice-setup.sh: its own environment in ~/.local/share/lumen/piper,
        voices in ~/.local/share/lumen/voices/) if present, else espeak-ng.
        voice-hint: "uk" (a British voice, for Jarvis) or "us".

Ears: ffmpeg (from the microphone through PipeWire) + whisper.cpp (whisper-cli,
and whisper-server for live words, built into ~/.local/bin: Fedora's package
has only the library) with a ggml model in ~/.local/share/lumen/whisper/.
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


def die_with_parent():
    """For every program started here: end it if this script dies (a shell
    reload kills us with SIGKILL), so no recorder keeps a mic open."""
    try:
        import ctypes
        # SIGKILL: a recorder stuck on a dead Bluetooth mic ignores SIGTERM
        ctypes.CDLL("libc.so.6", use_errno=True).prctl(1, signal.SIGKILL)   # PR_SET_PDEATHSIG
    except (OSError, AttributeError):
        pass


def stt_bin():
    for b in ("whisper-cli", "whisper-cpp"):
        p = shutil.which(b)
        if p:
            return p
    # Fedora's whisper-cpp package has only the library, so the CLI is built by
    # hand into ~/.local/bin, which the session's PATH may not include
    for p in (HOME + "/.local/bin/whisper-cli", DATA + "/whisper/whisper-cli"):
        if os.access(p, os.X_OK):
            return p
    return ""


# Settings → Halo → Voice → Recognition: which model listens
MODELS = {"fast": r"base\.en", "balanced": r"small\.en", "best": r"large-v3-turbo"}


def stt_model(pref=""):
    cands = []
    for d in (DATA + "/whisper", "/usr/share/whisper-cpp/models", "/usr/share/whisper.cpp/models", HOME + "/.cache/whisper"):
        cands += glob.glob(d + "/ggml-*.bin")
    cands = [c for c in cands if os.path.getsize(c) > 1_000_000]
    if pref in MODELS:
        pick = [c for c in cands if re.search(MODELS[pref], c)]
        if pick:
            return sorted(pick, key=os.path.getsize)[0]
    # otherwise small.en (accurate, still quick on a GPU), then base.en, then
    # any other English base/small model; never the big ones by surprise
    rank = lambda p: (0 if re.search(r"small\.en", p) else 1 if re.search(r"base\.en", p) else 2 if re.search(r"base|small", p) else 3,
                      os.path.getsize(p))
    return sorted(cands, key=rank)[0] if cands else ""


def model_arg(args):
    return "--model" in args and args[args.index("--model") + 1] or ""


def best_on_discrete(pref):
    """The large model is only quick on the discrete GPU."""
    if pref == "best" and "HALO_VOICE_GPU" not in os.environ:
        os.environ["HALO_VOICE_GPU"] = "discrete"


def wake_model():
    """The smallest model for the wake phrase (tiny.en if you have it)."""
    cands = []
    for d in (DATA + "/whisper", "/usr/share/whisper-cpp/models", "/usr/share/whisper.cpp/models", HOME + "/.cache/whisper"):
        cands += [c for c in glob.glob(d + "/ggml-*.bin") if os.path.getsize(c) > 1_000_000]
    return sorted(cands, key=os.path.getsize)[0] if cands else ""


def piper_voice(hint=""):
    """A Piper voice: British for "uk" (Jarvis), American otherwise, else any."""
    # only complete voices: the model and its .json (a download in progress has no .json yet)
    v = sorted(x for x in glob.glob(DATA + "/voices/*.onnx") if os.path.exists(x + ".json"))
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
         "sttBin": b, "model": m, "ffmpeg": bool(shutil.which("ffmpeg")), "server": bool(server_bin()),
         "models": [k for k in MODELS if stt_model(k) and re.search(MODELS[k], stt_model(k))]})


# ── listening ───────────────────────────────────────────────────────────────

def pick_mic(pref):
    """(PulseAudio source, kind). "auto": on Bluetooth headphones, the laptop's
    own mic, so the headphones never drop into headset mode (mono, low quality,
    and a second or two of silence each way while they switch, which swallowed
    both your first words and Halo's reply). "headset": the default mic as is."""
    try:
        default = subprocess.run(["pactl", "get-default-source"], capture_output=True, text=True, timeout=3).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return "default", "default"
    if not default.startswith("bluez_"):
        return "default", "default"
    if pref == "auto":
        try:
            names = [ln.split("\t")[1] for ln in subprocess.run(["pactl", "list", "short", "sources"], capture_output=True,
                     text=True, timeout=3).stdout.splitlines() if ln.count("\t") >= 1]
        except (OSError, subprocess.SubprocessError):
            names = []
        builtin = [n for n in names if n.startswith("alsa_input.")]
        if builtin:
            return builtin[0], "laptop"
    return default, "headset"


def server_bin():
    p = shutil.which("whisper-server")
    if p:
        return p
    for p in (HOME + "/.local/bin/whisper-server", DATA + "/whisper/whisper-server"):
        if os.access(p, os.X_OK):
            return p
    return ""


def gpu_env():
    """whisper.cpp built with Vulkan runs on the integrated GPU, and only that
    GPU's driver is loaded: Vulkan otherwise opens every GPU it finds, which
    wakes the discrete one (NVIDIA on hybrid laptops) and keeps it awake.
    HALO_VOICE_GPU=integrated (default) | discrete | cpu."""
    env = dict(os.environ)
    want = os.environ.get("HALO_VOICE_GPU", "integrated")
    if want == "cpu":
        env["GGML_VK_VISIBLE_DEVICES"] = ""
        return env
    # which kernel driver runs each GPU: amdgpu / i915 / xe are integrated here
    drivers = set()
    for d in glob.glob("/sys/class/drm/renderD*/device/driver"):
        drivers.add(os.path.basename(os.path.realpath(d)))
    icd_for = {"amdgpu": "radeon", "i915": "intel", "xe": "intel"}
    if want == "integrated":
        for drv, icd in icd_for.items():
            f = "/usr/share/vulkan/icd.d/%s_icd.x86_64.json" % icd
            if drv in drivers and os.path.exists(f):
                env["VK_DRIVER_FILES"] = env["VK_ICD_FILENAMES"] = f
                env["GGML_VK_VISIBLE_DEVICES"] = "0"
                break
    elif want == "discrete" and "nvidia" in drivers and os.path.exists("/usr/share/vulkan/icd.d/nvidia_icd.x86_64.json"):
        env["VK_DRIVER_FILES"] = env["VK_ICD_FILENAMES"] = "/usr/share/vulkan/icd.d/nvidia_icd.x86_64.json"
        env["GGML_VK_VISIBLE_DEVICES"] = "0"
    return env


def threads():
    return str(max(2, min(8, (os.cpu_count() or 4) // 2)))


# ── the warm ear: whisper-server with the model kept in memory ──────────────
# Started while you talk to Halo (and a couple of minutes after); listen sends
# it the audio so far while you speak (words appear live) and once at the end.
# Only on 127.0.0.1, on a port written to $XDG_RUNTIME_DIR/lumen-voice/server.

SERVER_FILE = os.path.join(RUN, "server")


def cmd_serve(args=()):
    pref = model_arg(args)
    best_on_discrete(pref)
    sb, model = server_bin(), stt_model(pref)
    if not sb or not model:
        out({"error": "no-server"})
        return
    import socket
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        port = s.getsockname()[1]
    os.makedirs(RUN, mode=0o700, exist_ok=True)
    prompt = "--prompt" in args and args[args.index("--prompt") + 1] or ""
    p = subprocess.Popen([sb, "-m", model, "--host", "127.0.0.1", "--port", str(port), "-t", threads(), "-l", "en",
                          *(["--prompt", prompt] if prompt else [])],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=gpu_env(), preexec_fn=die_with_parent)

    def bye(*_):
        try:
            with open(SERVER_FILE) as f:
                if f.read().strip() == str(port):
                    _rm(SERVER_FILE)
        except OSError:
            pass
        p.terminate()
        try:
            p.wait(timeout=3)
        except subprocess.TimeoutExpired:
            p.kill()
        sys.exit(0)
    signal.signal(signal.SIGTERM, bye)
    signal.signal(signal.SIGINT, bye)
    # the server answers once the model is loaded
    deadline = time.time() + 30
    while time.time() < deadline and p.poll() is None:
        try:
            socket.create_connection(("127.0.0.1", port), timeout=0.3).close()
            break
        except OSError:
            time.sleep(0.1)
    if p.poll() is not None or time.time() >= deadline:
        out({"error": "server didn't start"})
        bye()
    with open(SERVER_FILE + ".tmp", "w") as f:
        f.write(str(port))
    os.replace(SERVER_FILE + ".tmp", SERVER_FILE)
    out({"serving": port})
    p.wait()
    bye()


def server_port():
    try:
        with open(SERVER_FILE) as f:
            return int(f.read().strip())
    except (OSError, ValueError):
        return 0


def wav_bytes(pcm):
    import io
    import wave
    b = io.BytesIO()
    with wave.open(b, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(16000)
        w.writeframes(pcm)
    return b.getvalue()


def clean(text):
    text = re.sub(r"\[[^\]]*\]|\([^)]*\)", " ", text)       # [BLANK_AUDIO], (music)…
    return re.sub(r"\s+", " ", text).strip()


def louder(pcm):
    """Quiet recordings (a laptop mic turned down) raised to a healthy level:
    peaks to about -3 dB, by at most 20×."""
    import array
    a = array.array("h", pcm)
    peak = max((abs(x) for x in a), default=0)
    if peak <= 0:
        return pcm
    gain = min(20.0, 23000 / peak)
    if gain <= 1.05:
        return pcm
    return array.array("h", (max(-32768, min(32767, int(x * gain))) for x in a)).tobytes()


# Words you're likely to say, so whisper spells them right ("Anas asked Halo to
# open AmazeCC…"): a sentence works better than a list. whisper-server 1.8.1
# ignores a per-request prompt, so the server is given it when it starts.
PROMPT = {"text": ""}


def ask_server(port, pcm, timeout=30):
    """Text for 16 kHz mono PCM from the warm server, or None if it can't."""
    import urllib.request
    boundary = "lumen%d" % os.getpid()
    body = b"".join([
        b"--" + boundary.encode() + b"\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.wav\"\r\nContent-Type: audio/wav\r\n\r\n",
        wav_bytes(louder(pcm)), b"\r\n",
        b"--" + boundary.encode() + b"\r\nContent-Disposition: form-data; name=\"response_format\"\r\n\r\njson\r\n",
        b"--" + boundary.encode() + b"\r\nContent-Disposition: form-data; name=\"temperature\"\r\n\r\n0.0\r\n",
        b"--" + boundary.encode() + b"--\r\n"])
    req = urllib.request.Request("http://127.0.0.1:%d/inference" % port, data=body,
                                 headers={"Content-Type": "multipart/form-data; boundary=" + boundary})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return clean(json.loads(r.read().decode("utf-8", "replace")).get("text", ""))
    except (OSError, ValueError):
        return None


def is_muted(source):
    try:
        r = subprocess.run(["pactl", "get-source-mute", source], capture_output=True, text=True, timeout=3).stdout
    except (OSError, subprocess.SubprocessError):
        return False
    return "yes" in r.lower()


def cmd_listen(args):
    maxs = 20.0
    lang = "en"
    if "--max" in args:
        maxs = float(args[args.index("--max") + 1])
    if "--lang" in args:
        lang = args[args.index("--lang") + 1]
    pref = model_arg(args)
    best_on_discrete(pref)
    b, model = stt_bin(), stt_model(pref)
    PROMPT["text"] = "--prompt" in args and args[args.index("--prompt") + 1] or ""
    test = os.environ.get("HALO_VOICE_TEST", "")      # development: an ffmpeg lavfi source instead of the mic
    if (not b or not model) and not test:
        out({"error": "no-stt"})
        return
    fake = test and not os.environ.get("HALO_VOICE_TEST_STT")   # …and with _STT=1, really transcribed
    import array
    import math
    import threading
    stop = {"why": ""}
    signal.signal(signal.SIGTERM, lambda *_: stop.update(why="stop"))
    signal.signal(signal.SIGINT, lambda *_: stop.update(why="cancel"))
    mic = "--mic" in args and args[args.index("--mic") + 1] or "auto"
    source, kind = ("", "test") if test else pick_mic(mic)
    # if the headphones' mic gives nothing (a Bluetooth headset mode that never
    # comes up), the laptop's own mic, in the same go
    fallback = ""
    if kind == "headset":
        builtin, bkind = pick_mic("auto")
        fallback = builtin if bkind == "laptop" else ""
    test_fallback = os.environ.get("HALO_VOICE_TEST_FALLBACK", "")   # development: the fallback's lavfi source

    # raw 16 kHz mono samples straight to us: the loudness is measured here, and
    # the audio so far can be transcribed while you're still talking
    def record(src, lavfi=""):
        return subprocess.Popen(
            ["ffmpeg", "-hide_banner", "-nostats", "-loglevel", "error", *(["-f", "lavfi", "-re", "-i", lavfi] if lavfi else ["-f", "pulse", "-i", src]),
             "-ac", "1", "-ar", "16000", "-t", str(maxs), "-f", "s16le", "-"],
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, preexec_fn=die_with_parent)
    if not test and is_muted("@DEFAULT_SOURCE@" if source == "default" else source):
        out({"error": "muted", "source": source})
        return
    ff = record(source, test)
    if test_fallback:
        fallback = "test"
    RATE, CHUNK = 16000, 1024                     # 64 ms per loudness reading
    pcm = bytearray()
    lock = threading.Lock()
    partial = {"busy": False, "at": 0.0, "text": ""}

    def say(obj):
        with lock:
            out(obj)

    def live_words(clip):
        port = server_port()
        text = ask_server(port, clip, timeout=10) if port else None
        if text and not stop["why"]:
            partial["text"] = text
            say({"partial": text})
        partial["busy"] = False

    # Ready means real sound, not just an open stream: a Bluetooth headset's mic
    # sends pure digital silence for a second or two while it switches into
    # headset mode, and a muted mic never sends anything else.
    # Then a simple voice detector on the loudness: learn the room's noise in
    # the first moment, speech is well above it, the end is a short pause after
    # speech. People start talking straight away, so the noise is the quietest
    # part of that moment (not its middle), capped so a voice is never taken for
    # the room, and speech already under way then counts from the start.
    floor, samples, speech_at, quiet_since, loud_run = None, [], None, None, 0
    last_emit = 0.0
    t0 = None                                     # when the mic started sending real sound
    import select
    began = time.time()                           # wall clock: a stuck mic sends no samples at all
    pending = b""
    try:
        while not stop["why"]:
            # no real sound within 4 s: the other mic, or give up (never wait forever)
            if t0 is None and time.time() - began > 4.0:
                if fallback:
                    ff.kill()
                    ff.wait()
                    ff = record(fallback, test_fallback)
                    kind, fallback, began, pcm, pending = "laptop", "", time.time(), bytearray(), b""
                    say({"switched": "laptop"})
                    continue
                stop["why"] = "silent"
                break
            if len(pending) < CHUNK * 2:
                if not select.select([ff.stdout], [], [], 0.25)[0]:
                    continue
                got = os.read(ff.stdout.fileno(), CHUNK * 8)
                if not got:
                    break
                pending += got
                if len(pending) < CHUNK * 2:
                    continue
            data, pending = pending[:CHUNK * 2], pending[CHUNK * 2:]
            pcm += data
            t = len(pcm) / 2 / RATE
            a = array.array("h", data)
            rms = math.sqrt(sum(x * x for x in a) / max(1, len(a))) / 32768
            db = 20 * math.log10(rms) if rms > 0 else -90.0
            if t0 is None:
                if db > -85.0:
                    t0 = t
                    say({"ready": True, "mic": kind})     # you can talk now
                continue
            if t - t0 < 0.3:
                samples.append(db)
                continue
            if floor is None:
                quiet = sorted(samples)[len(samples) // 5] if samples else -55.0
                floor = min(-40.0, max(-62.0, quiet))
                if sum(1 for s in samples if s > min(floor + 13, -35.0)) >= 3:
                    speech_at = t0
                    say({"speech": True})
            # until you speak, the room's level keeps settling lower: the gaps
            # between words show it if you were already talking at the start
            if speech_at is None and db < floor:
                floor = max(-62.0, db)
            loud = db > floor + 13
            loud_run = loud_run + 1 if loud else 0
            if speech_at is None and loud_run >= 3:
                speech_at = t
                say({"speech": True})
            if speech_at is not None:
                if db < floor + 7:
                    quiet_since = quiet_since if quiet_since is not None else t
                    if t - quiet_since >= 0.7 and t - speech_at > 0.6:
                        break
                else:
                    quiet_since = None
                # your words so far, about every 0.8 s, while the warm server keeps up
                if not partial["busy"] and t - partial["at"] >= 0.8 and t - speech_at >= 0.6 and not fake:
                    partial.update(busy=True, at=t)
                    start = int(max(0.0, min(speech_at - 0.4, t0)) * RATE) * 2
                    threading.Thread(target=live_words, args=(bytes(pcm[start:]),), daemon=True).start()
            elif t - t0 > 7.0:
                stop["why"] = "nothing"
                break
            if t - last_emit >= 0.06:
                last_emit = t
                say({"level": round(max(0.0, min(1.0, (db - floor) / 30)), 2)})
    finally:
        ff.terminate()
        try:
            ff.wait(timeout=3)
        except subprocess.TimeoutExpired:
            ff.kill()
    stop_why = stop["why"]
    stop["why"] = stop_why or "done"              # no more live words after this
    if stop_why == "cancel":
        say({"error": "cancelled"})
        return
    if speech_at is None:
        say({"error": "silent" if stop_why == "silent" else "nothing"})
        return
    say({"state": "transcribing"})
    if fake:
        say({"heard": "test: speech from %.1fs" % speech_at})
        return
    # from when the mic came alive (or just before speech): quiet first words
    # that the detector only noticed late are still in it
    clip = bytes(pcm[int(max(0.0, min(speech_at - 0.4, t0)) * RATE) * 2:])
    port = server_port()
    text = ask_server(port, clip) if port else None
    if text is None:                              # no warm server: whisper-cli on a file in RAM
        os.makedirs(RUN, mode=0o700, exist_ok=True)
        wav = os.path.join(RUN, "heard-%d.wav" % os.getpid())
        with open(wav, "wb") as f:
            f.write(wav_bytes(louder(clip)))
        try:
            r = subprocess.run([b, "-m", model, "-f", wav, "-nt", "-np", "-l", lang, "-t", threads(),
                                *(["--prompt", PROMPT["text"]] if PROMPT["text"] else [])],
                               capture_output=True, text=True, timeout=90, env=gpu_env(), preexec_fn=die_with_parent)
            text = clean(r.stdout)
        except (OSError, subprocess.TimeoutExpired) as e:
            text = ""
            say({"error": "whisper: " + str(e)})
        _rm(wav)
    say({"heard": text} if text else {"error": "nothing"})


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
                           "-t", "30", "-y", wav], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, bufsize=1, preexec_fn=die_with_parent)
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


def cmd_wake(args=()):
    b, model = stt_bin(), wake_model()
    test = os.environ.get("HALO_VOICE_TEST", "")
    if (not b or not model) and not test:
        out({"error": "no-stt"})
        return
    stop = {"now": False}
    signal.signal(signal.SIGTERM, lambda *_: stop.update(now=True))
    mic = "--mic" in args and args[args.index("--mic") + 1] or "auto"
    src = ["-f", "lavfi", "-re", "-i", test] if test else ["-f", "pulse", "-i", pick_mic(mic)[0]]
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
            r = subprocess.run([b, "-m", model, "-f", wav, "-nt", "-np", "-l", "en", "-t", "2"], capture_output=True, text=True, timeout=30, preexec_fn=die_with_parent)
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
                             stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, text=True, preexec_fn=die_with_parent)
        procs.append(p)
        p.communicate(text)
    elif shutil.which("espeak-ng"):
        voice = "en-gb-x-rp" if hint == "uk" else "en-us"
        p = subprocess.Popen(["espeak-ng", "-v", voice, "-s", str(int(168 * rate)), "-p", "42", "-w", wav, text],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, preexec_fn=die_with_parent)
        procs.append(p)
        p.wait()
    else:
        return
    if os.path.exists(wav):
        # The mouth: how loud each 40 ms is, so Halo's lips move with the words
        out({"env": envelope(wav, 40), "step": 40})
        p = subprocess.Popen(["pw-play", "--volume", "0.8", wav], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, preexec_fn=die_with_parent)
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
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", "16000", "-y", wav], check=True, timeout=600, preexec_fn=die_with_parent)
        threads = str(max(2, min(8, (os.cpu_count() or 4) - 2)))
        r = subprocess.run([b, "-m", model, "-f", wav, "-nt", "-np", "-l", "en", "-t", threads], capture_output=True, text=True, timeout=7200, preexec_fn=die_with_parent)
        text = re.sub(r"\[[^\]]*\]|\([^)]*\)", " ", r.stdout)
        sys.stdout.write(re.sub(r"[ \t]+", " ", text).strip() + "\n")
    except (OSError, subprocess.SubprocessError) as e:
        sys.stderr.write(str(e) + "\n")
        sys.exit(1)
    finally:
        _rm(wav)


# ── live captions: what the speakers play, a few seconds at a time ──────────
def cmd_captions(args=()):
    sb, model = server_bin(), stt_model(model_arg(args))
    if not sb or not model:
        out({"error": "Live captions need whisper.cpp (Settings → Halo → Voice)."})
        return
    import socket
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        port = s.getsockname()[1]
    srv = subprocess.Popen([sb, "-m", model, "--host", "127.0.0.1", "--port", str(port), "-t", threads(), "-l", "en"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=gpu_env(), preexec_fn=die_with_parent)
    # the default output's monitor: what you hear, 16 kHz mono
    rec = subprocess.Popen(["parec", "--device=@DEFAULT_MONITOR@", "--format=s16le", "--rate=16000", "--channels=1",
                            "--latency-msec=200"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, preexec_fn=die_with_parent)

    def bye(*_):
        for q in (rec, srv):
            q.terminate()
        sys.exit(0)
    signal.signal(signal.SIGTERM, bye)
    signal.signal(signal.SIGINT, bye)
    deadline = time.time() + 30
    while time.time() < deadline and srv.poll() is None:
        try:
            socket.create_connection(("127.0.0.1", port), timeout=0.3).close()
            break
        except OSError:
            time.sleep(0.1)
    out({"ready": True})
    import array
    chunk = 16000 * 2 * 4                      # 4 s of 16-bit samples
    while True:
        pcm = rec.stdout.read(chunk)
        if not pcm:
            break
        a = array.array("h", pcm)
        if max((abs(x) for x in a), default=0) < 400:     # silence: nothing to say
            out({"caption": ""})
            continue
        text = ask_server(port, pcm, timeout=8)
        if text:
            out({"caption": text})
    bye()


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return
    if a[0] == "status":
        cmd_status()
    elif a[0] == "serve":
        cmd_serve(a[1:])
    elif a[0] == "listen":
        cmd_listen(a[1:])
    elif a[0] == "wake":
        cmd_wake(a[1:])
    elif a[0] == "captions":
        cmd_captions(a[1:])
    elif a[0] == "transcribe" and len(a) >= 2:
        cmd_transcribe(a[1])
    elif a[0] == "say" and len(a) >= 4:
        cmd_say(a[1], a[2], " ".join(a[3:]))
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
