const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");
const levelLabel = document.getElementById("levelLabel");
const skillLabel = document.getElementById("skillLabel");
const combatLabel = document.getElementById("combatLabel");

const W = canvas.width;
const H = canvas.height;
const tile = 32;
const cols = Math.floor(W / tile);
const rows = Math.floor(H / tile);
const bridgeColumns = [5, 6, 7, 21, 22, 23];

const keys = new Set();
let state = "start";
let menuChoice = 0;
let pillChoice = 0;
let startDifficulty = 1;
let level = 1;
let frame = 0;
let message = "";
let map = [];
let npcs = [];
let smiths = [];
let bullets = [];
let pickups = [];
let bombs = [];
let currentRiverY = 8;
let player;
let phone;
let redWoman;
let trinity;
let terminal;
let trinityFound = false;
let terminalHacked = false;
let rescued = 0;
let rescueGoal = 3;
let hasBulletTime = false;
let bulletTime = 0;
let bulletCooldown = 0;
let attract = 0;
let redCooldown = 0;
let lastDir = { x: 1, y: 0 };
let ammo = 0;
let charges = 0;
let empCount = 0;
let cloakCount = 0;
let mapFragments = 0;
let phoneCards = 0;
let empPulse = 0;
let cloakTimer = 0;
let shootCooldown = 0;
let chargeCooldown = 0;

const rnd = (() => {
  let seed = 0x4d595df4;
  return () => {
    seed ^= seed << 13;
    seed ^= seed >>> 17;
    seed ^= seed << 5;
    return ((seed >>> 0) % 10000) / 10000;
  };
})();

