import express from "express";
import fs from "fs";
import path from "path";
import { promisify } from "util";
import { execFile } from "child_process";
import dotenv from "dotenv";

dotenv.config();

const app = express();
const execFileAsync = promisify(execFile);
const PORT = Number(process.env.PIPELINE_PORT || 3010);
const WORK_ROOT = path.resolve(process.env.PIPELINE_WORKDIR || "./work");
const BLENDER_PATH = process.env.BLENDER_PATH || "";
const VEHICLE_BUILDER_SCRIPT = process.env.VEHICLE_BUILDER_SCRIPT || path.resolve("./scripts/build_vehicle.ps1");
const CLOTHING_BUILDER_SCRIPT = process.env.CLOTHING_BUILDER_SCRIPT || path.resolve("./scripts/build_clothing.ps1");
const MLO_BUILDER_SCRIPT = process.env.MLO_BUILDER_SCRIPT || path.resolve("./scripts/build_mlo.ps1");

app.use(express.json({ limit: "5mb" }));

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function safeName(name) {
  return String(name || "generated_asset")
    .toLowerCase()
    .replace(/[^a-z0-9_ -]/g, "")
    .trim()
    .replace(/\s+/g, "_");
}

function existsOnDisk(filePath) {
  try {
    fs.accessSync(filePath, fs.constants.F_OK);
    return true;
  } catch {
    return false;
  }
}

function createBlenderScript({ type, outFbx }) {
  const meshFactory =
    type === "vehicle"
      ? "bpy.ops.mesh.primitive_cube_add(location=(0,0,0)); obj=bpy.context.object; obj.scale=(2.2,4.6,0.8)"
      : type === "clothing"
        ? "bpy.ops.mesh.primitive_uv_sphere_add(location=(0,0,1.1)); obj=bpy.context.object; obj.scale=(0.6,0.35,1.0)"
        : "bpy.ops.mesh.primitive_cube_add(location=(0,0,0)); obj=bpy.context.object; obj.scale=(3.0,3.0,2.4)";

  return `
import bpy
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
${meshFactory}
bpy.ops.export_scene.fbx(filepath=r"${outFbx}", use_selection=False)
`;
}

function checkToolchain() {
  const missing = [];
  if (!BLENDER_PATH) missing.push("BLENDER_PATH");
  if (!existsOnDisk(VEHICLE_BUILDER_SCRIPT)) missing.push("VEHICLE_BUILDER_SCRIPT");
  if (!existsOnDisk(CLOTHING_BUILDER_SCRIPT)) missing.push("CLOTHING_BUILDER_SCRIPT");
  if (!existsOnDisk(MLO_BUILDER_SCRIPT)) missing.push("MLO_BUILDER_SCRIPT");

  return {
    blenderConfigured: Boolean(BLENDER_PATH),
    blenderExists: BLENDER_PATH ? existsOnDisk(BLENDER_PATH) : false,
    vehicleBuilderScript: VEHICLE_BUILDER_SCRIPT,
    clothingBuilderScript: CLOTHING_BUILDER_SCRIPT,
    mloBuilderScript: MLO_BUILDER_SCRIPT,
    missing,
  };
}

function buildStatusPayload() {
  return {
    service: "hunters-mods-pipeline",
    status: "ok",
    toolchain: checkToolchain(),
  };
}

