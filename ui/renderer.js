const state = {
  logs: {}
};

function shortThumbprint(value) {
  if (!value) return "-";
  return `${value.slice(0, 8)}...${value.slice(-6)}`;
}

function formatDate(value) {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "-";
  return date.toLocaleDateString("pt-BR");
}

function subjectName(subject) {
  if (!subject) return "-";
  const match = subject.match(/CN=([^,]+)/i);
  return match ? match[1] : subject;
}

function setText(id, value) {
  document.getElementById(id).textContent = value;
}

function renderStatus(data) {
  const certs = Array.isArray(data.VirtualCertificates) ? data.VirtualCertificates : [];
  state.logs = data.Logs || {};

  setText("subtitle", `${data.ComputerName || "-"} - Remote A3 ${data.Version || ""}`);
  setText("agentStatus", data.Agent && data.Agent.HealthOk ? "Online" : "Offline");
  setText("importStatus", data.AutoImport && data.AutoImport.TaskExists ? data.AutoImport.TaskState || "Registrada" : "Ausente");
  setText("kspStatus", data.Ksp && data.Ksp.ProviderOpenOk ? "OK" : "Falha");
  setText("certCount", String(certs.length));
  setText("lastUpdated", new Date().toLocaleString("pt-BR"));

  const body = document.getElementById("certTableBody");
  body.innerHTML = "";

  for (const cert of certs) {
    const row = document.createElement("tr");
    row.innerHTML = `
      <td>
        <div class="primary">${subjectName(cert.Subject)}</div>
        <div class="secondary">${shortThumbprint(cert.Thumbprint)}</div>
      </td>
      <td>${cert.SourceHost || "-"}</td>
      <td><span class="mono">${cert.AgentUrl || "-"}</span></td>
      <td>${formatDate(cert.NotAfter)}</td>
      <td>${cert.HasPrivateKey ? "Virtual" : "Ausente"}</td>
    `;
    body.appendChild(row);
  }

  document.getElementById("emptyState").style.display = certs.length ? "none" : "block";
}

async function refresh() {
  setText("subtitle", "Atualizando...");
  const result = await window.remoteA3.status();
  if (!result.ok) {
    setText("subtitle", result.error || "Falha ao carregar status.");
    return;
  }

  renderStatus(result.data);
}

async function setup() {
  setText("subtitle", "Reparando configuracao...");
  await window.remoteA3.setup();
  await refresh();
}

document.getElementById("refreshButton").addEventListener("click", refresh);
document.getElementById("setupButton").addEventListener("click", setup);
document.getElementById("openAutoImportLog").addEventListener("click", () => window.remoteA3.openPath(state.logs.AutoImport));
document.getElementById("openKspLog").addEventListener("click", () => window.remoteA3.openPath(state.logs.Ksp));
document.getElementById("openSetupLog").addEventListener("click", () => window.remoteA3.openPath(state.logs.PlugAndPlay));

refresh();
setInterval(refresh, 30000);
