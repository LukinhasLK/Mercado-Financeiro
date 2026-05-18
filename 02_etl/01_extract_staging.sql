-- ============================================================
-- PROJETO: BANCO DE DADOS MERCADO FINANCEIRO
-- FASE: ETL — EXTRACT (Extração e Carga em Staging)
-- Compatibilidade: SQL Server 2017+
-- Autor: Engenharia de Dados
-- Data: 2026-03-11
-- ============================================================
--
-- OBJETIVO:
--   Este script implementa a camada EXTRACT do pipeline ETL.
--   Cria as tabelas de staging no SQL Server, carrega os dados
--   brutos das fontes externas (CSV) e prepara tudo para
--   a fase TRANSFORM.
--
-- FONTES DE DADOS:
--   1. Kaggle/B3 — Cotações históricas (CSV)
--   2. BCB (Banco Central) — Selic, IPCA, Câmbio, CDI (CSV)
--   3. CVM — Demonstrações Financeiras e Cadastro de Empresas (CSV)
--
-- PRÉ-REQUISITOS:
--   - SQL Server 2017+ com permissão ADMINISTER BULK OPERATIONS
--   - Arquivos CSV baixados nas pastas definidas em @base_path
--   - Banco de dados MercadoFinanceiro já criado
--   - Para CSVs UTF-8: CODEPAGE = '65001'
--   - Para CSVs Latin1/Windows-1252: CODEPAGE = '1252'
--
-- CONVENÇÕES:
--   - Tabelas de staging usam prefixo stg_
--   - Todas as colunas são VARCHAR para preservar dados brutos
--   - Coluna dt_carga registra o momento da ingestão
--   - Coluna id_staging é IDENTITY (surrogate key)
-- ============================================================


-- ============================================================
-- 0. CONFIGURAÇÃO INICIAL
-- ============================================================

IF NOT EXISTS (
    SELECT name FROM sys.databases WHERE name = N'MercadoFinanceiro'
)
BEGIN
    CREATE DATABASE MercadoFinanceiro
        COLLATE Latin1_General_CI_AI;
END;
GO

USE MercadoFinanceiro;
GO

-- Caminho base dos arquivos CSV. Ajustar conforme o ambiente.
-- Exemplo: 'C:\mercado_financeiro\' ou '\\servidor\share\mercado_financeiro\'
DECLARE @base_path NVARCHAR(500) = N'C:\mercado_financeiro\';


-- ============================================================
-- 1. SCHEMA DE STAGING — TABELAS DE POUSO (LANDING ZONE)
-- ============================================================
-- As tabelas de staging recebem dados brutos sem transformação.
-- Todos os campos são VARCHAR para evitar erros de tipo na
-- ingestão. A conversão de tipos ocorre na fase TRANSFORM.
-- ============================================================


-- ------------------------------------------------------------
-- 1.1 STAGING: COTAÇÕES HISTÓRICAS (Fonte: Kaggle/B3)
-- ------------------------------------------------------------
-- Origem: CSV com preços diários de ações do Ibovespa
-- Colunas esperadas no CSV: ticker, date, open, close, high, low, volume
-- ------------------------------------------------------------

IF OBJECT_ID(N'dbo.stg_cotacao', N'U') IS NOT NULL
    DROP TABLE dbo.stg_cotacao;
GO

CREATE TABLE dbo.stg_cotacao (
    id_staging      BIGINT          NOT NULL IDENTITY(1,1),
    ticker          VARCHAR(10)     NULL,
    dt_pregao       VARCHAR(20)     NULL,
    vl_abertura     VARCHAR(20)     NULL,
    vl_fechamento   VARCHAR(20)     NULL,
    vl_maximo       VARCHAR(20)     NULL,
    vl_minimo       VARCHAR(20)     NULL,
    vl_volume       VARCHAR(30)     NULL,
    dt_carga        DATETIME        NOT NULL DEFAULT GETDATE(),
    fl_processado   TINYINT         NOT NULL DEFAULT 0,
    ds_erro         VARCHAR(500)    NULL,
    CONSTRAINT PK_stg_cotacao PRIMARY KEY (id_staging)
);
GO

CREATE INDEX idx_stg_cotacao_ticker      ON dbo.stg_cotacao (ticker);
CREATE INDEX idx_stg_cotacao_dt_pregao   ON dbo.stg_cotacao (dt_pregao);
CREATE INDEX idx_stg_cotacao_processado  ON dbo.stg_cotacao (fl_processado);
GO


-- ------------------------------------------------------------
-- 1.2 STAGING: INDICADORES MACROECONÔMICOS (Fonte: BCB)
-- ------------------------------------------------------------
-- Origem: CSV do Sistema Gerenciador de Séries Temporais (SGS)
-- Séries: 11 (Selic), 433 (IPCA), 1 (Câmbio USD/BRL), 12 (CDI)
-- Colunas esperadas: data;valor
-- ------------------------------------------------------------

IF OBJECT_ID(N'dbo.stg_indicadores_macro', N'U') IS NOT NULL
    DROP TABLE dbo.stg_indicadores_macro;
GO

CREATE TABLE dbo.stg_indicadores_macro (
    id_staging      BIGINT          NOT NULL IDENTITY(1,1),
    cd_indicador    VARCHAR(20)     NULL,
    cd_serie_bcb    VARCHAR(20)     NULL,
    dt_referencia   VARCHAR(20)     NULL,
    vl_indicador    VARCHAR(30)     NULL,
    dt_carga        DATETIME        NOT NULL DEFAULT GETDATE(),
    fl_processado   TINYINT         NOT NULL DEFAULT 0,
    ds_erro         VARCHAR(500)    NULL,
    CONSTRAINT PK_stg_indicadores_macro PRIMARY KEY (id_staging)
);
GO

CREATE INDEX idx_stg_macro_indicador    ON dbo.stg_indicadores_macro (cd_indicador);
CREATE INDEX idx_stg_macro_dt_ref       ON dbo.stg_indicadores_macro (dt_referencia);
CREATE INDEX idx_stg_macro_processado   ON dbo.stg_indicadores_macro (fl_processado);
GO


-- ------------------------------------------------------------
-- 1.3 STAGING: DEMONSTRAÇÕES FINANCEIRAS (Fonte: CVM DFP)
-- ------------------------------------------------------------
-- Origem: CSV do portal de dados abertos da CVM
-- Arquivo: dfp_cia_aberta_DRE_con_*.csv (e variantes BPA, BPP)
-- Colunas esperadas: CD_CVM, DS_CONTA, CD_CONTA, VL_CONTA, DT_REFER
-- ------------------------------------------------------------

IF OBJECT_ID(N'dbo.stg_dem_financeira', N'U') IS NOT NULL
    DROP TABLE dbo.stg_dem_financeira;
GO

CREATE TABLE dbo.stg_dem_financeira (
    id_staging      BIGINT          NOT NULL IDENTITY(1,1),
    cd_cvm          VARCHAR(20)     NULL,
    ds_conta        VARCHAR(200)    NULL,
    cd_conta        VARCHAR(50)     NULL,
    vl_conta        VARCHAR(30)     NULL,
    dt_referencia   VARCHAR(20)     NULL,
    ds_tipo_dem     VARCHAR(20)     NULL,
    nr_versao       VARCHAR(10)     NULL,
    dt_carga        DATETIME        NOT NULL DEFAULT GETDATE(),
    fl_processado   TINYINT         NOT NULL DEFAULT 0,
    ds_erro         VARCHAR(500)    NULL,
    CONSTRAINT PK_stg_dem_financeira PRIMARY KEY (id_staging)
);
GO

