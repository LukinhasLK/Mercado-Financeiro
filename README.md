# 📊 Projeto Final — Banco de Dados

## 📌 Tema
Mercado Financeiro — Análise de Ações da B3 (Bolsa Brasileira)

## 👥 Grupo
- Lucas Rodrigues Alves
- Lucas Oliveira Martins
- Ailton Santos Dantas
- Luigi Sapucaia de Lima
- Rubens Manoel

## 📋 Kanban
Acompanhe o progresso: https://app.clickup.com/90133094845/chat/r/7-90133094845-8


📊 Perguntas de Negócio

Aqui estão os links confirmados para cada pergunta:
Q1 — Selic vs. Retorno de Ações Financeiras
Pergunta: Empresas do setor financeiro superam a Selic em janelas de alta de juros ou apenas a replicam?

Selic diária: https://api.bcb.gov.br/dados/serie/bcdata.sgs.11/dados?formato=csv
Ações B3: https://www.kaggle.com/datasets/felsal/ibovespa-stocks

Q2 — Pergunta: Quais empresas listadas na B3 apresentaram crescimento de receita e lucro durante a crise de 2020, e o que elas têm em comum?

DFP receita/lucro: https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/
Cadastro empresas: https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/

Q3 — Pergunta: Setores com maior volume médio de negociação têm menor volatilidade histórica de preços, ou o volume é movido justamente pelos eventos de alta volatilidade?

Ações + volume: https://www.kaggle.com/datasets/felsal/ibovespa-stocks
Setor das empresas: https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/

Q4 — Pergunta: Ações de exportadoras (agro, mineração, papel & celulose) se valorizam de forma consistente quando o dólar sobe acima de determinado threshold?

Câmbio USD/BRL: https://api.bcb.gov.br/dados/serie/bcdata.sgs.1/dados?formato=csv
Setor das empresas: https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/

Q5 — Pergunta: Empresas no Novo Mercado oferecem melhor relação risco-retorno (Sharpe) do que as do Mercado Tradicional ao longo de 5+ anos?

Segmento listagem: https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/
Preços históricos: https://www.kaggle.com/datasets/felsal/ibovespa-stocks

Q6 — Pergunta: A concentração do volume financeiro diário na B3 em poucos setores e empresas aumentou nos últimos anos, e quais setores perderam participação relativa?

Volume diário: https://www.kaggle.com/datasets/felsal/ibovespa-stocks
Setor: https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/

Q7 — Pergunta: Setores de energia elétrica e saneamento lideram yield de dividendos histórico, e o dividend yield prediz retorno total nos 12 meses seguintes?

Dividendos: https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/
Preços: https://www.kaggle.com/datasets/felsal/ibovespa-stocks

Q8 — Pergunta: Surpresas de IPCA acima do teto da meta historicamente geram retorno negativo anormal nas ações de consumo discricionário no mês seguinte?

IPCA mensal: https://api.bcb.gov.br/dados/serie/bcdata.sgs.433/dados?formato=csv
Ações consumo: https://www.kaggle.com/datasets/felsal/ibovespa-stocks

Q9 — Pergunta: Existe uma relação não-linear entre o tamanho da empresa (total de ações emitidas × preço) e a liquidez diária: empresas muito grandes e muito pequenas têm padrões distintos?

Volume ações: https://www.kaggle.com/datasets/felsal/ibovespa-stocks
Total ações emitidas: https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/



## 🗂️ Estrutura do Repositório
| Pasta | Conteúdo |
|-------|----------|
| 01_ddl/ | Scripts de criação das tabelas |
| 02_etl/ | Stored Procedures de ETL |
| 03_dql/ | Consultas de validação |
| 04_views/ | Views criadas |
| 05_stored_procedures/ | SPs de ETL e analíticas |
| 06_functions/ | Functions |
| 07_triggers/ | Triggers de auditoria |
| 08_dcl/ | Roles e permissões |
| 09_documentacao/ | Dicionário, DER, manuais |
| 10_dados/ | Amostra do dataset |

## 🚀 Como executar
1. Execute os scripts na ordem numérica das pastas
2. Comece pelo 01_ddl/ para criar a estrutura
3. Execute o 02_etl/ para carregar os dados
4. Use o 03_dql/ para validar a carga