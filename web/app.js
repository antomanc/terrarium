// Terrarium in the browser: public GitHub data -> Bend (scene.bend compiled
// to JS) grows the world -> the GPU ray traces it at this screen's exact
// resolution. No server and no token.
import Bend from "./scene.mjs";
import { Renderer } from "./gl.js";

// GitHub's language colours (linguist), for the usual languages.
const COLORS = {
  JavaScript: "#f1e05a", TypeScript: "#3178c6", Python: "#3572A5", Java: "#b07219",
  C: "#555555", "C++": "#f34b7d", "C#": "#178600", Go: "#00ADD8", Rust: "#dea584",
  Ruby: "#701516", PHP: "#4F5D95", Swift: "#F05138", Kotlin: "#A97BFF", Dart: "#00B4AB",
  Shell: "#89e051", HTML: "#e34c26", CSS: "#663399", SCSS: "#c6538c", Vue: "#41b883",
  Svelte: "#ff3e00", Lua: "#000080", Haskell: "#5e5086", Elixir: "#6e4a7e",
  Erlang: "#B83998", Scala: "#c22d40", Clojure: "#db5855", OCaml: "#ef7a08",
  Zig: "#ec915c", Nim: "#ffc200", Julia: "#a270ba", R: "#198CE7",
  "Jupyter Notebook": "#DA5B0B", PowerShell: "#012456", "Objective-C": "#438eff",
  Perl: "#0298c3", Elm: "#60B5CC", "F#": "#b845fc", Assembly: "#6E4C13",
  Dockerfile: "#384d54", Makefile: "#427819", Nix: "#7e7eff", PLpgSQL: "#336790",
  TeX: "#3D6117", MDX: "#fcb32c", Astro: "#ff5a03", Solidity: "#AA6746",
  GDScript: "#355570", Gleam: "#ffaff3", Crystal: "#000100", "Vim Script": "#199f4b",
  "Emacs Lisp": "#c065db", Groovy: "#4298b8", Fortran: "#4d41b1", MATLAB: "#e16737",
};
const colorOf = name => COLORS[name] ||
  "#" + (([...name].reduce((h, c) => Math.imul(h ^ c.charCodeAt(0), 16777619), 2166136261) >>> 8) & 0xffffff).toString(16).padStart(6, "0");

const SIZES = {
  banner: [1280, 640], phone: [1080, 2340], "phone-hd": [1440, 3120],
  "fold-cover": [1080, 2520], "fold-inner": [1968, 2184], tablet: [1600, 2560],
  desktop: [3840, 2160], square: [1080, 1080],
};

const $ = id => document.getElementById(id);
const status = text => { $("status").textContent = text; };

async function json(url) {
  const res = await fetch(url);
  if (res.status === 404) throw new Error("No GitHub user with that name.");
  if (res.status === 403 || res.status === 429) throw new Error("GitHub's hourly limit for this network is used up. Try again in a while.");
  if (!res.ok) throw new Error("GitHub answered " + res.status + ".");
  return res.json();
}

// The same numbers terrarium.mjs passes to the renderer, from public APIs.
async function fetchStats(login) {
  const since = new Date(Date.now() - 365 * 864e5).toISOString().slice(0, 10);
  const [cal, repos, prs] = await Promise.all([
    json("https://github-contributions-api.jogruber.de/v4/" + encodeURIComponent(login) + "?y=last"),
    json("https://api.github.com/users/" + encodeURIComponent(login) + "/repos?per_page=100&type=owner"),
    json("https://api.github.com/search/issues?per_page=1&q=" +
      encodeURIComponent("author:" + login + " type:pr created:>=" + since)).catch(() => ({ total_count: 0 })),
  ]);
  const today = new Date().toISOString().slice(0, 10);
  const days = cal.contributions.filter(d => d.date <= today).map(d => d.count);
  let streak = 0;
  for (let i = days.length - 1; i >= 0; i--) {
    if (days[i] > 0) streak++;
    else if (i === days.length - 1) continue;
    else break;
  }
  let longest = 0, run = 0;
  for (const n of days) { run = n > 0 ? run + 1 : 0; longest = Math.max(longest, run); }
  const langs = new Map();
  let stars = 0;
  for (const r of repos) {
    if (r.fork) continue;
    stars += r.stargazers_count;
    if (r.language) langs.set(r.language, (langs.get(r.language) || 0) + Math.max(1, r.size));
  }
  const top = [...langs.entries()].sort((a, b) => b[1] - a[1]).slice(0, 3)
    .map(([name]) => ({ name, color: colorOf(name) }));
  while (top.length < 3) top.push({ name: "-", color: "#66ccff" });
  let seed = 2166136261;
  for (const ch of login) seed = Math.imul(seed ^ ch.charCodeAt(0), 16777619) >>> 0;
  return {
    login, seed: seed % 1000000, total: cal.total.lastYear ?? days.reduce((a, b) => a + b, 0),
    active: days.filter(n => n > 0).length, last30: days.slice(-30).reduce((a, b) => a + b, 0),
    streak, longest, prs: prs.total_count, stars, languages: top,
  };
}

const hex = c => parseInt(c.slice(1), 16);
const rgb = c => [(hex(c) >> 16 & 255) / 255, (hex(c) >> 8 & 255) / 255, (hex(c) & 255) / 255];

function bendStats(st, day) {
  return {
    $: "Stats", day: day ? 1 : 0, seed: st.seed, total: st.total, active: st.active,
    last30: st.last30, streak: st.streak, longest: st.longest, prs: st.prs, stars: st.stars,
    c1: hex(st.languages[0].color), c2: hex(st.languages[1].color), c3: hex(st.languages[2].color),
    w: 1080, h: 2340,
  };
}

