/* Perch landing demos — every scene acts out key-by-key inside a fixed stage.
   Scene content follows the app's intro showcases; visuals follow the site design. */

"use strict";

const $ = (id) => document.getElementById(id);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const REDUCED = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const ICON_PLAY = '<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M8 5.5v13a1 1 0 0 0 1.52.85l10.4-6.5a1 1 0 0 0 0-1.7l-10.4-6.5A1 1 0 0 0 8 5.5Z"/></svg>';
const ICON_PAUSE = '<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><rect x="6" y="5" width="4" height="14" rx="1.2"/><rect x="14" y="5" width="4" height="14" rx="1.2"/></svg>';

/* ---------- player: visibility-gated scene loop with injected controls ---------- */

class Player {
  constructor(stageEl, count, play, ctlKey) {
    this.count = count;
    this.play = play;       // async (i, alive) — acts out one full scene incl. dwell
    this.i = 0;
    this.gen = 0;
    this.running = false;
    this.paused = false;
    const ctl = stageEl.querySelector(`[data-ctl="${ctlKey}"]`);
    if (ctl) this.buildCtl(ctl);
    new IntersectionObserver(
      (es) => es.forEach((e) => (e.isIntersecting ? this.start() : this.stop())),
      { threshold: 0.3 }
    ).observe(stageEl);
  }

  buildCtl(el) {
    const btn = (cls, html, fn, label) => {
      const b = document.createElement("button");
      b.className = cls;
      b.innerHTML = html;
      b.type = "button";
      if (label) b.setAttribute("aria-label", label);
      b.onclick = fn;
      return b;
    };
    const chev = (d) =>
      `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M${d ? 10 : 14} 6l${d ? "" : "-"}6 6l${d ? "-" : ""}6 6"/></svg>`;
    el.appendChild(btn("c-nav", chev(0), () => this.jump(this.i - 1), "Previous scene"));
    this.playBtn = btn("c-play", ICON_PAUSE, () => this.togglePause(), "Pause");
    el.appendChild(this.playBtn);
    el.appendChild(btn("c-nav", chev(1), () => this.jump(this.i + 1), "Next scene"));
    const dots = document.createElement("div");
    dots.className = "c-dots";
    this.dots = [];
    for (let d = 0; d < this.count; d++) {
      const s = document.createElement("span");
      dots.appendChild(s);
      this.dots.push(s);
    }
    el.appendChild(dots);
  }

  updateCtl() {
    this.dots?.forEach((d, n) => d.classList.toggle("on", n === this.i));
    if (this.playBtn) {
      this.playBtn.innerHTML = this.paused ? ICON_PLAY : ICON_PAUSE;
      this.playBtn.setAttribute("aria-label", this.paused ? "Play" : "Pause");
    }
  }

  async run(i) {
    const g = ++this.gen;
    this.i = ((i % this.count) + this.count) % this.count;
    this.updateCtl();
    const alive = () => this.gen === g && this.running && !this.paused;
    await this.play(this.i, alive);
    if (alive()) this.run(this.i + 1);
  }

  start() { if (!this.running) { this.running = true; if (!this.paused) this.run(this.i); } }
  stop()  { this.running = false; this.gen++; }
  jump(i) {
    this.paused = false;
    if (this.running) this.run(i);
    else { this.i = ((i % this.count) + this.count) % this.count; this.updateCtl(); }
  }
  togglePause() {
    this.paused = !this.paused;
    this.updateCtl();
    if (!this.paused && this.running) this.run(this.i);
    else this.gen++;
  }
}

const setCap = (el, text) => {
  el.classList.add("fade");
  setTimeout(() => { el.textContent = text; el.classList.remove("fade"); }, 180);
};

/* ---------- mouse diagram — geometry from the app's MouseDiagramView ---------- */

function rr(x, y, w, h, tl, tr, br, bl) {
  return `M${x + tl},${y} h${w - tl - tr} a${tr},${tr} 0 0 1 ${tr},${tr} v${h - tr - br}
    a${br},${br} 0 0 1 -${br},${br} h${-(w - br - bl)} a${bl},${bl} 0 0 1 -${bl},-${bl}
    v${-(h - bl - tl)} a${tl},${tl} 0 0 1 ${tl},-${tl} z`;
}

const SPOTS = {
  left:   { x: 36,  y: 6,   w: 90, h: 118, r: [92, 8, 8, 8] },
  right:  { x: 134, y: 6,   w: 90, h: 118, r: [8, 92, 8, 8] },
  middle: { x: 117, y: 32,  w: 26, h: 60,  r: [13, 13, 13, 13] },
  top:    { x: 116, y: 100, w: 28, h: 18,  r: [6, 6, 6, 6] },
  fwd:    { x: 22,  y: 134, w: 16, h: 42,  r: [8, 8, 8, 8], label: "5" },
  back:   { x: 22,  y: 184, w: 16, h: 42,  r: [8, 8, 8, 8], label: "4" },
};

