import express from "express";
import basicAuth from "express-basic-auth";
import rateLimit from "express-rate-limit";
import helmet from "helmet";
import { spawn } from "child_process";
import fs from "fs";
import path from "path";
import dotenv from "dotenv";

dotenv.config();
const app = express();
app.use(helmet());
app.use(express.json({ limit: "200kb" }));

const HOST = process.env.HOST || "0.0.0.0";
const PORT = parseInt(process.env.PORT || "80", 10);
const REPO_ROOT = process.env.REPO_ROOT || "/opt/debian-secure-gitlab-runner";
const CFG_PATH = path.join(REPO_ROOT, "config.json");

app.use(
  basicAuth({
    users: {
      [process.env.ADMIN_USER || "admin"]: process.env.ADMIN_PASS || "admin",
    },
    challenge: true,
    realm: "runner-admin",
  })
);

app.use(
  rateLimit({
    windowMs: 60 * 1000,
    max: 60,
    standardHeaders: true,
    legacyHeaders: false,
  })
);

function runHelper(action, extraArgs = []) {
  return new Promise((resolve, reject) => {
    const p = spawn(
      "sudo",
      [path.join(REPO_ROOT, "scripts/admin-ctl.sh"), action, ...extraArgs],
      {
        stdio: ["ignore", "pipe", "pipe"],
      }
    );
    let out = "",
      err = "";
    p.stdout.on("data", (d) => (out += d));
    p.stderr.on("data", (d) => (err += d));
    p.on("close", (code) =>
      code === 0
        ? resolve(out.trim())
        : reject(new Error(err || `exit ${code}`))
    );
  });
}

app.get("/health", (_req, res) => res.json({ ok: true }));

app.get("/config", (_req, res) => {
  const data = fs.readFileSync(CFG_PATH, "utf8");
  const obj = JSON.parse(data);
  (obj.runners || []).forEach((r) => (r.registration_token = "********"));
  res.json(obj);
});

app.post("/config", (req, res, next) => {
  try {
    const incoming = req.body;
    if (typeof incoming.concurrent !== "number" || incoming.concurrent < 0) {
      return res.status(400).json({ error: "invalid concurrent" });
    }
    const tmp = CFG_PATH + ".tmp";
    fs.writeFileSync(tmp, JSON.stringify(incoming, null, 2));
    fs.renameSync(tmp, CFG_PATH);
    res.json({ ok: true });
  } catch (e) {
    next(e);
  }
});

app.post("/apply/concurrent", async (_req, res, next) => {
  try {
    res.json({ ok: true, output: await runHelper("set-concurrent") });
  } catch (e) {
    next(e);
  }
});

app.post("/apply/register", async (_req, res, next) => {
  try {
    res.json({ ok: true, output: await runHelper("register") });
  } catch (e) {
    next(e);
  }
});

app.post("/runner/restart", async (_req, res, next) => {
  try {
    res.json({ ok: true, output: await runHelper("restart") });
  } catch (e) {
    next(e);
  }
});

app.get("/runner/list", async (_req, res, next) => {
  try {
    res.json({ ok: true, output: await runHelper("list") });
  } catch (e) {
    next(e);
  }
});

app.use((err, _req, res, _next) => {
  res.status(500).json({ error: err.message });
});

app.listen(PORT, HOST, () => {
  console.log(`admin listening on http://${HOST}:${PORT}`);
});
