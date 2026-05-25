const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");

const COLS = 10;
const ROWS = 20;
const CELL = 20;
const BX = 40;
const BY = 40;
const PIECE_NAMES = ["I", "O", "T", "S", "Z", "J", "L"];
const COLORS = ["#1ad7ff", "#f4dc35", "#b15cff", "#3ee56f", "#ff4e56", "#4f7dff", "#ffa13b"];
const SHAPES = [
  [0x0f00, 0x1111, 0x00f0, 0x1111],
  [0x0330, 0x0330, 0x0330, 0x0330],
  [0x0072, 0x0232, 0x0270, 0x0131],
  [0x0063, 0x0132, 0x0063, 0x0132],
  [0x0036, 0x0231, 0x0036, 0x0231],
  [0x0074, 0x0223, 0x0170, 0x0311],
  [0x0071, 0x0322, 0x0470, 0x0113],
];

let board;
let cur;
let nextType;
let score;
let lines;
let level;
let gameOver;
let paused;
let fallFrames;
let frame;
let seed;
let logLines = [];

const ui = {
  score: document.getElementById("score"),
  lines: document.getElementById("lines"),
  level: document.getElementById("level"),
  piece: document.getElementById("piece"),
  next: document.getElementById("next"),
  pos: document.getElementById("pos"),
  badge: document.getElementById("stateBadge"),
  log: document.getElementById("log"),
};

function rng() {
  seed = ((seed << 1) ^ (((seed >> 15) ^ (seed >> 13) ^ (seed >> 12) ^ (seed >> 10)) & 1)) & 0xffff;
  const a = seed & 7;
  const b = (seed >> 3) & 7;
  return a < 7 ? a : b < 7 ? b : 0;
}

function shapeCells(type, rot, x, y) {
  const s = SHAPES[type][rot & 3];
  const cells = [];
  for (let r = 0; r < 4; r++) {
    for (let c = 0; c < 4; c++) {
      if (s & (1 << (r * 4 + c))) cells.push({ x: x + c, y: y + r });
    }
  }
  return cells;
}

function minLocalX(type, rot) {
  return Math.min(...shapeCells(type, rot, 0, 0).map(cell => cell.x));
}

function collision(x, y, rot, type) {
  for (const cell of shapeCells(type, rot, x, y)) {
    if (cell.x < 0 || cell.x >= COLS || cell.y < 0 || cell.y >= ROWS) return true;
    if (board[cell.y][cell.x]) return true;
  }
  return false;
}

function lockPiece() {
  for (const cell of shapeCells(cur.type, cur.rot, cur.x, cur.y)) {
    if (cell.y >= 0 && cell.y < ROWS && cell.x >= 0 && cell.x < COLS) {
      board[cell.y][cell.x] = cur.type + 1;
    }
  }
  const cleared = [];
  for (let y = 0; y < ROWS; y++) {
    if (board[y].every(Boolean)) cleared.push(y);
  }
  if (cleared.length) {
    board = board.filter((_, y) => !cleared.includes(y));
    while (board.length < ROWS) board.unshift(Array(COLS).fill(0));
    lines += cleared.length;
    score += [0, 100, 300, 500, 800][cleared.length] * (level + 1);
    if (lines >= (level + 1) * 10 && level < 15) level++;
    log(`clear ${cleared.length} row(s), score=${score}`);
  }
  spawn();
}

function ghostY() {
  let y = cur.y;
  while (!collision(cur.x, y + 1, cur.rot, cur.type)) y++;
  return y;
}

function spawn() {
  cur = { type: nextType, rot: 0, x: 3, y: 0 };
  nextType = rng();
  if (collision(cur.x, cur.y, cur.rot, cur.type)) {
    gameOver = true;
    log("game over: spawn collision");
  }
}

function move(dx) {
  if (!gameOver && !collision(cur.x + dx, cur.y, cur.rot, cur.type)) {
    cur.x += dx;
  }
}