function buildMouse(el, scale = 0.82) {
  const W = 260 * scale, H = 330 * scale;
  let svg = `<svg viewBox="0 0 260 330" width="${W}" height="${H}">
    <path class="m-body" d="${rr(30, 0, 200, 330, 96, 96, 96, 96)}"/>
    <line class="m-line" x1="129.5" y1="10" x2="129.5" y2="124"/>
    <line class="m-line" x1="38" y1="128" x2="222" y2="128"/>`;
  for (const [id, s] of Object.entries(SPOTS)) {
    svg += `<path class="m-spot" data-spot="${id}" d="${rr(s.x, s.y, s.w, s.h, ...s.r)}"/>`;
    if (s.label) svg += `<text class="m-label" x="${s.x + s.w / 2}" y="${s.y + s.h / 2 + 3}" text-anchor="middle">${s.label}</text>`;
  }
  svg += [0, 1, 2].map((n) => `<rect class="m-bar" x="124" y="${52 + n * 7}" width="12" height="1.6" rx="0.8"/>`).join("");
  svg += "</svg>";
  el.innerHTML = svg +
    `<span class="hold-tag">HOLD</span>
     <span class="m-flick"><svg width="22" height="30" viewBox="0 0 24 24" fill="none" stroke="#5B92F7" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20V5"/><path d="M6 11l6-6 6 6"/></svg></span>
     <span class="m-scrollhint">◦◦◦</span>`;
  const spots = {};
  el.querySelectorAll(".m-spot").forEach((p) => (spots[p.dataset.spot] = p));
  const tag = el.querySelector(".hold-tag");
  const flick = el.querySelector(".m-flick");
  const scroll = el.querySelector(".m-scrollhint");

  return {
    el,
    set(lit = [], hold = []) {
      for (const [id, p] of Object.entries(spots)) {
        p.classList.toggle("lit", lit.includes(id) && !hold.includes(id));
        p.classList.toggle("hold", hold.includes(id));
      }
      const h = hold[0];
      if (h) {
        const s = SPOTS[h];
        tag.style.left = `calc(50% + ${(s.x + s.w / 2 - 130) * scale}px)`;
        tag.style.top = (s.y - 16) * scale + "px";
        tag.style.transform = "translateX(-50%)";
        tag.classList.add("show");
      } else tag.classList.remove("show");
    },
    flick(on) { flick.classList.toggle("show", on); },
    scroll(on) { scroll.classList.toggle("show", on); },
    mirror(on) { this.el.classList.toggle("mirror", on); },
    reset() { this.set(); this.flick(false); this.scroll(false); this.mirror(false); },
  };
}

const showChip = (el, text) => { el.textContent = text; el.classList.add("show", "pop"); setTimeout(() => el.classList.remove("pop"), 350); };
const hideChip = (el) => el.classList.remove("show");

/* ---------- shared demo data ---------- */

const fmtDate = new Date().toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
const fmtTime = new Date().toTimeString().slice(0, 5);

/* ================= HERO — the four features perform, one at a time ================= */

