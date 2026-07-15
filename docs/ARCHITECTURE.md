# Arquitetura

## Objetivo

Permitir que o PC atual use um certificado A3 conectado em outro computador do mesmo dominio, sem exportar a chave privada do token.

Fluxo desejado:

```text
PC atual -> certificado remoto aparece no repositorio do Windows
PC atual -> usuario seleciona o certificado no sistema/browser
PC atual -> provedor local pede o PIN
PC atual -> provedor local envia hash + PIN ao PC com token
PC com token -> token A3 assina
PC com token -> assinatura volta ao PC atual
```

## Componentes

### 1. Agent

Roda no computador que possui o token/cartao A3 conectado.

Responsabilidades:

- Enumerar certificados locais com chave privada.
- Expor metadados publicos do certificado.
- Receber pedidos de assinatura de hash.
- Usar o provedor real do token instalado no computador remoto.
- Registrar logs de auditoria.

### 2. Client

Roda no PC atual.

Responsabilidades:

- Descobrir agentes no dominio.
- Mostrar certificados disponiveis ao usuario.
- Solicitar PIN no PC atual.
- Chamar o agente remoto.

### 3. Remote A3 KSP/CSP

Componente nativo do Windows instalado no PC atual.

Responsabilidades:

- Fazer o certificado remoto parecer um certificado com chave privada local.
- Implementar as chamadas de assinatura do Windows.
- Abrir uma UI local para PIN quando a aplicacao permitir.
- Encaminhar apenas o hash a assinar, nunca a chave privada.

Sem esse componente, o Windows pode importar o certificado publico, mas os programas nao vao conseguir assinar com ele como se fosse um A3 local.

## Como o Windows associa certificado e chave

Um certificado no repositorio `CurrentUser\My` ou `LocalMachine\My` contem a parte publica. Para assinar, o Windows procura uma propriedade no certificado que aponta para:

- um provedor CNG/KSP, em aplicativos modernos; ou
- um provedor CryptoAPI/CSP, em aplicativos legados.

Para o projeto, o certificado remoto deve ser importado no PC atual com uma referencia para o `Remote A3 KSP` ou `Remote A3 CSP`. Quando o aplicativo chama `SignHash`, o provedor local chama o agente remoto.

## PIN no PC atual

O PIN deve ser capturado no PC atual pelo provedor local, nao pelo agente remoto. O provedor local deve:

- pedir PIN somente no momento da assinatura;
- manter o PIN apenas em memoria;
- enviar o PIN somente por canal autenticado e criptografado;
- limpar a memoria assim que possivel;
- respeitar modo silencioso quando a aplicacao nao permite UI.

O agente remoto entao usa o PIN para liberar o token. A forma exata depende do driver do token:

- CNG: `NCryptSetProperty` com propriedade de PIN, quando suportado.
- CryptoAPI/CSP: `CryptSetProvParam` com PIN de assinatura/troca, quando suportado.
- Alguns tokens podem exigir UI local ou PIN pad fisico, o que inviabiliza PIN remoto para aquele modelo.

## Descoberta no dominio

MVP:

- Lista fixa de computadores.
- `Invoke-Command`/WinRM para consultar inventario.

Produto:

- Agentes publicam disponibilidade em um diretorio interno.
- Autorizacao por grupo do Active Directory.
- Cliente consulta somente agentes permitidos.

## Seguranca minima

- Kerberos/Negotiate para autenticar usuario e computador.
- TLS interno para proteger PIN e assinatura.
- Grupo do AD para autorizar uso.
- Logs com usuario, computador cliente, certificado, thumbprint, algoritmo, horario e resultado.
- Bloqueio de assinatura concorrente por token.
- Nenhum armazenamento persistente de PIN.
- Nenhuma exportacao de chave privada.

## Limitacoes do prototipo PowerShell

Os scripts conseguem descobrir certificados e testar chamadas de assinatura, mas nao substituem o KSP/CSP. Tambem nao garantem que todo token aceite PIN injetado por software; isso depende do provedor do fabricante.

