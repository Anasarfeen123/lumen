#!/usr/bin/env python3
"""monitor.py — Lumen Monitor's eyes: processes and hardware, from /proc and /sys.

Standard library only. Never wakes the NVIDIA dGPU: nvidia-smi runs only while
its runtime PM status already says "active".

  monitor.py static                       JSON: CPU model, cores, caches, GPUs, disks, kernel…
  monitor.py stream [--interval 1.0]      one JSON sample per line, forever (processes + hardware).
                                          procs are rows: [pid, ppid, name, uid, state, nice, threads, start,
                                          cpu %, private mem, rss, read B/s, write B/s, kernel]; "pinfo" carries
                                          {cmd, exe, user, comm} the first time a process is seen
  monitor.py detail <pid>                 JSON: one process in depth (memory, files, ports, unit…)
  monitor.py signal <pid> TERM|KILL|STOP|CONT [--tree]
  monitor.py renice <pid> <nice>          (raising priority needs root; lowering doesn't)
  monitor.py startup                      JSON: autostart entries and enabled user services
  monitor.py startup-set <kind> <id> on|off
  monitor.py services                     JSON: user services, and running system services
  monitor.py service <unit> start|stop|restart     (user services only)
"""
import argparse
import glob
import json
import os
import pwd
import re
import signal as sig
import socket
import subprocess
import sys
import time

PAGE = os.sysconf("SC_PAGE_SIZE")
HZ = os.sysconf("SC_CLK_TCK")
NCPU = os.cpu_count() or 1
ME = os.getuid()
REAL_FS = {"ext4", "ext3", "btrfs", "xfs", "vfat", "exfat", "ntfs", "ntfs3", "f2fs", "fuseblk", "zfs", "bcachefs"}


def out(obj):
    sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def read(path, default=""):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return default


def readint(path, default=None):
    try:
        return int(read(path).strip())
    except ValueError:
        return default


def run(cmd, timeout=5):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


_users = {}


def user(uid):
    if uid not in _users:
        try:
            _users[uid] = pwd.getpwuid(uid).pw_name
        except KeyError:
            _users[uid] = str(uid)
    return _users[uid]


def boot_time():
    for line in read("/proc/stat").splitlines():
        if line.startswith("btime"):
            return int(line.split()[1])
    return 0


BOOT = boot_time()


# ── static ──────────────────────────────────────────────────────────────────

def gpus():
    out_ = []
    for dev in sorted(glob.glob("/sys/class/drm/card[0-9]")):
        d = dev + "/device"
        vendor = read(d + "/vendor").strip()
        if not vendor:
            continue
        slot = os.path.basename(os.path.realpath(d))
        name = ""
        line = run(["lspci", "-mm", "-s", slot])
        m = re.findall(r'"([^"]*)"', line)
        if len(m) >= 3:
            name = re.sub(r"\[(.+)\]", r"\1", m[2]).strip()
        kind = {"0x1002": "amd", "0x10de": "nvidia", "0x8086": "intel"}.get(vendor, "other")
        vram = readint(d + "/mem_info_vram_total")
        out_.append({"card": os.path.basename(dev), "kind": kind, "name": name or kind.upper(), "slot": slot,
                     "vramTotal": vram})
    return out_


def cpu_static():
    model, cores = "", set()
    for block in read("/proc/cpuinfo").split("\n\n"):
        f = dict((k.strip(), v.strip()) for k, _, v in (l.partition(":") for l in block.splitlines()) if k)
        model = model or f.get("model name", "")
        if "core id" in f:
            cores.add((f.get("physical id", "0"), f["core id"]))
    caches = {}
    for idx in glob.glob("/sys/devices/system/cpu/cpu0/cache/index*"):
        lvl = read(idx + "/level").strip()
        typ = read(idx + "/type").strip()
        size = read(idx + "/size").strip()
        key = "L" + lvl + ("d" if typ == "Data" else "i" if typ == "Instruction" else "")
        caches[key] = size
    maxf = readint("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq")
    minf = readint("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq")
    return {"model": model, "cores": len(cores) or NCPU, "threads": NCPU, "caches": caches,
            "maxMHz": maxf // 1000 if maxf else None, "minMHz": minf // 1000 if minf else None,
            "virt": "svm" if " svm" in read("/proc/cpuinfo") else "vmx" if " vmx" in read("/proc/cpuinfo") else ""}