(() => {
  const LINES = [
    "Everything you copy, one shortcut away: search, pin, paste.",
    "Type a short code anywhere and it becomes your saved text.",
    "Hold one button, click another: every button gets a job. Per app.",
    "Caps Lock becomes a Hyper Key: a whole shortcut layer. Per app.",
  ];
  const ROWS = [
    { label: "Invoice #2291, due Friday", k: "⌘1" },
    { label: "linear.app/perch/PER-214", k: "⌘2" },
    { label: "Meeting notes from Monday", k: "⌘3" },
  ];
  const tabs = [...$("hero-tabs").children];
  const panels = [...document.querySelectorAll(".h-panel")];
  const capEl = $("hero-caption");
  const rowsEl = $("h-clip-rows"), pastedEl = $("h-clip-pasted");
  const noteEl = document.querySelector(".h-note"), snipEl = $("h-snip-text");
  const mouse = buildMouse($("h-mouse"), 0.52);
  const mouseFired = $("h-mouse-fired"), keysFired = $("h-keys-fired");
  const capsKey = $("h-caps-key"), wKey = $("h-w-key");

  const renderRows = (sel) => {
    rowsEl.innerHTML = ROWS.map((r, n) => `
      <div class="hp-row${n === sel ? " on" : ""}">
        <span class="hp-dot${n === sel ? "" : " alt"}"></span>
        <span class="hp-label">${r.label}</span><span class="mono hp-k">${r.k}</span>
      </div>`).join("");
  };

  const show = (f) => {
    tabs.forEach((t) => t.classList.toggle("on", +t.dataset.f === f));
    panels.forEach((p) => p.classList.toggle("on", +p.dataset.p === f));
    setCap(capEl, LINES[f]);
  };

  const scenes = [
    async (alive) => {                       // clipboard: walk, then paste
      renderRows(0); pastedEl.classList.remove("show");
      await sleep(900); if (!alive()) return;
      renderRows(1);
      await sleep(500); if (!alive()) return;
      renderRows(2);
      await sleep(600); if (!alive()) return;
      pastedEl.classList.add("show");
      await sleep(1600);
    },
    async (alive) => {                       // snippet types itself, then morphs
      noteEl.classList.remove("expanded");
      snipEl.textContent = "";
      await sleep(400); if (!alive()) return;
      for (const ch of ";meet;") {
        snipEl.textContent += ch;
        await sleep(130); if (!alive()) return;
      }
      await sleep(450); if (!alive()) return;
      noteEl.classList.add("expanded");
      snipEl.textContent = `Meeting notes · ${fmtDate}\nAttendees: `;
      await sleep(2100);
    },
    async (alive) => {                       // mouse: performs centered, then glides left
      const panel = panels.find((p) => p.dataset.p === "2");
      panel.classList.remove("done");
      mouse.reset(); hideChip(mouseFired);
      await sleep(500); if (!alive()) return;
      mouse.set([], ["back"]);
      await sleep(800); if (!alive()) return;
      mouse.set(["left"], ["back"]);
      await sleep(300); if (!alive()) return;
      panel.classList.add("done");
      showChip(mouseFired, "Spotlight");
      await sleep(2000);
    },
    async (alive) => {                       // keys: press centered, then slide left, action right
      const panel = panels.find((p) => p.dataset.p === "3");
      panel.classList.remove("done");
      capsKey.classList.remove("lit"); wKey.classList.remove("lit"); hideChip(keysFired);
      await sleep(500); if (!alive()) return;
      capsKey.classList.add("lit");
      await sleep(700); if (!alive()) return;
      wKey.classList.add("lit");
      await sleep(250); if (!alive()) return;
      panel.classList.add("done");
      showChip(keysFired, "Open WhatsApp");
      await sleep(300); if (!alive()) return;
      wKey.classList.remove("lit");
      await sleep(1700);
    },
  ];

  renderRows(0);
  const player = new Player($("hero-stage"), 4, async (i, alive) => {
    show(i);
    await scenes[i](alive);
  }, "none");
  tabs.forEach((t) => (t.onclick = () => player.jump(+t.dataset.f)));
  tabs.forEach((t) => (t.style.cursor = "pointer"));
})();

/* ================= CLIPBOARD ================= */

