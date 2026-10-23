const form = document.getElementById("simulation-form");
const runButton = document.getElementById("run-button");
const statusText = document.getElementById("status");
const bodiesText = document.getElementById("stat-bodies");
const timeText = document.getElementById("stat-time");
const framesText = document.getElementById("stat-frames");
const canvas = document.getElementById("canvas");
const ctx = canvas.getContext("2d");

const palette = [
  "#7dd3fc",
  "#f8fafc",
  "#fda4af",
  "#fde68a",
  "#c4b5fd",
  "#86efac",
  "#f9a8d4",
  "#93c5fd",
];

const state = {
  frames: [],
  masses: [],
  bounds: null,
  animationId: null,
};

function resizeCanvas() {
  const width = canvas.clientWidth;
  const height = canvas.clientHeight;
  const devicePixelRatio = window.devicePixelRatio || 1;

  canvas.width = Math.floor(width * devicePixelRatio);
  canvas.height = Math.floor(height * devicePixelRatio);
  ctx.setTransform(devicePixelRatio, 0, 0, devicePixelRatio, 0, 0);

  if (state.frames.length > 0) {
    drawFrame(state.frames.length - 1);
  }
}

function computeBounds(frames) {
  let minX = Infinity;
  let maxX = -Infinity;
  let minY = Infinity;
  let maxY = -Infinity;

  for (const frame of frames) {
    for (const [x, y] of frame.positions) {
      minX = Math.min(minX, x);
      maxX = Math.max(maxX, x);
      minY = Math.min(minY, y);
      maxY = Math.max(maxY, y);
    }
  }

  const spanX = Math.max(1e-6, maxX - minX);
  const spanY = Math.max(1e-6, maxY - minY);
  const paddingX = spanX * 0.18 + 0.25;
  const paddingY = spanY * 0.18 + 0.25;

  return {
    minX: minX - paddingX,
    maxX: maxX + paddingX,
    minY: minY - paddingY,
    maxY: maxY + paddingY,
  };
}

function worldToScreen(x, y, bounds) {
  const width = canvas.clientWidth;
  const height = canvas.clientHeight;
  const scaleX = width / (bounds.maxX - bounds.minX);
  const scaleY = height / (bounds.maxY - bounds.minY);
  const scale = Math.min(scaleX, scaleY) * 0.92;
  const centerX = (bounds.minX + bounds.maxX) / 2;
  const centerY = (bounds.minY + bounds.maxY) / 2;

  return {
    x: width / 2 + (x - centerX) * scale,
    y: height / 2 + (y - centerY) * scale,
    scale,
  };
}

function drawBackground() {
  const width = canvas.clientWidth;
  const height = canvas.clientHeight;

  ctx.clearRect(0, 0, width, height);
  const gradient = ctx.createLinearGradient(0, 0, width, height);
  gradient.addColorStop(0, "rgba(8, 17, 31, 0.98)");
  gradient.addColorStop(1, "rgba(4, 9, 18, 0.98)");
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height);

  ctx.strokeStyle = "rgba(148, 163, 184, 0.08)";
  ctx.lineWidth = 1;
  const grid = 60;
  for (let x = 0; x < width; x += grid) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, height);
    ctx.stroke();
  }
  for (let y = 0; y < height; y += grid) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(width, y);
    ctx.stroke();
  }
}

function drawFrame(frameIndex) {
  if (!state.frames.length) {
    drawBackground();
    return;
  }

  const frame = state.frames[frameIndex];
  const width = canvas.clientWidth;
  const height = canvas.clientHeight;
  const bounds = state.bounds;

  drawBackground();

  ctx.save();
  ctx.globalCompositeOperation = "lighter";

  const trailStart = Math.max(0, frameIndex - 14);
  for (let bodyIndex = 0; bodyIndex < frame.positions.length; bodyIndex += 1) {
    ctx.beginPath();
    for (let i = trailStart; i <= frameIndex; i += 1) {
      const point = state.frames[i].positions[bodyIndex];
      const { x, y } = worldToScreen(point[0], point[1], bounds);
      if (i === trailStart) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.strokeStyle = `${palette[bodyIndex % palette.length]}55`;
    ctx.lineWidth = 2;
    ctx.stroke();
  }

  for (let bodyIndex = 0; bodyIndex < frame.positions.length; bodyIndex += 1) {
    const [xPos, yPos] = frame.positions[bodyIndex];
    const { x, y, scale } = worldToScreen(xPos, yPos, bounds);
    const radius = Math.max(2.5, Math.sqrt(state.masses[bodyIndex]) * Math.max(2.5, scale * 0.015));
    const color = palette[bodyIndex % palette.length];

    ctx.beginPath();
    ctx.fillStyle = color;
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.fill();

    ctx.beginPath();
    ctx.fillStyle = "rgba(255, 255, 255, 0.9)";
    ctx.arc(x, y, Math.max(1.3, radius * 0.35), 0, Math.PI * 2);
    ctx.fill();
  }

  ctx.restore();

  ctx.fillStyle = "rgba(237, 243, 255, 0.9)";
  ctx.font = '600 14px "Arial", sans-serif';
  ctx.fillText(`Frame ${frameIndex + 1}/${state.frames.length}`, 18, height - 18);
}

function stopAnimation() {
  if (state.animationId !== null) {
    cancelAnimationFrame(state.animationId);
    state.animationId = null;
  }
}

function startPlayback() {
  stopAnimation();

  let startedAt = null;
  const frameDuration = 1000 / 30;

  const tick = (now) => {
    if (startedAt === null) {
      startedAt = now;
    }

    const elapsed = now - startedAt;
    const nextFrame = Math.min(state.frames.length - 1, Math.floor(elapsed / frameDuration));
    drawFrame(nextFrame);

    if (nextFrame >= state.frames.length - 1) {
      state.animationId = null;
      statusText.textContent = "Simulation finished.";
      return;
    }

    state.animationId = requestAnimationFrame(tick);
  };

  state.animationId = requestAnimationFrame(tick);
}

function updateStats(payload) {
  bodiesText.textContent = payload.n;
  timeText.textContent = `${payload.t_max.toFixed(1)}s`;
  framesText.textContent = payload.frame_count;
}

async function runSimulation(event) {
  event.preventDefault();

  stopAnimation();
  runButton.disabled = true;
  statusText.textContent = "Running simulation...";

  try {
    const response = await fetch("/api/simulate", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        n: Number(document.getElementById("n-input").value),
        t_max: Number(document.getElementById("tmax-input").value),
      }),
    });

    if (!response.ok) {
      throw new Error(`Request failed with status ${response.status}`);
    }

    const payload = await response.json();
    state.frames = payload.frames;
    state.masses = payload.masses;
    state.bounds = computeBounds(payload.frames);

    updateStats(payload);
    statusText.textContent = `Computed ${payload.frame_count} sampled frames. Playing back now...`;
    drawFrame(0);
    startPlayback();
  } catch (error) {
    console.error(error);
    statusText.textContent = "Simulation failed. Check the console for details.";
  } finally {
    runButton.disabled = false;
  }
}

window.addEventListener("resize", resizeCanvas);
form.addEventListener("submit", runSimulation);
resizeCanvas();
drawBackground();