def disks_static():
    res = []
    for b in sorted(os.listdir("/sys/block")):
        if re.match(r"^(loop|ram|dm-|sr|md)", b):
            continue
        size = (readint("/sys/block/%s/size" % b) or 0) * 512
        if size == 0:
            continue
        model = read("/sys/block/%s/device/model" % b).strip()
        rot = readint("/sys/block/%s/queue/rotational" % b)
        kind = "zram" if b.startswith("zram") else "nvme" if b.startswith("nvme") else "hdd" if rot == 1 else "ssd"
        res.append({"dev": b, "model": model or ("Compressed swap in RAM" if kind == "zram" else b), "size": size,
                    "kind": kind, "removable": readint("/sys/block/%s/removable" % b) == 1})
    return res


def cmd_static(a):
    u = os.uname()
    os_name = ""
    for line in read("/etc/os-release").splitlines():
        if line.startswith("PRETTY_NAME="):
            os_name = line.split("=", 1)[1].strip('"')
    mem = meminfo()
    out({"host": socket.gethostname(), "os": os_name, "kernel": u.release, "arch": u.machine,
         "cpu": cpu_static(), "gpus": gpus(), "disks": disks_static(), "memTotal": mem.get("MemTotal", 0) * 1024,
         "boot": BOOT, "pageSize": PAGE, "uid": ME})


# ── sampling ────────────────────────────────────────────────────────────────

def meminfo():
    m = {}
    for line in read("/proc/meminfo").splitlines():
        k, _, v = line.partition(":")
        try:
            m[k] = int(v.split()[0])
        except (ValueError, IndexError):
            pass
    return m


def cpu_times():
    res = []
    for line in read("/proc/stat").splitlines():
        if line.startswith("cpu"):
            p = line.split()
            vals = list(map(int, p[1:9]))
            idle = vals[3] + vals[4]
            res.append((sum(vals), idle))
    return res  # [total, cpu0, cpu1…]


def hwmon_temps():
    res = []
    for h in glob.glob("/sys/class/hwmon/hwmon*"):
        name = read(h + "/name").strip()
        for t in sorted(glob.glob(h + "/temp*_input")):
            v = readint(t)
            if v is None:
                continue
            label = read(t.replace("_input", "_label")).strip()
            crit = readint(t.replace("_input", "_crit"))
            res.append({"chip": name, "label": label or name, "c": round(v / 1000, 1),
                        "crit": round(crit / 1000) if crit else None})
    return res


def amd_gpu(card):
    d = "/sys/class/drm/%s/device" % card
    busy = readint(d + "/gpu_busy_percent")
    used = readint(d + "/mem_info_vram_used")
    total = readint(d + "/mem_info_vram_total")
    gtt = readint(d + "/mem_info_gtt_used")
    temp, power, freq = None, None, None
    for h in glob.glob(d + "/hwmon/hwmon*"):
        t = readint(h + "/temp1_input")
        temp = round(t / 1000, 1) if t else None
        p = readint(h + "/power1_average") or readint(h + "/power1_input")
        power = round(p / 1e6, 1) if p else None
    for line in read(d + "/pp_dpm_sclk").splitlines():
        if "*" in line:
            m = re.search(r"(\d+)\s*Mhz", line, re.I)
            freq = int(m.group(1)) if m else None
    return {"state": "active", "util": busy, "vramUsed": used, "vramTotal": total, "gtt": gtt,
            "temp": temp, "power": power, "mhz": freq}