function rotate() {
  if (gameOver) return;
  const nr = (cur.rot + 1) & 3;
  const kicks = [[0, 0], [-1, 0], [1, 0], [-2, 0], [2, 0], [-3, 0], [3, 0], [0, -1]];
  for (const [kx, ky] of kicks) {
    if (!collision(cur.x + kx, cur.y + ky, nr, cur.type)) {
      cur.x += kx;
      cur.y += ky;
      cur.rot = nr;
      return;
    }
  }
  log("rotation blocked");
}

function hardDrop() {
  if (gameOver) return;
  const before = cur.y;
  cur.y = ghostY();
  log(`hard drop ${cur.y - before} row(s)`);
  lockPiece();
}

function tick() {
  if (paused || gameOver) return;
  frame++;
  const threshold = Math.max(3, 48 - level * 5);
  if (++fallFrames >= threshold) {
    fallFrames = 0;
    if (!collision(cur.x, cur.y + 1, cur.rot, cur.type)) cur.y++;
    else lockPiece();
  }
}

function reset() {
  board = Array.from({ length: ROWS }, () => Array(COLS).fill(0));
  seed = 0xace1;
  score = 0;
  lines = 0;
  level = 0;
  gameOver = false;
  paused = false;
  fallFrames = 0;
  frame = 0;
  nextType = rng();
  spawn();
  logLines = [];
  log("reset");
}

function log(text) {
  logLines.unshift(`[${String(frame).padStart(4, "0")}] ${text}`);
  logLines = logLines.slice(0, 24);
  ui.log.textContent = logLines.join("\n");
}

function drawCell(x, y, color, alpha = 1) {
  ctx.globalAlpha = alpha;
  ctx.fillStyle = color;
  ctx.fillRect(BX + x * CELL + 1, BY + y * CELL + 1, CELL - 2, CELL - 2);
  ctx.globalAlpha = 1;
}

function draw() {
  ctx.fillStyle = "#111827";
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  ctx.fillStyle = "#050914";
  ctx.fillRect(BX, BY, COLS * CELL, ROWS * CELL);
  ctx.strokeStyle = "#4e5f75";
  ctx.lineWidth = 2;
  ctx.strokeRect(BX, BY, COLS * CELL, ROWS * CELL);

  ctx.strokeStyle = "#202c3d";
  ctx.lineWidth = 1;
  for (let x = 0; x <= COLS; x++) {
    ctx.beginPath();
    ctx.moveTo(BX + x * CELL, BY);
    ctx.lineTo(BX + x * CELL, BY + ROWS * CELL);
    ctx.stroke();
  }
  for (let y = 0; y <= ROWS; y++) {
    ctx.beginPath();
    ctx.moveTo(BX, BY + y * CELL);
    ctx.lineTo(BX + COLS * CELL, BY + y * CELL);
    ctx.stroke();
  }

  for (let y = 0; y < ROWS; y++) {
    for (let x = 0; x < COLS; x++) {
      if (board[y][x]) drawCell(x, y, COLORS[board[y][x] - 1]);
    }
  }

  if (!gameOver) {
    for (const c of shapeCells(cur.type, cur.rot, cur.x, ghostY())) drawCell(c.x, c.y, COLORS[cur.type], 0.25);
    for (const c of shapeCells(cur.type, cur.rot, cur.x, cur.y)) drawCell(c.x, c.y, COLORS[cur.type]);
  }

  ctx.fillStyle = "#e9edf2";
  ctx.font = "18px Segoe UI, Arial";
  ctx.fillText("NEXT", 290, 64);
  for (const c of shapeCells(nextType, 0, 0, 0)) {
    ctx.fillStyle = COLORS[nextType];
    ctx.fillRect(300 + c.x * CELL + 1, 78 + c.y * CELL + 1, CELL - 2, CELL - 2);
  }
  ctx.fillStyle = "#aeb9c7";
  ctx.fillText("A/D move", 290, 190);
  ctx.fillText("W rotate", 290, 216);
  ctx.fillText("S hard drop", 290, 242);

  if (gameOver) {
    ctx.fillStyle = "rgba(130, 20, 30, 0.75)";
    ctx.fillRect(120, 150, 400, 180);
    ctx.fillStyle = "#ffffff";
    ctx.font = "42px Segoe UI, Arial";
    ctx.fillText("GAME OVER", 185, 245);
  }
}