(() => {
  const CATS = ["All", "Text", "Links", "Images", "Snippets"];
  const CATKEY = ["", "text", "link", "image", "snippet"];
  const DOT = { text: "#5B92F7", link: "#7CC4F5", image: "#9B8CF0", snippet: "#63C9A4" };
  const ITEMS = [
    { t: "text", label: "Invoice #2291, due Friday", meta: "Mail · 2m ago" },
    { t: "link", label: "linear.app/perch/PER-214", meta: "Safari · 6m ago" },
    { t: "text", label: "invoice_march_final.pdf", meta: "Finder · 11m ago" },
    { t: "image", label: "Screenshot at 09.41", meta: "Shottr · 20m ago" },
    { t: "link", label: "github.com/azharbinanwar/perch", meta: "Safari · 25m ago" },
    { t: "text", label: "Invoice template, Northlight", meta: "Notes · 40m ago" },
    { t: "snippet", label: ";sig; · Azhar, Kode Elite", meta: "Snippet" },
    { t: "snippet", label: ";meet; · Meeting notes", meta: "Snippet" },
  ];
  const SCENES = [
    { chips: ["⌘", "⇧", "V"], label: "popup opens", cat: 0, q: "", sel: 0,
      cap: "Press ⌘⇧V over whatever you're doing. Focus never leaves your app." },
    { chips: ["↓", "↓"], label: "walk the list", cat: 0, q: "", sel: 2, walk: true,
      cap: "↑↓ walks everything you have copied. No mouse involved." },
    { chips: ["i", "n", "v"], label: "filtering", cat: 0, q: "inv", sel: 0, typeQ: true,
      cap: "Type three letters and the list is already down to what you meant." },
    { chips: ["⇥"], label: "category: Links", cat: 2, q: "", sel: 0,
      cap: "⇥ cycles categories: text, links, images, snippets." },
    { chips: ["⌘", "P"], label: "pinned", cat: 0, q: "", sel: 1, pin: [1],
      cap: "⌘P pins the things you reach for every day to the top." },
    { chips: ["⌘", "2"], label: "instant paste", cat: 0, q: "", sel: 1, flash: 1, paste: true,
      cap: "⌘1–9 pastes straight from the list. No arrow keys needed." },
    { chips: ["⇥"], label: "category: Snippets", cat: 4, q: "", sel: 0,
      cap: "Your snippets live in here too, same shortcut, same window." },
    { chips: ["⏎"], label: "pasted", cat: 0, q: "", sel: 0, flash: 0, paste: true,
      cap: "Enter drops it into the app you came from. Copy once, paste whenever." },
  ];

  const chipsEl = $("clip-chips"), labelEl = $("clip-label"), queryEl = $("clip-query"),
        countEl = $("clip-count"), catsEl = $("clip-cats"), listEl = $("clip-list"),
        pasteEl = $("clip-paste"), capEl = $("clip-cap");

  catsEl.innerHTML = CATS.map((c) => `<span class="pp-cat">${c}</span>`).join("");
  const catEls = [...catsEl.children];

  const filtered = (s) => ITEMS
    .filter((i) => (!CATKEY[s.cat] || i.t === CATKEY[s.cat]) && (!s.q || i.label.toLowerCase().includes(s.q)))
    .slice(0, 5);

  function render(s, { sel = s.sel, flash = -1 } = {}) {
    catEls.forEach((c, n) => c.classList.toggle("on", n === s.cat));
    queryEl.textContent = s.q || "Search clipboard";
    queryEl.classList.toggle("ghost", !s.q);
    const list = filtered(s);
    countEl.textContent = `${list.length} of ${ITEMS.length}`;
    listEl.innerHTML = list.map((it, n) => `
      <div class="pp-row${n === sel ? " sel" : ""}${n === flash ? " flash" : ""}">
        <span class="pp-dot" style="background:${DOT[it.t]}"></span>
        <div class="pp-main"><div class="pp-label">${it.label}</div><div class="pp-meta">${it.meta}</div></div>
        ${(s.pin || []).includes(n) ? '<span class="pp-pin">Pinned</span>' : `<span class="pp-badge">⌘${n + 1}</span>`}
      </div>`).join("");
    return list;
  }

  render(SCENES[0]);

  new Player($("clip-stage"), SCENES.length, async (i, alive) => {
    const s = SCENES[i];
    setCap(capEl, s.cap);
    labelEl.textContent = "";
    pasteEl.classList.remove("show");
    chipsEl.innerHTML = s.chips.map((k) => `<span class="chip mono">${k}</span>`).join("");
    const chipEls = [...chipsEl.children];
    await sleep(600); if (!alive()) return;

    // keys press one by one
    for (const c of chipEls) {
      c.classList.add("lit");
      await sleep(170); if (!alive()) return;
      if (!s.typeQ) c.classList.remove("lit");
      await sleep(90); if (!alive()) return;
    }

    if (s.walk) {                       // ↓ ↓ — selection steps down visibly
      render(s, { sel: 1 });
      await sleep(320); if (!alive()) return;
      render(s, { sel: 2 });
    } else if (s.typeQ) {               // letters land in the search field
      for (let n = 1; n <= s.q.length; n++) {
        queryEl.textContent = s.q.slice(0, n);
        queryEl.classList.remove("ghost");
        await sleep(160); if (!alive()) return;
      }
      render(s);
    } else {
      render(s, { flash: s.flash ?? -1 });
    }
    labelEl.textContent = s.label;

    if (s.paste) {
      await sleep(420); if (!alive()) return;
      pasteEl.textContent = "pasted → Mail";
      pasteEl.classList.add("show");
      await sleep(3400);
    } else {
      await sleep(3000);
    }
  }, "clip");
})();

/* ================= SNIPPETS ================= */

