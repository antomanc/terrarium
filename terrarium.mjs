#!/usr/bin/env node
// Reads a GitHub profile, turns it into the numbers the Bend renderer grows
// a terrarium from, and renders two phone wallpapers: day.png and night.png
// (AMOLED: a pure black sky).
//
//   node terrarium.mjs [login] [--out dir]
//
// Token: $GITHUB_TOKEN, else `gh auth token`. Renderer: $TERRARIUM_SCENE, else ./scene
// (build it with `bend scene.bend -o scene`).
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync, rmSync } from "node:fs";
import { resolve, join } from "node:path";
import { deflateSync } from "node:zlib";

const argv = process.argv.slice(2);
const outAt = argv.indexOf("--out");
const out = resolve(outAt >= 0 ? argv[outAt + 1] : ".");
const positional = argv.filter((a, i) => outAt < 0 || (i !== outAt && i !== outAt + 1));
const scene = resolve(process.env.TERRARIUM_SCENE || "./scene");

const token = process.env.GITHUB_TOKEN ||
  execFileSync("gh", ["auth", "token"], { encoding: "utf8" }).trim();

async function gql(query, variables) {
  const res = await fetch("https://api.github.com/graphql", {
    method: "POST",
    headers: { Authorization: "bearer " + token, "User-Agent": "terrarium" },
    body: JSON.stringify({ query, variables }),
  });
  const body = await res.json();
  if (body.errors) throw new Error(JSON.stringify(body.errors));
  return body.data;
}

const login = positional[0] || (await gql("query { viewer { login } }")).viewer.login;

const { user } = await gql(`query($login: String!) { user(login: $login) {
  contributionsCollection {
    totalPullRequestContributions
    contributionCalendar { totalContributions weeks { contributionDays { contributionCount } } }
  }
  repositories(first: 100, ownerAffiliations: OWNER, isFork: false) {
    nodes { stargazerCount languages(first: 10) { edges { size node { name color } } } }
  }
} }`, { login });

const cc = user.contributionsCollection;
const days = cc.contributionCalendar.weeks.flatMap(w => w.contributionDays.map(d => d.contributionCount));

// The current streak may skip today: the day is not over yet.
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
for (const r of user.repositories.nodes) {
  stars += r.stargazerCount;
  for (const e of r.languages.edges) {
    const cur = langs.get(e.node.name) || { size: 0, color: e.node.color || "#8888aa" };
    cur.size += e.size;
    langs.set(e.node.name, cur);
  }
}
const top = [...langs.entries()].sort((a, b) => b[1].size - a[1].size).slice(0, 3)
  .map(([name, l]) => ({ name, color: l.color }));
while (top.length < 3) top.push({ name: "-", color: "#66ccff" });

let seed = 2166136261;
for (const ch of login) seed = Math.imul(seed ^ ch.charCodeAt(0), 16777619) >>> 0;
seed = seed % 1000000;

const stats = {
  login, seed, total: cc.contributionCalendar.totalContributions,
  active: days.filter(n => n > 0).length,
  last30: days.slice(-30).reduce((a, b) => a + b, 0),
  streak, longest, prs: cc.totalPullRequestContributions, stars, languages: top,
};
console.log(JSON.stringify(stats));

const args = [stats.seed, stats.total, stats.active, stats.last30, stats.streak,
  stats.longest, stats.prs, stats.stars, ...top.map(l => parseInt(l.color.slice(1), 16))].map(String);

// PNG: one IHDR, one IDAT, one IEND; each row filtered with "Up".
const CRC = new Uint32Array(256).map((_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC[(c ^ b) & 255] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const head = Buffer.alloc(8);
  head.writeUInt32BE(data.length, 0);
  head.write(type, 4, "ascii");
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([head.subarray(4), data])), 0);
  return Buffer.concat([head, data, crc]);
}
function ppmToPng(ppm) {
  const text = ppm.subarray(0, 64).toString("latin1");
  const m = /^P6\s+(\d+)\s+(\d+)\s+255\s/.exec(text);
  if (!m) throw new Error("not a binary PPM");
  const [w, h] = [Number(m[1]), Number(m[2])];
  const px = ppm.subarray(m[0].length);
  const stride = w * 3;
  const raw = Buffer.alloc((stride + 1) * h);
  for (let y = 0; y < h; y++) {
    const o = y * (stride + 1);
    raw[o] = 2;
    for (let x = 0; x < stride; x++) {
      const up = y > 0 ? px[(y - 1) * stride + x] : 0;
      raw[o + 1 + x] = (px[y * stride + x] - up) & 255;
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr.set([8, 2, 0, 0, 0], 8);
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", ihdr), chunk("IDAT", deflateSync(raw, { level: 9 })),
    chunk("IEND", Buffer.alloc(0))]);
}

mkdirSync(out, { recursive: true });
for (const [flag, name] of [["0", "night"], ["1", "day"]]) {
  const t = Date.now();
  execFileSync(scene, [flag, ...args], { cwd: out, stdio: "inherit" });
  const ppm = join(out, name + ".ppm");
  writeFileSync(join(out, name + ".png"), ppmToPng(readFileSync(ppm)));
  rmSync(ppm);
  console.log(name + ".png", (Date.now() - t) + " ms");
}
writeFileSync(join(out, "terrarium.json"), JSON.stringify(stats, null, 2) + "\n");
