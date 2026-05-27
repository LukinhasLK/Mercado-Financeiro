# Instruções para Download dos CSVs

Os arquivos CSV **não estão no repositório** por causa do tamanho. Siga as instruções abaixo para baixar cada fonte e salvar nas pastas corretas.

---

## 1. B3 — Cotações Ibovespa (Kaggle)

Acesse: https://www.kaggle.com/datasets/felsal/ibovespa-stocks

Baixe o arquivo e renomeie para `ibovespa_stocks.csv`.  
Salve em: `10_dados/b3/ibovespa_stocks.csv`

---

## 2. Banco Central (BCB)

### Selic diária
https://api.bcb.gov.br/dados/serie/bcdata.sgs.11/dados/ultimos/3000?formato=csv  
Salve em: `10_dados/bcb/selic_diaria.csv`

### Câmbio USD/BRL
https://api.bcb.gov.br/dados/serie/bcdata.sgs.1/dados/ultimos/3000?formato=csv  
Salve em: `10_dados/bcb/cambio_usd_brl.csv`

### IPCA mensal
https://api.bcb.gov.br/dados/serie/bcdata.sgs.433/dados/ultimos/360?formato=csv  
Salve em: `10_dados/bcb/ipca_mensal.csv`

---

## 3. CVM — Empresas e Demonstrações Financeiras

### Cadastro de empresas abertas
https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/cia_aberta.csv  
Salve em: `10_dados/cvm/cia_aberta_cad.csv`

### DFP — Receita e Lucro
https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/  
Baixe o arquivo mais recente (ex.: `dfp_cia_aberta_DRE_con_2023.csv`)  
Salve em: `10_dados/cvm/dfp_receita_lucro.csv`

---

## Configuração no ETL

Após baixar os arquivos, abra `02_etl/01_extract_staging.sql` e ajuste o caminho base:

```sql
DECLARE @base_path NVARCHAR(500) = N'C:\dados\mercado_financeiro\';
```

Substitua pelo caminho real da pasta onde os CSVs estão salvos no servidor SQL Server.