CREATE INDEX idx_stg_dem_cd_cvm        ON dbo.stg_dem_financeira (cd_cvm);
CREATE INDEX idx_stg_dem_cd_conta      ON dbo.stg_dem_financeira (cd_conta);
CREATE INDEX idx_stg_dem_dt_ref        ON dbo.stg_dem_financeira (dt_referencia);
CREATE INDEX idx_stg_dem_processado    ON dbo.stg_dem_financeira (fl_processado);
GO


-- ------------------------------------------------------------
-- 1.4 STAGING: CADASTRO DE EMPRESAS (Fonte: CVM)
-- ------------------------------------------------------------
-- Origem: CSV do cadastro de companhias abertas da CVM
-- Colunas esperadas: CD_CVM, CNPJ_CIA, DENOM_SOCIAL, DENOM_COMERC,
--                    SETOR_ATIV, SIT, DT_REG, DT_CONST
-- ------------------------------------------------------------

IF OBJECT_ID(N'dbo.stg_cadastro_empresa', N'U') IS NOT NULL
    DROP TABLE dbo.stg_cadastro_empresa;
GO

CREATE TABLE dbo.stg_cadastro_empresa (
    id_staging          BIGINT          NOT NULL IDENTITY(1,1),
    cd_cvm              VARCHAR(20)     NULL,
    nr_cnpj             VARCHAR(20)     NULL,
    ds_razao_social     VARCHAR(200)    NULL,
    ds_nome_pregao      VARCHAR(100)    NULL,
    ds_setor_atividade  VARCHAR(200)    NULL,
    ds_situacao         VARCHAR(50)     NULL,
    dt_registro         VARCHAR(20)     NULL,
    dt_constituicao     VARCHAR(20)     NULL,
    ds_segmento         VARCHAR(100)    NULL,
    dt_carga            DATETIME        NOT NULL DEFAULT GETDATE(),
    fl_processado       TINYINT         NOT NULL DEFAULT 0,
    ds_erro             VARCHAR(500)    NULL,
    CONSTRAINT PK_stg_cadastro_empresa PRIMARY KEY (id_staging)
);
GO

CREATE INDEX idx_stg_cad_cd_cvm        ON dbo.stg_cadastro_empresa (cd_cvm);
CREATE INDEX idx_stg_cad_cnpj          ON dbo.stg_cadastro_empresa (nr_cnpj);
CREATE INDEX idx_stg_cad_processado    ON dbo.stg_cadastro_empresa (fl_processado);
GO


-- ------------------------------------------------------------
-- 1.5 STAGING: DIVIDENDOS (Fonte: CVM/B3)
-- ------------------------------------------------------------
-- Origem: CSV de eventos corporativos (proventos)
-- Colunas esperadas: ticker;cd_cvm;dt_aprovacao;valor;tipo;dt_ex;dt_pagamento
-- ------------------------------------------------------------

IF OBJECT_ID(N'dbo.stg_dividendos', N'U') IS NOT NULL
    DROP TABLE dbo.stg_dividendos;
GO

CREATE TABLE dbo.stg_dividendos (
    id_staging      BIGINT          NOT NULL IDENTITY(1,1),
    ticker          VARCHAR(10)     NULL,
    cd_cvm          VARCHAR(20)     NULL,
    dt_aprovacao    VARCHAR(20)     NULL,
    vl_provento     VARCHAR(30)     NULL,
    ds_tipo         VARCHAR(50)     NULL,
    dt_ex           VARCHAR(20)     NULL,
    dt_pagamento    VARCHAR(20)     NULL,
    dt_carga        DATETIME        NOT NULL DEFAULT GETDATE(),
    fl_processado   TINYINT         NOT NULL DEFAULT 0,
    ds_erro         VARCHAR(500)    NULL,
    CONSTRAINT PK_stg_dividendos PRIMARY KEY (id_staging)
);
GO

CREATE INDEX idx_stg_div_ticker        ON dbo.stg_dividendos (ticker);
CREATE INDEX idx_stg_div_processado    ON dbo.stg_dividendos (fl_processado);
GO


-- ------------------------------------------------------------
-- 1.6 STAGING: DESDOBRAMENTOS (Fonte: B3)
-- ------------------------------------------------------------
-- Origem: CSV de eventos corporativos (splits/grupamentos)
-- Colunas esperadas: ticker;data;tipo;fator;descricao
-- ------------------------------------------------------------

IF OBJECT_ID(N'dbo.stg_desdobramento', N'U') IS NOT NULL
    DROP TABLE dbo.stg_desdobramento;
GO

CREATE TABLE dbo.stg_desdobramento (
    id_staging      BIGINT          NOT NULL IDENTITY(1,1),
    ticker          VARCHAR(10)     NULL,
    dt_evento       VARCHAR(20)     NULL,
    ds_tipo         VARCHAR(30)     NULL,
    vl_fator        VARCHAR(20)     NULL,
    ds_descricao    VARCHAR(200)    NULL,
    dt_carga        DATETIME        NOT NULL DEFAULT GETDATE(),
    fl_processado   TINYINT         NOT NULL DEFAULT 0,
    ds_erro         VARCHAR(500)    NULL,
    CONSTRAINT PK_stg_desdobramento PRIMARY KEY (id_staging)
);
GO

CREATE INDEX idx_stg_desdobr_ticker        ON dbo.stg_desdobramento (ticker);
CREATE INDEX idx_stg_desdobr_processado    ON dbo.stg_desdobramento (fl_processado);
GO


-- ============================================================
-- 2. TABELA DE CONTROLE DE CARGA (ETL Metadata)
-- ============================================================

IF OBJECT_ID(N'dbo.etl_controle_carga', N'U') IS NOT NULL
    DROP TABLE dbo.etl_controle_carga;
GO

CREATE TABLE dbo.etl_controle_carga (
    id_carga            BIGINT          NOT NULL IDENTITY(1,1),
    ds_fonte            VARCHAR(100)    NOT NULL,
    ds_arquivo          VARCHAR(500)    NULL,
    ds_tabela_destino   VARCHAR(100)    NOT NULL,
    dt_inicio_carga     DATETIME        NOT NULL DEFAULT GETDATE(),
    dt_fim_carga        DATETIME        NULL,
    nr_registros_lidos  BIGINT          NULL,
    nr_registros_carga  BIGINT          NULL,
    nr_registros_erro   BIGINT          NULL DEFAULT 0,
    ds_status           VARCHAR(20)     NOT NULL DEFAULT 'EXECUTANDO',
    ds_erro             VARCHAR(MAX)    NULL,
    ds_checksum         VARCHAR(64)     NULL,
    CONSTRAINT PK_etl_controle_carga PRIMARY KEY (id_carga)
);
GO

