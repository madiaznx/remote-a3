# Seguranca e conformidade

Este projeto deve ser usado apenas com certificados do proprio titular ou com autorizacao formal da organizacao.

## Principios

- A chave privada do A3 nunca sai do token.
- O PIN nao deve ser salvo.
- O PIN nao deve trafegar sem criptografia.
- Cada assinatura deve ter usuario autenticado e auditavel.
- O agente remoto deve negar qualquer usuario fora dos grupos autorizados.

## Recomendacao para PIN

Mesmo em intranet, use HTTPS com certificado interno emitido pela CA do dominio. HTTP com Negotiate autentica, mas nao deve ser tratado como canal adequado para PIN.

## Auditoria minima

Logar:

- usuario do dominio;
- computador cliente;
- computador com token;
- thumbprint do certificado;
- algoritmo;
- hash do conteudo assinado ou correlation id;
- horario UTC;
- resultado.

Nao logar:

- PIN;
- documento completo;
- chave privada;
- assinatura quando isso puder vazar conteudo sensivel.