(() => {
  const SCENES = [
    { token: ";meet;", out: [`Meeting notes · ${fmtDate}`, "Attendees:"], chips: ["{date} filled in"],
      cap: "A short code becomes the whole block, wherever you are typing." },
    { token: ";q;", out: ["Ship it Friday, says Sam"], chips: ["{clipboard} filled in"],
      cap: "Snippets can reach into your clipboard as they expand." },
    { token: ";sig;", out: ["Azhar Bin Anwar", "Kode Elite · perch.kodeelite.com"], chips: [],
      cap: "Your whole signature from five keystrokes." },
    { token: ";sum;", out: [`${fmtDate} · ${fmtTime}`, "Ship it Friday, says Sam", "Next steps: "], chips: ["{date}", "{time}", "{clipboard}", "{cursor}"],
      cap: "Date, time, clipboard, and the cursor left exactly where you want it." },
  ];

  const tokenEl = $("snip-token"), labelEl = $("snip-label"), typedEl = $("snip-typed-text"),
        outEl = $("snip-out"), chipsEl = $("snip-chips"), capEl = $("snip-cap");

  new Player($("snip-stage"), SCENES.length, async (i, alive) => {
    const s = SCENES[i];
    setCap(capEl, s.cap);
    labelEl.textContent = "typing";
    typedEl.textContent = "";
    outEl.innerHTML = "";
    chipsEl.innerHTML = "";
    tokenEl.textContent = s.token;
    tokenEl.classList.remove("lit");
    await sleep(600); if (!alive()) return;

    for (const ch of s.token) {          // it types itself, for real
      typedEl.textContent += ch;
      await sleep(150); if (!alive()) return;
    }
    await sleep(450); if (!alive()) return;

    typedEl.textContent = "";            // …and becomes the text, line by line
    tokenEl.classList.add("lit");
    labelEl.textContent = "expanded";
    outEl.innerHTML = s.out.map((t, n) => `<div class="np-line${n === 0 ? " first" : ""}">${t}</div>`).join("");
    const lines = [...outEl.children];
    for (const l of lines) {
      l.classList.add("in");
      await sleep(200); if (!alive()) return;
    }
    chipsEl.innerHTML = s.chips.map((t) => `<span class="np-chip mono">${t}</span>`).join("");
    for (const c of [...chipsEl.children]) {
      c.classList.add("in");
      await sleep(140); if (!alive()) return;
    }
    await sleep(2600 + s.out.join("").length * 10);
  }, "snip");
})();

/* ================= MOUSE ================= */

(() => {
  const SCENES = [
    { lit: ["middle"], press: "Middle click", out: "Spotlight opens",
      cap: "One click for the thing you open all day." },
    { lit: ["back"], press: "Hold button 4", out: "Copy", holdPress: true,
      cap: "Click, double-click and hold are three separate jobs on every button." },
    { lit: ["top"], press: "Hold + flick up", out: "Mission Control", flick: true,
      cap: "Flick gestures, on a mouse that has no gestures." },
    { lit: ["left"], hold: ["middle"], press: "Hold middle + left", out: "Paste",
      cap: "One button holds, another fires. Combos out of plain buttons." },
    { lit: [], press: "Scroll wheel", out: "Smooth scroll · 1.0×", scroll: true,
      cap: "Smooth, reversed, faster, turbo, and different in every app." },
    { lit: ["right"], press: "Left-handed layout", out: "Buttons swapped", mirror: true,
      cap: "Swap the sides and the layout follows your hand." },
  ];

  const mouse = buildMouse($("mouse-diagram"));
  const pressEl = $("mouse-press"), outEl = $("mouse-out"), capEl = $("mouse-cap");

  new Player($("mouse-stage"), SCENES.length, async (i, alive) => {
    const s = SCENES[i];
    setCap(capEl, s.cap);
    mouse.reset();
    hideChip(pressEl); hideChip(outEl);
    await sleep(500); if (!alive()) return;

    showChip(pressEl, s.press);
    await sleep(450); if (!alive()) return;

    if (s.mirror) mouse.mirror(true);
    if (s.hold) {                          // combo: hold engages first, then the click
      mouse.set([], s.hold);
      await sleep(500); if (!alive()) return;
      mouse.set(s.lit, s.hold);
    } else {
      mouse.set(s.lit);
    }
    if (s.flick) mouse.flick(true);
    if (s.scroll) mouse.scroll(true);
    await sleep(s.holdPress ? 850 : 450); if (!alive()) return;

    showChip(outEl, s.out);
    await sleep(3300);
  }, "mouse");
})();

/* ================= MOUSE SHIFT ================= */