CREATE INDEX idx_etl_ctrl_fonte     ON dbo.etl_controle_carga (ds_fonte);
CREATE INDEX idx_etl_ctrl_status    ON dbo.etl_controle_carga (ds_status);
CREATE INDEX idx_etl_ctrl_dt        ON dbo.etl_controle_carga (dt_inicio_carga);
GO


-- ============================================================
-- 3. TABELA DE LOG DE ERROS ETL
-- ============================================================

IF OBJECT_ID(N'dbo.etl_log_erros', N'U') IS NOT NULL
    DROP TABLE dbo.etl_log_erros;
GO

CREATE TABLE dbo.etl_log_erros (
    id_erro         BIGINT          NOT NULL IDENTITY(1,1),
    id_carga        BIGINT          NULL,
    ds_etapa        VARCHAR(50)     NOT NULL,
    ds_fonte        VARCHAR(100)    NULL,
    ds_procedure    VARCHAR(100)    NULL,
    ds_erro         VARCHAR(MAX)    NOT NULL,
    ds_dados        VARCHAR(MAX)    NULL,
    dt_erro         DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_etl_log_erros PRIMARY KEY (id_erro)
);
GO

CREATE INDEX idx_etl_log_carga  ON dbo.etl_log_erros (id_carga);
CREATE INDEX idx_etl_log_etapa  ON dbo.etl_log_erros (ds_etapa);
CREATE INDEX idx_etl_log_dt     ON dbo.etl_log_erros (dt_erro);
GO


-- ============================================================
-- 4. PROCEDURES DE EXTRAÇÃO
-- ============================================================


-- ------------------------------------------------------------
-- 4.1 EXTRAÇÃO: COTAÇÕES HISTÓRICAS (Kaggle/B3)
-- ------------------------------------------------------------
-- Carrega CSV de cotações no formato:
--   ticker,date,open,close,high,low,volume
--
-- O arquivo deve estar em: <base_path>\cotacoes\
-- Uso: EXEC dbo.sp_extract_cotacoes 'ibovespa_stocks.csv';
-- ------------------------------------------------------------

IF OBJECT_ID(N'dbo.sp_extract_cotacoes', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_extract_cotacoes;
GO

CREATE PROCEDURE dbo.sp_extract_cotacoes
    @p_arquivo VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_id_carga         BIGINT;
    DECLARE @v_registros_antes  BIGINT;
    DECLARE @v_registros_depois BIGINT;
    DECLARE @v_caminho_arquivo  VARCHAR(1000);
    DECLARE @v_erro_msg         VARCHAR(MAX);
    DECLARE @v_sql              NVARCHAR(2000);

    SET @v_caminho_arquivo = 'C:\mercado_financeiro\cotacoes\' + @p_arquivo;

    INSERT INTO dbo.etl_controle_carga (ds_fonte, ds_arquivo, ds_tabela_destino, ds_status)
    VALUES ('KAGGLE_COTACAO', @v_caminho_arquivo, 'stg_cotacao', 'EXECUTANDO');

    SET @v_id_carga = SCOPE_IDENTITY();

    BEGIN TRY
        SELECT @v_registros_antes = COUNT(*) FROM dbo.stg_cotacao;

        -- Limpar registros não processados de cargas anteriores (idempotência)
        DELETE FROM dbo.stg_cotacao WHERE fl_processado = 0;

        -- Tabela temporária com as colunas do CSV
        IF OBJECT_ID(N'tempdb..#tmp_cotacao_raw', N'U') IS NOT NULL
            DROP TABLE #tmp_cotacao_raw;

        CREATE TABLE #tmp_cotacao_raw (
            ticker          VARCHAR(10),
            dt_pregao       VARCHAR(20),
            vl_abertura     VARCHAR(20),
            vl_fechamento   VARCHAR(20),
            vl_maximo       VARCHAR(20),
            vl_minimo       VARCHAR(20),
            vl_volume       VARCHAR(30)
        );

        -- Carregar CSV via BULK INSERT (separador vírgula, UTF-8, pula cabeçalho)
        SET @v_sql = N'BULK INSERT #tmp_cotacao_raw
            FROM ''' + @v_caminho_arquivo + N'''
            WITH (
                FORMAT        = ''CSV'',
                FIELDTERMINATOR = '','',
                ROWTERMINATOR   = ''0x0a'',
                FIRSTROW        = 2,
                CODEPAGE        = ''65001''
            );';

        EXEC sp_executesql @v_sql;

        INSERT INTO dbo.stg_cotacao
            (ticker, dt_pregao, vl_abertura, vl_fechamento, vl_maximo, vl_minimo, vl_volume)
        SELECT
            ticker, dt_pregao, vl_abertura, vl_fechamento, vl_maximo, vl_minimo, vl_volume
        FROM #tmp_cotacao_raw;

        DROP TABLE #tmp_cotacao_raw;

        SELECT @v_registros_depois = COUNT(*) FROM dbo.stg_cotacao WHERE fl_processado = 0;

        UPDATE dbo.etl_controle_carga
        SET ds_status          = 'SUCESSO',
            dt_fim_carga       = GETDATE(),
            nr_registros_carga = @v_registros_depois
        WHERE id_carga = @v_id_carga;

        SELECT
            @v_id_carga          AS id_carga,
            'KAGGLE_COTACAO'     AS fonte,
            @v_registros_depois  AS registros_carregados,
            'SUCESSO'            AS status;

    END TRY
    BEGIN CATCH
        SET @v_erro_msg = ERROR_MESSAGE();

        IF OBJECT_ID(N'tempdb..#tmp_cotacao_raw', N'U') IS NOT NULL
            DROP TABLE #tmp_cotacao_raw;

        UPDATE dbo.etl_controle_carga
        SET ds_status    = 'ERRO',
            dt_fim_carga = GETDATE(),
            ds_erro      = @v_erro_msg
        WHERE id_carga = @v_id_carga;

        INSERT INTO dbo.etl_log_erros (id_carga, ds_etapa, ds_fonte, ds_procedure, ds_erro)
        VALUES (@v_id_carga, 'EXTRACT', 'KAGGLE_COTACAO', 'sp_extract_cotacoes', @v_erro_msg);

        THROW;
    END CATCH;
END;
GO


-- ------------------------------------------------------------
-- 4.2 EXTRAÇÃO: INDICADORES MACROECONÔMICOS (BCB)
-- ------------------------------------------------------------
-- Carrega CSVs do Banco Central no formato SGS:
--   data;valor
-- (separador ponto-e-vírgula, decimal com vírgula)
--
-- O arquivo deve estar em: <base_path>\bcb\
-- Uso: EXEC dbo.sp_extract_indicador_bcb 'SELIC', '11', 'selic_serie_11.csv';
-- ------------------------------------------------------------