function renderStatusPage(payload) {
  const { toolchain } = payload;
  const cards = [
    ["Service", payload.service],
    ["Status", payload.status.toUpperCase()],
    ["Blender", toolchain.blenderExists ? "Connected" : "Missing"],
    ["Missing Items", toolchain.missing.length ? toolchain.missing.join(", ") : "None"],
  ];

  const cardHtml = cards.map(([label, value]) => `
    <div class="card">
      <p class="label">${label}</p>
      <p class="value">${value}</p>
    </div>
  `).join("");

  const scriptHtml = [
    ["Vehicle Builder", toolchain.vehicleBuilderScript],
    ["Clothing Builder", toolchain.clothingBuilderScript],
    ["MLO Builder", toolchain.mloBuilderScript],
  ].map(([label, value]) => `
    <div class="row">
      <span>${label}</span>
      <code>${value}</code>
    </div>
  `).join("");

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Hunters Mods Pipeline</title>
  <style>
    :root {
      --bg: #0a0a0b;
      --panel: #151518;
      --panel-2: #1d1d22;
      --line: rgba(255,255,255,0.08);
      --text: #f5f5f7;
      --muted: #a1a1aa;
      --accent: #f97316;
      --good: #4ade80;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "Segoe UI", Arial, sans-serif;
      background:
        radial-gradient(circle at top, rgba(249,115,22,0.18), transparent 30%),
        linear-gradient(180deg, #09090b 0%, #111113 100%);
      color: var(--text);
      min-height: 100vh;
      padding: 32px;
    }
    .shell {
      width: min(1100px, 100%);
      margin: 0 auto;
      display: grid;
      gap: 24px;
    }
    .hero, .panel {
      background: linear-gradient(180deg, rgba(255,255,255,0.04), rgba(255,255,255,0.02));
      border: 1px solid var(--line);
      border-radius: 28px;
      padding: 28px;
      box-shadow: 0 30px 80px rgba(0,0,0,0.35);
    }
    .eyebrow {
      margin: 0 0 10px;
      color: var(--accent);
      font-size: 12px;
      font-weight: 800;
      letter-spacing: 0.28em;
      text-transform: uppercase;
    }
    h1 {
      margin: 0;
      font-size: clamp(2rem, 5vw, 3.6rem);
      letter-spacing: -0.04em;
    }
    .sub {
      margin: 12px 0 0;
      color: var(--muted);
      font-size: 1rem;
      line-height: 1.7;
      max-width: 760px;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 16px;
    }
    .card {
      background: var(--panel-2);
      border: 1px solid var(--line);
      border-radius: 22px;
      padding: 18px;
    }
    .label {
      margin: 0 0 10px;
      color: var(--muted);
      font-size: 11px;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.18em;
    }
    .value {
      margin: 0;
      font-size: 1.05rem;
      font-weight: 800;
      color: ${toolchain.missing.length ? "var(--text)" : "var(--good)"};
      word-break: break-word;
    }
    .panel h2 {
      margin: 0 0 16px;
      font-size: 1.15rem;
      letter-spacing: -0.02em;
    }
    .row {
      display: grid;
      gap: 6px;
      padding: 14px 0;
      border-top: 1px solid var(--line);
    }
    .row:first-of-type { border-top: 0; padding-top: 0; }
    .row span {
      color: var(--muted);
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.14em;
    }
    code {
      color: var(--text);
      font-family: Consolas, "Courier New", monospace;
      font-size: 13px;
      white-space: pre-wrap;
      word-break: break-word;
    }
    .footer {
      color: var(--muted);
      font-size: 13px;
    }
    @media (max-width: 900px) {
      .grid { grid-template-columns: 1fr 1fr; }
    }
    @media (max-width: 640px) {
      body { padding: 18px; }
      .grid { grid-template-columns: 1fr; }
      .hero, .panel { padding: 20px; border-radius: 22px; }
    }
  </style>
</head>
<body>
  <main class="shell">
    <section class="hero">
      <p class="eyebrow">Hunters Mods Pipeline</p>
      <h1>Binary Fabrication Service Online</h1>
      <p class="sub">This local service powers vehicle, clothing, and MLO binary generation for the admin dashboard. Browser visits show this status page, while internal app requests still receive JSON.</p>
    </section>
    <section class="grid">${cardHtml}</section>
    <section class="panel">
      <h2>Toolchain Paths</h2>
      ${scriptHtml}
    </section>
    <p class="footer">JSON status remains available for the app at <code>/api/status</code>.</p>
  </main>
</body>
</html>`;
}

app.get("/api/status", (req, res) => {
  res.json(buildStatusPayload());
});

app.get("/", (req, res) => {
  const payload = buildStatusPayload();
  const accepts = String(req.headers.accept || "");

  if (accepts.includes("text/html")) {
    res.type("html").send(renderStatusPage(payload));
    return;
  }

  res.json(payload);
});

app.post("/api/pipeline/fabricate", async (req, res) => {
  const type = String(req.body?.type || "").toLowerCase();
  const name = safeName(req.body?.name || "generated_asset");
  const allowed = ["vehicle", "mlo", "clothing"];
  if (!allowed.includes(type)) {
    return res.status(400).json({ error: `Unsupported type "${type}"` });
  }

  const tools = checkToolchain();
  if (!tools.blenderConfigured || !tools.blenderExists) {
    return res.status(500).json({
      error: "BLENDER_PATH is not configured or Blender executable was not found.",
      toolchain: tools,
    });
  }

  const jobId = `${Date.now()}_${name}`;
  const jobDir = path.join(WORK_ROOT, jobId);
  const outDir = path.join(jobDir, "out");
  ensureDir(outDir);

  const outFbx = path.join(outDir, `${name}.fbx`);
  const outYft = path.join(outDir, `${name}.yft`);
  const outYtd = path.join(outDir, `${name}.ytd`);
  const outYdd = path.join(outDir, `${name}.ydd`);
  const outYmap = path.join(outDir, `${name}.ymap`);
  const scriptPath = path.join(jobDir, "generate.py");
  fs.writeFileSync(scriptPath, createBlenderScript({ type, outFbx }), "utf8");

  const steps = [];
  try {
    steps.push("running_blender");
    await execFileAsync(BLENDER_PATH, ["--background", "--python", scriptPath], { cwd: jobDir });

    if (type === "vehicle") {
      steps.push("building_yft_ytd");
      await execFileAsync(
        "powershell",
        ["-ExecutionPolicy", "Bypass", "-File", VEHICLE_BUILDER_SCRIPT, "-InputFbx", outFbx, "-OutputYft", outYft, "-OutputYtd", outYtd],
        { cwd: jobDir }
      );
    }

    if (type === "clothing") {
      steps.push("building_ydd_ytd");
      await execFileAsync(
        "powershell",
        ["-ExecutionPolicy", "Bypass", "-File", CLOTHING_BUILDER_SCRIPT, "-InputFbx", outFbx, "-OutputYdd", outYdd, "-OutputYtd", outYtd],
        { cwd: jobDir }
      );
    }

    if (type === "mlo") {
      steps.push("building_ymap");
      await execFileAsync(
        "powershell",
        ["-ExecutionPolicy", "Bypass", "-File", MLO_BUILDER_SCRIPT, "-InputFbx", outFbx, "-OutputYmap", outYmap],
        { cwd: jobDir }
      );
    }

    const files = fs.readdirSync(outDir).map((file) => path.join(outDir, file));
    res.json({
      success: true,
      jobId,
      type,
      steps,
      files,
      message: "Fabrication pipeline completed. Binary outputs depend on configured converter commands.",
    });
  } catch (error) {
    console.error("Pipeline error:", error);
    res.status(500).json({
      success: false,
      error: String(error?.message || error),
      steps,
      toolchain: tools,
      jobId,
    });
  }
});

app.listen(PORT, () => {
  ensureDir(WORK_ROOT);
  console.log(`Hunters pipeline running on http://localhost:${PORT}`);
});
