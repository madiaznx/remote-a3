# Remote A3

Protótipo para descobrir certificados A3 conectados em computadores do dominio e desenhar o caminho para assinatura remota pela intranet.

## O que este projeto cobre agora

- Inventario de certificados no computador local ou em computadores remotos via PowerShell Remoting.
- Agente HTTP/Negotiate para listar certificados e testar uma primitiva de assinatura remota.
- Cliente de teste que pede o PIN no computador atual e chama o agente remoto.
- Documentacao da parte nativa obrigatoria para o Windows enxergar o certificado remoto como se tivesse uma chave privada local.

## Ponto importante

Importar o certificado publico no PC atual nao basta. Para qualquer programa do Windows selecionar o A3 e assinar, o certificado precisa apontar para um provedor de chave local, normalmente um KSP/CSP. Esse provedor local e quem encaminha a operacao de assinatura para o computador onde o token esta conectado.

## Uso rapido

Listar certificados locais com chave privada:

```powershell
.\scripts\Get-A3CertificateInventory.ps1 -OnlyWithPrivateKey
```

Por padrao, o inventario nao abre a chave privada, para evitar prompt/travamento em token A3. Se precisar diagnosticar provedor CSP/KSP, use `-ReadPrivateKeyInfo` sabendo que alguns tokens podem pedir PIN.

Listar certificados provaveis A3 em outro computador do dominio via WinRM:

```powershell
.\scripts\Invoke-DomainA3Discovery.ps1 -ComputerName PC2 -IncludePublicCertificate
```

Subir o agente no computador onde o token esta conectado:

```powershell
.\scripts\Start-A3RemoteAgent.ps1 -Prefix "http://+:8765/"
```

Testar uma assinatura remota de hash/arquivo:

```powershell
.\scripts\Invoke-RemoteA3Sign.ps1 `
  -AgentUrl "https://PC2:8765" `
  -Thumbprint "THUMBPRINT_DO_CERTIFICADO" `
  -FilePath "C:\temp\documento.bin" `
  -PromptForPin
```

Para PIN remoto, use HTTPS. O cliente bloqueia PIN sobre HTTP por padrao.

Esse teste assina o hash de um arquivo. Ele ainda nao cria containers finais como XMLDSig, CMS/CAdES ou PDF/PAdES; esses formatos ficam na camada do aplicativo que chama a assinatura.

## Proximos passos para virar produto

1. Empacotar o agente como servico Windows ou aplicacao de bandeja por usuario.
2. Criar o Remote A3 KSP/CSP nativo.
3. Importar o certificado publico no PC atual com a propriedade de chave apontando para o Remote A3 KSP/CSP.
4. Adicionar instalador, GPO, logs assinados e politica por grupo do Active Directory.