_nv_cache = {"t": 0, "v": None}


def nvidia_gpu(card):
    d = "/sys/class/drm/%s/device" % card
    state = read(d + "/power/runtime_status").strip() or "unknown"
    res = {"state": state}
    if state != "active":
        return res   # asleep: asking would wake it
    now = time.time()
    if now - _nv_cache["t"] > 1.8:
        line = run(["nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,clocks.gr",
                    "--format=csv,noheader,nounits"], timeout=3).strip()
        v = None
        if line:
            p = [x.strip() for x in line.split(",")]
            def f(x):
                try:
                    return float(x)
                except ValueError:
                    return None
            v = {"util": f(p[0]), "vramUsed": f(p[1]) and f(p[1]) * 1048576, "vramTotal": f(p[2]) and f(p[2]) * 1048576,
                 "temp": f(p[3]), "power": f(p[4]), "mhz": f(p[5])}
        _nv_cache.update(t=now, v=v)
    res.update(_nv_cache["v"] or {})
    return res


def battery():
    for b in glob.glob("/sys/class/power_supply/BAT*"):
        e_now = readint(b + "/energy_now") or readint(b + "/charge_now")
        e_full = readint(b + "/energy_full") or readint(b + "/charge_full")
        e_design = readint(b + "/energy_full_design") or readint(b + "/charge_full_design")
        p = readint(b + "/power_now")
        if p is None:
            c, v = readint(b + "/current_now"), readint(b + "/voltage_now")
            p = c * v // 1000000 if c is not None and v is not None else None
        return {"name": os.path.basename(b), "pct": readint(b + "/capacity"), "status": read(b + "/status").strip(),
                "watts": round(p / 1e6, 2) if p else 0, "energyWh": round(e_now / 1e6, 1) if e_now else None,
                "fullWh": round(e_full / 1e6, 1) if e_full else None,
                "health": round(100 * e_full / e_design) if e_full and e_design else None,
                "cycles": readint(b + "/cycle_count"), "model": read(b + "/model_name").strip(),
                "limit": readint(b + "/charge_control_end_threshold")}
    return None


def diskstats():
    res = {}
    for line in read("/proc/diskstats").splitlines():
        p = line.split()
        if len(p) < 14:
            continue
        res[p[2]] = (int(p[5]) * 512, int(p[9]) * 512, int(p[12]))  # read B, written B, io ms
    return res


def filesystems():
    seen, res = set(), []
    for line in read("/proc/mounts").splitlines():
        dev, mnt, fs = line.split()[:3]
        mnt = mnt.replace("\\040", " ")
        if fs not in REAL_FS or dev in seen or mnt.startswith(("/snap", "/var/lib/flatpak")):
            continue
        seen.add(dev)
        try:
            st = os.statvfs(mnt)
        except OSError:
            continue
        size = st.f_blocks * st.f_frsize
        if size == 0:
            continue
        real = os.path.realpath(dev)
        base = os.path.basename(real)
        parent = os.path.basename(os.path.dirname(os.path.realpath("/sys/class/block/" + base))) if os.path.exists("/sys/class/block/" + base) else base
        res.append({"dev": dev, "disk": parent if parent != "block" else base, "mount": mnt, "fs": fs, "size": size,
                    "used": size - st.f_bfree * st.f_frsize, "free": st.f_bavail * st.f_frsize})
    return res


def netdev():
    res = {}
    for line in read("/proc/net/dev").splitlines()[2:]:
        name, _, rest = line.partition(":")
        name = name.strip()
        p = rest.split()
        if name == "lo" or len(p) < 9:
            continue
        res[name] = (int(p[0]), int(p[8]))
    return res


