// Lumen showcase — vanilla JS. Every demo pauses when it's off screen and
// holds still when the visitor prefers reduced motion.
(() => {
  "use strict";
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const esc = s => s.replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

  // Icon font: reveal icons once it's ready (or give up after 6 s and show them anyway)
  const iconsOk = () => document.documentElement.classList.add("ms-ok");
  if (document.fonts && document.fonts.load) document.fonts.load('20px "Material Symbols Rounded"', "home").then(f => f.length ? iconsOk() : setTimeout(iconsOk, 6000), () => setTimeout(iconsOk, 6000));
  else iconsOk();

  // Run `fn` only while `el` is on screen
  function whileVisible(el, onShow, onHide) {
    if (!el) return;
    new IntersectionObserver(es => es.forEach(e => e.isIntersecting ? onShow() : onHide && onHide()), { threshold: 0.25 }).observe(el);
  }

  // ── Reveal on scroll ──
  const rvObs = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting) { e.target.classList.add("in"); rvObs.unobserve(e.target); } }),
    { rootMargin: "0px 0px -8% 0px" });
  $$(".rv").forEach(el => rvObs.observe(el));

  // ── Nav: highlight the section in view ──
  const links = $$(".topnav a.nl[href^='#']");
  const secObs = new IntersectionObserver(es => es.forEach(e => {
    if (!e.isIntersecting) return;
    links.forEach(a => a.classList.toggle("on", a.getAttribute("href") === "#" + e.target.id));
  }), { rootMargin: "-45% 0px -50% 0px" });
  links.forEach(a => { const s = $(a.getAttribute("href")); if (s) secObs.observe(s); });

  // ── Parallax (hero only, cheap) ──
  if (!reduced) {
    const par = $$("[data-parallax]");
    let ticking = false;
    addEventListener("scroll", () => {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(() => {
        const y = scrollY;
        if (y < innerHeight * 1.2) par.forEach(el => el.style.transform = `translate3d(0, ${y * parseFloat(el.dataset.parallax)}px, 0)`);
        ticking = false;
      });
    }, { passive: true });
  }

  // ── Accent picker: re-tints the whole page ──
  const accents = { ember: ["#f4ac6f", "#1d140d"], ion: ["#6cb8f5", "#0b1620"], iris: ["#b59cf5", "#170f24"], jade: ["#6fd3a8", "#0b1a13"] };
  $$(".picker button").forEach(b => b.addEventListener("click", () => {
    const [a, on] = accents[b.dataset.accent];
    document.documentElement.style.setProperty("--accent", a);
    document.documentElement.style.setProperty("--on-accent", on);
    $$(".picker button").forEach(x => x.setAttribute("aria-pressed", x === b));
  }));

  // ── The island ──
  const isl = $("#isl");
  const screen = $(".screen");
  const states = [
    { s: "clock", label: "Clock", w: 150, h: 34, t: 2600 },
    { s: "media", label: "Now playing", w: 400, h: 100, t: 3600, glow: "rgba(242, 95, 92, .55)" },
    { s: "notif", label: "Notification", w: 410, h: 104, t: 3400 },
    { s: "osd", label: "Volume", w: 250, h: 34, t: 2200 },
    { s: "usb", label: "New device", w: 330, h: 78, t: 3000 },
    { s: "drive", label: "USB drive", w: 360, h: 102, t: 3400 },
    { s: "timer", label: "Focus timer", w: 190, h: 34, t: 2800 },
  ];
  const btnWrap = $("#stateBtns");
  states.forEach((st, i) => {
    const b = document.createElement("button");
    b.textContent = st.label; b.setAttribute("role", "tab");
    b.addEventListener("click", () => { go(i); restartAuto(); });
    btnWrap.appendChild(b);
  });
  let cur = 0, autoTimer = 0, islVisible = true;
  function go(i) {
    cur = (i + states.length) % states.length;
    const st = states[cur];
    const maxW = screen.clientWidth * 0.92;
    const scale = Math.min(1, maxW / st.w);
    isl.style.setProperty("--w", Math.round(st.w * scale) + "px");
    isl.style.setProperty("--h", Math.round(st.h * (st.h > 40 ? Math.max(scale, 0.9) : 1)) + "px");
    isl.classList.toggle("big", st.h > 40);
    isl.style.setProperty("--isl-glow", st.glow || "var(--glow)");
    $$(".st", isl).forEach(el => el.classList.toggle("on", el.dataset.s === st.s));
    $$("button", btnWrap).forEach((b, j) => { b.classList.toggle("on", j === cur); b.setAttribute("aria-selected", j === cur); });
    if (st.s === "osd") { let v = 40; const tick = setInterval(() => { v += 4; $("#volb").style.width = v + "%"; $("#volv").textContent = v; if (v >= 72) clearInterval(tick); }, 90); }
  }
  function restartAuto() {
    clearTimeout(autoTimer);
    if (reduced || !islVisible) return;
    autoTimer = setTimeout(() => { go(cur + 1); restartAuto(); }, states[cur].t);
  }
  isl.addEventListener("click", () => { go(cur + 1); restartAuto(); });
  isl.addEventListener("keydown", e => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); go(cur + 1); restartAuto(); } });
  whileVisible(screen, () => { islVisible = true; restartAuto(); }, () => { islVisible = false; clearTimeout(autoTimer); });
  addEventListener("resize", () => go(cur));
  go(0);

  // Live clock + timer ring
  const clk = $("#clk");
  const tick = () => { const d = new Date(); clk.textContent = d.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" }).replace(/\s?[AP]M/i, ""); };
  tick(); setInterval(tick, 10000);
  let tsec = 24 * 60 + 12;
  setInterval(() => { tsec = tsec > 0 ? tsec - 1 : 25 * 60; $("#tval").textContent = `${Math.floor(tsec / 60)}:${String(tsec % 60).padStart(2, "0")}`; $("#tring").style.setProperty("--p", (100 - tsec / 15) + "%"); }, 1000);

  // ── Control centre ──
  const cc = $("#cc");
  $$(".qt[data-detail]", cc).forEach(tile => {
    const sub = $("[data-sub]", tile), orig = sub.textContent;
    $("[data-toggle]", tile).addEventListener("click", e => {
      e.stopPropagation();
      const on = tile.classList.toggle("on");
      sub.textContent = on ? orig : "Off";
      $(".disc .ms", tile).textContent = tile.dataset.detail === "wifi" ? (on ? "wifi" : "wifi_off") : (on ? "bluetooth" : "bluetooth_disabled");
    });
    const open = () => { cc.classList.add("detail-open"); $$(".detail", cc).forEach(d => d.style.display = d.dataset.panel === tile.dataset.detail ? "" : "none"); $("[data-back]", $(`[data-panel=${tile.dataset.detail}]`, cc)).focus(); };
    tile.addEventListener("click", open);
    tile.addEventListener("keydown", e => { if (e.key === "Enter" || e.key === "ArrowRight") { e.preventDefault(); open(); } });
  });
  $$("[data-back]", cc).forEach(b => b.addEventListener("click", () => { cc.classList.remove("detail-open"); $(".qt", cc).focus(); }));
  $$("[data-more]", cc).forEach(b => b.addEventListener("click", e => { e.stopPropagation(); b.closest(".row").classList.toggle("open"); }));
  $$(".row", cc).forEach(r => r.addEventListener("keydown", e => { if (e.key === "Enter") r.click(); }));
  $$("[data-pair]", cc).forEach(r => r.addEventListener("click", async () => {
    if (r.dataset.state) return;
    r.dataset.state = "pairing";
    const sub = $(".sub", r), lead = $(".lead", r);
    sub.textContent = "Pairing…"; lead.classList.add("pulse");
    await sleep(1400);
    sub.textContent = "Connected"; lead.classList.remove("pulse"); r.classList.add("cur");
    $(".trail", r).innerHTML = '<span class="ms">check</span>';
  }));
  $$(".rt", cc).forEach(b => b.addEventListener("click", () => { const on = b.classList.toggle("on"); b.setAttribute("aria-pressed", on); }));

  // ── Device alerts ──
  const devEvents = [
    { card: true, icon: "keyboard", t: "Keychron K2", badge: "New", s: "Keyboard · connected by USB" },
    { card: true, icon: "hard_drive", t: "BACKUP", s: "USB drive · 63.9 GB · EXFAT", acts: [["folder_open", "Open"], ["eject", "Eject"]] },
    { pill: true, icon: "mouse", t: "MX Master 3S", s: "Connected" },
    { card: true, icon: "desktop_windows", t: "Dell U2723QE", badge: "New", s: "Display connected · HDMI-A-1", acts: [["tune", "Arrange"]] },
    { card: true, icon: "headphones", t: "WH-1000XM5", badge: "New", s: "Paired over Bluetooth · 80% battery" },
    { pill: true, icon: "usb_off", t: "Logitech G305", s: "Disconnected" },
    { pill: true, icon: "eject", t: "BACKUP", s: "Safe to remove" },
    { card: true, icon: "smartphone", t: "Pixel 8", s: "Phone or camera · connected by USB" },
  ];
  const devs = $("#devs");
  let di = 0, devTimer = 0;
  function pushDev() {
    const ev = devEvents[di++ % devEvents.length];
    const el = document.createElement("div");
    if (ev.pill) {
      el.className = "pillnote glass";
      el.innerHTML = `<span class="ms f">${ev.icon}</span><b>${esc(ev.t)}</b><span class="muted">${esc(ev.s)}</span>`;
    } else {
      el.className = "dcard glass";
      el.innerHTML = `<div class="tile52"><span class="ms f">${ev.icon}</span></div><div><div class="t">${esc(ev.t)}${ev.badge ? `<span class="badge">${ev.badge}</span>` : ""}</div><div class="s">${esc(ev.s)}</div>${ev.acts ? `<div class="chips">${ev.acts.map((a, i) => `<span class="chip${i ? "" : " p"}"><span class="ms">${a[0]}</span>${a[1]}</span>`).join("")}</div>` : ""}</div>`;
    }
    el.animate([{ opacity: 0, transform: "translateY(-16px) scale(.96)" }, { opacity: 1, transform: "none" }], { duration: reduced ? 1 : 520, easing: "cubic-bezier(0.34,1.36,0.64,1)" });
    devs.prepend(el);
    while (devs.children.length > 3) devs.lastElementChild.remove();
  }
  for (let i = 0; i < 3; i++) pushDev();
  whileVisible(devs, () => { clearInterval(devTimer); if (!reduced) devTimer = setInterval(pushDev, 2600); }, () => clearInterval(devTimer));

  // ── Overview search: a typing demo ──
  const ico = (g, sel) => `<span class="ic"><span class="ms${sel ? " f" : ""}">${g}</span></span>`;
  const queries = [
    { q: "volume 40", groups: [["Actions", [["volume_down", "Set volume to 40%", "Currently 62%", "Enter"]]], ["Settings", [["volume_up", "Sound", "Output, input, per-app volume", ""]]]] },
    { q: "open project lumen", groups: [["Projects", [["folder_code", "Open lumen", "~/Projects/lumen · editor + terminal", "Enter"], ["terminal", "Terminal in lumen", "kitty --directory ~/Projects/lumen", ""]]]] },
    { q: "timer 25m", groups: [["Timers", [["timer", "Start a 25 minute timer", "Shows in the island", "Enter"], ["hourglass_top", "Focus: 25/5 cycle", "Deep work mode", ""]]]] },
    { q: "= 23*4", groups: [["Maths", [["calculate", "92", "23 × 4 · Enter copies", "Enter"]]]] },
    { q: "fire", groups: [["Apps", [["language", "Firefox", "Web browser", "Enter"]]], ["Windows", [["web_asset", "Firefox — GitHub", "Workspace 2", ""]]], ["Settings", [["shield", "Security", "Firewall, SSH, encryption", ""]]]] },
  ];
  const qEl = $("#q"), rEl = $("#results");
  let searchRun = 0;
  function renderResults(groups) {
    let first = true;
    rEl.innerHTML = groups.map(([g, rows]) => `<div class="gl">${g}</div>` + rows.map(r => {
      const sel = first; first = false;
      return `<div class="res${sel ? " sel" : ""}">${ico(r[0], sel)}<div><b>${esc(r[1])}</b><span>${esc(r[2])}</span></div>${r[3] ? `<span class="kbd">${r[3]}</span>` : "<span></span>"}</div>`;
    }).join("")).join("");
  }
  async function searchLoop(run) {
    for (let i = 0; searchRun === run; i = (i + 1) % queries.length) {
      const { q, groups } = queries[i];
      for (let k = 1; k <= q.length && searchRun === run; k++) { qEl.textContent = q.slice(0, k); await sleep(65 + Math.random() * 60); }
      renderResults(groups);
      await sleep(2300);
      for (let k = q.length; k >= 0 && searchRun === run; k--) { qEl.textContent = q.slice(0, k); await sleep(18); }
      rEl.innerHTML = "";
      await sleep(250);
    }
  }
  if (reduced) { qEl.textContent = queries[0].q; renderResults(queries[0].groups); }
  else whileVisible($(".search"), () => searchLoop(++searchRun), () => searchRun++);

  // ── Clipboard filters ──
  $$("#cfilters button").forEach(b => b.addEventListener("click", () => {
    $$("#cfilters button").forEach(x => x.classList.toggle("on", x === b));
    $$(".ci").forEach(c => c.classList.toggle("hide", b.dataset.k !== "all" && c.dataset.k !== b.dataset.k));
  }));

  // ── Focus modes ──
  const modes = [
    { id: "deep", icon: "psychology", label: "Deep work", min: 25, phase: "Focus", does: ["Notifications held until the break", "Wallpaper dimmed", "Screen stays awake", "25 / 5 Pomodoro in the island"] },
    { id: "study", icon: "school", label: "Study", min: 50, phase: "Study", does: ["Notifications held", "Planner opens with today's to-dos", "50 / 10 cycle with a chime", "Wallpaper dimmed"] },
    { id: "game", icon: "sports_esports", label: "Game", min: 0, phase: "Playing", does: ["Performance power profile", "Window effects off", "Notifications held", "Tearing allowed in fullscreen"] },
    { id: "sleep", icon: "bedtime", label: "Sleep", min: 0, phase: "Quiet", does: ["Everything silent", "Warm night light", "Shorter banners after sunset", "Runs on a schedule"] },
    { id: "work", icon: "work", label: "Work", min: 0, phase: "Work", does: ["Only apps you allow get through", "Runs 9–5 on weekdays", "Everything else waits in history"] },
    { id: "dnd", icon: "do_not_disturb_on", label: "Do not disturb", min: 0, phase: "Quiet", does: ["No banners or sounds", "Notifications kept in history"] },
  ];
  const modesEl = $("#modes"), checks = $("#checks"), bring = $("#bring");
  let focusTimer = 0, mode = modes[0];
  function setMode(m) {
    mode = m;
    $$(".mode", modesEl).forEach(b => { b.classList.toggle("on", b.dataset.id === m.id); b.setAttribute("aria-selected", b.dataset.id === m.id); });
    checks.innerHTML = m.does.map((d, i) => `<li style="animation-delay:${i * 70}ms"><span class="ms">check_circle</span>${esc(d)}</li>`).join("");
    $("#bphase").textContent = m.phase;
    clearInterval(focusTimer);
    if (m.min) {
      let s = m.min * 60;
      const total = s;
      const upd = () => { $("#btime").textContent = `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`; bring.style.setProperty("--p", ((1 - s / total) * 100).toFixed(1)); };
      upd();
      if (!reduced) focusTimer = setInterval(() => { s = Math.max(0, s - 7); upd(); if (!s) s = total; }, 120);   // demo speed
    } else { $("#btime").innerHTML = `<span class="ms f" style="font-size:34px;color:var(--accent)">${m.icon}</span>`; bring.style.setProperty("--p", 100); }
  }
  modes.forEach(m => {
    const b = document.createElement("button");
    b.className = "mode"; b.dataset.id = m.id; b.setAttribute("role", "tab");
    b.innerHTML = `<span class="ms">${m.icon}</span>${m.label}`;
    b.addEventListener("click", () => setMode(m));
    modesEl.appendChild(b);
  });
  setMode(modes[0]);

  // ── Context meters jitter ──
  const meters = $$("#meters .meter");
  whileVisible($("#meters"), () => {
    if (reduced) return;
    meters.t = setInterval(() => {
      const cpu = 8 + Math.round(Math.random() * 30), gpu = 3 + Math.round(Math.random() * 14), tmp = 46 + Math.round(Math.random() * 12);
      [[0, cpu + "%", cpu], [1, gpu + "%", gpu], [3, tmp + "°", tmp]].forEach(([i, txt, v]) => { $("b", meters[i]).textContent = txt; $("i", meters[i]).style.setProperty("--m", v + "%"); });
    }, 1400);
  }, () => clearInterval(meters.t));

  // ── Lumen Halo: a scripted conversation ──
  const hbody = $("#hbody"), htxt = $("#htxt"), wrapH = $("#haloWrap"), smenu = $("#slashmenu");
  const convos = [
    { ask: "/explain", show: "📎 selection · /explain",
      ans: 'That error means <b>the port is already in use</b>: another process is listening on <code>:8080</code>.<br><br><b>Fix it:</b> find the process, then stop it or use another port.<pre>ss -ltnp | grep 8080</pre>',
      acts: [["content_copy", "Copy"], ["input", "Insert"], ["terminal", "Run in terminal"]] },
    { ask: "/cmd find the biggest files in Downloads", show: "/cmd find the biggest files in Downloads",
      ans: "Lists the 15 largest files and folders, biggest first. It only reads; nothing is deleted.<pre>du -ah ~/Downloads | sort -rh | head -n 15</pre>",
      acts: [["terminal", "Run in terminal"], ["content_copy", "Copy"]] },
    { ask: "/diagnose why is my Wi-Fi slow?", show: "/diagnose why is my Wi-Fi slow?",
      ans: "I checked NetworkManager and the last hour of logs:<br>• You're on <b>Home-5G</b> at <b>2.4 GHz</b>, 38% signal: the 5 GHz band would be faster here.<br>• <code>systemd-resolved</code> restarted 3 times: DNS may be stalling.<br>• No failed services, disk and memory are fine.",
      acts: [["content_copy", "Copy"], ["note_add", "Save to notes"]] },
    { ask: "/translate to Spanish", show: "📎 selection · /translate to Spanish",
      ans: "«Nos vemos a las siete en la estación; lleva el paraguas por si acaso.»",
      acts: [["content_copy", "Copy"], ["input", "Insert"]] },
  ];
  let haloRun = 0;
  async function typeInto(el, text, run, speed = 45) {
    for (let k = 1; k <= text.length; k++) { if (haloRun !== run) return false; el.textContent = text.slice(0, k); await sleep(speed + Math.random() * 30); }
    return true;
  }
  async function stream(el, html, run) {
    // reveal word by word, keeping tags intact
    const parts = html.split(/(<[^>]+>|\s+)/).filter(x => x !== "");
    let out = "";
    for (const p of parts) {
      if (haloRun !== run) return false;
      out += p; el.innerHTML = out;
      if (!p.startsWith("<") && p.trim()) await sleep(28 + Math.random() * 30);
    }
    return true;
  }
  async function haloLoop(run) {
    for (let i = 0; haloRun === run; i = (i + 1) % convos.length) {
      const c = convos[i];
      if (i === 0) hbody.innerHTML = "";
      while (hbody.children.length > 2) hbody.firstElementChild.remove();
      htxt.textContent = "";
      await sleep(500);
      if (!(await typeInto(htxt, "/", run))) return;
      smenu.classList.add("on");
      const key = c.ask.split(" ")[0];
      $$("div", smenu).forEach(d => d.classList.toggle("sel", $("code", d).textContent === key));
      await sleep(900);
      smenu.classList.remove("on");
      if (!(await typeInto(htxt, c.ask, run))) return;
      await sleep(350);
      htxt.innerHTML = '<span class="muted">Ask a follow-up</span>';
      const me = document.createElement("div"); me.className = "bub me"; me.textContent = c.show; hbody.appendChild(me);
      const ai = document.createElement("div"); ai.className = "bub ai"; ai.innerHTML = '<span class="typing"><i></i><i></i><i></i></span>'; hbody.appendChild(ai);
      wrapH.classList.add("thinking");
      await sleep(1500);
      const body = document.createElement("div"); ai.innerHTML = ""; ai.appendChild(body);
      if (!(await stream(body, c.ans, run))) { wrapH.classList.remove("thinking"); return; }
      wrapH.classList.remove("thinking");
      const acts = document.createElement("div"); acts.className = "acts";
      acts.innerHTML = c.acts.map((a, j) => `<span class="chip${j ? "" : " p"}"><span class="ms">${a[0]}</span>${a[1]}</span>`).join("");
      ai.appendChild(acts);
      acts.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 300 });
      await sleep(3200);
    }
  }
  if (reduced) {
    hbody.innerHTML = `<div class="bub me">${convos[0].show}</div><div class="bub ai">${convos[0].ans}</div>`;
  } else whileVisible(wrapH, () => haloLoop(++haloRun), () => { haloRun++; wrapH.classList.remove("thinking"); });

  // ── Settings mock ──
  const pages = [
    ["Personalise", [["palette", "Appearance", "Theme, accent style and intensity, glass, animation speed, icons and sounds.",
        [["dark_mode", "Theme", "Dark · Midnight · OLED · Light", "Dark"], ["colors", "Accent", "Taken from your wallpaper", "Wallpaper"], ["tune", "Accent style", "How strongly the accent tints", "Adaptive"], ["blur_on", "Glass", "Frosted panels and windows", "60%"], ["wb_twilight", "Adapt to the time of day", "Warmer and calmer after sunset", "On"]]],
      ["wallpaper", "Wallpaper", "Pick a picture; the accent follows it.", [["collections", "Library", "~/Pictures/Wallpapers, by folder", "42"], ["schedule", "By time of day", "Dawn · day · dusk · night", "Off"]]],
      ["top_panel_open", "Bar & Island", "What the bar and island show.", [["calendar_today", "Date in the island", "", "On"], ["pip", "Hot corners", "Overview and control centre", "On"]]],
      ["select_window", "Windows", "Gaps, corners, borders, animation and snapshots.", [["padding", "Gaps", "", "Normal"], ["rounded_corner", "Corners", "", "Round"], ["bookmarks", "Snapshots", "coding · writing", "2 saved"]]]]],
    ["Connections", [["wifi", "Network", "Wi-Fi, VPN and WARP.", [["wifi", "Wi-Fi", "Home-5G", "On"], ["vpn_lock", "WARP", "Cloudflare", "Off"]]],
      ["bluetooth", "Bluetooth", "Devices and their batteries.", [["headphones", "WH-1000XM5", "80% battery", "Connected"]]],
      ["smartphone", "Phone", "Lumen Connect through KDE Connect.", [["smartphone", "Pixel 8", "Battery 64%", "Paired"]]]]],
    ["Devices", [["volume_up", "Sound", "Output, input and your music app.", [["speaker", "Output", "Speakers", ""], ["music_note", "Music app", "YouTube Music", ""]]],
      ["brightness_6", "Display", "Brightness and night light.", [["nightlight", "Night light", "Sunset to sunrise", "Auto"]]],
      ["keyboard", "Keyboard & Gestures", "Every shortcut, read live from the config.", [["keyboard", "Shortcuts", "78 bindings", ""], ["swipe", "Gestures", "3 and 4 fingers", ""]]],
      ["battery_charging_80", "Power", "Profiles, charge limit and idle.", [["battery_saver", "Charge limit", "Stop at 80%", "On"], ["bedtime", "Sleep after", "30 minutes on battery", ""]]]]],
    ["Focus & privacy", [["notifications", "Notifications", "Focus modes, schedules and per-app rules.", [["do_not_disturb_on", "Focus", "Deep work · Study · Game · Sleep", ""], ["schedule", "Sleep schedule", "23:00 – 07:00", "On"]]],
      ["lock", "Lock screen", "Widgets and picture.", [["music_note", "Now playing", "", "On"], ["notifications", "Notification counts", "Never their content", "On"]]],
      ["face", "Face ID", "Unlock the lock screen with Gaze.", [["face", "Face ID", "Lock screen only", "On"], ["bolt", "On battery", "Press F2 to scan", ""]]],
      ["shield", "Security", "A read-only health check.", [["local_fire_department", "Firewall", "FedoraWorkstation", "Active"], ["lock", "Disk encryption", "LUKS", "On"], ["verified_user", "Secure Boot", "", "Enabled"]]]]],
    ["System", [["auto_awesome", "Halo", "Lumen Halo, your assistant.", [["memory", "Answers from", "Local · gemma3:4b", "Ollama"], ["download", "Models", "Pull or remove local models", ""], ["shield_lock", "Privacy", "Nothing is saved", ""]]],
      ["monitor_heart", "System", "Hardware and live use.", [["memory", "Processor", "Ryzen 7 · 16 threads", ""], ["developer_board", "Graphics", "Radeon 740M + RTX 3050", ""]]],
      ["system_update", "Updates", "dnf and Flatpak, installed when you say.", [["system_update", "12 updates", "3 security", "Review"]]],
      ["code", "Advanced", "The machinery, when you need it.", [["description", "Config files", "hyprland.lua · local.lua · tokens.toml", "Open"], ["fact_check", "Verify config", "No errors · contrast AA", "Check"], ["article", "Logs", "Shell, startup, Hyprland", "View"], ["refresh", "Reload everything", "Hyprland and the shell", "Reload"]]],
      ["info", "About", "Lumen for Hyprland.", [["info", "Version", "Lumen · Hyprland 0.56", ""]]]]],
  ];
  const snav = $("#snav"), spage = $("#spage");
  function showPage(p) {
    $$("button", snav).forEach(b => { b.classList.toggle("on", b.dataset.p === p[1]); b.setAttribute("aria-selected", b.dataset.p === p[1]); });
    spage.innerHTML = `<h3>${esc(p[1])}</h3><p class="sub">${esc(p[2])}</p><div class="grp">` +
      p[3].map(r => `<div class="srow"><span class="ms">${r[0]}</span><div>${esc(r[1])}${r[2] ? `<small>${esc(r[2])}</small>` : ""}</div>${r[3] ? `<span class="minibtn">${esc(r[3])}</span>` : "<span></span>"}</div>`).join("") + "</div>";
    spage.animate([{ opacity: 0, transform: "translateY(8px)" }, { opacity: 1, transform: "none" }], { duration: reduced ? 1 : 360, easing: "cubic-bezier(0.05,0.7,0.1,1)" });
  }
  pages.forEach(([g, ps]) => {
    const h = document.createElement("div"); h.className = "sh"; h.textContent = g; snav.appendChild(h);
    ps.forEach(p => {
      const b = document.createElement("button");
      b.dataset.p = p[1]; b.setAttribute("role", "tab");
      b.innerHTML = `<span class="ms">${p[0]}</span>${esc(p[1])}`;
      b.addEventListener("click", () => showPage(p));
      snav.appendChild(b);
    });
  });
  showPage(pages[0][1][0]);

  // ── Theme lab ──
  const card = $("#labCard");
  const lab = { style: "exact", hue: 55, int: 100, glass: 60, motion: 100 };
  function applyLab() {
    let c = 0.13 * lab.int / 100, l = 0.8, h = lab.hue;
    if (lab.style === "subtle") c *= 0.55;
    if (lab.style === "mono") c = 0.025;
    if (lab.style === "adaptive") { l = 0.78; h = (h + 12) % 360; }
    card.style.setProperty("--accent", `oklch(${l} ${c.toFixed(3)} ${h})`);
    card.style.setProperty("--on-accent", `oklch(0.2 ${Math.min(c, 0.04).toFixed(3)} ${h})`);
    card.style.setProperty("--glass-alpha", (0.95 - lab.glass / 100 * 0.6).toFixed(2));
    card.style.setProperty("--glass-blur", (8 + lab.glass / 100 * 26).toFixed(0) + "px");
    document.documentElement.style.setProperty("--speed", (100 / lab.motion).toFixed(2));
    $("#oHue").textContent = lab.hue + "°"; $("#oInt").textContent = lab.int + "%"; $("#oGlass").textContent = lab.glass + "%"; $("#oMotion").textContent = lab.motion + "%";
    $$("input[type=range]").forEach(r => r.style.setProperty("--f", ((r.value - r.min) / (r.max - r.min) * 100) + "%"));
  }
  [["rHue", "hue"], ["rInt", "int"], ["rGlass", "glass"], ["rMotion", "motion"]].forEach(([id, k]) => $("#" + id).addEventListener("input", e => { lab[k] = +e.target.value; applyLab(); }));
  $$("#styleSeg button").forEach(b => b.addEventListener("click", () => { lab.style = b.dataset.st; $$("#styleSeg button").forEach(x => x.classList.toggle("on", x === b)); applyLab(); }));
  applyLab();

  // ── Shortcuts ──
  const keys = [
    [["Super"], "Search apps, windows, maths"], [["Super", "A"], "Control centre"], [["Super", "N"], "Notifications"],
    [["Super", "Shift", "A"], "Planner"], [["Super", "Shift", "Space"], "Lumen Halo"], [["Alt", "Tab"], "Switch windows"],
    [["Super", "V"], "Clipboard history"], [["Super", "Shift", "S"], "Screenshot a region"], [["Super", "Shift", "T"], "Copy text from screen"],
    [["F12"], "Drop-down terminal"], [["Super", "Shift", "M"], "Music"], [["Ctrl", "Super", "Alt", "→"], "Next workspace with windows"],
    [["Super", "L"], "Lock"], [["Super", "I"], "Settings"], [["Super", "/"], "Every shortcut"],
  ];
  const kg = $("#keysGrid");
  kg.innerHTML = keys.map(([k, d]) => `<div class="kr"><span>${esc(d)}</span><span class="kc">${k.map(x => `<kbd>${esc(x)}</kbd>`).join("")}</span></div>`).join("");
  let kt = 0;
  whileVisible(kg, () => {
    if (reduced) return;
    const rows = $$(".kr", kg);
    kt = setInterval(() => {
      const r = rows[Math.floor(Math.random() * rows.length)];
      r.classList.add("press"); setTimeout(() => r.classList.remove("press"), 260);
    }, 700);
  }, () => clearInterval(kt));

  // ── Gallery + lightbox ──
  const shots = [
    ["01-desktop", "The desktop: one floating glass bar"], ["02-empty-workspace", "An empty workspace: three pills"], ["03-overview", "Overview and search"],
    ["04-control-centre", "Control centre"], ["05-notifications", "Notifications"], ["06-planner", "Planner"], ["07-ai", "Lumen Halo explaining an error"],
    ["08-switcher", "Alt+Tab switcher"], ["09-lock-screen", "Lock screen"], ["10-island-states", "Island states"], ["11-cheatsheet", "Shortcut cheatsheet"],
    ["12-power-menu", "Power menu"], ["13-app-menu", "App menu"], ["14-wallpapers", "Wallpaper picker"], ["15-password-prompt", "Admin password prompt"],
    ["16-focus-modes", "Focus modes"], ["17-sound", "Sound and per-app volume"], ["18-settings-appearance", "Settings: Appearance"], ["18-settings-updates", "Settings: Updates"],
    ["19-halo", "Lumen Halo: answer with runnable commands"], ["20-device-card", "A new display, announced by the island"], ["21-control-wifi", "Wi-Fi: connected, saved and nearby"], ["22-settings-advanced", "Settings: Advanced health check"], ["23-dolphin", "Dolphin in Lumen colours"],
    ["24-ribbon", "The Ribbon: window strip, chips and vitals"], ["25-peek", "Peek: live preview with CPU and memory"], ["26-drop-zone", "Drop Zone"], ["27-lumen-link", "Lumen Link: connect on any network"],
    ["28-backup", "Backup & recovery"], ["29-halo-whatsapp", "Halo drafts a WhatsApp message"], ["30-halo-rename", "Halo renames files (you apply)"], ["31-lyrics", "Synced lyrics in the island"],
    ["32-whatsapp-island", "WhatsApp in the island"], ["33-whatsapp-reply", "Quick reply (Super+Shift+W)"], ["34-now-timeline", "The Now timeline"], ["35-screen-time", "Your week: screen time"],
  ];
  const gg = $("#gallery-grid");
  gg.innerHTML = shots.map(([f, c], i) => `<button data-i="${i}" aria-label="Enlarge: ${esc(c)}"><img src="img/${f}.jpg" alt="${esc(c)}" loading="lazy" decoding="async"><span>${esc(c)}</span></button>`).join("");
  const lb = $("#lb"), lbImg = $("#lbImg"), lbCap = $("#lbCap");
  let li = 0, lastFocus = null, list = shots.map(([f, c]) => ["img/" + f + ".jpg", c]);
  function openLb(src, cap) {
    const i = list.findIndex(x => x[0] === src);
    li = i >= 0 ? i : 0;
    if (i < 0) list = [[src, cap], ...list];
    lastFocus = document.activeElement;
    showLb(); lb.classList.add("on"); lb.setAttribute("aria-hidden", "false");
    $("[data-lb-close]", lb).focus();
  }
  function showLb() { lbImg.src = list[li][0]; lbImg.alt = list[li][1]; lbCap.textContent = list[li][1]; }
  function closeLb() { lb.classList.remove("on"); lb.setAttribute("aria-hidden", "true"); lastFocus && lastFocus.focus(); }
  $$("button", gg).forEach(b => b.addEventListener("click", () => openLb(list[+b.dataset.i][0], list[+b.dataset.i][1])));
  $$("[data-lb]").forEach(b => b.addEventListener("click", () => openLb(b.dataset.lb, $("img", b).alt)));
  $("[data-lb-close]", lb).addEventListener("click", closeLb);
  $("[data-lb-prev]", lb).addEventListener("click", () => { li = (li - 1 + list.length) % list.length; showLb(); });
  $("[data-lb-next]", lb).addEventListener("click", () => { li = (li + 1) % list.length; showLb(); });
  lb.addEventListener("click", e => { if (e.target === lb) closeLb(); });
  addEventListener("keydown", e => {
    if (!lb.classList.contains("on")) return;
    if (e.key === "Escape") closeLb();
    else if (e.key === "ArrowLeft") { li = (li - 1 + list.length) % list.length; showLb(); }
    else if (e.key === "ArrowRight") { li = (li + 1) % list.length; showLb(); }
    else if (e.key === "Tab") {           // keep focus inside the dialog
      const f = $$("button", lb), i = f.indexOf(document.activeElement);
      e.preventDefault(); f[(i + (e.shiftKey ? -1 : 1) + f.length) % f.length].focus();
    }
  });

  // ── Copy install commands ──
  $("#copyBtn").addEventListener("click", async () => {
    const cmds = "git clone https://github.com/Anasarfeen123/lumen.git ~/Projects/lumen\ncd ~/Projects/lumen\n./install.sh --dry-run\n./install.sh\n";
    try { await navigator.clipboard.writeText(cmds); $("#copyBtn").textContent = "Copied"; } catch { $("#copyBtn").textContent = "Select to copy"; }
    setTimeout(() => $("#copyBtn").textContent = "Copy", 1600);
  });
})();

// Lyrics demo: three original lines that glide upward (not a real song)
(() => {
  const box = document.querySelector(".lyr");
  if (!box || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  const lines = ["Streetlights hum a quiet tune", "We chase the glow across the room", "And fold the night into the moon",
                 "The city blinks, we lose the time", "Your laugh arrives a beat behind", "And every sign says stay a while"];
  let i = 1;
  setInterval(() => {
    i = (i + 1) % lines.length;
    const spans = box.querySelectorAll("span");
    box.animate([{ transform: "translateY(0)" }, { transform: "translateY(-6px)", opacity: .6 }, { transform: "translateY(0)", opacity: 1 }], { duration: 520, easing: "cubic-bezier(0.05,0.7,0.1,1)" });
    spans[0].textContent = lines[(i + lines.length - 1) % lines.length];
    spans[1].textContent = lines[i];
    spans[2].textContent = lines[(i + 1) % lines.length];
  }, 2600);
})();
