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
Q1 — Selic vs retorno ações financeiras

Selic diária: https://api.bcb.gov.br/dados/serie/bcdata.sgs.11/dados?formato=csv
Ações B3: https://www.kaggle.com/datasets/felsal/ibovespa-stocks

Q2 — Empresas resilientes na COVID-2020

DFP receita/lucro: https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/
Cadastro empresas: https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/

Q3 — Volume vs volatilidade por setor

Ações + volume: https://www.kaggle.com/datasets/felsal/ibovespa-stocks
Setor das empresas: https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/

Q4 — Câmbio vs exportadoras

Câmbio USD/BRL: https://api.bcb.gov.br/dados/serie/bcdata.sgs.1/dados?formato=csv
Setor das empresas: https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/

Q5 — Risco-retorno por segmento

Segmento listagem: https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/
Preços históricos: https://www.kaggle.com/datasets/felsal/ibovespa-stocks

Q6 — Volume por setor

Volume diário: https://www.kaggle.com/datasets/felsal/ibovespa-stocks
Setor: https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/

Q7 — Dividendos por setor

Dividendos: https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/
Preços: https://www.kaggle.com/datasets/felsal/ibovespa-stocks

Q8 — IPCA vs setor consumo

IPCA mensal: https://api.bcb.gov.br/dados/serie/bcdata.sgs.433/dados?formato=csv
Ações consumo: https://www.kaggle.com/datasets/felsal/ibovespa-stocks

Q9 — Liquidez vs tamanho empresa

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