def net_meta():
    meta = {}
    try:
        addrs = json.loads(run(["ip", "-j", "addr"]) or "[]")
    except ValueError:
        addrs = []
    for a in addrs:
        n = a.get("ifname")
        if not n or n == "lo":
            continue
        kind = "wifi" if os.path.exists("/sys/class/net/%s/wireless" % n) else \
               "vpn" if re.match(r"^(tun|wg|tailscale|CloudflareWARP)", n) else \
               "virtual" if re.match(r"^(docker|br-|veth|virbr|vnet)", n) or not os.path.exists("/sys/class/net/%s/device" % n) else "ethernet"
        if n.startswith(("bnep", "enx", "usb")) or os.path.exists("/sys/class/net/%s/device/../../bluetooth" % n):
            kind = "phone" if n.startswith(("bnep", "usb", "enx")) else kind
        speed = readint("/sys/class/net/%s/speed" % n)
        meta[n] = {"kind": kind, "up": a.get("operstate") in ("UP", "UNKNOWN") and bool(a.get("addr_info")),
                   "mac": a.get("address", ""),
                   "v4": [x["local"] for x in a.get("addr_info", []) if x.get("family") == "inet"],
                   "v6": [x["local"] for x in a.get("addr_info", []) if x.get("family") == "inet6" and x.get("scope") == "global"],
                   "speed": speed if speed and speed > 0 else None}
    ssid = run(["sh", "-c", "nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes:' | head -1 | cut -d: -f2-"]).strip()
    for n, m in meta.items():
        if m["kind"] == "wifi" and ssid:
            m["ssid"] = ssid
    return meta


def windows():
    try:
        clients = json.loads(run(["hyprctl", "-j", "clients"], timeout=2) or "[]")
    except ValueError:
        return {}
    res = {}
    for c in clients:
        pid = c.get("pid")
        if pid and pid > 0 and pid not in res:
            res[pid] = {"class": c.get("class") or c.get("initialClass") or "", "title": c.get("title", "")}
    return res


class Procs:
    """Per-process sampling, with the state needed for rates."""

    def __init__(self):
        self.prev = {}        # pid → (cpu ticks, read B, write B, t)
        self.static = {}      # (pid, start) → (cmdline, exe)
        self.sent = set()     # processes whose details the reader already has
        self.new = {}         # pid → details, sent once

    def sample(self, now):
        res, seen = [], {}
        for e in os.scandir("/proc"):
            if not e.name.isdigit():
                continue
            pid = int(e.name)
            try:
                with open("/proc/%d/stat" % pid) as f:
                    raw = f.read()
                with open("/proc/%d/statm" % pid) as f:
                    statm = f.read().split()
                uid = e.stat().st_uid
            except OSError:
                continue
            lp, rp = raw.find("("), raw.rfind(")")
            comm = raw[lp + 1:rp]
            p = raw[rp + 2:].split()
            state, ppid = p[0], int(p[1])
            ticks = int(p[11]) + int(p[12])
            nice, threads, start = int(p[16]), int(p[17]), int(p[19])
            resident, shared = int(statm[1]) * PAGE, int(statm[2]) * PAGE
            key = (pid, start)
            if key not in self.static:
                cmd = read("/proc/%d/cmdline" % pid).replace("\0", " ").strip()
                try:
                    exe = os.readlink("/proc/%d/exe" % pid)
                except OSError:
                    exe = ""
                self.static[key] = (cmd[:400], exe)
            cmd, exe = self.static[key]
            rb = wb = None
            if uid == ME:
                for line in read("/proc/%d/io" % pid).splitlines():
                    if line.startswith("read_bytes:"):
                        rb = int(line.split()[1])
                    elif line.startswith("write_bytes:"):
                        wb = int(line.split()[1])
            cpu = rd = wr = 0.0
            pr = self.prev.get(key)
            if pr:
                dt = max(1e-3, now - pr[3])
                cpu = max(0.0, (ticks - pr[0]) / HZ / dt / NCPU * 100)
                if rb is not None and pr[1] is not None:
                    rd = max(0, rb - pr[1]) / dt
                    wr = max(0, wb - pr[2]) / dt
            seen[key] = (ticks, rb, wb, now)
            kernel = ppid == 2 or pid == 2
            name = comm
            # A clearer name than the 15-character comm, from the command line
            if cmd and not kernel:
                first = os.path.basename(cmd.split(" ")[0])
                if first and first.startswith(comm[:15]) and len(first) > len(comm):
                    name = first
            # Compact rows (the list is sent every tick): see ROW in the docstring
            res.append([pid, ppid, name, uid, state, nice, threads, round(BOOT + start / HZ),
                        round(cpu, 2), max(0, resident - shared), resident, round(rd), round(wr), 1 if kernel else 0])
            if key not in self.sent:
                self.new[pid] = {"cmd": cmd, "exe": exe, "user": user(uid), "comm": comm}
        self.prev = seen
        live = set(seen)
        self.static = {k: v for k, v in self.static.items() if k in live}
        self.sent = live
        return res

    def take_new(self):
        n, self.new = self.new, {}
        return n