function rects(a, b) {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

function clamp(v, lo, hi) {
  return Math.max(lo, Math.min(hi, v));
}

function distance(a, b) {
  const ax = a.x + a.w / 2;
  const ay = a.y + a.h / 2;
  const bx = b.x + b.w / 2;
  const by = b.y + b.h / 2;
  return Math.hypot(ax - bx, ay - by);
}

function centerOf(e) {
  return { x: e.x + e.w / 2, y: e.y + e.h / 2 };
}

function makeMap() {
  map = Array.from({ length: rows }, () => Array(cols).fill("street"));
  const riverY = 5 + Math.floor(rnd() * 6);
  currentRiverY = riverY;
  for (let y = riverY; y < riverY + 3; y++) {
    for (let x = 0; x < cols; x++) map[y][x] = "river";
  }
  for (let y = riverY; y < riverY + 3; y++) {
    for (let x of bridgeColumns) map[y][x] = "bridge";
  }
  for (let i = 0; i < 28 + level * 3; i++) {
    const x = 2 + Math.floor(rnd() * (cols - 4));
    const y = 2 + Math.floor(rnd() * (rows - 4));
    const bw = 1 + Math.floor(rnd() * 3);
    const bh = 1 + Math.floor(rnd() * 3);
    for (let yy = y; yy < Math.min(rows - 2, y + bh); yy++) {
      for (let xx = x; xx < Math.min(cols - 2, x + bw); xx++) {
        if (map[yy][xx] === "street") map[yy][xx] = "building";
      }
    }
  }
  for (let i = 0; i < 46; i++) {
    const x = Math.floor(rnd() * cols);
    const y = Math.floor(rnd() * rows);
    if (map[y][x] === "street") map[y][x] = "tree";
  }
  clearArea(1, rows - 4, 4, 3);
  clearArea(cols - 5, 1, 4, 4);
  clearBridgeApproaches(riverY);
}

function clearArea(x, y, w, h) {
  for (let yy = y; yy < y + h; yy++) {
    for (let xx = x; xx < x + w; xx++) {
      if (map[yy] && map[yy][xx]) map[yy][xx] = "street";
    }
  }
}

function clearBridgeApproaches(riverY) {
  for (const x of bridgeColumns) {
    for (let y = riverY - 2; y <= riverY + 4; y++) {
      if (map[y]?.[x] && map[y][x] !== "river") map[y][x] = "street";
      if (map[y]?.[x - 1] && map[y][x - 1] !== "river") map[y][x - 1] = "street";
      if (map[y]?.[x + 1] && map[y][x + 1] !== "river") map[y][x + 1] = "street";
    }
  }
  for (let y = riverY; y < riverY + 3; y++) {
    for (const x of bridgeColumns) map[y][x] = "bridge";
  }
}

function walkable(x, y, w, h) {
  const points = [
    [x + 2, y + 2],
    [x + w - 2, y + 2],
    [x + 2, y + h - 2],
    [x + w - 2, y + h - 2],
    [x + w / 2, y + h / 2]
  ];
  return points.every(([px, py]) => {
    const tx = Math.floor(px / tile);
    const ty = Math.floor(py / tile);
    const t = map[ty]?.[tx];
    return t && t !== "river" && t !== "building";
  });
}

function destructibleAt(tx, ty) {
  const t = map[ty]?.[tx];
  return t === "building" || t === "tree";
}

function destroyTerrainAt(px, py, radius = 1) {
  const tx = Math.floor(px / tile);
  const ty = Math.floor(py / tile);
  let changed = false;
  for (let y = ty - radius; y <= ty + radius; y++) {
    for (let x = tx - radius; x <= tx + radius; x++) {
      if (destructibleAt(x, y)) {
        map[y][x] = "street";
        changed = true;
      }
    }
  }
  return changed;
}

function moveEntity(entity, dx, dy) {
  const nx = clamp(entity.x + dx, 0, W - entity.w);
  const ny = clamp(entity.y + dy, 0, H - entity.h);
  if (walkable(nx, ny, entity.w, entity.h)) {
    entity.x = nx;
    entity.y = ny;
    return true;
  }
  if (walkable(nx, entity.y, entity.w, entity.h)) {
    entity.x = nx;
    return true;
  }
  if (walkable(entity.x, ny, entity.w, entity.h)) {
    entity.y = ny;
    return true;
  }
  return false;
}

function moveSmith(smith, target, speed, slow) {
  let dx = 0;
  let dy = 0;
  if (smith.chasing) {
    dx = target.x - smith.x;
    dy = target.y - smith.y;
    const len = Math.hypot(dx, dy) || 1;
    dx = (dx / len) * speed;
    dy = (dy / len) * speed;
  } else {
    if (frame % 70 === 0 || smith.vx === undefined) {
      smith.vx = (rnd() - 0.5) * 2.2;
      smith.vy = (rnd() - 0.5) * 2.2;
    }
    dx = smith.vx;
    dy = smith.vy;
  }

  dx *= slow;
  dy *= slow;
  if (moveEntity(smith, dx, dy)) return;

  const sidestep = Math.max(1.1, speed * 0.9) * slow;
  const horizontalFirst = Math.abs(target.x - smith.x) > Math.abs(target.y - smith.y);
  const options = horizontalFirst
    ? [[0, Math.sign(target.y - smith.y || smith.vy || 1) * sidestep], [Math.sign(target.x - smith.x || smith.vx || 1) * sidestep, 0], [0, -Math.sign(target.y - smith.y || smith.vy || 1) * sidestep]]
    : [[Math.sign(target.x - smith.x || smith.vx || 1) * sidestep, 0], [0, Math.sign(target.y - smith.y || smith.vy || 1) * sidestep], [-Math.sign(target.x - smith.x || smith.vx || 1) * sidestep, 0]];

  for (const [sx, sy] of options) {
    if (moveEntity(smith, sx, sy)) return;
  }

  smith.vx = (rnd() - 0.5) * 2.6;
  smith.vy = (rnd() - 0.5) * 2.6;
}

function spawnEntity(width = 22, height = width) {
  for (let i = 0; i < 500; i++) {
    const x = Math.floor(rnd() * (W - 80)) + 40;
    const y = Math.floor(rnd() * (H - 80)) + 40;
    if (walkable(x, y, width, height)) return { x, y, w: width, h: height };
  }
  return { x: 80, y: 80, w: width, h: height };
}

function spawnAwayFrom(avoid, minDistance, width = 22, height = width) {
  for (let i = 0; i < 700; i++) {
    const entity = spawnEntity(width, height);
    if (!avoid || distance(entity, avoid) >= minDistance) return entity;
  }
  return spawnEntity(width, height);
}

function spawnNearTile(tx, ty, width = 24, height = width) {
  for (let radius = 0; radius < 9; radius++) {
    for (let dy = -radius; dy <= radius; dy++) {
      for (let dx = -radius; dx <= radius; dx++) {
        const x = clamp((tx + dx) * tile + 4, 0, W - width);
        const y = clamp((ty + dy) * tile + 4, 0, H - height);
        if (walkable(x, y, width, height)) return { x, y, w: width, h: height };
      }
    }
  }
  return spawnEntity(width, height);
}

function spawnPickup(type, avoid, minDistance) {
  const item = spawnAwayFrom(avoid, minDistance, 18, 18);
  item.type = type;
  return item;
}

function addPickup(type, avoid, minDistance) {
  pickups.push(spawnPickup(type, avoid, minDistance));
}

function smithLimit() {
  return Math.max(2, Math.min(10, 1 + level * 2 - rescued));
}

function startLevel(nextLevel) {
  level = nextLevel;
  trinityFound = false;
  terminalHacked = false;
  rescued = 0;
  rescueGoal = Math.min(5, 2 + Math.floor(level / 2));
  makeMap();
  player = { x: 48, y: H - 96, w: 16, h: 20, speed: 3.1 };
  phone = spawnAwayFrom(player, 430, 32, 46);
  redWoman = spawnAwayFrom(player, 180, 16, 20);
  trinity = spawnNearTile(4, 3, 16, 20);
  terminal = spawnNearTile(6, Math.min(rows - 2, currentRiverY + 4), 24, 24);
  hasBulletTime = false;
  bulletTime = 0;
  bulletCooldown = 0;
  attract = 0;
  redCooldown = 0;
  bullets = [];
  bombs = [];
  ammo = 0;
  charges = 0;
  empCount = 0;
  cloakCount = 0;
  mapFragments = 0;
  phoneCards = 0;
  empPulse = 0;
  cloakTimer = 0;
  shootCooldown = 0;
  chargeCooldown = 0;
  lastDir = { x: 1, y: 0 };
  npcs = Array.from({ length: 9 }, () => spawnEntity(15, 19));
  const firstSmith = spawnAwayFrom(player, 360, 16, 20);
  const hunter = spawnAwayFrom(player, 420, 16, 20);
  const interceptor = spawnAwayFrom(player, 460, 16, 20);
  smiths = [
    { ...firstSmith, type: "patrol", vx: 1.2, vy: 0.8, chasing: false, alert: 0 },
    { ...hunter, type: "hunter", vx: -1.0, vy: 0.9, chasing: false, alert: 0 },
    { ...interceptor, type: "interceptor", vx: 0.8, vy: -1.1, chasing: false, alert: 0 }
  ].slice(0, Math.min(3, 1 + level));
  pickups = [];
  addPickup("gun", player, 170);
  addPickup("ammo", player, 230);
  addPickup("charge", player, 210);
  addPickup("charge", player, 280);
  addPickup("emp", player, 210);
  addPickup("cloak", player, 240);
  addPickup("map", player, 260);
  addPickup("phonecard", player, 300);
  state = "play";
  message = "";
}

function update() {
  frame++;
  levelLabel.textContent = `Level ${level}`;
  skillLabel.textContent = hasBulletTime
    ? bulletTime > 0 ? "Bullet Time: active" : "Bullet Time: ready"
    : "Bullet Time: locked";
  combatLabel.textContent = ammo > 0 || charges > 0 || bombs.length > 0
    ? `Ammo ${ammo} | Bomb ${charges} | EMP ${empCount} | Cloak ${cloakCount} | Cards ${phoneCards} | Saved ${rescued}/${rescueGoal}`
    : `EMP ${empCount} | Cloak ${cloakCount} | Cards ${phoneCards} | Saved ${rescued}/${rescueGoal}`;

  if (bulletTime > 0) bulletTime--;
  if (bulletCooldown > 0) bulletCooldown--;
  if (attract > 0) attract--;
  if (redCooldown > 0) redCooldown--;
  if (shootCooldown > 0) shootCooldown--;
  if (chargeCooldown > 0) chargeCooldown--;
  if (empPulse > 0) empPulse--;
  if (cloakTimer > 0) cloakTimer--;

  if (state !== "play") return;

  if (keys.has(" ") && hasBulletTime && bulletTime === 0 && bulletCooldown === 0) {
    bulletTime = 260;
    bulletCooldown = 420;
  }

  if (attract === 0) {
    let dx = 0;
    let dy = 0;
    if (keys.has("w") || keys.has("arrowup")) dy--;
    if (keys.has("s") || keys.has("arrowdown")) dy++;
    if (keys.has("a") || keys.has("arrowleft")) dx--;
    if (keys.has("d") || keys.has("arrowright")) dx++;
    const len = Math.hypot(dx, dy) || 1;
    if (dx !== 0 || dy !== 0) {
      lastDir = { x: dx / len, y: dy / len };
    }
    moveEntity(player, (dx / len) * player.speed, (dy / len) * player.speed);
  }

  if (keys.has("j") && ammo > 0 && shootCooldown === 0) {
    const c = centerOf(player);
    bullets.push({
      x: c.x - 3,
      y: c.y - 3,
      w: 6,
      h: 6,
      vx: lastDir.x * 8,
      vy: lastDir.y * 8,
      life: 70
    });
    ammo--;
    shootCooldown = 12;
  }

  if (keys.has("k") && charges > 0 && chargeCooldown === 0) {
    const c = centerOf(player);
    bombs.push({
      x: c.x + lastDir.x * 22 - 8,
      y: c.y + lastDir.y * 22 - 8,
      w: 16,
      h: 16,
      timer: 110,
      radius: 1
    });
    charges--;
    chargeCooldown = 28;
  }

  if (keys.has("e") && empCount > 0 && empPulse === 0) {
    empCount--;
    empPulse = 150;
    for (const smith of smiths) {
      if (distance(player, smith) < 190) smith.stunned = 150;
    }
  }

  if (keys.has("q") && cloakCount > 0 && cloakTimer === 0) {
    cloakCount--;
    cloakTimer = 360;
  }

  if (rects(player, redWoman) && attract === 0 && redCooldown === 0) {
    attract = 170;
    redCooldown = 420;
  }
  if (rects(player, trinity)) {
    hasBulletTime = true;
    trinityFound = true;
  }
  if (trinityFound && !terminalHacked && rects(player, terminal)) {
    terminalHacked = true;
  }
  for (let i = pickups.length - 1; i >= 0; i--) {
    if (rects(player, pickups[i])) {
      if (pickups[i].type === "gun") ammo += 18;
      if (pickups[i].type === "ammo") ammo += 12;
      if (pickups[i].type === "charge") charges += 1;
      if (pickups[i].type === "emp") empCount += 1;
      if (pickups[i].type === "cloak") cloakCount += 1;
      if (pickups[i].type === "map") mapFragments = Math.min(3, mapFragments + 1);
      if (pickups[i].type === "phonecard") phoneCards += 1;
      pickups.splice(i, 1);
    }
  }
  for (let i = npcs.length - 1; i >= 0 && rescued < rescueGoal; i--) {
    if (trinityFound && rects(player, npcs[i])) {
      npcs.splice(i, 1);
      rescued++;
    }
  }
  if (trinityFound && terminalHacked && rescued >= rescueGoal && rects(player, phone)) {
    if (phoneCards > 0) {
      phoneCards--;
      state = "win";
    } else {
      state = "pill";
    }
    pillChoice = 0;
  }

  for (const npc of npcs) {
    if (frame % 24 === 0) {
      npc.vx = (rnd() - 0.5) * 2;
      npc.vy = (rnd() - 0.5) * 2;
    }
    if (!moveEntity(npc, npc.vx || 0, npc.vy || 0)) {
      npc.vx = -(npc.vx || 0);
      npc.vy = -(npc.vy || 0);
    }
  }

  const slow = bulletTime > 0 ? 0.28 : 1;
  if (frame % 36 === 0) {
    redWoman.vx = (rnd() - 0.5) * 1.2;
    redWoman.vy = (rnd() - 0.5) * 1.2;
  }
  moveEntity(redWoman, (redWoman.vx || 0) * slow, (redWoman.vy || 0) * slow);

  if (frame % 42 === 0 || trinity.vx === undefined) {
    trinity.vx = (rnd() - 0.5) * 1.8;
    trinity.vy = (rnd() - 0.5) * 1.8;
  }
  if (!moveEntity(trinity, trinity.vx * slow, trinity.vy * slow)) {
    trinity.vx = -trinity.vx;
    trinity.vy = -trinity.vy;
  }

  for (let i = bombs.length - 1; i >= 0; i--) {
    bombs[i].timer--;
    if (bombs[i].timer <= 0) {
      const c = centerOf(bombs[i]);
      destroyTerrainAt(c.x, c.y, bombs[i].radius);
      for (let s = smiths.length - 1; s >= 0; s--) {
        if (distance(bombs[i], smiths[s]) < tile * 1.7) {
          smiths.splice(s, 1);
        }
      }
      bombs.splice(i, 1);
    }
  }

  for (const smith of smiths) {
    if (smith.stunned > 0) {
      smith.stunned--;
      continue;
    }
    const cloakScale = cloakTimer > 0 ? 0.45 : 1;
    const sense = (smith.type === "hunter" ? 260 + level * 24 : smith.type === "interceptor" ? 190 + level * 16 : 170 + level * 14) * cloakScale;
    if (distance(smith, player) < sense) smith.alert = smith.type === "hunter" ? 220 : 90;
    if (smith.alert > 0) smith.alert--;
    smith.chasing = smith.alert > 0;
    const target = smithTarget(smith);
    const speed = (smith.type === "hunter" ? 1.28 : smith.type === "interceptor" ? 1.04 : 0.92) + level * 0.13;
    moveSmith(smith, target, speed, slow);
    if (rects(player, smith)) {
      state = "lose";
      message = "Smith rewrote Neo.";
    }
  }

  for (let i = bullets.length - 1; i >= 0; i--) {
    const b = bullets[i];
    b.x += b.vx;
    b.y += b.vy;
    b.life--;
    const tx = Math.floor((b.x + b.w / 2) / tile);
    const ty = Math.floor((b.y + b.h / 2) / tile);
    if (b.life <= 0 || b.x < 0 || b.y < 0 || b.x > W || b.y > H) {
      bullets.splice(i, 1);
      continue;
    }
    if (map[ty]?.[tx] === "building" || map[ty]?.[tx] === "river") {
      bullets.splice(i, 1);
      continue;
    }
    let hit = false;
    for (let s = smiths.length - 1; s >= 0; s--) {
      if (rects(b, smiths[s])) {
        smiths.splice(s, 1);
        bullets.splice(i, 1);
        hit = true;
        break;
      }
    }
    if (hit) continue;
  }

  for (const smith of smiths) {
    for (let i = npcs.length - 1; i >= 0; i--) {
      if (smiths.length < smithLimit() && rects(smith, npcs[i])) {
        const n = npcs.splice(i, 1)[0];
        smiths.push({ x: n.x, y: n.y, w: 16, h: 20, type: "patrol", vx: (rnd() - 0.5) * 2, vy: (rnd() - 0.5) * 2, chasing: false, alert: 0 });
      }
    }
  }
}

function smithTarget(smith) {
  if (smith.type === "interceptor" && !smith.chasing) {
    if (trinityFound && !terminalHacked) return terminal;
    if (trinityFound && terminalHacked) return phone;
    return trinity;
  }
  if (smith.type === "interceptor" && smith.chasing) {
    return {
      x: clamp(player.x + lastDir.x * 90, 0, W - player.w),
      y: clamp(player.y + lastDir.y * 90, 0, H - player.h),
      w: player.w,
      h: player.h
    };
  }
  return player;
}

function drawRain(alpha = 1) {
  ctx.fillStyle = `rgba(28, 255, 90, ${alpha})`;
  ctx.font = "16px Consolas, monospace";
  for (let x = 0; x < W; x += 22) {
    for (let y = -40; y < H; y += 32) {
      const bit = ((x * 17 + y * 9 + frame) & 32) ? "1" : "0";
      ctx.fillText(bit, x, (y + frame * 3 + x) % (H + 40));
    }
  }
}

function drawMap() {
  for (let y = 0; y < rows; y++) {
    for (let x = 0; x < cols; x++) {
      const t = map[y][x];
      const px = x * tile;
      const py = y * tile;
      if (t === "river") ctx.fillStyle = "#0d4d82";
      else if (t === "bridge") ctx.fillStyle = terminalHacked ? "#8e6532" : "#735127";
      else if (t === "building") ctx.fillStyle = "#44505a";
      else if (t === "tree") ctx.fillStyle = "#185b28";
      else ctx.fillStyle = "#1c1f20";
      ctx.fillRect(px, py, tile, tile);
      ctx.strokeStyle = t === "street" ? "#272b2c" : "rgba(0,0,0,.18)";
      ctx.strokeRect(px, py, tile, tile);
      if (t === "bridge" && !terminalHacked) {
        ctx.fillStyle = "rgba(241, 207, 100, .45)";
        ctx.fillRect(px + 4, py + 14, 24, 4);
      }
      if (t === "building") {
        ctx.fillStyle = "#b7d2bd";
        ctx.fillRect(px + 7, py + 8, 5, 5);
        ctx.fillRect(px + 20, py + 17, 5, 5);
      }
    }
  }
}

function drawPickup(item) {
  if (item.type === "gun") {
    ctx.fillStyle = "#d8ffe0";
    ctx.fillRect(item.x, item.y + 7, 18, 4);
    ctx.fillRect(item.x + 11, item.y + 11, 4, 7);
  } else if (item.type === "ammo") {
    ctx.fillStyle = "#f1cf64";
    ctx.fillRect(item.x + 4, item.y + 2, 10, 14);
    ctx.fillStyle = "#5b4310";
    ctx.fillRect(item.x + 7, item.y + 4, 4, 10);
  } else if (item.type === "charge") {
    ctx.fillStyle = "#ff8a2a";
    ctx.fillRect(item.x + 3, item.y + 3, 12, 12);
    ctx.fillStyle = "#fff0b0";
    ctx.fillRect(item.x + 7, item.y, 4, 6);
  } else if (item.type === "emp") {
    ctx.fillStyle = "#6ff7ff";
    ctx.beginPath();
    ctx.arc(item.x + 9, item.y + 9, 8, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#06232d";
    ctx.fillRect(item.x + 5, item.y + 8, 8, 2);
  } else if (item.type === "cloak") {
    ctx.fillStyle = "rgba(170, 120, 255, .82)";
    ctx.fillRect(item.x + 3, item.y + 2, 12, 15);
    ctx.fillStyle = "#3b176f";
    ctx.fillRect(item.x + 7, item.y + 5, 4, 10);
  } else if (item.type === "map") {
    ctx.fillStyle = "#d8c48a";
    ctx.fillRect(item.x + 2, item.y + 3, 14, 12);
    ctx.fillStyle = "#2f3f28";
    ctx.fillRect(item.x + 5, item.y + 6, 8, 2);
    ctx.fillRect(item.x + 9, item.y + 9, 4, 2);
  } else if (item.type === "phonecard") {
    ctx.fillStyle = "#13c6ff";
    ctx.fillRect(item.x + 2, item.y + 4, 14, 10);
    ctx.fillStyle = "#b9faff";
    ctx.fillRect(item.x + 5, item.y + 7, 8, 2);
  }
}

function drawPhoneArrow() {
  if (!trinityFound || mapFragments === 0) return;
  const px = player.x + player.w / 2;
  const py = player.y + player.h / 2;
  const tx = phone.x + phone.w / 2;
  const ty = phone.y + phone.h / 2;
  const ang = Math.atan2(ty - py, tx - px);
  const strength = Math.min(1, mapFragments / 3);
  ctx.save();
  ctx.translate(W - 62, 72);
  ctx.rotate(ang);
  ctx.fillStyle = `rgba(92, 255, 120, ${0.35 + strength * 0.55})`;
  ctx.beginPath();
  ctx.moveTo(28, 0);
  ctx.lineTo(-16, -12);
  ctx.lineTo(-8, 0);
  ctx.lineTo(-16, 12);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
  ctx.fillStyle = "#5cff78";
  ctx.font = "14px Consolas, monospace";
  ctx.fillText(`SIGNAL x${mapFragments}`, W - 118, 110);
}

function drawBomb(bomb) {
  ctx.fillStyle = bomb.timer < 35 && frame % 8 < 4 ? "#fff0b0" : "#ff6a1a";
  ctx.fillRect(bomb.x, bomb.y, bomb.w, bomb.h);
  ctx.fillStyle = "#151008";
  ctx.fillRect(bomb.x + 4, bomb.y + 4, 8, 8);
  ctx.strokeStyle = "rgba(255, 138, 42, .45)";
  ctx.lineWidth = 2;
  ctx.strokeRect(bomb.x - tile, bomb.y - tile, bomb.w + tile * 2, bomb.h + tile * 2);
}

function drawTerminal() {
  ctx.fillStyle = terminalHacked ? "#5cff78" : "#f1cf64";
  ctx.fillRect(terminal.x, terminal.y, terminal.w, terminal.h);
  ctx.fillStyle = "#071109";
  ctx.fillRect(terminal.x + 4, terminal.y + 4, terminal.w - 8, terminal.h - 8);
  ctx.fillStyle = terminalHacked ? "#5cff78" : "#f1cf64";
  ctx.fillRect(terminal.x + 7, terminal.y + 8, terminal.w - 14, 3);
  ctx.fillRect(terminal.x + 7, terminal.y + 14, terminal.w - 18, 3);
}

function objectiveText() {
  if (!trinityFound) return "Find Trinity to reveal the phone signal";
  if (!terminalHacked) return "Hack the terminal to stabilize the phone signal";
  if (rescued < rescueGoal) return `Rescue civilians ${rescued}/${rescueGoal} to weaken assimilation`;
  return "Reach the phone booth";
}

function person(e, coat, skin, glasses = false) {
  const headW = Math.max(6, e.w - 8);
  const headX = e.x + (e.w - headW) / 2;
  const headH = Math.max(5, Math.floor(e.h * 0.28));
  const bodyY = e.y + headH;
  const bodyX = e.x + Math.max(2, Math.floor(e.w * 0.18));
  const bodyW = e.w - Math.max(4, Math.floor(e.w * 0.36));
  const armW = Math.max(3, Math.floor(e.w * 0.18));
  const footW = Math.max(4, Math.floor(e.w * 0.34));
  ctx.fillStyle = skin;
  ctx.fillRect(headX, e.y, headW, headH);
  ctx.fillStyle = coat;
  ctx.fillRect(bodyX, bodyY, bodyW, e.h - headH - 3);
  ctx.fillRect(e.x, bodyY + 4, armW, Math.max(6, e.h - headH - 8));
  ctx.fillRect(e.x + e.w - armW, bodyY + 4, armW, Math.max(6, e.h - headH - 8));
  ctx.fillStyle = "#0a0a0a";
  ctx.fillRect(e.x + 2, e.y + e.h - 3, footW, 3);
  ctx.fillRect(e.x + e.w - footW - 2, e.y + e.h - 3, footW, 3);
  if (glasses) {
    ctx.fillStyle = "#050505";
    ctx.fillRect(headX, e.y + Math.max(2, Math.floor(headH / 2)), headW, 2);
  }
}

function drawPlay() {
  drawMap();
  if (bulletTime > 0) {
    ctx.strokeStyle = "rgba(90,255,126,.35)";
    for (let x = 0; x < W; x += 32) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, H);
      ctx.stroke();
    }
  }
  if (cloakTimer > 0) {
    ctx.fillStyle = "rgba(133, 86, 255, .16)";
    ctx.fillRect(0, 0, W, H);
  }
  if (empPulse > 0) {
    ctx.strokeStyle = "rgba(111, 247, 255, .55)";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.arc(player.x + player.w / 2, player.y + player.h / 2, 190 * (empPulse / 150), 0, Math.PI * 2);
    ctx.stroke();
  }
  drawTerminal();
  if (trinityFound) {
    ctx.fillStyle = terminalHacked && rescued >= rescueGoal ? "#13c6ff" : "#095a73";
    ctx.fillRect(phone.x, phone.y, phone.w, phone.h);
    ctx.fillStyle = "#06232d";
    ctx.fillRect(phone.x + 8, phone.y + 9, 16, 10);
    ctx.fillStyle = "#b9faff";
    ctx.fillRect(phone.x + 11, phone.y + 26, 10, 12);
  }

  for (const item of pickups) drawPickup(item);
  for (const bomb of bombs) drawBomb(bomb);
  ctx.fillStyle = "#e8ff72";
  for (const b of bullets) ctx.fillRect(b.x, b.y, b.w, b.h);

  for (const npc of npcs) person(npc, "#7f8a91", "#d6b08a");
  person(redWoman, "#e32338", "#f2c69b");
  ctx.strokeStyle = hasBulletTime ? "#5cff78" : "#00f0a8";
  ctx.lineWidth = 3;
  ctx.strokeRect(trinity.x - 5, trinity.y - 5, trinity.w + 10, trinity.h + 10);
  person(trinity, "#06351f", "#d8bd9b", true);
  ctx.fillStyle = "#5cff78";
  ctx.font = "14px Consolas, monospace";
  ctx.fillText("TRINITY", trinity.x - 18, trinity.y - 10);
  for (const smith of smiths) {
    const coat = smith.type === "hunter" ? "#250000" : smith.type === "interceptor" ? "#001829" : "#050505";
    person(smith, smith.stunned > 0 ? "#225d66" : smith.chasing ? "#3a0000" : coat, "#dfc29d", true);
    if (smith.stunned > 0) {
      ctx.strokeStyle = "#6ff7ff";
      ctx.lineWidth = 2;
      ctx.strokeRect(smith.x - 5, smith.y - 5, smith.w + 10, smith.h + 10);
    }
    if (smith.chasing) {
      ctx.strokeStyle = smith.type === "hunter" ? "#ff405c" : smith.type === "interceptor" ? "#40bfff" : "#ffffff";
      ctx.lineWidth = 2;
      ctx.strokeRect(smith.x - 4, smith.y - 4, smith.w + 8, smith.h + 8);
    }
  }
  ctx.strokeStyle = "#5cff78";
  ctx.lineWidth = 3;
  ctx.strokeRect(player.x - 5, player.y - 5, player.w + 10, player.h + 10);
  person(player, "#09220f", "#deb58e", true);
  drawPhoneArrow();

  if (attract > 0) {
    ctx.fillStyle = "rgba(255,40,70,.28)";
    ctx.fillRect(0, 0, W, H);
    banner("RED WOMAN SIGNAL LOCK", "#ff405c");
  }
  ctx.fillStyle = "rgba(0,0,0,.62)";
  ctx.fillRect(0, H - 42, W, 42);
  ctx.fillStyle = "#5cff78";
  ctx.font = "20px Consolas, monospace";
  ctx.fillText(objectiveText(), 18, H - 16);
}