IF OBJECT_ID(N'dbo.sp_extract_indicador_bcb', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_extract_indicador_bcb;
GO

CREATE PROCEDURE dbo.sp_extract_indicador_bcb
    @p_cd_indicador VARCHAR(20),
    @p_cd_serie     VARCHAR(20),
    @p_arquivo      VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_id_carga         BIGINT;
    DECLARE @v_registros        BIGINT;
    DECLARE @v_caminho_arquivo  VARCHAR(1000);
    DECLARE @v_erro_msg         VARCHAR(MAX);
    DECLARE @v_sql              NVARCHAR(2000);

    SET @v_caminho_arquivo = 'C:\mercado_financeiro\bcb\' + @p_arquivo;

    INSERT INTO dbo.etl_controle_carga (ds_fonte, ds_arquivo, ds_tabela_destino, ds_status)
    VALUES (CONCAT('BCB_', @p_cd_indicador), @v_caminho_arquivo, 'stg_indicadores_macro', 'EXECUTANDO');

    SET @v_id_carga = SCOPE_IDENTITY();

    BEGIN TRY
        -- Limpar dados não processados deste indicador (idempotência)
        DELETE FROM dbo.stg_indicadores_macro
        WHERE cd_indicador = @p_cd_indicador AND fl_processado = 0;

        IF OBJECT_ID(N'tempdb..#tmp_bcb_raw', N'U') IS NOT NULL
            DROP TABLE #tmp_bcb_raw;

        -- O CSV do BCB usa ponto-e-vírgula como separador
        CREATE TABLE #tmp_bcb_raw (
            dt_referencia   VARCHAR(20),
            vl_indicador    VARCHAR(30)
        );

        SET @v_sql = N'BULK INSERT #tmp_bcb_raw
            FROM ''' + @v_caminho_arquivo + N'''
            WITH (
                FORMAT          = ''CSV'',
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR   = ''0x0a'',
                FIRSTROW        = 2,
                CODEPAGE        = ''65001''
            );';

        EXEC sp_executesql @v_sql;

        -- Inserir na staging enriquecendo com código do indicador
        INSERT INTO dbo.stg_indicadores_macro (cd_indicador, cd_serie_bcb, dt_referencia, vl_indicador)
        SELECT
            @p_cd_indicador,
            @p_cd_serie,
            dt_referencia,
            vl_indicador
        FROM #tmp_bcb_raw
        WHERE dt_referencia IS NOT NULL
          AND TRIM(dt_referencia) <> '';

        SET @v_registros = @@ROWCOUNT;

        DROP TABLE #tmp_bcb_raw;

        UPDATE dbo.etl_controle_carga
        SET ds_status          = 'SUCESSO',
            dt_fim_carga       = GETDATE(),
            nr_registros_carga = @v_registros
        WHERE id_carga = @v_id_carga;

        SELECT
            @v_id_carga                   AS id_carga,
            CONCAT('BCB_', @p_cd_indicador) AS fonte,
            @v_registros                  AS registros_carregados,
            'SUCESSO'                     AS status;

    END TRY
    BEGIN CATCH
        SET @v_erro_msg = ERROR_MESSAGE();

        IF OBJECT_ID(N'tempdb..#tmp_bcb_raw', N'U') IS NOT NULL
            DROP TABLE #tmp_bcb_raw;

        UPDATE dbo.etl_controle_carga
        SET ds_status    = 'ERRO',
            dt_fim_carga = GETDATE(),
            ds_erro      = @v_erro_msg
        WHERE id_carga = @v_id_carga;

        INSERT INTO dbo.etl_log_erros (id_carga, ds_etapa, ds_fonte, ds_procedure, ds_erro)
        VALUES (@v_id_carga, 'EXTRACT', CONCAT('BCB_', @p_cd_indicador), 'sp_extract_indicador_bcb', @v_erro_msg);

        THROW;
    END CATCH;
END;
GO


-- ------------------------------------------------------------
-- 4.3 EXTRAÇÃO: DEMONSTRAÇÕES FINANCEIRAS (CVM DFP)
-- ------------------------------------------------------------
-- Carrega CSVs de demonstrações financeiras da CVM.
-- Formato típico (separador ;, encoding Latin1/Windows-1252):
--   CNPJ_CIA;DT_REFER;VERSAO;DENOM_CIA;CD_CVM;...;CD_CONTA;DS_CONTA;VL_CONTA;...
--
-- O arquivo deve estar em: <base_path>\cvm\dfp\
-- Uso: EXEC dbo.sp_extract_dem_financeira 'dfp_cia_aberta_DRE_con_2023.csv', 'DRE';
-- ------------------------------------------------------------

IF OBJECT_ID(N'dbo.sp_extract_dem_financeira', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_extract_dem_financeira;
GO

CREATE PROCEDURE dbo.sp_extract_dem_financeira
    @p_arquivo      VARCHAR(500),
    @p_tipo_dem     VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_id_carga         BIGINT;
    DECLARE @v_registros        BIGINT;
    DECLARE @v_caminho_arquivo  VARCHAR(1000);
    DECLARE @v_erro_msg         VARCHAR(MAX);
    DECLARE @v_sql              NVARCHAR(2000);

    SET @v_caminho_arquivo = 'C:\mercado_financeiro\cvm\dfp\' + @p_arquivo;

    INSERT INTO dbo.etl_controle_carga (ds_fonte, ds_arquivo, ds_tabela_destino, ds_status)
    VALUES (CONCAT('CVM_DFP_', @p_tipo_dem), @v_caminho_arquivo, 'stg_dem_financeira', 'EXECUTANDO');

    SET @v_id_carga = SCOPE_IDENTITY();

    BEGIN TRY
        IF OBJECT_ID(N'tempdb..#tmp_cvm_dfp_raw', N'U') IS NOT NULL
            DROP TABLE #tmp_cvm_dfp_raw;

        -- Tabela temporária reflete a estrutura completa do CSV da CVM
        -- CSV da CVM usa ponto-e-vírgula como separador, encoding Windows-1252
        CREATE TABLE #tmp_cvm_dfp_raw (
            cnpj_cia        VARCHAR(20),
            dt_refer        VARCHAR(20),
            versao          VARCHAR(10),
            denom_cia       VARCHAR(200),
            cd_cvm          VARCHAR(20),
            grupo_dfp       VARCHAR(100),
            moeda           VARCHAR(10),
            escala_moeda    VARCHAR(20),
            ordem_exerc     VARCHAR(20),
            dt_ini_exerc    VARCHAR(20),
            dt_fim_exerc    VARCHAR(20),
            cd_conta        VARCHAR(50),
            ds_conta        VARCHAR(200),
            vl_conta        VARCHAR(30),
            st_conta_fixa   VARCHAR(5)
        );

        SET @v_sql = N'BULK INSERT #tmp_cvm_dfp_raw
            FROM ''' + @v_caminho_arquivo + N'''
            WITH (
                FORMAT          = ''CSV'',
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR   = ''0x0a'',
                FIRSTROW        = 2,
                CODEPAGE        = ''1252''
            );';

        EXEC sp_executesql @v_sql;

        -- Inserir apenas as colunas relevantes; filtrar exercício atual para evitar duplicatas
        INSERT INTO dbo.stg_dem_financeira
            (cd_cvm, ds_conta, cd_conta, vl_conta, dt_referencia, ds_tipo_dem, nr_versao)
        SELECT
            cd_cvm,
            ds_conta,
            cd_conta,
            vl_conta,
            dt_refer,
            @p_tipo_dem,
            versao
        FROM #tmp_cvm_dfp_raw
        WHERE cd_cvm IS NOT NULL
          AND TRIM(cd_cvm) <> ''
          AND ordem_exerc = N'ÚLTIMO';

        SET @v_registros = @@ROWCOUNT;

        DROP TABLE #tmp_cvm_dfp_raw;

        UPDATE dbo.etl_controle_carga
        SET ds_status          = 'SUCESSO',
            dt_fim_carga       = GETDATE(),
            nr_registros_carga = @v_registros
        WHERE id_carga = @v_id_carga;

        SELECT
            @v_id_carga                     AS id_carga,
            CONCAT('CVM_DFP_', @p_tipo_dem) AS fonte,
            @v_registros                    AS registros_carregados,
            'SUCESSO'                       AS status;

    END TRY
    BEGIN CATCH
        SET @v_erro_msg = ERROR_MESSAGE();

        IF OBJECT_ID(N'tempdb..#tmp_cvm_dfp_raw', N'U') IS NOT NULL
            DROP TABLE #tmp_cvm_dfp_raw;

        UPDATE dbo.etl_controle_carga
        SET ds_status    = 'ERRO',
            dt_fim_carga = GETDATE(),
            ds_erro      = @v_erro_msg
        WHERE id_carga = @v_id_carga;

        INSERT INTO dbo.etl_log_erros (id_carga, ds_etapa, ds_fonte, ds_procedure, ds_erro)
        VALUES (@v_id_carga, 'EXTRACT', CONCAT('CVM_DFP_', @p_tipo_dem), 'sp_extract_dem_financeira', @v_erro_msg);

        THROW;
    END CATCH;
