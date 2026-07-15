const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("remoteA3", {
  status: () => ipcRenderer.invoke("remote-a3:status"),
  available: () => ipcRenderer.invoke("remote-a3:available"),
  importCertificate: (certificate) => ipcRenderer.invoke("remote-a3:import", certificate),
  setup: () => ipcRenderer.invoke("remote-a3:setup"),
  openPath: (targetPath) => ipcRenderer.invoke("remote-a3:open-path", targetPath)
});