function banner(text, color) {
  ctx.fillStyle = "rgba(0,0,0,.55)";
  ctx.fillRect(0, 0, W, 54);
  ctx.fillStyle = color;
  ctx.font = "26px Consolas, monospace";
  ctx.textAlign = "center";
  ctx.fillText(text, W / 2, 36);
  ctx.textAlign = "left";
}

function drawStart() {
  ctx.fillStyle = "#020502";
  ctx.fillRect(0, 0, W, H);
  drawRain(0.72);
  ctx.textAlign = "center";
  ctx.fillStyle = "#5cff78";
  ctx.font = "74px Consolas, monospace";
  ctx.fillText("MATRIX", W / 2, 180);
  drawOption("START GAME", 270, menuChoice === 0);
  drawOption(`DIFFICULTY ${startDifficulty}`, 350, menuChoice === 1);
  drawOption("EXIT GAME", 430, menuChoice === 2);
  ctx.fillStyle = "#6aff83";
  ctx.font = "18px Consolas, monospace";
  ctx.fillText("Use A/D or arrows on DIFFICULTY", W / 2, 488);
  ctx.textAlign = "left";
}

function drawOption(text, y, active) {
  ctx.fillStyle = active ? "#5cff78" : "#1f7a33";
  ctx.strokeStyle = active ? "#d8ffe0" : "#174d25";
  ctx.lineWidth = 2;
  ctx.strokeRect(W / 2 - 190, y - 38, 380, 58);
  ctx.font = "32px Consolas, monospace";
  ctx.fillText(text, W / 2, y);
}