END;
GO


-- ------------------------------------------------------------
-- 4.4 EXTRAÇÃO: CADASTRO DE EMPRESAS (CVM)
-- ------------------------------------------------------------
-- Carrega CSV do cadastro de companhias abertas da CVM.
-- Formato (separador ;, encoding Windows-1252):
--   CNPJ_CIA;DT_REG;DT_CONST;DT_CANCEL;MOTIVO_CANCEL;SIT;...
--   ...;CD_CVM;SETOR_ATIV;...;DENOM_SOCIAL;DENOM_COMERC;...
--
-- O arquivo deve estar em: <base_path>\cvm\cad\
-- Uso: EXEC dbo.sp_extract_cadastro_empresa 'cad_cia_aberta.csv';
-- ------------------------------------------------------------

IF OBJECT_ID(N'dbo.sp_extract_cadastro_empresa', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_extract_cadastro_empresa;
GO

CREATE PROCEDURE dbo.sp_extract_cadastro_empresa
    @p_arquivo VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_id_carga         BIGINT;
    DECLARE @v_registros        BIGINT;
    DECLARE @v_caminho_arquivo  VARCHAR(1000);
    DECLARE @v_erro_msg         VARCHAR(MAX);
    DECLARE @v_sql              NVARCHAR(2000);

    SET @v_caminho_arquivo = 'C:\mercado_financeiro\cvm\cad\' + @p_arquivo;

    INSERT INTO dbo.etl_controle_carga (ds_fonte, ds_arquivo, ds_tabela_destino, ds_status)
    VALUES ('CVM_CADASTRO', @v_caminho_arquivo, 'stg_cadastro_empresa', 'EXECUTANDO');

    SET @v_id_carga = SCOPE_IDENTITY();

    BEGIN TRY
        -- Limpar dados anteriores não processados (idempotência)
        DELETE FROM dbo.stg_cadastro_empresa WHERE fl_processado = 0;

        IF OBJECT_ID(N'tempdb..#tmp_cvm_cad_raw', N'U') IS NOT NULL
            DROP TABLE #tmp_cvm_cad_raw;

        -- Tabela temporária reflete a estrutura completa do CSV de cadastro da CVM
        CREATE TABLE #tmp_cvm_cad_raw (
            cnpj_cia        VARCHAR(20),
            dt_reg          VARCHAR(20),
            dt_const        VARCHAR(20),
            dt_cancel       VARCHAR(20),
            motivo_cancel   VARCHAR(100),
            sit             VARCHAR(50),
            dt_ini_sit      VARCHAR(20),
            cd_cvm          VARCHAR(20),
            setor_ativ      VARCHAR(200),
            tp_merc         VARCHAR(50),
            categ_reg       VARCHAR(50),
            dt_ini_categ    VARCHAR(20),
            sit_emissor     VARCHAR(50),
            dt_ini_sit_em   VARCHAR(20),
            controle_acion  VARCHAR(100),
            tp_ender        VARCHAR(50),
            logradouro      VARCHAR(200),
            complemento     VARCHAR(200),
            bairro          VARCHAR(100),
            municipio       VARCHAR(100),
            uf              VARCHAR(5),
            pais            VARCHAR(50),
            cep             VARCHAR(10),
            ddd_tel         VARCHAR(5),
            tel             VARCHAR(20),
            ddd_fax         VARCHAR(5),
            fax             VARCHAR(20),
            email           VARCHAR(200),
            tp_resp         VARCHAR(50),
            resp            VARCHAR(200),
            dt_ini_resp     VARCHAR(20),
            logr_resp       VARCHAR(200),
            compl_resp      VARCHAR(200),
            bairro_resp     VARCHAR(100),
            mun_resp        VARCHAR(100),
            uf_resp         VARCHAR(5),
            pais_resp       VARCHAR(50),
            cep_resp        VARCHAR(10),
            ddd_tel_resp    VARCHAR(5),
            tel_resp        VARCHAR(20),
            ddd_fax_resp    VARCHAR(5),
            fax_resp        VARCHAR(20),
            email_resp      VARCHAR(200),
            denom_social    VARCHAR(200),
            denom_comerc    VARCHAR(100)
        );

        SET @v_sql = N'BULK INSERT #tmp_cvm_cad_raw
            FROM ''' + @v_caminho_arquivo + N'''
            WITH (
                FORMAT          = ''CSV'',
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR   = ''0x0a'',
                FIRSTROW        = 2,
                CODEPAGE        = ''1252''
            );';

        EXEC sp_executesql @v_sql;

        -- Extrair apenas colunas relevantes para staging
        INSERT INTO dbo.stg_cadastro_empresa
            (cd_cvm, nr_cnpj, ds_razao_social, ds_nome_pregao,
             ds_setor_atividade, ds_situacao, dt_registro, dt_constituicao)
        SELECT
            cd_cvm,
            cnpj_cia,
            denom_social,
            denom_comerc,
            setor_ativ,
            sit,
            dt_reg,
            dt_const
        FROM #tmp_cvm_cad_raw
        WHERE cd_cvm IS NOT NULL
          AND TRIM(cd_cvm) <> '';

        SET @v_registros = @@ROWCOUNT;

        DROP TABLE #tmp_cvm_cad_raw;

        UPDATE dbo.etl_controle_carga
        SET ds_status          = 'SUCESSO',
            dt_fim_carga       = GETDATE(),
            nr_registros_carga = @v_registros
        WHERE id_carga = @v_id_carga;

        SELECT
            @v_id_carga     AS id_carga,
            'CVM_CADASTRO'  AS fonte,
            @v_registros    AS registros_carregados,
            'SUCESSO'       AS status;

    END TRY
    BEGIN CATCH
        SET @v_erro_msg = ERROR_MESSAGE();

        IF OBJECT_ID(N'tempdb..#tmp_cvm_cad_raw', N'U') IS NOT NULL
            DROP TABLE #tmp_cvm_cad_raw;

        UPDATE dbo.etl_controle_carga
        SET ds_status    = 'ERRO',
            dt_fim_carga = GETDATE(),
            ds_erro      = @v_erro_msg
        WHERE id_carga = @v_id_carga;

        INSERT INTO dbo.etl_log_erros (id_carga, ds_etapa, ds_fonte, ds_procedure, ds_erro)
        VALUES (@v_id_carga, 'EXTRACT', 'CVM_CADASTRO', 'sp_extract_cadastro_empresa', @v_erro_msg);

        THROW;
    END CATCH;
