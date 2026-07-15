# Remote A3 KSP/CSP

Esta e a parte que transforma o projeto em algo transparente para aplicativos do Windows.

## Por que ela existe

Aplicativos nao conversam com "nosso agente" diretamente. Eles pedem ao Windows para assinar usando a chave privada associada ao certificado escolhido. Entao o PC atual precisa ter um provedor de chave registrado no Windows.

## KSP ou CSP

Use KSP/CNG para aplicativos modernos:

- `NCryptOpenStorageProvider`
- `NCryptOpenKey`
- `NCryptGetProperty`
- `NCryptSetProperty`
- `NCryptSignHash`
- `NCryptFreeObject`

Use CSP/CryptoAPI se precisar cobrir aplicativos antigos:

- `CPAcquireContext`
- `CPGetProvParam`
- `CPGetUserKey`
- `CPSignHash`
- `CPDestroyKey`
- `CPReleaseContext`

Muitos ambientes brasileiros com A3 ainda tem softwares legados. Na pratica, pode ser necessario entregar os dois.

## Como representar uma chave remota

O nome do container local pode carregar um identificador opaco:

```text
remote-a3://PC2/THUMBPRINT/KeySpec
```

O provedor local resolve esse identificador para:

- computador remoto;
- thumbprint do certificado;
- tipo de chave;
- politica de autorizacao.

## Fluxo de assinatura

1. Aplicativo chama assinatura no Windows.
2. Windows chama o Remote A3 KSP/CSP.
3. Remote A3 KSP/CSP abre dialogo de PIN no PC atual, se permitido.
4. KSP/CSP envia ao agente:
   - thumbprint;
   - algoritmo;
   - hash;
   - PIN em memoria;
   - usuario autenticado;
   - nonce/correlation id.
5. Agente valida autorizacao.
6. Agente usa o token local para assinar.
7. Assinatura volta ao KSP/CSP.
8. KSP/CSP devolve ao Windows.

## Registro do certificado no PC atual

O certificado publico deve ser importado no repositorio do usuario e receber uma propriedade de provedor de chave apontando para o Remote A3 KSP/CSP.

Para CNG, use um `CERT_KEY_PROV_INFO_PROP_ID` com:

- `pwszProvName`: nome do Remote A3 KSP;
- `pwszContainerName`: identificador opaco da chave remota;
- `dwProvType`: 0;
- `dwKeySpec`: `CERT_NCRYPT_KEY_SPEC`.

Para CryptoAPI legado, a propriedade aponta para o Remote A3 CSP com `dwProvType` e `dwKeySpec` adequados.

## Regras de UI

O provedor precisa respeitar flags silenciosas. Se o aplicativo chamar assinatura em modo silencioso e o PIN nao estiver disponivel em cache de sessao, retorne erro equivalente a contexto silencioso em vez de abrir janela.

## Checklist antes de producao

- Assinatura do binario do provedor.
- Instalador MSI.
- Registro seguro do KSP/CSP.
- Dialogo de PIN com protecao contra captura basica e sem logs.
- TLS mutuo ou Kerberos com canal TLS.
- Politica por grupo do AD.
- Logs de auditoria imutaveis ou enviados a SIEM.
- Testes com os tokens reais usados pela empresa.

