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

## 🗂️ Fonte de Dados
- **Dataset principal:** https://www.kaggle.com/datasets/renanfioramonte/ibovespa-index
- **Dados complementares:** https://dados.cvm.gov.br

📊 Perguntas de Negócio

Considerando os dados históricos de ações da B3 e o índice Ibovespa como referência de mercado, o projeto busca responder às seguintes questões:

Qual setor teve maior crescimento acumulado no período analisado?

Qual ação apresentou maior volatilidade no período?

Qual foi o trimestre mais volátil?

Quais ações são menos negociadas?

Qual setor é mais resiliente em crises?

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