END;
GO


-- ------------------------------------------------------------
-- 4.5 EXTRAÇÃO: DIVIDENDOS (CVM/B3)
-- ------------------------------------------------------------
-- Carrega CSV de proventos no formato:
--   ticker;cd_cvm;dt_aprovacao;valor;tipo;dt_ex;dt_pagamento
--
-- Uso: EXEC dbo.sp_extract_dividendos 'proventos_2023.csv';
-- ------------------------------------------------------------

IF OBJECT_ID(N'dbo.sp_extract_dividendos', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_extract_dividendos;
GO

CREATE PROCEDURE dbo.sp_extract_dividendos
    @p_arquivo VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_id_carga         BIGINT;
    DECLARE @v_registros        BIGINT;
    DECLARE @v_caminho_arquivo  VARCHAR(1000);
    DECLARE @v_erro_msg         VARCHAR(MAX);
    DECLARE @v_sql              NVARCHAR(2000);

    SET @v_caminho_arquivo = 'C:\mercado_financeiro\eventos\' + @p_arquivo;

    INSERT INTO dbo.etl_controle_carga (ds_fonte, ds_arquivo, ds_tabela_destino, ds_status)
    VALUES ('B3_DIVIDENDOS', @v_caminho_arquivo, 'stg_dividendos', 'EXECUTANDO');

    SET @v_id_carga = SCOPE_IDENTITY();

    BEGIN TRY
        DELETE FROM dbo.stg_dividendos WHERE fl_processado = 0;

        IF OBJECT_ID(N'tempdb..#tmp_dividendos_raw', N'U') IS NOT NULL
            DROP TABLE #tmp_dividendos_raw;

        CREATE TABLE #tmp_dividendos_raw (
            ticker          VARCHAR(10),
            cd_cvm          VARCHAR(20),
            dt_aprovacao    VARCHAR(20),
            vl_provento     VARCHAR(30),
            ds_tipo         VARCHAR(50),
            dt_ex           VARCHAR(20),
            dt_pagamento    VARCHAR(20)
        );

        SET @v_sql = N'BULK INSERT #tmp_dividendos_raw
            FROM ''' + @v_caminho_arquivo + N'''
            WITH (
                FORMAT          = ''CSV'',
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR   = ''0x0a'',
                FIRSTROW        = 2,
                CODEPAGE        = ''65001''
            );';

        EXEC sp_executesql @v_sql;

        INSERT INTO dbo.stg_dividendos
            (ticker, cd_cvm, dt_aprovacao, vl_provento, ds_tipo, dt_ex, dt_pagamento)
        SELECT
            ticker, cd_cvm, dt_aprovacao, vl_provento, ds_tipo, dt_ex, dt_pagamento
        FROM #tmp_dividendos_raw;

        SET @v_registros = @@ROWCOUNT;

        DROP TABLE #tmp_dividendos_raw;

        UPDATE dbo.etl_controle_carga
        SET ds_status          = 'SUCESSO',
            dt_fim_carga       = GETDATE(),
            nr_registros_carga = @v_registros
        WHERE id_carga = @v_id_carga;

        SELECT
            @v_id_carga     AS id_carga,
            'B3_DIVIDENDOS' AS fonte,
            @v_registros    AS registros_carregados,
            'SUCESSO'       AS status;

    END TRY
    BEGIN CATCH
        SET @v_erro_msg = ERROR_MESSAGE();

        IF OBJECT_ID(N'tempdb..#tmp_dividendos_raw', N'U') IS NOT NULL
            DROP TABLE #tmp_dividendos_raw;

        UPDATE dbo.etl_controle_carga
        SET ds_status    = 'ERRO',
            dt_fim_carga = GETDATE(),
            ds_erro      = @v_erro_msg
        WHERE id_carga = @v_id_carga;

        INSERT INTO dbo.etl_log_erros (id_carga, ds_etapa, ds_fonte, ds_procedure, ds_erro)
        VALUES (@v_id_carga, 'EXTRACT', 'B3_DIVIDENDOS', 'sp_extract_dividendos', @v_erro_msg);

        THROW;
    END CATCH;
END;
GO


-- ------------------------------------------------------------
-- 4.6 EXTRAÇÃO: DESDOBRAMENTOS (B3)
-- ------------------------------------------------------------
-- Carrega CSV de splits/grupamentos no formato:
--   ticker;data;tipo;fator;descricao
--
-- Uso: EXEC dbo.sp_extract_desdobramentos 'desdobramentos_2023.csv';
-- ------------------------------------------------------------

IF OBJECT_ID(N'dbo.sp_extract_desdobramentos', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_extract_desdobramentos;
GO

CREATE PROCEDURE dbo.sp_extract_desdobramentos
    @p_arquivo VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_id_carga         BIGINT;
    DECLARE @v_registros        BIGINT;
    DECLARE @v_caminho_arquivo  VARCHAR(1000);
    DECLARE @v_erro_msg         VARCHAR(MAX);
    DECLARE @v_sql              NVARCHAR(2000);

    SET @v_caminho_arquivo = 'C:\mercado_financeiro\eventos\' + @p_arquivo;

    INSERT INTO dbo.etl_controle_carga (ds_fonte, ds_arquivo, ds_tabela_destino, ds_status)
    VALUES ('B3_DESDOBRAMENTO', @v_caminho_arquivo, 'stg_desdobramento', 'EXECUTANDO');

    SET @v_id_carga = SCOPE_IDENTITY();

    BEGIN TRY
        DELETE FROM dbo.stg_desdobramento WHERE fl_processado = 0;

        IF OBJECT_ID(N'tempdb..#tmp_desdobramento_raw', N'U') IS NOT NULL
            DROP TABLE #tmp_desdobramento_raw;

        CREATE TABLE #tmp_desdobramento_raw (
            ticker          VARCHAR(10),
            dt_evento       VARCHAR(20),
            ds_tipo         VARCHAR(30),
            vl_fator        VARCHAR(20),
            ds_descricao    VARCHAR(200)
        );

        SET @v_sql = N'BULK INSERT #tmp_desdobramento_raw
            FROM ''' + @v_caminho_arquivo + N'''
            WITH (
                FORMAT          = ''CSV'',
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR   = ''0x0a'',
                FIRSTROW        = 2,
                CODEPAGE        = ''65001''
            );';

        EXEC sp_executesql @v_sql;

        INSERT INTO dbo.stg_desdobramento
            (ticker, dt_evento, ds_tipo, vl_fator, ds_descricao)
        SELECT
            ticker, dt_evento, ds_tipo, vl_fator, ds_descricao
        FROM #tmp_desdobramento_raw;

        SET @v_registros = @@ROWCOUNT;

        DROP TABLE #tmp_desdobramento_raw;

        UPDATE dbo.etl_controle_carga
        SET ds_status          = 'SUCESSO',
            dt_fim_carga       = GETDATE(),
            nr_registros_carga = @v_registros
        WHERE id_carga = @v_id_carga;

        SELECT
            @v_id_carga         AS id_carga,
            'B3_DESDOBRAMENTO'  AS fonte,
            @v_registros        AS registros_carregados,
            'SUCESSO'           AS status;

    END TRY
    BEGIN CATCH
        SET @v_erro_msg = ERROR_MESSAGE();

        IF OBJECT_ID(N'tempdb..#tmp_desdobramento_raw', N'U') IS NOT NULL
            DROP TABLE #tmp_desdobramento_raw;

        UPDATE dbo.etl_controle_carga
        SET ds_status    = 'ERRO',
            dt_fim_carga = GETDATE(),
            ds_erro      = @v_erro_msg
        WHERE id_carga = @v_id_carga;

        INSERT INTO dbo.etl_log_erros (id_carga, ds_etapa, ds_fonte, ds_procedure, ds_erro)
        VALUES (@v_id_carga, 'EXTRACT', 'B3_DESDOBRAMENTO', 'sp_extract_desdobramentos', @v_erro_msg);

        THROW;
    END CATCH;