function drawPill() {
  ctx.fillStyle = "#030503";
  ctx.fillRect(0, 0, W, H);
  ctx.fillStyle = "#6f5439";
  ctx.fillRect(330, 128, 300, 145);
  ctx.fillStyle = "#d0a46f";
  ctx.fillRect(362, 160, 58, 105);
  ctx.fillRect(540, 160, 58, 105);
  ctx.fillStyle = "#e82a36";
  ctx.beginPath();
  ctx.ellipse(300, 410, 62, 34, -0.2, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#1f5dff";
  ctx.beginPath();
  ctx.ellipse(660, 410, 62, 34, 0.2, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = "#d8ffe0";
  ctx.lineWidth = 5;
  ctx.strokeRect(pillChoice === 0 ? 228 : 588, 358, 144, 100);
  ctx.fillStyle = "#5cff78";
  ctx.font = "28px Consolas, monospace";
  ctx.textAlign = "center";
  ctx.fillText("RED: LEAVE MATRIX", 300, 502);
  ctx.fillText("BLUE: NEXT LEVEL", 660, 502);
  ctx.textAlign = "left";
}

function drawEnd(win) {
  ctx.fillStyle = "#020502";
  ctx.fillRect(0, 0, W, H);
  drawRain(win ? 0.5 : 0.25);
  ctx.textAlign = "center";
  ctx.fillStyle = win ? "#5cff78" : "#ff405c";
  ctx.font = "60px Consolas, monospace";
  ctx.fillText(win ? "YOU LEFT THE MATRIX" : "GAME OVER", W / 2, 260);
  ctx.font = "24px Consolas, monospace";
  ctx.fillText("Press Enter to return", W / 2, 330);
  ctx.textAlign = "left";
}

function render() {
  ctx.clearRect(0, 0, W, H);
  if (state === "start" || state === "exit") drawStart();
  else if (state === "play") drawPlay();
  else if (state === "pill") drawPill();
  else if (state === "win") drawEnd(true);
  else if (state === "lose") drawEnd(false);
  requestAnimationFrame(loop);
}

function loop() {
  update();
  render();
}

window.addEventListener("keydown", (e) => {
  const k = e.key.toLowerCase();
  keys.add(k);
  if (["arrowup", "arrowdown", "arrowleft", "arrowright", " ", "enter"].includes(k)) e.preventDefault();
  if (state === "start") {
    if (k === "w" || k === "arrowup") menuChoice = (menuChoice + 2) % 3;
    if (k === "s" || k === "arrowdown") menuChoice = (menuChoice + 1) % 3;
    if (menuChoice === 1 && (k === "a" || k === "arrowleft")) startDifficulty = Math.max(1, startDifficulty - 1);
    if (menuChoice === 1 && (k === "d" || k === "arrowright")) startDifficulty = Math.min(5, startDifficulty + 1);
    if (k === "enter" || k === " ") {
      if (menuChoice === 0) startLevel(startDifficulty);
      else if (menuChoice === 1) startDifficulty = startDifficulty === 5 ? 1 : startDifficulty + 1;
      else state = "exit";
    }
  } else if (state === "pill") {
    if (k === "a" || k === "arrowleft") pillChoice = 0;
    if (k === "d" || k === "arrowright") pillChoice = 1;
    if (k === "enter" || k === " ") {
      if (pillChoice === 0) state = "win";
      else startLevel(level + 1);
    }
  } else if (state === "win" || state === "lose" || state === "exit") {
    if (k === "enter" || k === " " || k === "escape") state = "start";
  } else if (state === "play" && k === "escape") {
    state = "start";
  }
});

window.addEventListener("keyup", (e) => keys.delete(e.key.toLowerCase()));

loop();
