# 📖 Dicionário de Dados — Mercado Financeiro B3

> **Banco de Dados:** `MercadoFinanceiro`  
> **SGBD:** Microsoft SQL Server (T-SQL)  
> **Versão:** 1.0.0  
> **Atualizado em:** 2026-03-11  
> **Grupo:** LukinhasLK — Disciplina: Gerenciamento de Banco de Dados

---

## 📋 Índice de Tabelas

| # | Tabela | Schema | Tipo | Registros Estimados | Descrição Resumida |
|---|--------|--------|------|--------------------|--------------------|
| 1 | [staging.cotacao](#1-stagingcotacao) | staging | Staging | ~500k | Dados brutos de cotações vindos do Kaggle |
| 2 | [staging.indicadores_macro](#2-stagingindicadores_macro) | staging | Staging | ~50k | Dados brutos de indicadores do Banco Central |
| 3 | [staging.dem_financeira](#3-stagingdem_financeira) | staging | Staging | ~200k | Dados brutos de demonstrações da CVM |
| 4 | [dim_setor](#4-dim_setor) | dbo | Dimensão | ~12 | Setores econômicos da B3 |
| 5 | [dim_subsetor](#5-dim_subsetor) | dbo | Dimensão | ~30 | Subsetores econômicos da B3 |
| 6 | [dim_segmento_listagem](#6-dim_segmento_listagem) | dbo | Dimensão | ~5 | Segmentos de governança (Novo Mercado, N1, N2...) |
| 7 | [dim_tipo_acao](#7-dim_tipo_acao) | dbo | Dimensão | ~3 | Tipos de ação (ON, PN, UNIT) |
| 8 | [dim_empresa](#8-dim_empresa) | dbo | Dimensão | ~500 | Empresas listadas na B3 |
| 9 | [dim_acao](#9-dim_acao) | dbo | Dimensão | ~800 | Ações negociadas na B3 |
| 10 | [dim_data](#10-dim_data) | dbo | Dimensão | ~9.000 | Calendário de 2000 a 2024 |
| 11 | [dim_periodo_crise](#11-dim_periodo_crise) | dbo | Dimensão | ~5 | Períodos históricos de crise |
| 12 | [dim_indicador_macro](#12-dim_indicador_macro) | dbo | Dimensão | ~4 | Catálogo de indicadores macro |
| 13 | [fato_cotacao](#13-fato_cotacao) | dbo | Fato | ~500k+ | Cotações diárias históricas (tabela principal) |
| 14 | [fato_indicador_macro](#14-fato_indicador_macro) | dbo | Fato | ~50k | Valores históricos dos indicadores macro |
| 15 | [fato_dem_financeira](#15-fato_dem_financeira) | dbo | Fato | ~20k | Demonstrações financeiras anuais/trimestrais |
| 16 | [fato_indicadores](#16-fato_indicadores) | dbo | Fato | ~200k | Indicadores calculados (P/L, ROE, Sharpe...) |
| 17 | [hist_dividendos](#17-hist_dividendos) | dbo | Histórico | ~50k | Pagamentos de dividendos por ação |
| 18 | [hist_desdobramento](#18-hist_desdobramento) | dbo | Histórico | ~2k | Splits, grupamentos e bonificações |
| 19 | [hist_preco_ajustado](#19-hist_preco_ajustado) | dbo | Histórico | ~500k+ | Preços ajustados por dividendos e splits |
| 20 | [log_auditoria](#20-log_auditoria) | dbo | Controle | Variável | Registro automático de operações via Trigger |
| 21 | [log_erros_etl](#21-log_erros_etl) | dbo | Controle | Variável | Registro de erros durante o ETL |
| 22 | [parametros_sistema](#22-parametros_sistema) | dbo | Controle | ~4 | Parâmetros e configurações do sistema |

---

## 📐 Padrões de Nomenclatura

| Prefixo | Significado | Exemplo |
|---------|-------------|---------|
| `id_` | Chave primária ou estrangeira | `id_acao`, `id_empresa` |
| `cd_` | Código de negócio (legível) | `cd_ticker`, `cd_cvm` |
| `ds_` | Descrição ou texto | `ds_setor`, `ds_razao_social` |
| `vl_` | Valor numérico | `vl_fechamento`, `vl_volume` |
| `nr_` | Número sem semântica de valor | `nr_ano`, `nr_mes` |
| `dt_` | Data ou datetime | `dt_pregao`, `dt_carga` |
| `fl_` | Flag booleano (BIT) | `fl_ativa`, `fl_feriado` |

---

## 🗄️ Schemas Utilizados

| Schema | Finalidade |
|--------|-----------|
| `staging` | Área de pouso para dados brutos antes da transformação ETL |
| `dbo` | Schema padrão — contém todas as tabelas de dimensão, fato, histórico e controle |

---

## STAGING

> As tabelas de staging recebem dados brutos **sem validação**. Todas as colunas de negócio são `VARCHAR` para evitar erros de conversão durante a carga. A transformação e validação ocorre nas Stored Procedures de ETL.

---

### 1. staging.cotacao

**Descrição:** Área de pouso para dados brutos de cotações vindos do dataset Kaggle (ibovespa-stocks). Os dados chegam como CSV e são inseridos nessa tabela antes de serem validados e transformados para `fato_cotacao`.

**Fonte:** Kaggle — https://www.kaggle.com/datasets/felsal/ibovespa-stocks  
**Frequência de carga:** Diária (dias úteis)  
**Registros estimados:** ~500.000  
**Retenção:** Dados podem ser truncados após carga bem-sucedida para `fato_cotacao`

| Coluna | Tipo | PK | FK | Nulo | Descrição | Exemplo |
|--------|------|----|----|------|-----------|---------|
| id_staging | INT IDENTITY(1,1) | ✅ | — | NÃO | Chave primária auto-incremental da staging | 1, 2, 3... |
| ticker | VARCHAR(10) | — | — | SIM | Código do ativo no formato bruto do CSV | `PETR4`, `VALE3`, `ITUB4` |
| dt_pregao | VARCHAR(20) | — | — | SIM | Data do pregão em texto bruto (pode vir em formatos variados) | `2024-01-15`, `15/01/2024` |
| vl_abertura | VARCHAR(20) | — | — | SIM | Preço de abertura em texto (pode conter vírgula ou ponto) | `32.45`, `32,45` |
| vl_fechamento | VARCHAR(20) | — | — | SIM | Preço de fechamento em texto | `33.10`, `33,10` |
| vl_maximo | VARCHAR(20) | — | — | SIM | Preço máximo do dia em texto | `33.50`, `33,50` |
| vl_minimo | VARCHAR(20) | — | — | SIM | Preço mínimo do dia em texto | `31.90`, `31,90` |
| vl_volume | VARCHAR(30) | — | — | SIM | Volume financeiro negociado em texto | `45230000`, `45.230.000` |
| dt_carga | DATETIME | — | — | NÃO | Timestamp automático da inserção na staging | `2024-01-15 08:30:00` |

**Regras de negócio:**
- Todos os campos de negócio são `VARCHAR` intencionalmente — a conversão de tipos ocorre na SP de ETL
- O campo `dt_carga` serve para identificar lotes de carga e reprocessar em caso de erro
- Registros com `ticker NULL` são descartados pelo ETL e registrados em `log_erros_etl`

---

### 2. staging.indicadores_macro

**Descrição:** Área de pouso para dados brutos das APIs do Banco Central do Brasil (SGS — Sistema Gerenciador de Séries Temporais). Recebe Selic, IPCA, Câmbio e CDI antes do tratamento ETL.

**Fonte:** Banco Central — https://dadosabertos.bcb.gov.br  
**Frequência de carga:** Diária (Selic, Câmbio) e Mensal (IPCA)  
**Registros estimados:** ~50.000

| Coluna | Tipo | PK | FK | Nulo | Descrição | Exemplo |
|--------|------|----|----|------|-----------|---------|
| id_staging | INT IDENTITY(1,1) | ✅ | — | NÃO | Chave primária auto-incremental | 1, 2, 3... |
| cd_indicador | VARCHAR(20) | — | — | SIM | Código do indicador para identificar origem | `SELIC`, `IPCA`, `CAMBIO`, `CDI` |
| dt_referencia | VARCHAR(20) | — | — | SIM | Data de referência em texto bruto | `15/01/2024`, `2024-01-15` |
| vl_indicador | VARCHAR(30) | — | — | SIM | Valor do indicador em texto | `0.043250`, `4.83`, `4.9650` |
| dt_carga | DATETIME | — | — | NÃO | Timestamp automático da inserção | `2024-01-15 09:00:00` |

**Regras de negócio:**
- A API do BCB retorna datas no formato `DD/MM/AAAA` — a SP de ETL converte para DATE
- Valores do IPCA são mensais; a SP de ETL replica o valor para todos os dias do mês na `fato_indicador_macro`
- Registros duplicados (mesma data + indicador) são ignorados pelo ETL via `MERGE`

---

### 3. staging.dem_financeira

**Descrição:** Área de pouso para dados brutos das Demonstrações Financeiras Padronizadas (DFP) da CVM. Os arquivos CSV da CVM têm estrutura vertical (uma linha por conta contábil), que é pivotada pela SP de ETL.

**Fonte:** CVM — https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/  
**Frequência de carga:** Anual (após divulgação das DFPs, geralmente abril/maio)  
**Registros estimados:** ~200.000

| Coluna | Tipo | PK | FK | Nulo | Descrição | Exemplo |
|--------|------|----|----|------|-----------|---------|
| id_staging | INT IDENTITY(1,1) | ✅ | — | NÃO | Chave primária auto-incremental | 1, 2, 3... |
| cd_cvm | VARCHAR(20) | — | — | SIM | Código CVM da empresa emissora | `9512`, `4170`, `19348` |
| ds_conta | VARCHAR(200) | — | — | SIM | Descrição da conta contábil | `Receita de Venda de Bens e/ou Serviços` |
| cd_conta | VARCHAR(50) | — | — | SIM | Código estruturado da conta (plano de contas) | `3.01`, `3.11`, `1.01.01` |
| vl_conta | VARCHAR(30) | — | — | SIM | Valor da conta em texto bruto | `45230000000`, `-12500000` |
| dt_referencia | VARCHAR(20) | — | — | SIM | Data de referência da demonstração | `2023-12-31`, `2023-09-30` |
| dt_carga | DATETIME | — | — | NÃO | Timestamp automático da inserção | `2024-04-30 10:00:00` |

**Regras de negócio:**
- Os arquivos da CVM têm separador `;` e encoding `ISO-8859-1` — a SP de ETL trata isso
- A SP de ETL filtra apenas as contas relevantes (receita, lucro, EBITDA, dívida, patrimônio, ativo)
- Valores negativos representam despesas — mantidos com sinal na `fato_dem_financeira`

---

## DIMENSÕES

> Tabelas de dimensão armazenam os atributos descritivos das entidades do negócio. São tabelas menores, com baixo volume, atualizadas com pouca frequência. Seguem o padrão **SCD Tipo 1** (sobrescreve o valor antigo sem histórico).

---

### 4. dim_setor

**Descrição:** Setores econômicos da B3 conforme classificação da CVM. Cada empresa pertence a exatamente um setor, que agrupa atividades econômicas similares para fins de análise comparativa.

**Registros estimados:** 12  
**Frequência de atualização:** Raramente (apenas quando a B3 cria novos setores)

| Coluna | Tipo | PK | FK | Nulo | Unique | Descrição | Exemplo |
|--------|------|----|----|------|--------|-----------|---------|
| id_setor | INT IDENTITY(1,1) | ✅ | — | NÃO | — | Chave primária surrogate auto-incremental | 1, 2, 3... |
| cd_setor | VARCHAR(20) | — | — | NÃO | ✅ | Código de negócio único e legível do setor | `FIN`, `UTIL`, `AGRO` |
| ds_setor | VARCHAR(100) | — | — | NÃO | — | Nome completo do setor | `Financeiro e Seguros` |
| ds_descricao | VARCHAR(500) | — | — | SIM | — | Descrição detalhada das atividades do setor | `Inclui bancos, seguradoras...` |
| dt_criacao | DATETIME | — | — | NÃO | — | Data de criação do registro | `2026-03-11 10:00:00` |
| dt_atualizacao | DATETIME | — | — | NÃO | — | Data da última atualização do registro | `2026-03-11 10:00:00` |

**Dados iniciais:**

| id_setor | cd_setor | ds_setor |
|----------|----------|----------|
| 1 | FIN | Financeiro e Seguros |
| 2 | CONS | Consumo Cíclico |
| 3 | CONB | Consumo Não Cíclico |
| 4 | UTIL | Utilidade Pública |
| 5 | MATS | Materiais Básicos |
| 6 | SAUDE | Saúde |
| 7 | PETRO | Petróleo, Gás e Biocombustíveis |
| 8 | TELE | Telecomunicações |
| 9 | TI | Tecnologia da Informação |
| 10 | IMOV | Imóveis |
| 11 | INDU | Bens Industriais |
| 12 | AGRO | Agropecuária |

**Constraints:**
- `UNIQUE (cd_setor)` — evita duplicidade de código de setor
- Referenciado por: `dim_subsetor`, `dim_empresa`

---

### 5. dim_subsetor

**Descrição:** Subsetores econômicos que detalham a classificação das empresas dentro de cada setor. Permite análise mais granular (ex: dentro de Financeiro há Bancos, Seguradoras, Corretoras).

**Registros estimados:** 30  
**Frequência de atualização:** Raramente

| Coluna | Tipo | PK | FK | Nulo | Unique | Descrição | Exemplo |
|--------|------|----|----|------|--------|-----------|---------|
| id_subsetor | INT IDENTITY(1,1) | ✅ | — | NÃO | — | Chave primária surrogate | 1, 2, 3... |
| id_setor | INT | — | ✅ dim_setor | NÃO | — | Setor pai ao qual o subsetor pertence | 1 (Financeiro) |
| cd_subsetor | VARCHAR(20) | — | — | NÃO | ✅ | Código único do subsetor | `BANCO`, `SEGUR`, `ELETRI` |
| ds_subsetor | VARCHAR(100) | — | — | NÃO | — | Nome completo do subsetor | `Bancos`, `Seguradoras`, `Energia Elétrica` |
| dt_criacao | DATETIME | — | — | NÃO | — | Data de criação do registro | `2026-03-11 10:00:00` |

**Regras de negócio:**
- Um subsetor pertence a exatamente um setor (`id_setor NOT NULL`)
- A exclusão de um setor é bloqueada se houver subsetores vinculados (FK com restrição)

---

### 6. dim_segmento_listagem

**Descrição:** Segmentos de listagem da B3 que definem o nível de governança corporativa exigido da empresa. Quanto maior o nível, maior a proteção ao acionista minoritário. Usado na pergunta analítica Q5.

**Registros estimados:** 5  
**Frequência de atualização:** Raramente

| Coluna | Tipo | PK | FK | Nulo | Unique | Descrição | Exemplo |
|--------|------|----|----|------|--------|-----------|---------|
| id_segmento | INT IDENTITY(1,1) | ✅ | — | NÃO | — | Chave primária surrogate | 1, 2, 3... |
| cd_segmento | VARCHAR(20) | — | — | NÃO | ✅ | Código do segmento | `NM`, `N2`, `N1`, `MA`, `TRAD` |
| ds_segmento | VARCHAR(100) | — | — | NÃO | — | Nome completo do segmento | `Novo Mercado`, `Nível 2` |
| ds_descricao | VARCHAR(500) | — | — | SIM | — | Requisitos e características do segmento | `Somente ações ON, tag along 100%...` |
| dt_criacao | DATETIME | — | — | NÃO | — | Data de criação do registro | `2026-03-11 10:00:00` |

**Dados iniciais:**

| cd_segmento | ds_segmento | Principais requisitos |
|-------------|-------------|----------------------|
| NM | Novo Mercado | Apenas ON, tag along 100%, free float mín. 25% |
| N2 | Nível 2 | ON e PN com tag along 100%, árbitro obrigatório |
| N1 | Nível 1 | Divulgação adicional, free float mín. 25% |
| MA | Bovespa Mais | Empresas de menor porte, acesso simplificado |
| TRAD | Tradicional | Sem requisitos adicionais de governança |

---

### 7. dim_tipo_acao

**Descrição:** Tipos de ação disponíveis na B3. Define os direitos do acionista (voto e dividendos). É relevante para calcular market cap corretamente e entender o perfil de cada papel.

**Registros estimados:** 3  
**Frequência de atualização:** Raramente

| Coluna | Tipo | PK | FK | Nulo | Unique | Descrição | Exemplo |
|--------|------|----|----|------|--------|-----------|---------|
| id_tipo_acao | INT IDENTITY(1,1) | ✅ | — | NÃO | — | Chave primária surrogate | 1, 2, 3 |
| cd_tipo | VARCHAR(10) | — | — | NÃO | ✅ | Código do tipo de ação | `ON`, `PN`, `UNIT` |
| ds_tipo | VARCHAR(50) | — | — | NÃO | — | Nome do tipo | `Ordinária`, `Preferencial`, `Unit` |
| ds_descricao | VARCHAR(200) | — | — | SIM | — | Descrição dos direitos do acionista | `Direito a voto nas assembleias` |

**Dados iniciais:**

| cd_tipo | ds_tipo | Direito a Voto | Prioridade em Dividendos |
|---------|---------|---------------|--------------------------|
| ON | Ordinária | ✅ Sim | ❌ Não |
| PN | Preferencial | ❌ Não | ✅ Sim |
| UNIT | Unit | Depende da composição | Depende da composição |

**Regra de negócio:**
- Ações ON terminam em número ímpar no ticker (ex: PETR3, VALE3)
- Ações PN terminam em número par (ex: PETR4, ITUB4)
- UNITs terminam em 11 (ex: TAEE11, SANB11)

---

### 8. dim_empresa

**Descrição:** Cadastro completo das empresas de capital aberto listadas na B3, com dados da CVM. É a entidade central do modelo, conectando dimensões de classificação às tabelas fato.

**Fonte:** CVM — https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/  
**Registros estimados:** ~500 empresas ativas  
**Frequência de atualização:** Mensal (novas listagens, cancelamentos, mudanças de setor)

| Coluna | Tipo | PK | FK | Nulo | Unique | Descrição | Exemplo |
|--------|------|----|----|------|--------|-----------|---------|
| id_empresa | INT IDENTITY(1,1) | ✅ | — | NÃO | — | Chave primária surrogate | 1, 2, 3... |
| cd_cvm | VARCHAR(20) | — | — | NÃO | ✅ | Código CVM único — chave natural da empresa | `9512` (Petrobras), `4170` (Vale) |
| nr_cnpj | VARCHAR(20) | — | — | SIM | — | CNPJ formatado da empresa | `33.000.167/0001-01` |
| ds_razao_social | VARCHAR(200) | — | — | NÃO | — | Razão social completa registrada na CVM | `PETROLEO BRASILEIRO S.A. - PETROBRAS` |
| ds_nome_pregao | VARCHAR(100) | — | — | SIM | — | Nome abreviado usado no pregão da B3 | `PETROBRAS`, `VALE`, `ITAUUNIBANCO` |
| id_setor | INT | — | ✅ dim_setor | SIM | — | Setor econômico da empresa | 7 (PETRO) |
| id_subsetor | INT | — | ✅ dim_subsetor | SIM | — | Subsetor econômico | 15 (Exploração e Refino) |
| id_segmento | INT | — | ✅ dim_segmento_listagem | SIM | — | Segmento de listagem na B3 | 1 (Novo Mercado) |
| dt_constituicao | DATE | — | — | SIM | — | Data de constituição da empresa | `1953-10-03` |
| dt_listagem | DATE | — | — | SIM | — | Data de listagem na B3 | `2000-07-25` |
| fl_ativa | BIT | — | — | NÃO | — | 1 = ativa e negociada, 0 = cancelada/suspensa | `1` |
| dt_criacao | DATETIME | — | — | NÃO | — | Data de criação do registro | `2026-03-11 10:00:00` |
| dt_atualizacao | DATETIME | — | — | NÃO | — | Data da última atualização | `2026-03-11 10:00:00` |

**Exemplos de registros:**

| cd_cvm | ds_nome_pregao | cd_setor | cd_segmento |
|--------|----------------|----------|-------------|
| 9512 | PETROBRAS | PETRO | TRAD |
| 4170 | VALE | MATS | NM |
| 19348 | ITAUUNIBANCO | FIN | NM |
| 906 | AMBEV S/A | CONB | NM |

**Regras de negócio:**
- `cd_cvm` é a chave natural — único identificador oficial da empresa na CVM
- Empresas com `fl_ativa = 0` são mantidas para preservar histórico de cotações
- `id_setor`, `id_subsetor` e `id_segmento` podem ser NULL para empresas ainda não classificadas

---

### 9. dim_acao

**Descrição:** Ações individuais negociadas na B3, identificadas pelo ticker. Uma empresa pode ter múltiplas ações (ex: PETR3 e PETR4). É a entidade que conecta a empresa às cotações diárias.

**Registros estimados:** ~800 tickers ativos  
**Frequência de atualização:** Quando há novas emissões, cancelamentos ou mudanças de ticker

| Coluna | Tipo | PK | FK | Nulo | Unique | Descrição | Exemplo |
|--------|------|----|----|------|--------|-----------|---------|
| id_acao | INT IDENTITY(1,1) | ✅ | — | NÃO | — | Chave primária surrogate | 1, 2, 3... |
| cd_ticker | VARCHAR(10) | — | — | NÃO | ✅ | Código do ativo no pregão (chave natural) | `PETR4`, `VALE3`, `ITUB4`, `BBDC3` |
| id_empresa | INT | — | ✅ dim_empresa | NÃO | — | Empresa emissora da ação | 1 (Petrobras) |
| id_tipo_acao | INT | — | ✅ dim_tipo_acao | NÃO | — | Tipo da ação (ON, PN, UNIT) | 2 (PN) |
| ds_acao | VARCHAR(200) | — | — | SIM | — | Descrição completa da ação | `PETROBRAS PN` |
| nr_total_acoes | BIGINT | — | — | SIM | — | Total de ações emitidas pela empresa | `13044496930` |
| fl_ativa | BIT | — | — | NÃO | — | 1 = negociada ativamente, 0 = inativa | `1` |
| dt_criacao | DATETIME | — | — | NÃO | — | Data de criação do registro | `2026-03-11 10:00:00` |
| dt_atualizacao | DATETIME | — | — | NÃO | — | Data da última atualização | `2026-03-11 10:00:00` |

**Exemplos de registros:**

| cd_ticker | ds_acao | cd_tipo | ds_nome_pregao |
|-----------|---------|---------|----------------|
| PETR3 | PETROBRAS ON | ON | PETROBRAS |
| PETR4 | PETROBRAS PN | PN | PETROBRAS |
| VALE3 | VALE ON | ON | VALE |
| ITUB4 | ITAUUNIBANCO PN | PN | ITAUUNIBANCO |
| TAEE11 | TAESA UNIT | UNIT | TAESA |

**Regras de negócio:**
- `cd_ticker` é a chave natural — identificador oficial no pregão da B3
- `nr_total_acoes` é usado para calcular market cap: `nr_total_acoes × vl_fechamento`
- Tickers inativos (`fl_ativa = 0`) são mantidos para preservar o histórico de cotações

---

### 10. dim_data

**Descrição:** Tabela calendário com todos os dias do período de análise (2000 a 2024). Permite análise temporal por qualquer granularidade (dia, mês, trimestre, semestre, ano) sem necessidade de funções de data nas queries.

**Registros estimados:** ~9.000 dias (25 anos × 365 dias)  
**Frequência de atualização:** Anual (adicionar o próximo ano)

| Coluna | Tipo | PK | Nulo | Descrição | Exemplo |
|--------|------|----|----|-----------|---------|
| id_data | INT | ✅ | NÃO | Chave primária no formato `YYYYMMDD` — permite ordenação natural | `20240115` |
| dt_data | DATE | — | NÃO | Data no tipo nativo DATE — garante integridade | `2024-01-15` |
| nr_ano | SMALLINT | — | NÃO | Ano com 4 dígitos | `2024` |
| nr_mes | TINYINT | — | NÃO | Mês de 1 a 12 (CHECK constraint aplicada) | `1` |
| nr_dia | TINYINT | — | NÃO | Dia do mês de 1 a 31 (CHECK constraint aplicada) | `15` |
| nr_trimestre | TINYINT | — | NÃO | Trimestre de 1 a 4 | `1` |
| nr_semestre | TINYINT | — | NÃO | Semestre 1 ou 2 | `1` |
| ds_dia_semana | VARCHAR(20) | — | NÃO | Nome do dia da semana em português | `Segunda-feira` |
| nr_dia_semana | TINYINT | — | NÃO | Número do dia: 1=Domingo, 2=Segunda... 7=Sábado | `2` |
| fl_feriado | BIT | — | NÃO | 1 = feriado nacional brasileiro, 0 = dia normal | `0` |
| fl_dia_util | BIT | — | NÃO | 1 = dia útil de pregão na B3, 0 = final de semana ou feriado | `1` |
| ds_mes | VARCHAR(20) | — | NÃO | Nome do mês em português | `Janeiro` |

**Constraints:**
- `CHECK (nr_mes BETWEEN 1 AND 12)`
- `CHECK (nr_dia BETWEEN 1 AND 31)`
- `UNIQUE (dt_data)` — garante um registro por dia

**Regra de negócio:**
- O `id_data` no formato `YYYYMMDD` (ex: `20240115`) permite JOIN direto com datas convertidas via `CONVERT(INT, CONVERT(VARCHAR, dt_data, 112))`
- `fl_dia_util` considera feriados nacionais — pregões não ocorrem nesses dias
- Esta tabela é populada pela SP de ETL que gera automaticamente todos os dias do período

---

### 11. dim_periodo_crise

**Descrição:** Períodos históricos de crise econômica ou política que impactaram o mercado financeiro brasileiro. Usado para segmentar análises comparativas (antes, durante e após crises).

**Registros estimados:** 5  
**Frequência de atualização:** Conforme necessidade analítica

| Coluna | Tipo | PK | Nulo | Descrição | Exemplo |
|--------|------|----|----|-----------|---------|
| id_crise | INT IDENTITY(1,1) | ✅ | NÃO | Chave primária surrogate | 1, 2, 3... |
| ds_crise | VARCHAR(100) | — | NÃO | Nome identificador do período de crise | `Pandemia COVID-19` |
| dt_inicio | DATE | — | NÃO | Data de início do período | `2020-02-01` |
| dt_fim | DATE | — | NÃO | Data de fim do período | `2020-12-31` |
| ds_descricao | VARCHAR(500) | — | SIM | Contexto histórico e impactos | `Crise sanitária global que causou...` |

**Constraints:**
- `CHECK (dt_fim >= dt_inicio)` — garante que o período é válido

**Dados iniciais:**

| ds_crise | dt_inicio | dt_fim | Contexto |
|----------|-----------|--------|----------|
| Crise Financeira Global 2008 | 2008-09-01 | 2009-03-31 | Lehman Brothers, subprime nos EUA |
| Crise Política Brasil 2015-2016 | 2015-01-01 | 2016-12-31 | Recessão, impeachment, Lava Jato |
| Lava Jato - Pico 2017 | 2017-05-01 | 2017-06-30 | Gravações JBS, crise política aguda |
| Pandemia COVID-19 | 2020-02-01 | 2020-12-31 | Crash de março, circuit breakers |
| Alta da Selic 2022-2023 | 2022-01-01 | 2023-06-30 | Ciclo de aperto monetário, Selic a 13,75% |

---

### 12. dim_indicador_macro

**Descrição:** Catálogo dos indicadores macroeconômicos monitorados. Define metadados como unidade, fonte e código de série do Banco Central para facilitar consultas e documentação.

**Registros estimados:** 4  
**Frequência de atualização:** Raramente (apenas quando novos indicadores são adicionados)

| Coluna | Tipo | PK | Nulo | Unique | Descrição | Exemplo |
|--------|------|----|----|--------|-----------|---------|
| id_indicador | INT IDENTITY(1,1) | ✅ | NÃO | — | Chave primária surrogate | 1, 2, 3, 4 |
| cd_indicador | VARCHAR(20) | — | NÃO | ✅ | Código único e legível do indicador | `SELIC`, `IPCA`, `CAMBIO` |
| ds_indicador | VARCHAR(100) | — | NÃO | — | Nome completo oficial do indicador | `Taxa de Juros Selic` |
| ds_unidade | VARCHAR(50) | — | NÃO | — | Unidade de medida do valor | `% ao dia`, `% ao mês`, `R$/USD` |
| ds_fonte | VARCHAR(100) | — | NÃO | — | Instituição responsável pelo dado | `Banco Central do Brasil` |
| cd_serie_bcb | VARCHAR(20) | — | SIM | — | Código da série no SGS do BCB para download via API | `11` (Selic), `433` (IPCA) |
| ds_descricao | VARCHAR(500) | — | SIM | — | Descrição do indicador e seu uso nas análises | `Taxa básica de juros da economia...` |

**Dados iniciais:**

| cd_indicador | ds_indicador | ds_unidade | cd_serie_bcb | URL da API |
|-------------|-------------|------------|--------------|------------|
| SELIC | Taxa de Juros Selic | % ao dia | 11 | https://api.bcb.gov.br/dados/serie/bcdata.sgs.11/dados?formato=csv |
| IPCA | IPCA - Inflação | % ao mês | 433 | https://api.bcb.gov.br/dados/serie/bcdata.sgs.433/dados?formato=csv |
| CAMBIO | Taxa de Câmbio USD/BRL | R$/USD | 1 | https://api.bcb.gov.br/dados/serie/bcdata.sgs.1/dados?formato=csv |
| CDI | Taxa CDI | % ao dia | 12 | https://api.bcb.gov.br/dados/serie/bcdata.sgs.12/dados?formato=csv |

---

## FATOS

> Tabelas fato armazenam os eventos de negócio com métricas numéricas. São as maiores tabelas do banco, com alto volume de registros. Seguem o padrão **Star Schema** — chaves estrangeiras para dimensões + métricas.

---

### 13. fato_cotacao

**Descrição:** Tabela principal e maior do banco. Armazena as cotações diárias históricas de todas as ações da B3 desde 2000. Cada linha representa um pregão de uma ação específica.

**Fonte:** Kaggle — https://www.kaggle.com/datasets/felsal/ibovespa-stocks  
**Registros estimados:** 500.000+ registros  
**Frequência de atualização:** Diária (dias úteis, após fechamento do pregão)

| Coluna | Tipo | PK | FK | Nulo | Descrição | Exemplo |
|--------|------|----|----|------|-----------|---------|
| id_cotacao | BIGINT IDENTITY(1,1) | ✅ | — | NÃO | Chave primária surrogate | 1, 2, 3... |
| id_acao | INT | — | ✅ dim_acao | NÃO | Ação negociada no pregão | 5 (PETR4) |
| id_data | INT | — | ✅ dim_data | NÃO | Data do pregão no formato YYYYMMDD | `20240115` |
| vl_abertura | DECIMAL(18,4) | — | — | NÃO | Preço de abertura do pregão em R$ | `36.8500` |
| vl_fechamento | DECIMAL(18,4) | — | — | NÃO | Preço de fechamento do pregão em R$ | `37.2100` |
| vl_maximo | DECIMAL(18,4) | — | — | NÃO | Preço máximo atingido durante o dia em R$ | `37.5000` |
| vl_minimo | DECIMAL(18,4) | — | — | NÃO | Preço mínimo atingido durante o dia em R$ | `36.7000` |
| vl_volume | BIGINT | — | — | NÃO | Volume financeiro negociado no dia em R$ | `452300000` |
| vl_retorno_diario | DECIMAL(10,6) | — | — | SIM | Retorno diário calculado: `(fechamento/fechamento_anterior) - 1` | `0.009762` (= +0,97%) |
| vl_amplitude | DECIMAL(18,4) | — | — | SIM | Amplitude do dia: `vl_maximo - vl_minimo` | `0.8000` |
| dt_carga | DATETIME | — | — | NÃO | Timestamp da carga do registro | `2024-01-15 18:00:00` |

**Constraints:**
- `UNIQUE (id_acao, id_data)` — garante que não há cotação duplicada para a mesma ação no mesmo dia
- `CHECK (vl_maximo >= vl_minimo)` — máximo não pode ser menor que mínimo
- `CHECK (vl_volume >= 0)` — volume não pode ser negativo

**Índices:**
- `IX_cotacao_acao_data (id_acao, id_data)` — índice composto para buscas por ação e período
- `IX_cotacao_data (id_data)` — índice para buscas por data (análises macro cruzadas)

**Regras de negócio:**
- `vl_retorno_diario` é calculado pela SP de ETL após a carga e pode ser NULL no primeiro dia de negociação de um ticker
- `vl_amplitude` mede a volatilidade intraday — quanto maior, mais volátil o dia

---

### 14. fato_indicador_macro

**Descrição:** Valores históricos diários e mensais dos indicadores macroeconômicos. Permite cruzar eventos macro (alta de Selic, pico de inflação, valorização do dólar) com o comportamento das ações.

**Registros estimados:** ~50.000 registros  
**Frequência de atualização:** Diária (Selic, Câmbio) e Mensal (IPCA)

| Coluna | Tipo | PK | FK | Nulo | Descrição | Exemplo |
|--------|------|----|----|------|-----------|---------|
| id_fato | BIGINT IDENTITY(1,1) | ✅ | — | NÃO | Chave primária surrogate | 1, 2, 3... |
| id_indicador | INT | — | ✅ dim_indicador_macro | NÃO | Indicador macroeconômico | 1 (SELIC) |
| id_data | INT | — | ✅ dim_data | NÃO | Data de referência do valor | `20240115` |
| vl_indicador | DECIMAL(18,6) | — | — | NÃO | Valor do indicador na data | `0.043250` (Selic diária) |
| dt_carga | DATETIME | — | — | NÃO | Timestamp da carga | `2024-01-15 09:00:00` |

**Constraints:**
- `UNIQUE (id_indicador, id_data)` — um valor por indicador por data

**Exemplos de valores por indicador:**

| cd_indicador | Data | vl_indicador | Interpretação |
|-------------|------|-------------|----------------|
| SELIC | 2024-01-15 | 0.043250 | 0,04325% ao dia |
| IPCA | 2024-01-31 | 0.420000 | 0,42% no mês de janeiro |
| CAMBIO | 2024-01-15 | 4.965000 | R$ 4,965 por USD 1,00 |
| CDI | 2024-01-15 | 0.043100 | 0,0431% ao dia |

---

### 15. fato_dem_financeira

**Descrição:** Demonstrações financeiras anuais e trimestrais das empresas, extraídas e consolidadas das DFPs da CVM. Permite análise fundamentalista e responde às perguntas Q2 e Q7.

**Fonte:** CVM — https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/  
**Registros estimados:** ~20.000 registros  
**Frequência de atualização:** Anual (DFP) e Trimestral (ITR)

| Coluna | Tipo | PK | FK | Nulo | Descrição | Exemplo |
|--------|------|----|----|------|-----------|---------|
| id_fato | BIGINT IDENTITY(1,1) | ✅ | — | NÃO | Chave primária surrogate | 1, 2, 3... |
| id_empresa | INT | — | ✅ dim_empresa | NÃO | Empresa que publicou a demonstração | 1 (Petrobras) |
| id_data | INT | — | ✅ dim_data | NÃO | Data de referência (ex: 31/12/2023 = `20231231`) | `20231231` |
| vl_receita_liquida | DECIMAL(20,2) | — | — | SIM | Receita líquida total em R$ | `502637000000.00` |
| vl_lucro_liquido | DECIMAL(20,2) | — | — | SIM | Lucro líquido do período em R$ | `124642000000.00` |
| vl_ebitda | DECIMAL(20,2) | — | — | SIM | EBITDA (lucro antes de juros, impostos, depreciação) em R$ | `218500000000.00` |
| vl_divida_bruta | DECIMAL(20,2) | — | — | SIM | Dívida financeira bruta total em R$ | `310000000000.00` |
| vl_patrimonio_liq | DECIMAL(20,2) | — | — | SIM | Patrimônio líquido em R$ | `387000000000.00` |
| vl_ativo_total | DECIMAL(20,2) | — | — | SIM | Ativo total em R$ | `984000000000.00` |
| ds_tipo_dem | VARCHAR(20) | — | — | NÃO | Tipo da demonstração: `ANUAL` ou `TRIMESTRAL` | `ANUAL` |
| dt_carga | DATETIME | — | — | NÃO | Timestamp da carga | `2024-04-30 10:00:00` |

**Constraints:**
- `CHECK (ds_tipo_dem IN ('ANUAL', 'TRIMESTRAL'))` — apenas dois valores válidos

**Regras de negócio:**
- Valores em R$ (moeda corrente) — sem ajuste pela inflação
- Valores negativos representam prejuízo (lucro_liquido < 0) ou saldo credor
- A SP de ETL extrai e pivota os dados da `staging.dem_financeira` filtrando os códigos de conta relevantes

---

### 16. fato_indicadores

**Descrição:** Indicadores financeiros calculados por ação, como P/L, ROE, Dividend Yield, Sharpe e volatilidade. Gerados pela SP analítica a partir das outras tabelas fato. Responde diretamente às perguntas Q1, Q5, Q7 e Q9.

**Registros estimados:** ~200.000 registros  
**Frequência de atualização:** Mensal ou após carga de novas demonstrações financeiras

| Coluna | Tipo | PK | FK | Nulo | Descrição | Exemplo |
|--------|------|----|----|------|-----------|---------|
| id_fato | BIGINT IDENTITY(1,1) | ✅ | — | NÃO | Chave primária surrogate | 1, 2, 3... |
| id_acao | INT | — | ✅ dim_acao | NÃO | Ação para a qual os indicadores foram calculados | 5 (PETR4) |
| id_data | INT | — | ✅ dim_data | NÃO | Data de referência do cálculo | `20231231` |
| vl_pl | DECIMAL(10,4) | — | — | SIM | Preço / Lucro — quantos anos de lucro valem o preço atual | `6.5200` |
| vl_roe | DECIMAL(10,6) | — | — | SIM | Return on Equity: `Lucro Líquido / Patrimônio Líquido` | `0.321800` (= 32,18%) |
| vl_dy | DECIMAL(10,6) | — | — | SIM | Dividend Yield: `Dividendos por ação / Preço` | `0.087500` (= 8,75%) |
| vl_ev_ebitda | DECIMAL(10,4) | — | — | SIM | Enterprise Value / EBITDA — múltiplo de valuation | `3.2100` |
| vl_sharpe | DECIMAL(10,6) | — | — | SIM | Índice de Sharpe: `(Retorno - Selic) / Volatilidade` | `1.450000` |
| vl_volatilidade | DECIMAL(10,6) | — | — | SIM | Desvio padrão anualizado dos retornos diários | `0.285000` (= 28,5% ao ano) |
| vl_market_cap | DECIMAL(20,2) | — | — | SIM | Capitalização de mercado: `nr_total_acoes × vl_fechamento` | `504000000000.00` |
| dt_carga | DATETIME | — | — | NÃO | Timestamp da carga | `2024-01-31 20:00:00` |

**Regras de negócio:**
- `vl_sharpe` usa a Selic diária da `fato_indicador_macro` como taxa livre de risco
- `vl_volatilidade` é calculada com janela de 252 dias úteis (1 ano de pregão)
- Indicadores só são calculados quando há dados suficientes nas tabelas fato dependentes

---

## HISTÓRICOS

### 17. hist_dividendos

**Descrição:** Histórico completo de pagamentos de dividendos, JCP (Juros sobre Capital Próprio) e outros proventos por ação. Essencial para calcular o retorno total (preço + proventos) e o Dividend Yield histórico (Q7).

**Registros estimados:** ~50.000 registros  
**Frequência de atualização:** Conforme anúncios das empresas

| Coluna | Tipo | PK | FK | Nulo | Descrição | Exemplo |
|--------|------|----|----|------|-----------|---------|
| id_dividendo | BIGINT IDENTITY(1,1) | ✅ | — | NÃO | Chave primária surrogate | 1, 2, 3... |
| id_acao | INT | — | ✅ dim_acao | NÃO | Ação que pagou o provento | 5 (PETR4) |
| id_data | INT | — | ✅ dim_data | NÃO | Data de aprovação do provento | `20231201` |
| vl_dividendo | DECIMAL(18,6) | — | — | NÃO | Valor pago por ação em R$ | `3.374200` |
| ds_tipo | VARCHAR(50) | — | — | NÃO | Tipo de provento | `Dividendo`, `JCP`, `Rendimento`, `Amortização` |
| dt_ex | DATE | — | — | SIM | Data ex-dividendo — último dia com direito ao provento | `2023-12-15` |
| dt_pagamento | DATE | — | — | SIM | Data efetiva de pagamento na conta do acionista | `2023-12-29` |
| dt_carga | DATETIME | — | — | NÃO | Timestamp da carga | `2023-12-01 10:00:00` |

**Constraints:**
- `CHECK (vl_dividendo > 0)` — valor de dividendo deve ser positivo

**Regra de negócio:**
- `dt_ex` (data ex) é o mais importante: quem comprar a ação APÓS essa data não recebe o dividendo
- JCP (Juros sobre Capital Próprio) tem tratamento fiscal diferente de dividendos — mantidos separados pelo `ds_tipo`

---

### 18. hist_desdobramento

**Descrição:** Histórico de eventos corporativos que alteram a quantidade de ações: splits (desdobramentos), grupamentos e bonificações. Necessário para ajustar preços históricos e evitar distorções nas análises.

**Registros estimados:** ~2.000 registros  
**Frequência de atualização:** Conforme anúncios corporativos

| Coluna | Tipo | PK | FK | Nulo | Descrição | Exemplo |
|--------|------|----|----|------|-----------|---------|
| id_desdobramento | INT IDENTITY(1,1) | ✅ | — | NÃO | Chave primária surrogate | 1, 2, 3... |
| id_acao | INT | — | ✅ dim_acao | NÃO | Ação que sofreu o evento | 5 (PETR4) |
| id_data | INT | — | ✅ dim_data | NÃO | Data do evento | `20220601` |
| ds_tipo | VARCHAR(20) | — | — | NÃO | Tipo do evento corporativo | `SPLIT`, `GRUPAMENTO`, `BONIFICACAO` |
| vl_fator | DECIMAL(10,4) | — | — | NÃO | Fator de ajuste multiplicativo | `2.0000` (dobrou ações), `0.5000` (grupamento) |
| ds_descricao | VARCHAR(200) | — | — | SIM | Descrição detalhada do evento | `Desdobramento na proporção 1 para 2` |
| dt_carga | DATETIME | — | — | NÃO | Timestamp da carga | `2022-06-01 08:00:00` |

**Constraints:**
- `CHECK (ds_tipo IN ('SPLIT', 'GRUPAMENTO', 'BONIFICACAO'))` — apenas 3 tipos válidos

**Exemplos de fatores:**

| ds_tipo | vl_fator | Significado |
|---------|----------|-------------|
| SPLIT | 2.0000 | Cada ação virou 2 — preço dividido por 2 |
| SPLIT | 3.0000 | Cada ação virou 3 — preço dividido por 3 |
| GRUPAMENTO | 0.5000 | Cada 2 ações viraram 1 — preço dobrado |
| BONIFICACAO | 1.1000 | Cada ação ganhou 0,1 ação extra (10% de bonificação) |

---

### 19. hist_preco_ajustado

**Descrição:** Preços de fechamento ajustados retroativamente por dividendos e desdobramentos. Permite comparação histórica real de retorno total, eliminando distorções causadas por splits e proventos.

**Registros estimados:** ~500.000+ registros (mesmo volume da fato_cotacao)  
**Frequência de atualização:** Diária + retroativo quando ocorre um evento corporativo

| Coluna | Tipo | PK | FK | Nulo | Descrição | Exemplo |
|--------|------|----|----|------|-----------|---------|
| id_preco_aj | BIGINT IDENTITY(1,1) | ✅ | — | NÃO | Chave primária surrogate | 1, 2, 3... |
| id_acao | INT | — | ✅ dim_acao | NÃO | Ação com preço ajustado | 5 (PETR4) |
| id_data | INT | — | ✅ dim_data | NÃO | Data do pregão | `20240115` |
| vl_fechamento_aj | DECIMAL(18,4) | — | — | NÃO | Preço de fechamento ajustado em R$ | `34.2500` |
| vl_retorno_aj | DECIMAL(10,6) | — | — | SIM | Retorno ajustado diário (considera dividendos) | `0.010500` (= +1,05%) |
| dt_carga | DATETIME | — | — | NÃO | Timestamp da carga | `2024-01-15 20:00:00` |

**Constraints:**
- `UNIQUE (id_acao, id_data)` — sem duplicata por ação por data

**Regra de negócio:**
- O preço ajustado pode ser **menor** que o preço real — isso é normal (ex: após split, todos os preços anteriores são divididos pelo fator)
- Usar `hist_preco_ajustado` para análises de retorno histórico; usar `fato_cotacao` para análises de preço pontual

---

## CONTROLE

> Tabelas de controle garantem rastreabilidade, auditoria e operação segura do banco. São preenchidas automaticamente por Triggers e Stored Procedures.

---

### 20. log_auditoria

**Descrição:** Registra automaticamente todas as operações de INSERT, UPDATE e DELETE nas tabelas principais via Triggers de auditoria. Garante rastreabilidade completa de quem alterou o quê e quando.

**Registros estimados:** Variável (cresce conforme uso)  
**Preenchida por:** Triggers (`TR_audit_dim_empresa`, `TR_audit_dim_acao`, etc.)

| Coluna | Tipo | PK | Nulo | Descrição | Exemplo |
|--------|------|----|----|-----------|---------|
| id_log | BIGINT IDENTITY(1,1) | ✅ | NÃO | Chave primária surrogate | 1, 2, 3... |
| ds_tabela | VARCHAR(100) | — | NÃO | Nome da tabela onde a operação ocorreu | `dim_empresa`, `dim_acao` |
| ds_operacao | VARCHAR(10) | — | NÃO | Tipo de operação realizada | `INSERT`, `UPDATE`, `DELETE` |
| ds_usuario | VARCHAR(100) | — | NÃO | Login do usuário SQL (via `SYSTEM_USER`) | `sa`, `app_user` |
| dt_operacao | DATETIME | — | NÃO | Data e hora exata da operação | `2024-01-15 10:32:45` |
| ds_dados_antes | VARCHAR(MAX) | — | SIM | JSON com os dados ANTES da alteração (NULL em INSERTs) | `{"ds_setor": "Financeiro"}` |
| ds_dados_depois | VARCHAR(MAX) | — | SIM | JSON com os dados APÓS a alteração (NULL em DELETEs) | `{"ds_setor": "Financeiro e Seguros"}` |

**Constraints:**
- `CHECK (ds_operacao IN ('INSERT', 'UPDATE', 'DELETE'))` — apenas 3 valores válidos

**Regra de negócio:**
- Para INSERT: `ds_dados_antes = NULL`, `ds_dados_depois` contém o novo registro
- Para DELETE: `ds_dados_antes` contém o registro deletado, `ds_dados_depois = NULL`
- Para UPDATE: ambos preenchidos para comparação antes/depois

---

### 21. log_erros_etl

**Descrição:** Registra erros ocorridos durante a execução das Stored Procedures de ETL. Permite diagnóstico rápido de falhas e reprocessamento seletivo de lotes com erro.

**Registros estimados:** Variável (idealmente zero em produção)  
**Preenchida por:** Blocos `CATCH` das Stored Procedures de ETL

| Coluna | Tipo | PK | Nulo | Descrição | Exemplo |
|--------|------|----|----|-----------|---------|
| id_erro | BIGINT IDENTITY(1,1) | ✅ | NÃO | Chave primária surrogate | 1, 2, 3... |
| ds_procedure | VARCHAR(100) | — | NÃO | Nome da Stored Procedure que gerou o erro | `SP_ETL_CargaCotacoes` |
| ds_erro | VARCHAR(MAX) | — | NÃO | Mensagem de erro completa do SQL Server | `Conversion failed when converting...` |
| ds_dados | VARCHAR(MAX) | — | SIM | Dados que causaram o erro (para reprocessamento) | `{"ticker":"PETR4","dt":"2024-01-15"}` |
| dt_erro | DATETIME | — | NÃO | Data e hora do erro | `2024-01-15 08:45:22` |

**Regra de negócio:**
- A presença de registros nessa tabela indica que a carga não foi 100% bem-sucedida
- O campo `ds_dados` armazena o registro problemático para facilitar análise e correção
- A SP de ETL usa `TRY...CATCH` e insere aqui em caso de erro, sem interromper a carga inteira

---

### 22. parametros_sistema

**Descrição:** Armazena configurações e parâmetros globais do sistema. As SPs de ETL consultam essa tabela para saber, por exemplo, a partir de qual data devem buscar novos dados (carga incremental).

**Registros estimados:** ~4 registros fixos  
**Frequência de atualização:** Atualizado automaticamente pelas SPs após cada carga bem-sucedida

| Coluna | Tipo | PK | Nulo | Unique | Descrição | Exemplo |
|--------|------|----|----|--------|-----------|---------|
| id_parametro | INT IDENTITY(1,1) | ✅ | NÃO | — | Chave primária surrogate | 1, 2, 3, 4 |
| cd_parametro | VARCHAR(50) | — | NÃO | ✅ | Código único e legível do parâmetro | `ULTIMA_CARGA_COTACAO` |
| vl_parametro | VARCHAR(200) | — | NÃO | — | Valor atual do parâmetro | `2024-01-15` |
| ds_descricao | VARCHAR(500) | — | SIM | — | Descrição do uso do parâmetro | `Data da última carga bem-sucedida de cotações` |
| dt_atualizacao | DATETIME | — | NÃO | — | Data da última atualização do parâmetro | `2024-01-15 20:00:00` |

**Dados iniciais:**

| cd_parametro | vl_parametro inicial | Atualizado por |
|-------------|---------------------|----------------|
| ULTIMA_CARGA_COTACAO | 1900-01-01 | SP_ETL_CargaCotacoes |
| ULTIMA_CARGA_MACRO | 1900-01-01 | SP_ETL_CargaIndicadoresMacro |
| ULTIMA_CARGA_DFP | 1900-01-01 | SP_ETL_CargaDemFinanceira |
| VERSAO_BANCO | 1.0.0 | Manualmente |

**Regra de negócio:**
- O valor `1900-01-01` como data inicial força a primeira carga a buscar todos os dados históricos
- Após cada carga bem-sucedida, a SP atualiza o parâmetro com a data atual para permitir carga incremental

---

## 🔗 Mapa de Relacionamentos

| Tabela Filho | Coluna FK | Tabela Pai | Coluna PK | Cardinalidade | Obrigatório |
|-------------|-----------|-----------|-----------|---------------|-------------|
| dim_subsetor | id_setor | dim_setor | id_setor | N:1 | ✅ Sim |
| dim_empresa | id_setor | dim_setor | id_setor | N:1 | ❌ Não |
| dim_empresa | id_subsetor | dim_subsetor | id_subsetor | N:1 | ❌ Não |
| dim_empresa | id_segmento | dim_segmento_listagem | id_segmento | N:1 | ❌ Não |
| dim_acao | id_empresa | dim_empresa | id_empresa | N:1 | ✅ Sim |
| dim_acao | id_tipo_acao | dim_tipo_acao | id_tipo_acao | N:1 | ✅ Sim |
| fato_cotacao | id_acao | dim_acao | id_acao | N:1 | ✅ Sim |
| fato_cotacao | id_data | dim_data | id_data | N:1 | ✅ Sim |
| fato_indicador_macro | id_indicador | dim_indicador_macro | id_indicador | N:1 | ✅ Sim |
| fato_indicador_macro | id_data | dim_data | id_data | N:1 | ✅ Sim |
| fato_dem_financeira | id_empresa | dim_empresa | id_empresa | N:1 | ✅ Sim |
| fato_dem_financeira | id_data | dim_data | id_data | N:1 | ✅ Sim |
| fato_indicadores | id_acao | dim_acao | id_acao | N:1 | ✅ Sim |
| fato_indicadores | id_data | dim_data | id_data | N:1 | ✅ Sim |
| hist_dividendos | id_acao | dim_acao | id_acao | N:1 | ✅ Sim |
| hist_dividendos | id_data | dim_data | id_data | N:1 | ✅ Sim |
| hist_desdobramento | id_acao | dim_acao | id_acao | N:1 | ✅ Sim |
| hist_desdobramento | id_data | dim_data | id_data | N:1 | ✅ Sim |
| hist_preco_ajustado | id_acao | dim_acao | id_acao | N:1 | ✅ Sim |
| hist_preco_ajustado | id_data | dim_data | id_data | N:1 | ✅ Sim |

---

## 📊 Índices

| Índice | Tabela | Colunas | Tipo | Justificativa |
|--------|--------|---------|------|---------------|
| IX_cotacao_acao_data | fato_cotacao | id_acao, id_data | NONCLUSTERED | Busca de cotações por ação e período — query mais comum |
| IX_cotacao_data | fato_cotacao | id_data | NONCLUSTERED | Busca cruzada com dados macro por data |
| IX_macro_indicador_data | fato_indicador_macro | id_indicador, id_data | NONCLUSTERED | Busca de séries históricas de indicadores |
| IX_dem_empresa_data | fato_dem_financeira | id_empresa, id_data | NONCLUSTERED | Busca de demonstrações por empresa e período |
| IX_acao_ticker | dim_acao | cd_ticker | NONCLUSTERED | Lookup de ação por ticker (usado no ETL) |
| IX_empresa_cvm | dim_empresa | cd_cvm | NONCLUSTERED | Lookup de empresa por código CVM (usado no ETL) |

---

## 📦 Volumetria Total Estimada

| Tipo | Tabelas | Total de Registros Estimados |
|------|---------|------------------------------|
| Staging | 3 | ~750.000 |
| Dimensão | 9 | ~10.000 |
| Fato | 4 | ~770.000 |
| Histórico | 3 | ~550.000 |
| Controle | 3 | Variável |
| **TOTAL** | **22** | **~2.080.000+** |

---

## 📚 Glossário de Termos Financeiros

| Termo | Significado |
|-------|-------------|
| **B3** | Brasil, Bolsa, Balcão — bolsa de valores brasileira |
| **Ticker** | Código de identificação de uma ação no pregão (ex: PETR4) |
| **Pregão** | Sessão de negociação na bolsa de valores |
| **Selic** | Taxa básica de juros da economia brasileira |
| **IPCA** | Índice de Preços ao Consumidor Amplo — inflação oficial do Brasil |
| **CDI** | Certificado de Depósito Interbancário — taxa de referência para renda fixa |
| **P/L** | Preço / Lucro — indica quantos anos de lucro valem o preço atual |
| **ROE** | Return on Equity — retorno sobre o patrimônio líquido |
| **DY** | Dividend Yield — rendimento de dividendos em relação ao preço |
| **EBITDA** | Lucro antes de juros, impostos, depreciação e amortização |
| **Market Cap** | Capitalização de mercado = preço × total de ações emitidas |
| **Sharpe** | Índice de retorno ajustado ao risco |
| **Split** | Desdobramento: uma ação vira várias, preço cai proporcionalmente |
| **Grupamento** | Inverso do split: várias ações viram uma, preço sobe proporcionalmente |
| **Tag Along** | Direito do minoritário de vender ações pelo mesmo preço do controlador |
| **Free Float** | Percentual de ações disponíveis para negociação no mercado |
| **DFP** | Demonstração Financeira Padronizada — relatório anual exigido pela CVM |
| **CVM** | Comissão de Valores Mobiliários — regulador do mercado de capitais |
| **JCP** | Juros sobre Capital Próprio — forma de distribuição de lucros com benefício fiscal |

---

*Dicionário de Dados — Projeto Mercado Financeiro B3*  
*Disciplina: Gerenciamento de Banco de Dados | Versão 1.0.0 | 2026-03-11*
