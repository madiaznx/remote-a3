const state = {
  logs: {},
  status: null,
  available: []
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

function showError(result, fallback) {
  const suffix = result && result.logPath ? " Detalhes gravados no log." : "";
  setText("subtitle", `${(result && result.error) || fallback}${suffix}`);
}

function renderStatus(data) {
  const certs = Array.isArray(data.VirtualCertificates) ? data.VirtualCertificates : [];
  state.logs = data.Logs || {};
  state.status = data;

  setText("subtitle", `${data.ComputerName || "-"} - Remote A3 ${data.Version || ""}`);
  setText("agentStatus", data.Agent && data.Agent.HealthOk ? "Online" : "Offline");
  setText("kspStatus", data.Ksp && data.Ksp.ProviderOpenOk ? "OK" : "Falha");
  setText("certCount", String(certs.length));
  setText("lastUpdated", new Date().toLocaleString("pt-BR"));
}

function renderAvailable(certs) {
  state.available = Array.isArray(certs) ? certs : [];
  setText("foundCount", String(state.available.filter((cert) => cert.Thumbprint).length));

  const body = document.getElementById("certTableBody");
  body.innerHTML = "";

  for (const cert of state.available) {
    const row = document.createElement("tr");
    const canImport = cert.Thumbprint && cert.AgentUrl && !cert.Imported && !cert.InstalledLocal;
    const button = canImport
      ? `<button class="import-button" type="button" data-agent="${encodeURIComponent(cert.AgentUrl)}" data-thumbprint="${encodeURIComponent(cert.Thumbprint)}">Importar</button>`
      : `<button type="button" disabled>${cert.InstalledLocal ? "Instalado" : cert.Imported ? "Importado" : "Indisponivel"}</button>`;
    const status = cert.DiscoveryError ? "Credencial necessaria" : cert.InstalledLocal ? "Instalado local" : cert.Imported ? "Importado" : "Disponivel";

    row.innerHTML = `
      <td>
        <div class="primary">${subjectName(cert.Subject)}</div>
        <div class="secondary">${cert.Thumbprint ? shortThumbprint(cert.Thumbprint) : cert.DiscoveryError || ""}</div>
      </td>
      <td>${cert.MachineName || cert.SourceHost || "-"}</td>
      <td><span class="mono">${cert.AgentUrl || "-"}</span></td>
      <td>${formatDate(cert.NotAfter)}</td>
      <td>${status}</td>
      <td>${button}</td>
    `;
    body.appendChild(row);
  }

  document.querySelectorAll(".import-button").forEach((button) => {
    button.addEventListener("click", () => importCertificate({
      AgentUrl: decodeURIComponent(button.dataset.agent),
      Thumbprint: decodeURIComponent(button.dataset.thumbprint)
    }));
  });

  document.getElementById("emptyState").style.display = state.available.length ? "none" : "block";
}

async function refresh() {
  setText("subtitle", "Atualizando...");
  document.getElementById("refreshButton").disabled = true;
  const result = await window.remoteA3.status();
  if (!result.ok) {
    showError(result, "Falha ao carregar status.");
    document.getElementById("refreshButton").disabled = false;
    return;
  }

  renderStatus(result.data);

  setText("subtitle", "Procurando certificados anunciados por ate 10 segundos...");
  const available = await window.remoteA3.available();
  if (available.ok) {
    renderAvailable(available.data);
    setText("subtitle", `${result.data.ComputerName || "-"} - Remote A3 ${result.data.Version || ""}`);
  } else {
    showError(available, "Falha ao descobrir certificados.");
  }
  document.getElementById("refreshButton").disabled = false;
}

async function setup() {
  setText("subtitle", "Reparando configuracao...");
  const result = await window.remoteA3.setup();
  if (!result.ok) {
    showError(result, "Falha ao reparar configuracao.");
    return;
  }
  await refresh();
}

async function importCertificate(certificate) {
  setText("subtitle", "Importando certificado...");
  const result = await window.remoteA3.importCertificate(certificate);
  if (!result.ok) {
    showError(result, "Falha ao importar certificado.");
    return;
  }

  await refresh();
}

document.getElementById("refreshButton").addEventListener("click", refresh);
document.getElementById("setupButton").addEventListener("click", setup);
document.getElementById("openUiLog").addEventListener("click", () => window.remoteA3.openPath(state.logs.Ui));
document.getElementById("openKspLog").addEventListener("click", () => window.remoteA3.openPath(state.logs.Ksp));
document.getElementById("openSetupLog").addEventListener("click", () => window.remoteA3.openPath(state.logs.PlugAndPlay));

refresh();