(() => {
  const SCENES = [
    { hold: "back", target: "left", mode: "click", holdLabel: "Back button", press: "Click Left", out: "Spotlight",
      cap: "Hold Back, and Left stops being Left." },
    { hold: "back", target: "left", mode: "double", holdLabel: "Back button", press: "Double-click Left", out: "Mission Control",
      cap: "Double-click is its own slot: a different action again." },
    { hold: "back", target: "right", mode: "hold", holdLabel: "Back button", press: "Hold Right", out: "Screenshot Area",
      cap: "And holding gives you a third." },
    { hold: "fwd", target: "left", mode: "click", holdLabel: "Forward button", press: "Click Left", out: "Paste as Plain Text",
      cap: "Each hold button has its own set of combos." },
  ];

  const mouse = buildMouse($("shift-diagram"));
  const comboEl = $("shift-combo"), outEl = $("shift-out"), capEl = $("shift-cap");
  const row = document.querySelector(".shift-row");

  new Player($("shift-stage"), SCENES.length, async (i, alive) => {
    const s = SCENES[i];
    setCap(capEl, s.cap);
    row.classList.remove("done");                  // back to center for the next combo
    mouse.reset();
    hideChip(comboEl); hideChip(outEl);
    await sleep(600); if (!alive()) return;

    mouse.set([], [s.hold]);                       // finger goes down, amber HOLD
    showChip(comboEl, `Hold ${s.holdLabel}`);
    await sleep(900); if (!alive()) return;

    comboEl.textContent = `Hold ${s.holdLabel} · ${s.press}`;
    if (s.mode === "double") {                     // two quick visible taps
      for (let t = 0; t < 2; t++) {
        mouse.set([s.target], [s.hold]);
        await sleep(180); if (!alive()) return;
        mouse.set([], [s.hold]);
        await sleep(120); if (!alive()) return;
      }
      mouse.set([s.target], [s.hold]);
    } else {
      mouse.set([s.target], [s.hold]);
      await sleep(s.mode === "hold" ? 900 : 350); if (!alive()) return;
    }

    row.classList.add("done");                     // glide left, the second action expands in
    showChip(outEl, s.out);
    await sleep(2400); if (!alive()) return;
    mouse.reset();                                 // release
    await sleep(400);
  }, "shift");
})();

/* ================= KEYS ================= */

(() => {
  const SCENES = [
    { caps: ["⌃", "C"], out: "⌘C", cap: "Remap any key to any other key." },
    { caps: ["Caps Lock"], out: "⌘⌥⌃⇧", cap: "Caps Lock becomes a Hyper Key: a private layer no app claims." },
    { caps: ["⇧", "⇧"], out: "Spotlight", pulse: true, cap: "Double-tap a modifier to run an action." },
    { caps: ["⇧", "⌘", "T"], out: "Terminal launches", cap: "Shortcuts that open apps, not just menus." },
  ];

  const capsEl = $("keys-caps"), outEl = $("keys-out"), capEl = $("keys-cap");

  new Player($("keys-stage"), SCENES.length, async (i, alive) => {
    const s = SCENES[i];
    setCap(capEl, s.cap);
    outEl.classList.remove("show");
    capsEl.innerHTML = s.caps.map((k) => `<div class="kcap${k.length > 3 ? " small" : ""}">${k}</div>`).join("");
    const caps = [...capsEl.children];
    outEl.textContent = s.out;
    await sleep(600); if (!alive()) return;

    if (s.pulse) {                        // tap-tap
      for (let t = 0; t < 2; t++) {
        caps.forEach((c) => c.classList.add("lit"));
        await sleep(170); if (!alive()) return;
        caps.forEach((c) => c.classList.remove("lit"));
        await sleep(110); if (!alive()) return;
      }
      caps.forEach((c) => c.classList.add("lit"));
    } else {                              // keys sink one by one
      for (const c of caps) {
        c.classList.add("lit");
        await sleep(220); if (!alive()) return;
      }
    }
    await sleep(380); if (!alive()) return;
    outEl.classList.add("show");
    await sleep(3300);
  }, "keysd");
})();

/* ================= PER APP ================= */