END;
GO


-- ============================================================
-- 5. PROCEDURE ORQUESTRADORA — EXTRAÇÃO COMPLETA
-- ============================================================
-- Executa todas as extrações na ordem correta.
-- Pode ser chamada por um scheduler (SQL Agent, Airflow, etc.)
--
-- Uso: EXEC dbo.sp_extract_full;
-- ============================================================

IF OBJECT_ID(N'dbo.sp_extract_full', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_extract_full;
GO

CREATE PROCEDURE dbo.sp_extract_full
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_erro_msg VARCHAR(MAX);
    DECLARE @v_etapa    VARCHAR(100) = '';

    BEGIN TRY

        PRINT '=============================================';
        PRINT 'INÍCIO DA EXTRAÇÃO COMPLETA';
        PRINT CONVERT(VARCHAR, GETDATE(), 120);
        PRINT '=============================================';

        -- ---------------------------------------------------------
        -- ETAPA 1: Cotações históricas (Kaggle/B3)
        -- ---------------------------------------------------------
        SET @v_etapa = 'COTACOES';
        PRINT CONCAT('>> Extraindo: ', @v_etapa);
        EXEC dbo.sp_extract_cotacoes 'ibovespa_stocks.csv';

        -- ---------------------------------------------------------
        -- ETAPA 2: Indicadores Macroeconômicos (BCB)
        -- ---------------------------------------------------------
        SET @v_etapa = 'BCB_SELIC';
        PRINT CONCAT('>> Extraindo: ', @v_etapa);
        EXEC dbo.sp_extract_indicador_bcb 'SELIC', '11', 'selic_serie_11.csv';

        SET @v_etapa = 'BCB_IPCA';
        PRINT CONCAT('>> Extraindo: ', @v_etapa);
        EXEC dbo.sp_extract_indicador_bcb 'IPCA', '433', 'ipca_serie_433.csv';

        SET @v_etapa = 'BCB_CAMBIO';
        PRINT CONCAT('>> Extraindo: ', @v_etapa);
        EXEC dbo.sp_extract_indicador_bcb 'CAMBIO', '1', 'cambio_serie_1.csv';

        SET @v_etapa = 'BCB_CDI';
        PRINT CONCAT('>> Extraindo: ', @v_etapa);
        EXEC dbo.sp_extract_indicador_bcb 'CDI', '12', 'cdi_serie_12.csv';

        -- ---------------------------------------------------------
        -- ETAPA 3: Cadastro de Empresas (CVM)
        -- ---------------------------------------------------------
        SET @v_etapa = 'CVM_CADASTRO';
        PRINT CONCAT('>> Extraindo: ', @v_etapa);
        EXEC dbo.sp_extract_cadastro_empresa 'cad_cia_aberta.csv';

        -- ---------------------------------------------------------
        -- ETAPA 4: Demonstrações Financeiras (CVM DFP)
        -- ---------------------------------------------------------
        SET @v_etapa = 'CVM_DFP_DRE';
        PRINT CONCAT('>> Extraindo: ', @v_etapa);
        EXEC dbo.sp_extract_dem_financeira 'dfp_cia_aberta_DRE_con_2024.csv', 'DRE';

        SET @v_etapa = 'CVM_DFP_BPA';
        PRINT CONCAT('>> Extraindo: ', @v_etapa);
        EXEC dbo.sp_extract_dem_financeira 'dfp_cia_aberta_BPA_con_2024.csv', 'BPA';

        SET @v_etapa = 'CVM_DFP_BPP';
        PRINT CONCAT('>> Extraindo: ', @v_etapa);
        EXEC dbo.sp_extract_dem_financeira 'dfp_cia_aberta_BPP_con_2024.csv', 'BPP';

        -- ---------------------------------------------------------
        -- ETAPA 5: Dividendos
        -- ---------------------------------------------------------
        SET @v_etapa = 'DIVIDENDOS';
        PRINT CONCAT('>> Extraindo: ', @v_etapa);
        EXEC dbo.sp_extract_dividendos 'proventos_2024.csv';

        -- ---------------------------------------------------------
        -- ETAPA 6: Desdobramentos
        -- ---------------------------------------------------------
        SET @v_etapa = 'DESDOBRAMENTOS';
        PRINT CONCAT('>> Extraindo: ', @v_etapa);
        EXEC dbo.sp_extract_desdobramentos 'desdobramentos_2024.csv';

        PRINT '=============================================';
        PRINT 'EXTRAÇÃO COMPLETA FINALIZADA';
        PRINT CONVERT(VARCHAR, GETDATE(), 120);
        PRINT '=============================================';

    END TRY
    BEGIN CATCH
        SET @v_erro_msg = ERROR_MESSAGE();

        INSERT INTO dbo.etl_log_erros (ds_etapa, ds_fonte, ds_procedure, ds_erro, ds_dados)
        VALUES ('EXTRACT', 'ORQUESTRADOR', 'sp_extract_full',
                @v_erro_msg, CONCAT('Falha na etapa: ', @v_etapa));

        -- Registra o erro mas não relança para não bloquear cargas seguintes
        SELECT CONCAT('ERRO na etapa: ', @v_etapa, ' — ', @v_erro_msg) AS resultado;
    END CATCH;
END;
GO


-- ============================================================
-- 6. VIEWS DE MONITORAMENTO DA EXTRAÇÃO
-- ============================================================

-- Vista: resumo das últimas cargas por fonte
IF OBJECT_ID(N'dbo.vw_etl_resumo_cargas', N'V') IS NOT NULL
    DROP VIEW dbo.vw_etl_resumo_cargas;
GO

CREATE VIEW dbo.vw_etl_resumo_cargas AS
SELECT
    ds_fonte,
    ds_tabela_destino,
    ds_status,
    nr_registros_carga,
    nr_registros_erro,
    dt_inicio_carga,
    dt_fim_carga,
    DATEDIFF(SECOND, dt_inicio_carga, dt_fim_carga) AS duracao_segundos
FROM dbo.etl_controle_carga;
GO


-- Vista: contagem de registros pendentes por staging
IF OBJECT_ID(N'dbo.vw_etl_staging_pendentes', N'V') IS NOT NULL
    DROP VIEW dbo.vw_etl_staging_pendentes;
GO

CREATE VIEW dbo.vw_etl_staging_pendentes AS
SELECT
    'stg_cotacao'           AS tabela,
    COUNT(*)                AS total,
    SUM(CASE WHEN fl_processado = 0 THEN 1 ELSE 0 END) AS pendentes,
    SUM(CASE WHEN fl_processado = 1 THEN 1 ELSE 0 END) AS processados,
    SUM(CASE WHEN fl_processado = 2 THEN 1 ELSE 0 END) AS com_erro
FROM dbo.stg_cotacao
UNION ALL
SELECT
    'stg_indicadores_macro',
    COUNT(*),
    SUM(CASE WHEN fl_processado = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN fl_processado = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN fl_processado = 2 THEN 1 ELSE 0 END)
FROM dbo.stg_indicadores_macro
UNION ALL
SELECT
    'stg_dem_financeira',
    COUNT(*),
    SUM(CASE WHEN fl_processado = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN fl_processado = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN fl_processado = 2 THEN 1 ELSE 0 END)
FROM dbo.stg_dem_financeira
UNION ALL
SELECT
    'stg_cadastro_empresa',
    COUNT(*),
    SUM(CASE WHEN fl_processado = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN fl_processado = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN fl_processado = 2 THEN 1 ELSE 0 END)
FROM dbo.stg_cadastro_empresa
UNION ALL
SELECT
    'stg_dividendos',
    COUNT(*),
    SUM(CASE WHEN fl_processado = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN fl_processado = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN fl_processado = 2 THEN 1 ELSE 0 END)
FROM dbo.stg_dividendos
UNION ALL
SELECT
    'stg_desdobramento',
    COUNT(*),
    SUM(CASE WHEN fl_processado = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN fl_processado = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN fl_processado = 2 THEN 1 ELSE 0 END)
FROM dbo.stg_desdobramento;
GO


-- Vista: erros recentes do ETL (últimos 100)
IF OBJECT_ID(N'dbo.vw_etl_erros_recentes', N'V') IS NOT NULL
    DROP VIEW dbo.vw_etl_erros_recentes;
GO

CREATE VIEW dbo.vw_etl_erros_recentes AS
SELECT TOP 100
    e.id_erro,
    e.ds_etapa,
    e.ds_fonte,
    e.ds_procedure,
    e.ds_erro,
    e.dt_erro,
    c.ds_arquivo
FROM dbo.etl_log_erros e
LEFT JOIN dbo.etl_controle_carga c ON e.id_carga = c.id_carga
ORDER BY e.dt_erro DESC;
GO


-- ============================================================
-- 7. SCRIPT DE DOWNLOAD DE DADOS (Referência)
-- ============================================================
-- Este bloco é comentado e serve como referência para o
-- script de download que deve ser executado ANTES da carga SQL.
-- Recomenda-se usar Python, curl ou PowerShell para baixar os CSVs.
-- ============================================================

/*
-- ============================================================
-- download_dados.ps1 (executar antes do SQL — PowerShell)
-- ============================================================

$BASE_DIR = "C:\mercado_financeiro"

# Criar estrutura de diretórios
New-Item -ItemType Directory -Force -Path "$BASE_DIR\cotacoes"
New-Item -ItemType Directory -Force -Path "$BASE_DIR\bcb"
New-Item -ItemType Directory -Force -Path "$BASE_DIR\cvm\dfp"
New-Item -ItemType Directory -Force -Path "$BASE_DIR\cvm\cad"
New-Item -ItemType Directory -Force -Path "$BASE_DIR\eventos"

# --- BCB: Indicadores Macroeconômicos ---
Write-Host "Baixando Selic (série 11)..."
Invoke-WebRequest -Uri "https://api.bcb.gov.br/dados/serie/bcdata.sgs.11/dados?formato=csv" `
    -OutFile "$BASE_DIR\bcb\selic_serie_11.csv"

Write-Host "Baixando IPCA (série 433)..."
Invoke-WebRequest -Uri "https://api.bcb.gov.br/dados/serie/bcdata.sgs.433/dados?formato=csv" `
    -OutFile "$BASE_DIR\bcb\ipca_serie_433.csv"

Write-Host "Baixando Câmbio USD/BRL (série 1)..."
Invoke-WebRequest -Uri "https://api.bcb.gov.br/dados/serie/bcdata.sgs.1/dados?formato=csv" `
    -OutFile "$BASE_DIR\bcb\cambio_serie_1.csv"

Write-Host "Baixando CDI (série 12)..."
Invoke-WebRequest -Uri "https://api.bcb.gov.br/dados/serie/bcdata.sgs.12/dados?formato=csv" `
    -OutFile "$BASE_DIR\bcb\cdi_serie_12.csv"

# --- CVM: Cadastro de Empresas ---
Write-Host "Baixando cadastro de companhias abertas..."
Invoke-WebRequest -Uri "https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/cad_cia_aberta.csv" `
    -OutFile "$BASE_DIR\cvm\cad\cad_cia_aberta.csv"

# --- CVM: Demonstrações Financeiras (DFP) ---
$YEAR = 2024
Write-Host "Baixando DFP DRE consolidado $YEAR..."
Invoke-WebRequest -Uri "https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/dfp_cia_aberta_DRE_con_${YEAR}.csv" `
    -OutFile "$BASE_DIR\cvm\dfp\dfp_cia_aberta_DRE_con_${YEAR}.csv"

Write-Host "Baixando DFP BPA consolidado $YEAR..."
Invoke-WebRequest -Uri "https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/dfp_cia_aberta_BPA_con_${YEAR}.csv" `
    -OutFile "$BASE_DIR\cvm\dfp\dfp_cia_aberta_BPA_con_${YEAR}.csv"

Write-Host "Baixando DFP BPP consolidado $YEAR..."
Invoke-WebRequest -Uri "https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/dfp_cia_aberta_BPP_con_${YEAR}.csv" `
    -OutFile "$BASE_DIR\cvm\dfp\dfp_cia_aberta_BPP_con_${YEAR}.csv"

# --- Kaggle: Cotações B3 ---
# Requer kaggle CLI configurado (pip install kaggle)
Write-Host "Baixando cotações do Kaggle..."
kaggle datasets download -d felsal/ibovespa-stocks -p "$BASE_DIR\cotacoes\" --unzip

Write-Host "Download concluído!"
*/


-- ============================================================
-- FIM DO SCRIPT DE EXTRAÇÃO
-- ============================================================
-- Próximo passo: executar o script de TRANSFORM (02_transform.sql)
-- que irá ler os dados das tabelas stg_* e popular as tabelas
-- de dimensão e fato do modelo dimensional.
-- ============================================================