// Bend grows the garden and decides every voxel and every light.
function grow(st) {
  const garden = Bend["Grow.garden"](bendStats(st, false));
  const voxels = new Uint8Array(64 * 64 * 64);
  for (let z = 0; z < 64; z++)
    for (let y = 0; y < 64; y++)
      for (let x = 0; x < 64; x++)
        voxels[x + 64 * (y + 64 * z)] = Bend["Vox.at"](garden, x, y, z);
  return voxels;
}

function lightsFor(st, day) {
  const garden = Bend["Grow.garden"](bendStats(st, day));
  const out = [];
  for (let l = Bend["Lights.all"](garden, st.streak); l.$ === "Con"; l = l.tail) {
    const h = l.head;
    out.push({ pos: [h.x, h.y, h.z], col: [h.r, h.g, h.b] });
  }
  return out;
}

// This screen, in device pixels, in its current orientation.
function screenSize() {
  const r = window.devicePixelRatio || 1;
  return [Math.round(screen.width * r), Math.round(screen.height * r)];
}

let renderer, stats, voxels, busy = false;
const state = { mode: "night", size: "screen" };

function sizeNow() {
  if (state.size === "screen") return screenSize();
  return SIZES[state.size];
}

async function draw() {
  if (!stats || busy) return;
  busy = true;
  document.body.classList.add("busy");
  try {
    const [width, height] = sizeNow();
    const t = performance.now();
    await renderer.render({
      width, height, day: state.mode === "day", seed: stats.seed, stars: stats.stars,
      colors: stats.languages.map(l => rgb(l.color)), lights: lightsFor(stats, state.mode === "day"),
    }, p => status("Painting " + Math.round(p * 100) + "%"));
    status(width + "×" + height + " in " + Math.round(performance.now() - t) + " ms");
    $("save").disabled = false;
  } finally {
    busy = false;
    document.body.classList.remove("busy");
  }
}

function describe(st) {
  const l = st.languages.filter(x => x.name !== "-").map(x =>
    '<span class="dot" style="background:' + x.color + '"></span>' + x.name).join(" ");
  $("facts").innerHTML =
    "<b>" + st.total + "</b> contributions grew the tree · <b>" + st.active + "</b> active days, the mushrooms · " +
    "<b>" + st.streak + "</b>-day streak, the fireflies · <b>" + st.prs + "</b> PRs, the flowers · " +
    "<b>" + st.stars + "</b> stars in the sky" + (l ? " · crystals: " + l : "") +
    (st.last30 === 0 ? " · asleep under snow: no activity in 30 days" : "");
}

async function start(login) {
  login = login.trim().replace(/^@/, "");
  if (!login || busy) return;
  try {
    status("Reading " + login + "'s year on GitHub…");
    stats = await fetchStats(login);
    status("Growing the island in Bend…");
    await new Promise(r => setTimeout(r, 30));
    const t = performance.now();
    voxels = grow(stats);
    renderer.setWorld(voxels);
    console.log("Bend grew the world in", Math.round(performance.now() - t), "ms");
    describe(stats);
    history.replaceState(null, "", "?u=" + encodeURIComponent(login) + (state.mode === "day" ? "&m=day" : ""));
    document.body.classList.add("grown");
    await draw();
  } catch (e) {
    status(e.message || String(e));
  }
}

async function save() {
  const [w, h] = sizeNow();
  const blob = await new Promise(r => $("canvas").toBlob(r, "image/png"));
  const name = "terrarium-" + stats.login + "-" + state.mode + "-" + w + "x" + h + ".png";
  const file = new File([blob], name, { type: "image/png" });
  if (navigator.canShare?.({ files: [file] })) {
    try { await navigator.share({ files: [file], title: "My terrarium" }); return; } catch (e) {
      if (e.name === "AbortError") return;
    }
  }
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 10000);
}

function init() {
  try {
    renderer = new Renderer($("canvas"));
  } catch (e) {
    status(e.message);
    return;
  }
  const [sw, sh] = screenSize();
  $("size").options[0].text = "This screen (" + sw + "×" + sh + ")";
  for (const [k, [w, h]] of Object.entries(SIZES)) $("size").add(new Option(k + " (" + w + "×" + h + ")", k));
  $("form").addEventListener("submit", e => { e.preventDefault(); start($("login").value); });
  for (const b of document.querySelectorAll("[data-mode]")) b.addEventListener("click", () => {
    state.mode = b.dataset.mode;
    for (const o of document.querySelectorAll("[data-mode]")) o.classList.toggle("on", o === b);
    if (stats) history.replaceState(null, "", "?u=" + encodeURIComponent(stats.login) + (state.mode === "day" ? "&m=day" : ""));
    draw();
  });
  $("size").addEventListener("change", () => { state.size = $("size").value; draw(); });
  $("save").addEventListener("click", save);
  $("share").addEventListener("click", async () => {
    const url = location.href;
    if (navigator.share) navigator.share({ url, title: "My GitHub terrarium" }).catch(() => {});
    else { await navigator.clipboard.writeText(url); status("Link copied."); }
  });
  const q = new URLSearchParams(location.search);
  if (q.get("m") === "day") document.querySelector('[data-mode="day"]').click();
  if (SIZES[q.get("s")]) { $("size").value = q.get("s"); state.size = q.get("s"); }
  if (q.get("u")) { $("login").value = q.get("u"); start(q.get("u")); }
}

init();
