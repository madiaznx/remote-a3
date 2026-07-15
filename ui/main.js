const { app, BrowserWindow, ipcMain, shell } = require("electron");
const { execFile } = require("node:child_process");
const path = require("node:path");

function getRemoteA3ScriptPath() {
  return path.join(process.env.LOCALAPPDATA || "", "RemoteA3", "scripts", "RemoteA3.ps1");
}

function runRemoteA3(args) {
  return new Promise((resolve) => {
    const powershell = path.join(process.env.SystemRoot || "C:\\Windows", "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
    const scriptPath = getRemoteA3ScriptPath();
    const commandArgs = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", scriptPath, ...args];

    execFile(powershell, commandArgs, { windowsHide: true, timeout: 30000 }, (error, stdout, stderr) => {
      resolve({
        ok: !error,
        stdout: stdout || "",
        stderr: stderr || "",
        error: error ? error.message : null
      });
    });
  });
}

function createWindow() {
  const window = new BrowserWindow({
    width: 1120,
    height: 720,
    minWidth: 880,
    minHeight: 560,
    title: "Remote A3",
    backgroundColor: "#f7f8fb",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  window.loadFile(path.join(__dirname, "index.html"));
}

app.whenReady().then(() => {
  ipcMain.handle("remote-a3:status", async () => {
    const result = await runRemoteA3(["status-json"]);
    if (!result.ok) {
      return { ok: false, error: result.stderr || result.error || "Falha ao ler status." };
    }

    try {
      return { ok: true, data: JSON.parse(result.stdout) };
    } catch (error) {
      return { ok: false, error: error.message, raw: result.stdout };
    }
  });

  ipcMain.handle("remote-a3:setup", async () => runRemoteA3(["setup"]));

  ipcMain.handle("remote-a3:open-path", async (_event, targetPath) => {
    if (!targetPath) {
      return false;
    }

    await shell.openPath(targetPath);
    return true;
  });

  createWindow();
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});