(() => {
  const NAMES = ["WhatsApp", "Browser", "Figma", "Terminal"];
  const SCENES = [
    { app: 0, press: "Click Back button", out: "Spotlight", active: true,
      cap: "In your chat app, the Back button opens Spotlight." },
    { app: 1, press: "Click Back button", out: "Just a normal click", active: false,
      cap: "In the browser, the very same click stays a click." },
    { app: 0, press: "Scroll", out: "Slow and smooth", active: true, cap: "Chat scrolls gently." },
    { app: 1, press: "Scroll", out: "Fast · 3×", active: true, cap: "The browser scrolls fast." },
    { app: 2, press: "Hold Forward button", out: "Zoom In", active: true,
      cap: "In Figma the same button becomes a zoom." },
    { app: 2, press: "Caps Lock + Z", out: "Zoom to Fit", active: true,
      cap: "Hyper Key shortcuts, scoped to the app that needs them." },
    { app: 3, press: "Caps Lock", out: "Just Caps Lock", active: false,
      cap: "And in Terminal, Perch stays out of the way entirely." },
  ];

  const ICONS = [
    '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a8 8 0 0 1-11.6 7.1L4 21l1.9-5.4A8 8 0 1 1 21 12z"/></svg>',
    '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M3 12h18"/><path d="M12 3a14 14 0 0 0 0 18a14 14 0 0 0 0-18"/></svg>',
    '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3.5" y="3.5" width="17" height="17" rx="3"/><path d="M3.5 12h17"/><circle cx="15.5" cy="16.5" r="2.6"/></svg>',
    '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="2.5" y="4" width="19" height="16" rx="2.5"/><path d="M7 10l2.5 2L7 14"/><path d="M12.5 14.5H17"/></svg>',
  ];

  const tiles = [...$("apps-tiles").children];
  const pressEl = $("apps-press"), outEl = $("apps-out"), nameEl = $("apps-appname"),
        iconEl = $("apps-appicon"), winEl = $("apps-window"), signalEl = $("apps-signal"),
        capEl = $("apps-cap");
  let lastApp = -1;

  new Player($("apps-stage"), SCENES.length, async (i, alive) => {
    const s = SCENES[i];
    setCap(capEl, s.cap);
    tiles.forEach((t) => t.classList.toggle("front", +t.dataset.app === s.app));
    hideChip(outEl);
    winEl.classList.remove("active");
    pressEl.textContent = s.press;

    if (s.app !== lastApp) {                 // the app window swaps to the front app
      winEl.classList.add("out");
      await sleep(280); if (!alive()) return;
      nameEl.textContent = NAMES[s.app];
      iconEl.innerHTML = ICONS[s.app];
      winEl.classList.remove("out");
      lastApp = s.app;
    }
    await sleep(800); if (!alive()) return;

    pressEl.classList.add("lit");            // the same press, every time
    await sleep(220); if (!alive()) return;
    pressEl.classList.remove("lit");

    signalEl.classList.remove("go");         // the signal travels to the front app
    void signalEl.offsetWidth;
    signalEl.classList.add("go");
    await sleep(430); if (!alive()) return;

    showChip(outEl, s.out);                  // …and the action lands inside it
    outEl.classList.toggle("grey", !s.active);
    winEl.classList.toggle("active", s.active);
    await sleep(2900);
  }, "apps");
})();

/* ================= chrome: reveals, parallax, copy ================= */

document.querySelectorAll(".reveal, [data-stagger]").forEach((el) => {
  new IntersectionObserver((es, io) => {
    es.forEach((e) => { if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); } });
  }, { threshold: 0.15 }).observe(el);
});

if (!REDUCED) {
  const heroVis = document.querySelector("[data-parallax]");
  let ticking = false;
  addEventListener("scroll", () => {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(() => {
      const y = scrollY;
      if (heroVis && y < 900) heroVis.style.transform = `translateY(${y * 0.05}px)`;
      ticking = false;
    });
  }, { passive: true });
}

/* install commands: copy, then a check for a moment */
const CURL = "curl -fsSL perch.kodeelite.com/install.sh | sh";
const BREW = "brew install --cask azharbinanwar/tap/perch";
[["hero-cmd", "hero-copy", CURL], ["copy-btn", "copy-btn", CURL], ["hero-brew", "hero-brew-copy", BREW], ["copy-brew", "copy-brew", BREW]]
  .forEach(([trigger, badge, text]) => $(trigger)?.addEventListener("click", () => {
    navigator.clipboard?.writeText(text);
    const b = $(badge), label = b.querySelector("span");
    b.classList.add("done"); label.textContent = "Copied";
    clearTimeout(b._t);
    b._t = setTimeout(() => { b.classList.remove("done"); label.textContent = "Copy"; }, 1800);
  }));

/* sticky header: hides while scrolling down, comes back on the way up */
(() => {
  const nav = document.querySelector("header.nav");
  if (!nav) return;
  let last = scrollY;
  addEventListener("scroll", () => {
    const y = scrollY;
    nav.classList.toggle("scrolled", y > 8);
    if (Math.abs(y - last) < 6) return;
    nav.classList.toggle("hide", y > last && y > 160);
    last = y;
  }, { passive: true });
})();

