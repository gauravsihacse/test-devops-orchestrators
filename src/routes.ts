import { Router } from "express";
import path from "path";
import fs from "fs";

const router = Router();

router.get("/health", (req, res) => {
    res.json({ status: "ok", timestamp: new Date() });
});


router.get("/healthz", (req, res) => {
  const logFile = path.join(__dirname, "../logs/output.log");

  try {
    const logLines = fs.readFileSync(logFile, "utf-8").trim().split("\n");
    const lastLine = logLines.reverse().find(line => line.includes("[heartbeat]"));

    if (!lastLine) {
      return res.status(503).json({ status: "fail", reason: "no heartbeat found" });
    }

    const match = lastLine.match(/\[heartbeat\] (.+)/);
    if (!match) {
      return res.status(503).json({ status: "fail", reason: "malformed heartbeat log" });
    }

    const lastTimestamp = new Date(match[1]);
    const now = new Date();
    const uptimeSeconds = Math.floor((now.getTime() - lastTimestamp.getTime()) / 1000);
    const uptimeMinutes = Math.floor(uptimeSeconds / 60);

    const isHealthy = uptimeSeconds < 10;

    return res.status(isHealthy ? 200 : 503).json({
      status: isHealthy ? "ok" : "fail",
      last_heartbeat: lastTimestamp.toISOString(),
      uptime_seconds: uptimeSeconds,
      uptime_minutes: uptimeMinutes,
      reason: isHealthy ? undefined : "heartbeat stale"
    });
  } catch (err: any) {
    return res.status(500).json({ status: "error", message: err.message });
  }
});

router.get("/metrics", (req, res) => {
  const logFile = path.join(__dirname, "../logs/output.log");

  let heartbeatCount = 0;
  let lastTimestamp = null;

  try {
    const lines = fs.readFileSync(logFile, "utf-8")
      .trim()
      .split("\n")
      .filter(line => line.includes("[heartbeat]"));

    heartbeatCount = lines.length;

    if (heartbeatCount > 0) {
      const lastLine = lines[heartbeatCount - 1];
      const match = lastLine.match(/\[heartbeat\] (.+)/);
      if (match) {
        lastTimestamp = new Date(match[1]);
      }
    }

    const now = new Date();
    const secondsSinceLast = lastTimestamp ? Math.floor((now.getTime() - lastTimestamp.getTime()) / 1000) : -1;

    // System resource metrics
    const memoryUsage = process.memoryUsage(); // in bytes
    const cpuUsage = process.cpuUsage();       // in microseconds

    res.set("Content-Type", "text/plain");
    res.send(
`# HELP swap_optimizer_heartbeat_count Total number of heartbeats recorded
# TYPE swap_optimizer_heartbeat_count counter
swap_optimizer_heartbeat_count ${heartbeatCount}

# HELP swap_optimizer_last_heartbeat_seconds Seconds since last heartbeat
# TYPE swap_optimizer_last_heartbeat_seconds gauge
swap_optimizer_last_heartbeat_seconds ${secondsSinceLast}

# HELP swap_optimizer_memory_rss_bytes Resident Set Size memory
# TYPE swap_optimizer_memory_rss_bytes gauge
swap_optimizer_memory_rss_bytes ${memoryUsage.rss}

# HELP swap_optimizer_memory_heap_used_bytes Heap memory used
# TYPE swap_optimizer_memory_heap_used_bytes gauge
swap_optimizer_memory_heap_used_bytes ${memoryUsage.heapUsed}

# HELP swap_optimizer_cpu_user_usec User-space CPU time (microseconds)
# TYPE swap_optimizer_cpu_user_usec counter
swap_optimizer_cpu_user_usec ${cpuUsage.user}

# HELP swap_optimizer_cpu_system_usec Kernel-space CPU time (microseconds)
# TYPE swap_optimizer_cpu_system_usec counter
swap_optimizer_cpu_system_usec ${cpuUsage.system}`
    );
  } catch (err: any) {
    res.status(500).send(`# ERROR reading logs: ${err.message}`);
  }
});

export default router;