function updateUi() {
  ui.score.textContent = score;
  ui.lines.textContent = lines;
  ui.level.textContent = level;
  ui.piece.textContent = PIECE_NAMES[cur.type];
  ui.next.textContent = PIECE_NAMES[nextType];
  ui.pos.textContent = `${cur.x},${cur.y} r${cur.rot}`;
  ui.badge.textContent = gameOver ? "GAME OVER" : paused ? "PAUSED" : "RUNNING";
  ui.badge.className = `badge ${gameOver ? "fail" : paused ? "warn" : ""}`;
}

function runTest(name) {
  reset();
  if (name === "wallKick") {
    cur = { type: 0, rot: 1, x: 9, y: 2 };
    rotate();
    const ok = cur.rot === 2 && cur.x === 6 && !collision(cur.x, cur.y, cur.rot, cur.type);
    log(ok ? "PASS I-piece right-edge rotation kick" : `FAIL wall rotation x=${cur.x} r=${cur.rot}`);
  } else if (name === "lineClear") {
    board[19] = [1, 1, 1, 1, 1, 1, 0, 0, 0, 0];
    cur = { type: 0, rot: 0, x: 6, y: 17 };
    hardDrop();
    const ok = lines === 1 && board[19].every(v => v === 0);
    log(ok ? "PASS single-line clear and compaction" : `FAIL line clear lines=${lines}`);
  } else if (name === "hardDrop") {
    cur = { type: 0, rot: 0, x: 3, y: 0 };
    const gy = ghostY();
    hardDrop();
    const placed = board[gy + 2].slice(3, 7).every(Boolean);
    log(placed ? "PASS hard drop locks at ghost position" : "FAIL hard drop lock mismatch");
  } else if (name === "topOut") {
    for (let y = 0; y < 3; y++) board[y].fill(1);
    spawn();
    log(gameOver ? "PASS spawn collision game over" : "FAIL expected game over");
  } else if (name === "leftReach") {
    let ok = true;
    for (let type = 0; type < SHAPES.length; type++) {
      for (let rot = 0; rot < 4; rot++) {
        cur = { type, rot, x: 0, y: 4 };
        const legal = !collision(0, 4, rot, type);
        const touchesLeft = Math.min(...shapeCells(type, rot, 0, 4).map(cell => cell.x)) === 0;
        if (!legal || !touchesLeft || minLocalX(type, rot) !== 0) {
          ok = false;
          log(`FAIL ${PIECE_NAMES[type]} r${rot} legal=${legal} min=${minLocalX(type, rot)}`);
        }
      }
    }
    if (ok) log("PASS every piece rotation can occupy board column 0");
  }
}

window.addEventListener("keydown", (event) => {
  const key = event.key.toLowerCase();
  if (["a", "d", "w", "s", " ", "r"].includes(key)) event.preventDefault();
  if (key === "a") move(-1);
  if (key === "d") move(1);
  if (key === "w") rotate();
  if (key === "s") hardDrop();
  if (key === " ") paused = !paused;
  if (key === "r") reset();
});

document.getElementById("pauseBtn").addEventListener("click", () => paused = !paused);
document.getElementById("stepBtn").addEventListener("click", () => {
  const wasPaused = paused;
  paused = false;
  tick();
  paused = wasPaused;
});
document.getElementById("resetBtn").addEventListener("click", reset);
document.querySelectorAll("[data-test]").forEach((button) => {
  button.addEventListener("click", () => runTest(button.dataset.test));
});

function loop() {
  tick();
  draw();
  updateUi();
  requestAnimationFrame(loop);
}

reset();
loop();