/* the page obeys Perch shortcuts (idea 2) */
(() => {
  const pop = document.createElement("div");
  pop.className = "kbd-pop";
  pop.innerHTML = `
    <div>
      <div class="hp-card">
        <div class="hp-search">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg>
          Search clipboard<span class="mono hp-k right">⌘⇧V</span>
        </div>
        <div class="hp-rows">
          <div class="hp-row on"><span class="hp-dot"></span><span class="hp-label">Invoice #2291, due Friday</span><span class="mono hp-k">⌘1</span></div>
          <div class="hp-row"><span class="hp-dot alt"></span><span class="hp-label">linear.app/perch/PER-214</span><span class="mono hp-k">⌘2</span></div>
          <div class="hp-row"><span class="hp-dot alt"></span><span class="hp-label">Meeting notes from Monday</span><span class="mono hp-k">⌘3</span></div>
        </div>
      </div>
      <div class="kbd-hint">This is Perch's popup. In Perch itself, it opens over any app. Press Esc to close.</div>
    </div>`;
  document.body.appendChild(pop);
  pop.addEventListener("click", () => pop.classList.remove("open"));

  const flash = document.createElement("div");
  flash.className = "flash-pill";
  flash.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg>Spotlight · double-tap ⇧, like in Perch`;
  document.body.appendChild(flash);
  let flashT, lastShift = 0;

  addEventListener("keydown", (e) => {
    if (e.key === "Escape") pop.classList.remove("open");
    if ((e.metaKey || e.ctrlKey) && e.shiftKey && (e.key === "v" || e.key === "V")) {
      e.preventDefault();
      pop.classList.toggle("open");
    }
    if (e.key === "Shift" && !e.repeat && !e.metaKey && !e.altKey && !e.ctrlKey) {
      const now = performance.now();
      if (now - lastShift < 350) {
        lastShift = 0;
        flash.classList.add("show");
        clearTimeout(flashT);
        flashT = setTimeout(() => flash.classList.remove("show"), 1400);
      } else lastShift = now;
    }
  });
})();

/* hero stage: 3D tilt toward the cursor */
if (!REDUCED && matchMedia("(pointer: fine)").matches) {
  const stage = $("hero-stage");
  const zone = document.querySelector(".hero-visual");
  if (stage && zone) {
    zone.addEventListener("pointermove", (e) => {
      const r = stage.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width - 0.5;
      const y = (e.clientY - r.top) / r.height - 0.5;
      stage.style.transform = `perspective(950px) rotateY(${(x * 7).toFixed(2)}deg) rotateX(${(-y * 6).toFixed(2)}deg) translateY(-2px)`;
    });
    zone.addEventListener("pointerleave", () => { stage.style.transform = ""; });
  }
}

/* tour video: one big play button, native controls once it's playing */
(() => {
  const player = document.querySelector(".tour-player");
  if (!player) return;
  const video = player.querySelector("video");
  const play = player.querySelector(".tour-play");
  video.controls = false;
  player.classList.add("ready");
  play.addEventListener("click", () => {
    player.classList.add("playing");
    video.controls = true;
    video.play();
  });
  video.addEventListener("ended", () => {
    player.classList.remove("playing");
    video.controls = false;
    video.load();
  });
})();

/* FAQ: animate the answer open and closed instead of snapping */
document.querySelectorAll(".faq-item").forEach((item) => {
  const summary = item.querySelector("summary");
  const body = item.querySelector(".faq-body");
  const ease = "cubic-bezier(0.2, 0.7, 0.3, 1)";
  let running = null;
  summary.addEventListener("click", (e) => {
    e.preventDefault();
    if (running) return;
    const opening = !item.open;
    item.classList.toggle("is-open", opening);
    if (opening) item.open = true;
    if (REDUCED) { item.open = opening; return; }
    const h = body.scrollHeight;
    running = body.animate(
      opening ? [{ height: "0px", opacity: 0 }, { height: h + "px", opacity: 1 }]
              : [{ height: h + "px", opacity: 1 }, { height: "0px", opacity: 0 }],
      { duration: opening ? 320 : 260, easing: ease }
    );
    running.onfinish = () => { if (!opening) item.open = false; running = null; };
  });
});

/* live release info: real version + size from the latest GitHub release */
fetch("https://api.github.com/repos/azharbinanwar/Perch/releases/latest")
  .then((r) => (r.ok ? r.json() : null))
  .then((rel) => {
    const dmg = rel?.assets?.find((a) => a.name.endsWith(".dmg"));
    if (!dmg) return;
    const mb = (dmg.size / 1048576).toFixed(1);
    $("dl-meta").innerHTML = `Free and open source. Version ${rel.tag_name.replace(/^v/, "")}, ${mb}&nbsp;MB. Needs macOS&nbsp;14+ on Apple&nbsp;Silicon.`;
  })
  .catch(() => {});

/* hero install command: click anywhere on it to copy */
