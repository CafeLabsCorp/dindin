# Registro de progresso

[Read in English](PROGRESSO.md)

## Retomar daqui

- **Fase:** passada de documentação da versão 1.2.1+7 (enviada à Google Play em
  2026-11-16, aprovada e no ar em 2026-11-17). Todos os docs de `docs/` e os dois READMEs
  foram reconciliados com o código em 2026-11-16; nada commitado ainda.
- **Próximo passo:** o mantenedor revisa o diff do working tree e commita. Quando
  o Google aprovar a 1.2.1, registrar na tabela de versões publicadas do
  `docs/DEPLOY.md` (e `.pt-br`) e no bloco de status do `README.md`. Depois fechar
  ou mover itens em `docs/PENDENCIAS.pt-br.md`.
- **Aguardando o usuário:** declaração de comerciante no Play Console (até
  2027-02-01); conferência em aparelho real do onboarding e do seletor de tema em tela
  estreita (animação e indicador de atualização in-app confirmados em
  2026-11-17).

## Unidades

| Unidade | Estado | Saída |
|---|---|---|
| README (en/pt-br) | feito | `README.md`, `README.pt-br.md` |
| Arquitetura, com Rastro C (onboarding) | feito | `docs/ARQUITETURA*.md` |
| Backend / rules / superfície de integração | feito | `docs/BACKEND*.md` |
| Deploy, fluxo de release, versões publicadas | feito | `docs/DEPLOY*.md` |
| Situação do Play Console | feito | `docs/PLAY_CONSOLE*.md` |
| Design (seletor de tema, manual, visuais do onboarding) | feito | `docs/DESIGN*.md` |
| Desenho do onboarding vs. o que foi construído | feito | `docs/onboarding-design.md` (seção 10) |
| Pendências | feito | `docs/PENDENCIAS*.md` |

## Decisões e convenções

- O inglês é o idioma primário do conjunto de docs; os irmãos em português usam o
  sufixo `.pt-br.md`. `docs/onboarding-design.md` e o mockup HTML são só em
  português.
- O manual de marca mora no `cafelabs-vault` e aqui só é referenciado.
- Fatos que não dava pra ler do repo (estado do Play Console, datas de aprovação)
  vêm do board do mantenedor e estão marcados como tal; o que não se sabe é
  `TODO: confirmar`, listado em `docs/PENDENCIAS.pt-br.md`.

## Histórico

- 2026-11-16, docs: conjunto de docs reconciliado com a 1.2.1+7 (testes: 715 do
  Flutter, 128 + 9 das rules contados nos arquivos), criados `PENDENCIAS` e
  `PROGRESSO`.
