# KSP Alpha

Esta versao adiciona um provedor CNG experimental chamado `Remote A3 Key Storage Provider`.

## O que ele tenta fazer

- O certificado publico remoto e importado no store `CurrentUser\My`.
- A propriedade `CERT_KEY_PROV_INFO_PROP_ID` aponta para o provider `Remote A3 Key Storage Provider`.
- O container local `remote-a3-THUMBPRINT` aponta para um arquivo em `%LOCALAPPDATA%\RemoteA3\keys`.
- Quando um aplicativo chama `NCryptSignHash`, o KSP pede o PIN no PC atual e chama `/sign` no agente remoto.

## Limites da alpha

- Apenas CNG/KSP. CSP legado ainda nao existe.
- Apenas assinatura RSA.
- `ExportKey` ainda nao esta implementado, entao alguns aplicativos que comparam chave publica podem falhar.
- O PIN e enviado ao agente remoto. Use HTTPS interno antes de qualquer uso real.
- O DLL nativo precisa ser compilado com Visual Studio Build Tools/Windows SDK.

## Build

```powershell
.\build\Build-NativeKsp.ps1
```

Ou use o workflow `native-ksp` no GitHub Actions.

## Instalar no PC atual

```powershell
& "$env:LOCALAPPDATA\RemoteA3\bin\remote-a3-install-ksp.cmd" `
  -NativeBuildDirectory "C:\caminho\RemoteA3Native-x64-Release"
```

Depois associe um certificado remoto:

```powershell
& "$env:LOCALAPPDATA\RemoteA3\bin\remote-a3-install-virtual-cert.cmd" `
  -AgentUrl "http://CARTORIO-02:28765/" `
  -Thumbprint "THUMBPRINT"
```

Teste:

```powershell
& "$env:LOCALAPPDATA\RemoteA3\bin\remote-a3-test-virtual-cert.cmd" -Thumbprint "THUMBPRINT"
```

