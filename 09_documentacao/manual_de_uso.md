# Manual de Uso — Projeto Mercado Financeiro B3
**Disciplina:** Gerenciamento de Banco de Dados  
**Responsável pela documentação:** Luigi Sapucaia de Lima  
**Banco de dados:** SQL Server 2017+  
**Repositório:** `Mercado-Financeiro-main/`

---

## Sumário

1. [Visão Geral do Projeto](#1-visão-geral-do-projeto)
2. [Pré-requisitos](#2-pré-requisitos)
3. [Como Executar o ETL](#3-como-executar-o-etl)
4. [Como Usar as Stored Procedures Analíticas](#4-como-usar-as-stored-procedures-analíticas)
5. [Como Usar as Functions](#5-como-usar-as-functions)
6. [Como Usar as Views](#6-como-usar-as-views)
7. [Controle de Acesso — Roles e Usuários](#7-controle-de-acesso--roles-e-usuários)
8. [Triggers — O que Fazem e Como Verificar](#8-triggers--o-que-fazem-e-como-verificar)
9. [Estrutura de Pastas do Repositório](#9-estrutura-de-pastas-do-repositório)
10. [Perguntas Frequentes (FAQ)](#10-perguntas-frequentes-faq)

---

## 1. Visão Geral do Projeto

Este projeto simula um pipeline completo de engenharia e análise de dados do mercado financeiro brasileiro, integrando três fontes públicas:

| Fonte | Dado |
|-------|------|
| **Kaggle** (B3) | Preços históricos e volume de ações do Ibovespa |
| **Banco Central (BCB)** | Selic diária, Câmbio USD/BRL e IPCA mensal |
| **CVM** | Cadastro de empresas abertas e Demonstrações Financeiras (DFP) |

O modelo final possui **22 tabelas**, com a tabela `fato_cotacao` contendo mais de **200.000 registros**.

---

## 2. Pré-requisitos

Antes de executar qualquer script, certifique-se de que:

- SQL Server 2017 ou superior está instalado e rodando
- O cliente SSMS (SQL Server Management Studio) está configurado e conectado
- O banco de dados `MercadoFinanceiro` foi criado:

```sql
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'MercadoFinanceiro')
BEGIN
    CREATE DATABASE MercadoFinanceiro
        COLLATE Latin1_General_CI_AI;
END;
GO

USE MercadoFinanceiro;
GO
```

- Os CSVs foram baixados e salvos em uma pasta acessível pelo servidor SQL Server (necessário para o `BULK INSERT`)

---

## 3. Como Executar o ETL

O pipeline de ETL é composto por Stored Procedures orquestradas por uma procedure principal.

### 3.1 Passo a passo

**Etapa 1 — Criar a estrutura (DDL):**
```sql
-- Execute o script completo de criação de tabelas
-- 01_ddl/01_ddl_mercado_financeiro.sql
```

**Etapa 2 — Ajustar o caminho dos CSVs:**

Abra o arquivo `02_etl/01_extract_staging.sql` e localize a variável:
```sql
DECLARE @base_path NVARCHAR(500) = N'C:\dados\mercado_financeiro\';
```
Substitua pelo caminho real onde os CSVs foram salvos no servidor.

**Etapa 3 — Executar o pipeline completo:**
```sql
EXEC dbo.usp_etl_executar_pipeline;
```

**Etapa 4 — Validar a carga:**
```sql
-- Confirmar volume mínimo na tabela fato
SELECT COUNT(*) AS total_registros FROM dbo.fato_cotacao;
-- Esperado: >= 200.000

-- Verificar ausência de preços inválidos
SELECT COUNT(*) AS invalidos
FROM dbo.fato_cotacao
WHERE vl_fechamento <= 0
   OR vl_maximo < vl_minimo;
-- Esperado: 0 (os triggers bloqueiam automaticamente)
```

### 3.2 Descrição das Procedures de ETL

| Procedure | Responsabilidade |
|-----------|-----------------|
| `sp_extract_cotacoes` | Carrega cotações históricas do Kaggle (B3) |
| `sp_extract_indicador_bcb` | Carrega Selic, IPCA e Câmbio dos CSVs do BCB |
| `sp_extract_dem_financeira` | Carrega DFP da CVM |
| `sp_extract_cadastro_empresa` | Carrega cadastro de empresas da CVM |
| `usp_etl_executar_pipeline` | **Orquestrador** — chama todas as acima em sequência |

---

## 4. Como Usar as Stored Procedures Analíticas

As procedures analíticas respondem às perguntas de negócio definidas no Plano de Análise.

### SP 1 — Selic vs. Retorno de Ações Financeiras (Q1)

**Pergunta respondida:** Empresas do setor financeiro superam a Selic em janelas de alta de juros?

```sql
EXEC dbo.usp_selic_vs_retorno_financeiras
    @dt_inicio = '2021-01-01',
    @dt_fim    = '2023-12-31';
```

**Resultado retornado:**

| Coluna | Descrição |
|--------|-----------|
| `cd_ticker` | Código da ação |
| `ds_setor` | Subsetor financeiro |
| `retorno_acumulado_pct` | Retorno total no período (%) |
| `selic_acumulada_pct` | Selic acumulada no mesmo período (%) |
| `superou_selic` | `SIM` ou `NÃO` |

### SP 2 — Empresas Resilientes na COVID-2020 (Q2)

**Pergunta respondida:** Quais empresas cresceram receita e lucro durante a crise de 2020?

```sql
EXEC dbo.usp_empresas_resilientes_covid;
```

**Resultado retornado:**

| Coluna | Descrição |
|--------|-----------|
| `ds_razao_social` | Nome da empresa |
| `ds_setor` | Setor de atuação |
| `cagr_receita_2019_2021` | CAGR de receita no período (%) |
| `cagr_lucro_2019_2021` | CAGR de lucro no período (%) |
| `ds_segmento_listagem` | Novo Mercado, Nível 1, etc. |

---

## 5. Como Usar as Functions

As functions são utilitários reutilizáveis para cálculos financeiros.

### fn_retorno_acumulado

Calcula o retorno percentual acumulado de uma ação em um período.

```sql
SELECT dbo.fn_retorno_acumulado(
    'PETR4',          -- ticker da ação
    '2022-01-03',     -- data de início
    '2022-12-30'      -- data de fim
) AS retorno_acumulado_pct;
```

**Exemplo de uso em consulta combinada:**
```sql
SELECT
    cd_ticker,
    dbo.fn_retorno_acumulado(cd_ticker, '2022-01-03', '2022-12-30') AS retorno_2022,
    dbo.fn_retorno_acumulado(cd_ticker, '2023-01-02', '2023-12-29') AS retorno_2023
FROM dbo.dim_empresa
WHERE ds_setor = 'Financeiro';
```

### fn_volatilidade_historica

Calcula o desvio padrão dos retornos diários (volatilidade histórica).

```sql
SELECT dbo.fn_volatilidade_historica(
    'VALE3',          -- ticker da ação
    '2023-01-02',     -- data de início
    '2023-12-29'      -- data de fim
) AS volatilidade_diaria_pct;
```

> **Dica:** Multiplique por `SQRT(252)` para anualizar a volatilidade (252 = dias úteis/ano).

---

## 6. Como Usar as Views

As views são a interface de consumo recomendada para relatórios e dashboards.

| View | Descrição |
|------|-----------|
| `vw_cotacao_diaria` | Preços completos com nome da empresa e setor |
| `vw_retorno_mensal` | Retorno mensal calculado por ação |
| `vw_selic_vs_acoes` | Comparativo entre Selic e retorno de ações financeiras |
| `vw_empresas_resilientes` | Empresas com CAGR positivo em 2019–2021 |
| `vw_volume_por_setor` | Volume financeiro agregado por setor e mês |

**Exemplos de uso:**

```sql
-- Consultar cotações do último mês
SELECT * FROM dbo.vw_cotacao_diaria
WHERE dt_pregao >= DATEADD(DAY, -30, GETDATE())
ORDER BY dt_pregao DESC;

-- Top 10 setores por volume no ano corrente
SELECT ds_setor, SUM(vl_volume) AS volume_total
FROM dbo.vw_volume_por_setor
WHERE YEAR(dt_pregao) = YEAR(GETDATE())
GROUP BY ds_setor
ORDER BY volume_total DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;
```

---

## 7. Controle de Acesso — Roles e Usuários

O projeto implementa três perfis de acesso seguindo o **princípio do menor privilégio**.

### 7.1 Resumo dos Perfis

| Role | Pode fazer | Não pode fazer |
|------|-----------|----------------|
| `role_leitura` | SELECT em tabelas fato, dimensões e views | INSERT, UPDATE, DELETE, EXECUTE, DDL |
| `role_analista` | Tudo do role_leitura + EXECUTE nas SPs e Functions + SELECT em log_auditoria | INSERT, UPDATE, DELETE, DDL, ETL |
| `role_admin` | Controle total (CONTROL ON SCHEMA::dbo) | — |

### 7.2 Como Aplicar um Role a um Novo Usuário

```sql
-- 1. Criar o login no servidor
CREATE LOGIN novo_usuario WITH PASSWORD = 'SenhaSegura@123',
    CHECK_EXPIRATION = ON, CHECK_POLICY = ON;
GO

-- 2. Criar o usuário no banco
CREATE USER novo_usuario FOR LOGIN novo_usuario;
GO

-- 3. Conceder o role adequado
ALTER ROLE role_leitura ADD MEMBER novo_usuario;
-- ou: ALTER ROLE role_analista ADD MEMBER novo_usuario;
-- ou: ALTER ROLE role_admin    ADD MEMBER novo_usuario;
GO
```

### 7.3 Como Revogar Acesso

```sql
-- Remover de um role específico
ALTER ROLE role_analista DROP MEMBER usuario_demitido;
GO

-- Remover o usuário do banco
DROP USER IF EXISTS usuario_demitido;
GO

-- Remover o login do servidor
DROP LOGIN IF EXISTS usuario_demitido;
GO
```

### 7.4 Verificar Permissões de um Usuário

```sql
-- Ver membros de cada role
SELECT r.name AS role_name, m.name AS membro
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
ORDER BY r.name, m.name;

-- Ver permissões concedidas a cada role
SELECT pr.name AS role_name, p.class_desc,
       p.permission_name, p.state_desc AS grant_or_deny
FROM sys.database_permissions p
JOIN sys.database_principals pr ON pr.principal_id = p.grantee_principal_id
WHERE pr.type = 'R'
ORDER BY pr.name, p.permission_name;
```

---

## 8. Triggers — O que Fazem e Como Verificar

### 8.1 trg_auditoria_cotacao

Registra automaticamente toda operação de **INSERT, UPDATE ou DELETE** em `fato_cotacao` na tabela `log_auditoria`.

**Nenhuma ação manual é necessária** — o trigger dispara automaticamente.

**Como consultar o log:**
```sql
-- Últimas 50 operações registradas
SELECT TOP 50
    id_log,
    ds_operacao,
    ds_tabela,
    dt_operacao,
    ds_dados_antes,
    ds_dados_depois,
    ds_usuario
FROM dbo.log_auditoria
ORDER BY dt_operacao DESC;

-- Filtrar por tipo de operação
SELECT * FROM dbo.log_auditoria
WHERE ds_operacao = 'DELETE'
ORDER BY dt_operacao DESC;

-- Filtrar por tabela
SELECT * FROM dbo.log_auditoria
WHERE ds_tabela = 'fato_cotacao'
ORDER BY dt_operacao DESC;
```

### 8.2 trg_validar_preco

Bloqueia automaticamente qualquer INSERT ou UPDATE em `fato_cotacao` que viole as regras:

| Regra | Mensagem de erro |
|-------|-----------------|
| Preço negativo ou zero | `vl_X não pode ser negativo ou zero` |
| Máximo < Mínimo | `vl_maximo não pode ser menor que vl_minimo` |
| Fechamento fora do intervalo | `vl_fechamento deve estar entre vl_minimo e vl_maximo` |
| Volume negativo | `vl_volume não pode ser negativo` |

**Exemplo de comportamento:**
```sql
-- Esta inserção será BLOQUEADA automaticamente pelo trigger:
INSERT INTO dbo.fato_cotacao
    (id_acao, id_data, vl_abertura, vl_fechamento, vl_maximo, vl_minimo, vl_volume)
VALUES
    (1, 1, 10.00, -5.00, 12.00, 8.00, 100000);
-- Erro: [trg_validar_preco]: vl_fechamento não pode ser negativo ou zero.
```

### 8.3 Verificar se os Triggers estão ativos

```sql
SELECT
    name            AS trigger_name,
    is_disabled,
    parent_class_desc,
    create_date,
    modify_date
FROM sys.triggers
WHERE parent_id = OBJECT_ID('dbo.fato_cotacao')
ORDER BY name;
```

---

## 9. Estrutura de Pastas do Repositório

```
Mercado-Financeiro-main/
├── README.md
├── 01_ddl/
│   └── 01_ddl_mercado_financeiro.sql      # DDL das 22 tabelas (Lucas R.)
├── 02_etl/
│   └── 01_extract_staging.sql             # Pipeline ETL completo (Lucas O.)
├── 03_dql/
│   └── 01_validacao_pos_etl.sql           # Validação da carga (Ailton)
├── 04_views/
│   └── views.sql                          # 5 views analíticas (Lucas R.)
├── 05_stored_procedures/
│   ├── usp_selic_vs_retorno_financeiras.sql   # SP analítica Q1 (Lucas O.)
│   └── usp_empresas_resilientes_covid.sql     # SP analítica Q2 (Lucas O.)
├── 06_functions/
│   ├── fn_retorno_acumulado.sql           # Function retorno (Ailton)
│   └── fn_volatilidade_historica.sql      # Function volatilidade (Ailton)
├── 07_triggers/
│   ├── trg_auditoria_cotacao.sql          # Trigger de auditoria (Luigi)
│   └── trg_validar_preco.sql              # Trigger de validação (Luigi)
├── 08_dcl/
│   └── roles_e_permissoes_sqlserver.sql   # Roles e grants (Luigi)
├── 09_documentacao/
│   ├── manual_de_uso.md                   # Este documento (Luigi)
│   └── dicionario_de_dados_completo.md    # Dicionário das tabelas
└── 10_dados/
    ├── INSTRUCOES.md                      # Como baixar os CSVs
    ├── b3/LEIA-ME.md
    ├── bcb/LEIA-ME.md
    └── cvm/LEIA-ME.md
```

---

## 10. Perguntas Frequentes (FAQ)

**Q: O ETL falhou com erro de permissão no `BULK INSERT`. O que fazer?**  
A: Certifique-se de que o usuário possui a permissão `ADMINISTER BULK OPERATIONS` no SQL Server. O arquivo CSV também deve estar em um caminho acessível pelo serviço do SQL Server.

**Q: Como reexecutar apenas uma etapa do ETL sem recarregar tudo?**  
A: Cada procedure de ETL pode ser chamada individualmente:
```sql
EXEC dbo.sp_extract_cotacoes;
EXEC dbo.sp_extract_indicador_bcb;
EXEC dbo.sp_extract_dem_financeira;
EXEC dbo.sp_extract_cadastro_empresa;
```

**Q: O trigger `trg_validar_preco` está bloqueando minha carga do ETL. Por que?**  
A: Os dados brutos do CSV podem conter registros inválidos. Verifique as linhas com problema:
```sql
SELECT * FROM dbo.stg_cotacao
WHERE vl_maximo < vl_minimo OR vl_fechamento <= 0;
```
O ETL deve limpar esses registros antes de inserir em `fato_cotacao`.

**Q: Posso usar as functions diretamente no Power BI ou Looker Studio?**  
A: Sim. Crie uma consulta SQL personalizada na ferramenta de BI usando `SELECT dbo.fn_retorno_acumulado(...)`. Prefira usar as **views** para fontes de dados fixas, pois têm melhor desempenho.

**Q: Como saber qual usuário deletou um registro?**  
A: Consulte a tabela `log_auditoria` filtrando pela operação e período:
```sql
SELECT ds_usuario, ds_tabela, dt_operacao, ds_dados_antes
FROM dbo.log_auditoria
WHERE ds_operacao = 'DELETE'
ORDER BY dt_operacao DESC;
```

---

*Documento elaborado por Luigi Sapucaia de Lima — Projeto Final GBD 2026*