def cmd_stream(a):
    procs = Procs()
    prev_cpu = cpu_times()
    prev_disk, prev_net = diskstats(), netdev()
    prev_t = time.time()
    procs.sample(prev_t)
    static_gpus = gpus()
    tick = 0
    meta, wins = net_meta(), windows()
    time.sleep(0.25)
    while True:
        now = time.time()
        dt = max(1e-3, now - prev_t)
        cpu = cpu_times()
        usage = []
        for (t1, i1), (t0, i0) in zip(cpu, prev_cpu):
            dtot = t1 - t0
            usage.append(round(100 * (1 - (i1 - i0) / dtot), 1) if dtot > 0 else 0.0)
        freqs = []
        for c in range(NCPU):
            f = readint("/sys/devices/system/cpu/cpu%d/cpufreq/scaling_cur_freq" % c)
            freqs.append(f // 1000 if f else None)
        m = meminfo()
        disk = diskstats()
        disks = {}
        for d in os.listdir("/sys/block"):
            if re.match(r"^(loop|ram|dm-|sr|md)", d) or d not in disk or d not in prev_disk:
                continue
            r0, w0, io0 = prev_disk[d]
            r1, w1, io1 = disk[d]
            disks[d] = {"read": round((r1 - r0) / dt), "write": round((w1 - w0) / dt),
                        "active": min(100, round((io1 - io0) / (dt * 10), 1)), "readTotal": r1, "writeTotal": w1}
        net = netdev()
        nets = {}
        if tick % 10 == 0:
            meta = net_meta()
        if tick % 2 == 0:
            wins = windows()
        for n, (rx, tx) in net.items():
            if n not in prev_net:
                continue
            nets[n] = dict(meta.get(n, {"kind": "other", "up": True}), rx=round((rx - prev_net[n][0]) / dt),
                           tx=round((tx - prev_net[n][1]) / dt), rxTotal=rx, txTotal=tx)
        gpu_out = []
        for g in static_gpus:
            v = amd_gpu(g["card"]) if g["kind"] == "amd" else nvidia_gpu(g["card"]) if g["kind"] == "nvidia" else {"state": "active"}
            gpu_out.append(dict(g, **v))
        plist = procs.sample(now)
        sample = {
            "t": int(now * 1000),
            "uptime": float(read("/proc/uptime").split()[0] or 0),
            "load": [float(x) for x in read("/proc/loadavg").split()[:3]],
            "cpu": usage[0] if usage else 0, "cores": usage[1:], "mhz": freqs,
            "mem": {"total": m.get("MemTotal", 0) * 1024, "available": m.get("MemAvailable", 0) * 1024,
                    "free": m.get("MemFree", 0) * 1024, "cached": (m.get("Cached", 0) + m.get("SReclaimable", 0)) * 1024,
                    "buffers": m.get("Buffers", 0) * 1024, "shared": m.get("Shmem", 0) * 1024,
                    "dirty": m.get("Dirty", 0) * 1024, "committed": m.get("Committed_AS", 0) * 1024,
                    "swapTotal": m.get("SwapTotal", 0) * 1024, "swapFree": m.get("SwapFree", 0) * 1024},
            "temps": hwmon_temps() if tick % 2 == 0 else None,
            "disks": disks, "net": nets, "gpus": gpu_out,
            "battery": battery() if tick % 2 == 0 else None,
            "fs": filesystems() if tick % 10 == 0 else None,
            "windows": {str(k): v for k, v in wins.items()},
            "procs": plist,
            "pinfo": procs.take_new(),     # command line, path, user: once per process
        }
        out(sample)
        prev_cpu, prev_disk, prev_net, prev_t = cpu, disk, net, now
        tick += 1
        time.sleep(max(0.1, a.interval - (time.time() - now)))


# ── one process in depth ────────────────────────────────────────────────────

def cmd_detail(a):
    pid = a.pid
    base = "/proc/%d" % pid
    if not os.path.isdir(base):
        out({"ok": False, "error": "That process has ended"})
        return
    st = {}
    for line in read(base + "/status").splitlines():
        k, _, v = line.partition(":")
        st[k] = v.strip()
    def kb(k):
        try:
            return int(st.get(k, "0 kB").split()[0]) * 1024
        except ValueError:
            return None
    raw = read(base + "/stat")
    p = raw[raw.rfind(")") + 2:].split()
    try:
        fds = len(os.listdir(base + "/fd"))
    except OSError:
        fds = None
    try:
        cwd = os.readlink(base + "/cwd")
    except OSError:
        cwd = ""
    try:
        exe = os.readlink(base + "/exe")
    except OSError:
        exe = ""
    cg = read(base + "/cgroup").strip().split("::")[-1]
    unit = (re.findall(r"/([^/]+\.(?:service|scope))", cg) or [""])[-1]
    children = []
    for e in os.scandir("/proc"):
        if e.name.isdigit():
            r = read("/proc/%s/stat" % e.name)
            q = r[r.rfind(")") + 2:].split()
            if len(q) > 1 and q[1] == str(pid):
                children.append({"pid": int(e.name), "name": r[r.find("(") + 1:r.rfind(")")]})
    ports = []
    for line in run(["ss", "-Hlntup"]).splitlines():
        if "pid=%d," % pid in line:
            f = line.split()
            ports.append({"proto": f[0], "local": f[4] if len(f) > 4 else ""})
    out({"ok": True, "pid": pid, "name": st.get("Name", ""), "state": st.get("State", ""),
         "cmd": read(base + "/cmdline").replace("\0", " ").strip(), "exe": exe, "cwd": cwd,
         "user": user(os.stat(base).st_uid), "ppid": int(st.get("PPid", "0") or 0),
         "threads": int(st.get("Threads", "0") or 0), "fds": fds,
         "rss": kb("VmRSS"), "anon": kb("RssAnon"), "file": kb("RssFile"), "shmem": kb("RssShmem"),
         "swap": kb("VmSwap"), "virt": kb("VmSize"), "peak": kb("VmHWM"),
         "cpuTime": (int(p[11]) + int(p[12])) / HZ if len(p) > 12 else None,
         "start": BOOT + int(p[19]) / HZ if len(p) > 19 else None, "nice": int(p[16]) if len(p) > 16 else None,
         "ctxVoluntary": int(st.get("voluntary_ctxt_switches", "0") or 0),
         "ctxInvoluntary": int(st.get("nonvoluntary_ctxt_switches", "0") or 0),
         "unit": unit, "cgroup": cg, "children": children[:50], "ports": ports})


def cmd_signal(a):
    signum = {"TERM": sig.SIGTERM, "KILL": sig.SIGKILL, "STOP": sig.SIGSTOP, "CONT": sig.SIGCONT}[a.sig]
    targets = [a.pid]
    if a.tree:
        kids = {}
        for e in os.scandir("/proc"):
            if e.name.isdigit():
                r = read("/proc/%s/stat" % e.name)
                q = r[r.rfind(")") + 2:].split()
                if len(q) > 1:
                    kids.setdefault(int(q[1]), []).append(int(e.name))
        i = 0
        while i < len(targets):
            targets += kids.get(targets[i], [])
            i += 1
    errors = []
    # Children first for a clean end; the parent last
    for pid in reversed(targets) if a.sig in ("TERM", "KILL") else targets:
        try:
            os.kill(pid, signum)
        except ProcessLookupError:
            pass
        except PermissionError:
            errors.append(pid)
    out({"ok": not errors, "count": len(targets), "denied": errors,
         "error": "Not allowed (it belongs to another user)" if errors else ""})


def cmd_renice(a):
    try:
        os.setpriority(os.PRIO_PROCESS, a.pid, a.nice)
        out({"ok": True})
    except PermissionError:
        out({"ok": False, "error": "Raising priority needs administrator rights"})
    except ProcessLookupError:
        out({"ok": False, "error": "That process has ended"})


# ── startup and services ────────────────────────────────────────────────────

def desktop_fields(path):
    f, in_main = {}, False
    for line in read(path).splitlines():
        if line.startswith("["):
            in_main = line.strip() == "[Desktop Entry]"
            continue
        if in_main and "=" in line:
            k, _, v = line.partition("=")
            f.setdefault(k.strip(), v.strip())
    return f


def cmd_startup(a):
    home = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    entries = {}
    for d in ["/etc/xdg/autostart", os.path.join(home, "autostart")]:
        for path in sorted(glob.glob(d + "/*.desktop")):
            entries[os.path.basename(path)] = (path, desktop_fields(path))
    items = []
    desktop = (os.environ.get("XDG_CURRENT_DESKTOP") or "Hyprland").split(":")
    for name, (path, f) in entries.items():
        only = [x for x in f.get("OnlyShowIn", "").split(";") if x]
        notin = [x for x in f.get("NotShowIn", "").split(";") if x]
        if only and not set(only) & set(desktop + ["Lumen"]):
            continue
        if set(notin) & set(desktop):
            continue
        hidden = f.get("Hidden", "").lower() == "true" or f.get("X-GNOME-Autostart-enabled", "").lower() == "false"
        items.append({"kind": "autostart", "id": name, "name": f.get("Name", name), "comment": f.get("Comment", ""),
                      "icon": f.get("Icon", ""), "exec": f.get("Exec", ""), "enabled": not hidden,
                      "user": path.startswith(home)})
    for line in run(["systemctl", "--user", "list-unit-files", "--type=service", "--state=enabled,disabled", "--no-legend"]).splitlines():
        p = line.split()
        if len(p) < 2 or "@" in p[0]:
            continue
        unitf = run(["systemctl", "--user", "show", p[0], "-p", "Description,WantedBy,FragmentPath"]).splitlines()
        sh = dict(x.split("=", 1) for x in unitf if "=" in x)
        wanted = sh.get("WantedBy", "")
        if p[1] == "disabled" and not wanted:
            continue
        if not re.search(r"default\.target|graphical-session\.target|lumen", wanted + " " + p[0]) and p[1] != "enabled":
            continue
        items.append({"kind": "service", "id": p[0], "name": sh.get("Description") or p[0], "comment": p[0],
                      "icon": "", "exec": sh.get("FragmentPath", ""), "enabled": p[1] == "enabled", "user": True})
    out(sorted(items, key=lambda x: (x["kind"] != "autostart", x["name"].lower())))


def cmd_startup_set(a):
    on = a.state == "on"
    if a.kind == "service":
        if not re.fullmatch(r"[\w@.\-]+\.service", a.id):
            out({"ok": False, "error": "bad unit"}); return
        r = subprocess.run(["systemctl", "--user", "enable" if on else "disable", a.id], capture_output=True, text=True)
        out({"ok": r.returncode == 0, "error": r.stderr.strip()})
        return
    name = os.path.basename(a.id)
    if not name.endswith(".desktop"):
        out({"ok": False, "error": "bad entry"}); return
    home = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    mine = os.path.join(home, "autostart", name)
    system = os.path.join("/etc/xdg/autostart", name)
    src = mine if os.path.exists(mine) else system
    text = read(src)
    if not text:
        out({"ok": False, "error": "entry not found"}); return
    lines = [l for l in text.splitlines() if not re.match(r"^(Hidden|X-GNOME-Autostart-enabled)\s*=", l)]
    out_lines, inserted = [], False
    for l in lines:
        out_lines.append(l)
        if l.strip() == "[Desktop Entry]" and not inserted:
            out_lines.append("Hidden=" + ("false" if on else "true"))
            inserted = True
    os.makedirs(os.path.dirname(mine), exist_ok=True)
    with open(mine, "w") as f:
        f.write("\n".join(out_lines) + "\n")
    out({"ok": True})


def cmd_services(a):
    def units(scope):
        cmd = ["systemctl"] + (["--user"] if scope == "user" else []) + \
              ["list-units", "--type=service", "--all" if scope == "user" else "--state=running", "--no-legend", "--plain", "--no-pager"]
        res = []
        for line in run(cmd).splitlines():
            p = line.split(None, 4)
            if len(p) < 4 or "@" in p[0] and scope == "system":
                continue
            if scope == "user" and p[2] == "inactive" and p[1] != "loaded":
                continue
            res.append({"id": p[0], "load": p[1], "active": p[2], "sub": p[3], "desc": p[4] if len(p) > 4 else "",
                        "scope": scope})
        return res
    user_units = [u for u in units("user") if u["load"] == "loaded"]
    mem = {}
    for u in user_units:
        if u["active"] == "active":
            s = run(["systemctl", "--user", "show", u["id"], "-p", "MemoryCurrent,MainPID"])
            d = dict(x.split("=", 1) for x in s.splitlines() if "=" in x)
            mc = d.get("MemoryCurrent", "")
            u["memory"] = int(mc) if mc.isdigit() else None
            u["pid"] = int(d.get("MainPID", "0") or 0)
    out({"user": user_units, "system": units("system")})


def cmd_service(a):
    if not re.fullmatch(r"[\w@.\-]+\.service", a.unit) or a.action not in ("start", "stop", "restart"):
        out({"ok": False, "error": "bad request"}); return
    r = subprocess.run(["systemctl", "--user", a.action, a.unit], capture_output=True, text=True, timeout=30)
    out({"ok": r.returncode == 0, "error": r.stderr.strip()})


def main():
    p = argparse.ArgumentParser(description="Lumen Monitor")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("static")
    s = sub.add_parser("stream"); s.add_argument("--interval", type=float, default=1.0)
    s = sub.add_parser("detail"); s.add_argument("pid", type=int)
    s = sub.add_parser("signal"); s.add_argument("pid", type=int); s.add_argument("sig", choices=["TERM", "KILL", "STOP", "CONT"]); s.add_argument("--tree", action="store_true")
    s = sub.add_parser("renice"); s.add_argument("pid", type=int); s.add_argument("nice", type=int)
    sub.add_parser("startup")
    s = sub.add_parser("startup-set"); s.add_argument("kind", choices=["autostart", "service"]); s.add_argument("id"); s.add_argument("state", choices=["on", "off"])
    sub.add_parser("services")
    s = sub.add_parser("service"); s.add_argument("unit"); s.add_argument("action")
    a = p.parse_args()
    try:
        globals()["cmd_" + a.cmd.replace("-", "_")](a)
    except (BrokenPipeError, KeyboardInterrupt):
        pass


if __name__ == "__main__":
    main()
