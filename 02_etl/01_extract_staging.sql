-- ============================================================
-- PROJETO: BANCO DE DADOS MERCADO FINANCEIRO
-- FASE: ETL — EXTRACT (Extração e Carga em Staging)
-- Compatibilidade: MySQL 8.0+
-- Autor: ETL Pipeline — Engenharia de Dados
-- Data: 2026-03-11
-- ============================================================
--
-- OBJETIVO:
--   Este script implementa a camada EXTRACT do pipeline ETL.
--   Ele cria as tabelas de staging no MySQL, carrega os dados
--   brutos das fontes externas (CSV/API) e prepara tudo para
--   a fase TRANSFORM.
--
-- FONTES DE DADOS:
--   1. Kaggle/B3 — Cotações históricas (CSV)
--   2. BCB (Banco Central) — Selic, IPCA, Câmbio, CDI (CSV/API)
--   3. CVM — Demonstrações Financeiras e Cadastro de Empresas (CSV)
--
-- PRÉ-REQUISITOS:
--   - MySQL 8.0+ com LOCAL INFILE habilitado:
--       SET GLOBAL local_infile = 1;
--   - Arquivos CSV baixados nas pastas definidas em @base_path
--   - Banco de dados MercadoFinanceiro já criado
--
-- CONVENÇÕES:
--   - Tabelas de staging usam prefixo stg_
--   - Todas as colunas são VARCHAR para preservar dados brutos
--   - Coluna dt_carga registra o momento da ingestão
--   - Coluna id_staging é auto-incremental (surrogate key)
-- ============================================================


-- ============================================================
-- 0. CONFIGURAÇÃO INICIAL
-- ============================================================

CREATE DATABASE IF NOT EXISTS MercadoFinanceiro
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE MercadoFinanceiro;

-- Variável com o caminho base dos arquivos CSV.
-- Ajustar conforme o ambiente de execução.
SET @base_path = '/var/lib/mysql-files/mercado_financeiro/';

-- Habilitar carregamento local (requer permissão no servidor)
-- SET GLOBAL local_infile = 1;


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
-- URL: https://www.kaggle.com/datasets/felsal/ibovespa-stocks
-- ------------------------------------------------------------

DROP TABLE IF EXISTS stg_cotacao;

CREATE TABLE stg_cotacao (
    id_staging      BIGINT          NOT NULL AUTO_INCREMENT,
    ticker          VARCHAR(10)     NULL COMMENT 'Código do papel (ex: PETR4, VALE3)',
    dt_pregao       VARCHAR(20)     NULL COMMENT 'Data do pregão (formato bruto do CSV)',
    vl_abertura     VARCHAR(20)     NULL COMMENT 'Preço de abertura (texto bruto)',
    vl_fechamento   VARCHAR(20)     NULL COMMENT 'Preço de fechamento (texto bruto)',
    vl_maximo       VARCHAR(20)     NULL COMMENT 'Preço máximo do dia (texto bruto)',
    vl_minimo       VARCHAR(20)     NULL COMMENT 'Preço mínimo do dia (texto bruto)',
    vl_volume       VARCHAR(30)     NULL COMMENT 'Volume negociado (texto bruto)',
    dt_carga        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp da ingestão',
    fl_processado   TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '0=pendente, 1=processado, 2=erro',
    ds_erro         VARCHAR(500)    NULL COMMENT 'Mensagem de erro se fl_processado=2',
    PRIMARY KEY (id_staging),
    INDEX idx_stg_cotacao_ticker (ticker),
    INDEX idx_stg_cotacao_dt_pregao (dt_pregao),
    INDEX idx_stg_cotacao_processado (fl_processado)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Staging: cotações brutas do Kaggle/B3';


-- ------------------------------------------------------------
-- 1.2 STAGING: INDICADORES MACROECONÔMICOS (Fonte: BCB)
-- ------------------------------------------------------------
-- Origem: CSV do Sistema Gerenciador de Séries Temporais (SGS)
-- Séries: 11 (Selic), 433 (IPCA), 1 (Câmbio USD/BRL), 12 (CDI)
-- Colunas esperadas: data, valor
-- URLs:
--   https://api.bcb.gov.br/dados/serie/bcdata.sgs.11/dados?formato=csv
--   https://api.bcb.gov.br/dados/serie/bcdata.sgs.433/dados?formato=csv
--   https://api.bcb.gov.br/dados/serie/bcdata.sgs.1/dados?formato=csv
--   https://api.bcb.gov.br/dados/serie/bcdata.sgs.12/dados?formato=csv
-- ------------------------------------------------------------

DROP TABLE IF EXISTS stg_indicadores_macro;

CREATE TABLE stg_indicadores_macro (
    id_staging      BIGINT          NOT NULL AUTO_INCREMENT,
    cd_indicador    VARCHAR(20)     NULL COMMENT 'Código do indicador (SELIC, IPCA, CAMBIO, CDI)',
    cd_serie_bcb    VARCHAR(20)     NULL COMMENT 'Número da série no SGS do BCB',
    dt_referencia   VARCHAR(20)     NULL COMMENT 'Data de referência (formato bruto dd/mm/yyyy)',
    vl_indicador    VARCHAR(30)     NULL COMMENT 'Valor do indicador (texto bruto, vírgula decimal)',
    dt_carga        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp da ingestão',
    fl_processado   TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '0=pendente, 1=processado, 2=erro',
    ds_erro         VARCHAR(500)    NULL COMMENT 'Mensagem de erro se fl_processado=2',
    PRIMARY KEY (id_staging),
    INDEX idx_stg_macro_indicador (cd_indicador),
    INDEX idx_stg_macro_dt_ref (dt_referencia),
    INDEX idx_stg_macro_processado (fl_processado)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Staging: indicadores macroeconômicos brutos do BCB';


-- ------------------------------------------------------------
-- 1.3 STAGING: DEMONSTRAÇÕES FINANCEIRAS (Fonte: CVM DFP)
-- ------------------------------------------------------------
-- Origem: CSV do portal de dados abertos da CVM
-- Arquivo: dfp_cia_aberta_DRE_con_*.csv (e variantes BPA, BPP)
-- Colunas esperadas: CD_CVM, DS_CONTA, CD_CONTA, VL_CONTA, DT_REFER
-- URL: https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/
-- ------------------------------------------------------------

DROP TABLE IF EXISTS stg_dem_financeira;

CREATE TABLE stg_dem_financeira (
    id_staging      BIGINT          NOT NULL AUTO_INCREMENT,
    cd_cvm          VARCHAR(20)     NULL COMMENT 'Código CVM da empresa',
    ds_conta        VARCHAR(200)    NULL COMMENT 'Descrição da conta contábil',
    cd_conta        VARCHAR(50)     NULL COMMENT 'Código da conta contábil (ex: 3.01)',
    vl_conta        VARCHAR(30)     NULL COMMENT 'Valor da conta (texto bruto)',
    dt_referencia   VARCHAR(20)     NULL COMMENT 'Data de referência da demonstração',
    ds_tipo_dem     VARCHAR(20)     NULL COMMENT 'Tipo: DRE, BPA, BPP',
    nr_versao       VARCHAR(10)     NULL COMMENT 'Versão do documento (1=original, 2+=reapresentação)',
    dt_carga        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp da ingestão',
    fl_processado   TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '0=pendente, 1=processado, 2=erro',
    ds_erro         VARCHAR(500)    NULL COMMENT 'Mensagem de erro se fl_processado=2',
    PRIMARY KEY (id_staging),
    INDEX idx_stg_dem_cd_cvm (cd_cvm),
    INDEX idx_stg_dem_cd_conta (cd_conta),
    INDEX idx_stg_dem_dt_ref (dt_referencia),
    INDEX idx_stg_dem_processado (fl_processado)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Staging: demonstrações financeiras brutas da CVM';


-- ------------------------------------------------------------
-- 1.4 STAGING: CADASTRO DE EMPRESAS (Fonte: CVM)
-- ------------------------------------------------------------
-- Origem: CSV do cadastro de companhias abertas da CVM
-- Colunas esperadas: CD_CVM, CNPJ_CIA, DENOM_SOCIAL, DENOM_COMERC,
--                    SETOR_ATIV, SIT, DT_REG, DT_CONST
-- URL: https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/
-- ------------------------------------------------------------

DROP TABLE IF EXISTS stg_cadastro_empresa;

CREATE TABLE stg_cadastro_empresa (
    id_staging          BIGINT          NOT NULL AUTO_INCREMENT,
    cd_cvm              VARCHAR(20)     NULL COMMENT 'Código CVM da empresa',
    nr_cnpj             VARCHAR(20)     NULL COMMENT 'CNPJ da companhia',
    ds_razao_social     VARCHAR(200)    NULL COMMENT 'Razão social',
    ds_nome_pregao      VARCHAR(100)    NULL COMMENT 'Nome de pregão (denominação comercial)',
    ds_setor_atividade  VARCHAR(200)    NULL COMMENT 'Setor de atividade CVM',
    ds_situacao         VARCHAR(50)     NULL COMMENT 'Situação do registro (ATIVA, CANCELADA, etc.)',
    dt_registro         VARCHAR(20)     NULL COMMENT 'Data de registro na CVM',
    dt_constituicao     VARCHAR(20)     NULL COMMENT 'Data de constituição da empresa',
    ds_segmento         VARCHAR(100)    NULL COMMENT 'Segmento de listagem (Novo Mercado, N1, etc.)',
    dt_carga            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp da ingestão',
    fl_processado       TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '0=pendente, 1=processado, 2=erro',
    ds_erro             VARCHAR(500)    NULL COMMENT 'Mensagem de erro se fl_processado=2',
    PRIMARY KEY (id_staging),
    INDEX idx_stg_cad_cd_cvm (cd_cvm),
    INDEX idx_stg_cad_cnpj (nr_cnpj),
    INDEX idx_stg_cad_processado (fl_processado)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Staging: cadastro de empresas bruto da CVM';


-- ------------------------------------------------------------
-- 1.5 STAGING: DIVIDENDOS (Fonte: CVM/B3)
-- ------------------------------------------------------------
-- Origem: CSV de eventos corporativos (proventos)
-- Colunas esperadas: ticker, data, valor, tipo, dt_ex, dt_pagamento
-- ------------------------------------------------------------

DROP TABLE IF EXISTS stg_dividendos;

CREATE TABLE stg_dividendos (
    id_staging      BIGINT          NOT NULL AUTO_INCREMENT,
    ticker          VARCHAR(10)     NULL COMMENT 'Código do papel',
    cd_cvm          VARCHAR(20)     NULL COMMENT 'Código CVM da empresa',
    dt_aprovacao    VARCHAR(20)     NULL COMMENT 'Data de aprovação do provento',
    vl_provento     VARCHAR(30)     NULL COMMENT 'Valor por ação (texto bruto)',
    ds_tipo         VARCHAR(50)     NULL COMMENT 'Tipo: DIVIDENDO, JCP, RENDIMENTO',
    dt_ex           VARCHAR(20)     NULL COMMENT 'Data ex-dividendo',
    dt_pagamento    VARCHAR(20)     NULL COMMENT 'Data de pagamento',
    dt_carga        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp da ingestão',
    fl_processado   TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '0=pendente, 1=processado, 2=erro',
    ds_erro         VARCHAR(500)    NULL COMMENT 'Mensagem de erro se fl_processado=2',
    PRIMARY KEY (id_staging),
    INDEX idx_stg_div_ticker (ticker),
    INDEX idx_stg_div_processado (fl_processado)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Staging: proventos/dividendos brutos';


-- ------------------------------------------------------------
-- 1.6 STAGING: DESDOBRAMENTOS (Fonte: B3)
-- ------------------------------------------------------------
-- Origem: CSV de eventos corporativos (splits/grupamentos)
-- Colunas esperadas: ticker, data, tipo, fator, descricao
-- ------------------------------------------------------------

DROP TABLE IF EXISTS stg_desdobramento;

CREATE TABLE stg_desdobramento (
    id_staging      BIGINT          NOT NULL AUTO_INCREMENT,
    ticker          VARCHAR(10)     NULL COMMENT 'Código do papel',
    dt_evento       VARCHAR(20)     NULL COMMENT 'Data do evento',
    ds_tipo         VARCHAR(30)     NULL COMMENT 'Tipo: SPLIT, GRUPAMENTO, BONIFICACAO',
    vl_fator        VARCHAR(20)     NULL COMMENT 'Fator do desdobramento (texto bruto)',
    ds_descricao    VARCHAR(200)    NULL COMMENT 'Descrição do evento',
    dt_carga        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp da ingestão',
    fl_processado   TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '0=pendente, 1=processado, 2=erro',
    ds_erro         VARCHAR(500)    NULL COMMENT 'Mensagem de erro se fl_processado=2',
    PRIMARY KEY (id_staging),
    INDEX idx_stg_desdobr_ticker (ticker),
    INDEX idx_stg_desdobr_processado (fl_processado)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Staging: desdobramentos/splits brutos';


-- ============================================================
-- 2. TABELA DE CONTROLE DE CARGA (ETL Metadata)
-- ============================================================
-- Registra cada execução de carga para rastreabilidade,
-- idempotência e auditoria do pipeline.
-- ============================================================

DROP TABLE IF EXISTS etl_controle_carga;

CREATE TABLE etl_controle_carga (
    id_carga            BIGINT          NOT NULL AUTO_INCREMENT,
    ds_fonte            VARCHAR(100)    NOT NULL COMMENT 'Nome da fonte (KAGGLE_COTACAO, BCB_SELIC, CVM_DFP, etc.)',
    ds_arquivo          VARCHAR(500)    NULL COMMENT 'Nome/caminho do arquivo processado',
    ds_tabela_destino   VARCHAR(100)    NOT NULL COMMENT 'Tabela de staging de destino',
    dt_inicio_carga     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Início da execução',
    dt_fim_carga        DATETIME        NULL COMMENT 'Fim da execução',
    nr_registros_lidos  BIGINT          NULL COMMENT 'Total de linhas lidas do arquivo',
    nr_registros_carga  BIGINT          NULL COMMENT 'Total de linhas inseridas na staging',
    nr_registros_erro   BIGINT          NULL DEFAULT 0 COMMENT 'Total de linhas com erro',
    ds_status           VARCHAR(20)     NOT NULL DEFAULT 'EXECUTANDO' COMMENT 'EXECUTANDO, SUCESSO, ERRO, PARCIAL',
    ds_erro             TEXT            NULL COMMENT 'Detalhes do erro, se houver',
    ds_checksum         VARCHAR(64)     NULL COMMENT 'Hash SHA-256 do arquivo para detecção de duplicatas',
    PRIMARY KEY (id_carga),
    INDEX idx_etl_ctrl_fonte (ds_fonte),
    INDEX idx_etl_ctrl_status (ds_status),
    INDEX idx_etl_ctrl_dt (dt_inicio_carga)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Controle de execução das cargas ETL';


-- ============================================================
-- 3. TABELA DE LOG DE ERROS ETL
-- ============================================================

DROP TABLE IF EXISTS etl_log_erros;

CREATE TABLE etl_log_erros (
    id_erro         BIGINT          NOT NULL AUTO_INCREMENT,
    id_carga        BIGINT          NULL COMMENT 'Referência à execução de carga',
    ds_etapa        VARCHAR(50)     NOT NULL COMMENT 'EXTRACT, TRANSFORM, LOAD',
    ds_fonte        VARCHAR(100)    NULL COMMENT 'Fonte de dados',
    ds_procedure    VARCHAR(100)    NULL COMMENT 'Procedure/script que gerou o erro',
    ds_erro         TEXT            NOT NULL COMMENT 'Mensagem de erro',
    ds_dados        TEXT            NULL COMMENT 'Dados que causaram o erro (linha/registro)',
    dt_erro         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_erro),
    INDEX idx_etl_log_carga (id_carga),
    INDEX idx_etl_log_etapa (ds_etapa),
    INDEX idx_etl_log_dt (dt_erro)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Log de erros do pipeline ETL';


-- ============================================================
-- 4. PROCEDURES DE EXTRAÇÃO
-- ============================================================
-- Cada procedure encapsula a lógica de extração de uma fonte
-- específica, garantindo idempotência e rastreabilidade.
-- ============================================================

DELIMITER $$

-- ------------------------------------------------------------
-- 4.1 EXTRAÇÃO: COTAÇÕES HISTÓRICAS (Kaggle/B3)
-- ------------------------------------------------------------
-- Carrega CSV de cotações no formato:
--   ticker,date,open,close,high,low,volume
--
-- O arquivo deve estar em @base_path/cotacoes/
-- Exemplo: /var/lib/mysql-files/mercado_financeiro/cotacoes/ibovespa_stocks.csv
--
-- Uso: CALL sp_extract_cotacoes('ibovespa_stocks.csv');
-- ------------------------------------------------------------

DROP PROCEDURE IF EXISTS sp_extract_cotacoes$$

CREATE PROCEDURE sp_extract_cotacoes(
    IN p_arquivo VARCHAR(500)
)
BEGIN
    DECLARE v_id_carga BIGINT;
    DECLARE v_registros_antes BIGINT;
    DECLARE v_registros_depois BIGINT;
    DECLARE v_caminho_arquivo VARCHAR(1000);
    DECLARE v_erro_msg TEXT;

    -- Handler para capturar erros SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_erro_msg = MESSAGE_TEXT;

        -- Registrar erro no controle de carga
        UPDATE etl_controle_carga
        SET ds_status = 'ERRO',
            dt_fim_carga = NOW(),
            ds_erro = v_erro_msg
        WHERE id_carga = v_id_carga;

        -- Registrar no log de erros
        INSERT INTO etl_log_erros (id_carga, ds_etapa, ds_fonte, ds_procedure, ds_erro)
        VALUES (v_id_carga, 'EXTRACT', 'KAGGLE_COTACAO', 'sp_extract_cotacoes', v_erro_msg);

        -- Re-sinalizar o erro
        RESIGNAL;
    END;

    -- Montar caminho completo do arquivo
    SET v_caminho_arquivo = CONCAT('/var/lib/mysql-files/mercado_financeiro/cotacoes/', p_arquivo);

    -- Registrar início da carga
    INSERT INTO etl_controle_carga (ds_fonte, ds_arquivo, ds_tabela_destino, ds_status)
    VALUES ('KAGGLE_COTACAO', v_caminho_arquivo, 'stg_cotacao', 'EXECUTANDO');

    SET v_id_carga = LAST_INSERT_ID();

    -- Contar registros antes da carga (para calcular delta)
    SELECT COUNT(*) INTO v_registros_antes FROM stg_cotacao;

    -- Limpar registros não processados de cargas anteriores (idempotência)
    -- Mantém registros já processados para auditoria
    DELETE FROM stg_cotacao WHERE fl_processado = 0;

    -- Carregar dados brutos do CSV via LOAD DATA INFILE
    -- O arquivo CSV deve ter cabeçalho na primeira linha
    LOAD DATA INFILE '/var/lib/mysql-files/mercado_financeiro/cotacoes/dummy.csv'
    INTO TABLE stg_cotacao
    CHARACTER SET utf8mb4
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES
    (ticker, dt_pregao, vl_abertura, vl_fechamento, vl_maximo, vl_minimo, vl_volume);
    -- Nota: dt_carga e fl_processado usam valores DEFAULT

    -- Contar registros após a carga
    SELECT COUNT(*) INTO v_registros_depois FROM stg_cotacao WHERE fl_processado = 0;

    -- Atualizar controle de carga com resultado
    UPDATE etl_controle_carga
    SET ds_status = 'SUCESSO',
        dt_fim_carga = NOW(),
        nr_registros_carga = v_registros_depois
    WHERE id_carga = v_id_carga;

    -- Resultado informativo
    SELECT
        v_id_carga AS id_carga,
        'KAGGLE_COTACAO' AS fonte,
        v_registros_depois AS registros_carregados,
        'SUCESSO' AS status;

END$$


-- ------------------------------------------------------------
-- 4.2 EXTRAÇÃO: INDICADORES MACROECONÔMICOS (BCB)
-- ------------------------------------------------------------
-- Carrega CSVs do Banco Central no formato SGS:
--   data;valor
-- (separador ponto-e-vírgula, decimal com vírgula)
--
-- O arquivo deve estar em @base_path/bcb/
-- Exemplo: /var/lib/mysql-files/mercado_financeiro/bcb/selic_serie_11.csv
--
-- Uso: CALL sp_extract_indicador_bcb('SELIC', '11', 'selic_serie_11.csv');
-- ------------------------------------------------------------

DROP PROCEDURE IF EXISTS sp_extract_indicador_bcb$$

CREATE PROCEDURE sp_extract_indicador_bcb(
    IN p_cd_indicador VARCHAR(20),
    IN p_cd_serie     VARCHAR(20),
    IN p_arquivo      VARCHAR(500)
)
BEGIN
    DECLARE v_id_carga BIGINT;
    DECLARE v_registros BIGINT;
    DECLARE v_caminho_arquivo VARCHAR(1000);
    DECLARE v_erro_msg TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_erro_msg = MESSAGE_TEXT;

        UPDATE etl_controle_carga
        SET ds_status = 'ERRO',
            dt_fim_carga = NOW(),
            ds_erro = v_erro_msg
        WHERE id_carga = v_id_carga;

        INSERT INTO etl_log_erros (id_carga, ds_etapa, ds_fonte, ds_procedure, ds_erro)
        VALUES (v_id_carga, 'EXTRACT', CONCAT('BCB_', p_cd_indicador), 'sp_extract_indicador_bcb', v_erro_msg);

        RESIGNAL;
    END;

    SET v_caminho_arquivo = CONCAT('/var/lib/mysql-files/mercado_financeiro/bcb/', p_arquivo);

    -- Registrar início da carga
    INSERT INTO etl_controle_carga (ds_fonte, ds_arquivo, ds_tabela_destino, ds_status)
    VALUES (CONCAT('BCB_', p_cd_indicador), v_caminho_arquivo, 'stg_indicadores_macro', 'EXECUTANDO');

    SET v_id_carga = LAST_INSERT_ID();

    -- Limpar dados não processados deste indicador (idempotência)
    DELETE FROM stg_indicadores_macro
    WHERE cd_indicador = p_cd_indicador AND fl_processado = 0;

    -- Carregar CSV do BCB (formato: data;valor com cabeçalho)
    -- Usar tabela temporária para popular cd_indicador e cd_serie_bcb
    DROP TEMPORARY TABLE IF EXISTS tmp_bcb_raw;

    CREATE TEMPORARY TABLE tmp_bcb_raw (
        dt_referencia   VARCHAR(20),
        vl_indicador    VARCHAR(30)
    );

    -- O CSV do BCB usa ponto-e-vírgula como separador
    LOAD DATA INFILE '/var/lib/mysql-files/mercado_financeiro/bcb/dummy.csv'
    INTO TABLE tmp_bcb_raw
    CHARACTER SET utf8mb4
    FIELDS TERMINATED BY ';'
    OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES
    (dt_referencia, vl_indicador);

    -- Inserir na staging enriquecendo com código do indicador
    INSERT INTO stg_indicadores_macro (cd_indicador, cd_serie_bcb, dt_referencia, vl_indicador)
    SELECT
        p_cd_indicador,
        p_cd_serie,
        dt_referencia,
        vl_indicador
    FROM tmp_bcb_raw
    WHERE dt_referencia IS NOT NULL
      AND TRIM(dt_referencia) <> '';

    -- Contar registros inseridos
    SET v_registros = ROW_COUNT();

    DROP TEMPORARY TABLE IF EXISTS tmp_bcb_raw;

    -- Atualizar controle
    UPDATE etl_controle_carga
    SET ds_status = 'SUCESSO',
        dt_fim_carga = NOW(),
        nr_registros_carga = v_registros
    WHERE id_carga = v_id_carga;

    SELECT
        v_id_carga AS id_carga,
        CONCAT('BCB_', p_cd_indicador) AS fonte,
        v_registros AS registros_carregados,
        'SUCESSO' AS status;

END$$


-- ------------------------------------------------------------
-- 4.3 EXTRAÇÃO: DEMONSTRAÇÕES FINANCEIRAS (CVM DFP)
-- ------------------------------------------------------------
-- Carrega CSVs de demonstrações financeiras da CVM.
-- Formato típico (separador ;):
--   CNPJ_CIA;DT_REFER;VERSAO;DENOM_CIA;CD_CVM;...;CD_CONTA;DS_CONTA;VL_CONTA;...
--
-- O arquivo deve estar em @base_path/cvm/dfp/
-- Exemplo: /var/lib/mysql-files/mercado_financeiro/cvm/dfp/dfp_cia_aberta_DRE_con_2023.csv
--
-- Uso: CALL sp_extract_dem_financeira('dfp_cia_aberta_DRE_con_2023.csv', 'DRE');
-- ------------------------------------------------------------

DROP PROCEDURE IF EXISTS sp_extract_dem_financeira$$

CREATE PROCEDURE sp_extract_dem_financeira(
    IN p_arquivo    VARCHAR(500),
    IN p_tipo_dem   VARCHAR(20)
)
BEGIN
    DECLARE v_id_carga BIGINT;
    DECLARE v_registros BIGINT;
    DECLARE v_caminho_arquivo VARCHAR(1000);
    DECLARE v_erro_msg TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_erro_msg = MESSAGE_TEXT;

        UPDATE etl_controle_carga
        SET ds_status = 'ERRO',
            dt_fim_carga = NOW(),
            ds_erro = v_erro_msg
        WHERE id_carga = v_id_carga;

        INSERT INTO etl_log_erros (id_carga, ds_etapa, ds_fonte, ds_procedure, ds_erro)
        VALUES (v_id_carga, 'EXTRACT', CONCAT('CVM_DFP_', p_tipo_dem), 'sp_extract_dem_financeira', v_erro_msg);

        RESIGNAL;
    END;

    SET v_caminho_arquivo = CONCAT('/var/lib/mysql-files/mercado_financeiro/cvm/dfp/', p_arquivo);

    INSERT INTO etl_controle_carga (ds_fonte, ds_arquivo, ds_tabela_destino, ds_status)
    VALUES (CONCAT('CVM_DFP_', p_tipo_dem), v_caminho_arquivo, 'stg_dem_financeira', 'EXECUTANDO');

    SET v_id_carga = LAST_INSERT_ID();

    -- Usar tabela temporária para parsear o CSV completo da CVM
    -- e extrair apenas as colunas relevantes
    DROP TEMPORARY TABLE IF EXISTS tmp_cvm_dfp_raw;

    CREATE TEMPORARY TABLE tmp_cvm_dfp_raw (
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

    -- CSV da CVM usa ponto-e-vírgula como separador, encoding latin1
    LOAD DATA INFILE '/var/lib/mysql-files/mercado_financeiro/cvm/dfp/dummy.csv'
    INTO TABLE tmp_cvm_dfp_raw
    CHARACTER SET latin1
    FIELDS TERMINATED BY ';'
    OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES
    (cnpj_cia, dt_refer, versao, denom_cia, cd_cvm, grupo_dfp,
     moeda, escala_moeda, ordem_exerc, dt_ini_exerc, dt_fim_exerc,
     cd_conta, ds_conta, vl_conta, st_conta_fixa);

    -- Inserir na staging apenas colunas necessárias
    -- Filtrar apenas o exercício atual (ULTIMO) para evitar duplicatas
    INSERT INTO stg_dem_financeira
        (cd_cvm, ds_conta, cd_conta, vl_conta, dt_referencia, ds_tipo_dem, nr_versao)
    SELECT
        cd_cvm,
        ds_conta,
        cd_conta,
        vl_conta,
        dt_refer,
        p_tipo_dem,
        versao
    FROM tmp_cvm_dfp_raw
    WHERE cd_cvm IS NOT NULL
      AND TRIM(cd_cvm) <> ''
      AND ordem_exerc = 'ÚLTIMO';

    SET v_registros = ROW_COUNT();

    DROP TEMPORARY TABLE IF EXISTS tmp_cvm_dfp_raw;

    UPDATE etl_controle_carga
    SET ds_status = 'SUCESSO',
        dt_fim_carga = NOW(),
        nr_registros_carga = v_registros
    WHERE id_carga = v_id_carga;

    SELECT
        v_id_carga AS id_carga,
        CONCAT('CVM_DFP_', p_tipo_dem) AS fonte,
        v_registros AS registros_carregados,
        'SUCESSO' AS status;

END$$


-- ------------------------------------------------------------
-- 4.4 EXTRAÇÃO: CADASTRO DE EMPRESAS (CVM)
-- ------------------------------------------------------------
-- Carrega CSV do cadastro de companhias abertas da CVM.
-- Formato (separador ;):
--   CNPJ_CIA;DT_REG;DT_CONST;DT_CANCEL;MOTIVO_CANCEL;SIT;...
--   ...;CD_CVM;SETOR_ATIV;...;DENOM_SOCIAL;DENOM_COMERC;...
--
-- O arquivo deve estar em @base_path/cvm/cad/
-- Uso: CALL sp_extract_cadastro_empresa('cad_cia_aberta.csv');
-- ------------------------------------------------------------

DROP PROCEDURE IF EXISTS sp_extract_cadastro_empresa$$

CREATE PROCEDURE sp_extract_cadastro_empresa(
    IN p_arquivo VARCHAR(500)
)
BEGIN
    DECLARE v_id_carga BIGINT;
    DECLARE v_registros BIGINT;
    DECLARE v_caminho_arquivo VARCHAR(1000);
    DECLARE v_erro_msg TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_erro_msg = MESSAGE_TEXT;

        UPDATE etl_controle_carga
        SET ds_status = 'ERRO',
            dt_fim_carga = NOW(),
            ds_erro = v_erro_msg
        WHERE id_carga = v_id_carga;

        INSERT INTO etl_log_erros (id_carga, ds_etapa, ds_fonte, ds_procedure, ds_erro)
        VALUES (v_id_carga, 'EXTRACT', 'CVM_CADASTRO', 'sp_extract_cadastro_empresa', v_erro_msg);

        RESIGNAL;
    END;

    SET v_caminho_arquivo = CONCAT('/var/lib/mysql-files/mercado_financeiro/cvm/cad/', p_arquivo);

    INSERT INTO etl_controle_carga (ds_fonte, ds_arquivo, ds_tabela_destino, ds_status)
    VALUES ('CVM_CADASTRO', v_caminho_arquivo, 'stg_cadastro_empresa', 'EXECUTANDO');

    SET v_id_carga = LAST_INSERT_ID();

    -- Limpar dados anteriores não processados (idempotência)
    DELETE FROM stg_cadastro_empresa WHERE fl_processado = 0;

    -- Tabela temporária para o CSV completo da CVM
    DROP TEMPORARY TABLE IF EXISTS tmp_cvm_cad_raw;

    CREATE TEMPORARY TABLE tmp_cvm_cad_raw (
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

    LOAD DATA INFILE '/var/lib/mysql-files/mercado_financeiro/cvm/cad/dummy.csv'
    INTO TABLE tmp_cvm_cad_raw
    CHARACTER SET latin1
    FIELDS TERMINATED BY ';'
    OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES;

    -- Extrair apenas colunas relevantes para staging
    INSERT INTO stg_cadastro_empresa
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
    FROM tmp_cvm_cad_raw
    WHERE cd_cvm IS NOT NULL
      AND TRIM(cd_cvm) <> '';

    SET v_registros = ROW_COUNT();

    DROP TEMPORARY TABLE IF EXISTS tmp_cvm_cad_raw;

    UPDATE etl_controle_carga
    SET ds_status = 'SUCESSO',
        dt_fim_carga = NOW(),
        nr_registros_carga = v_registros
    WHERE id_carga = v_id_carga;

    SELECT
        v_id_carga AS id_carga,
        'CVM_CADASTRO' AS fonte,
        v_registros AS registros_carregados,
        'SUCESSO' AS status;

END$$


-- ------------------------------------------------------------
-- 4.5 EXTRAÇÃO: DIVIDENDOS (CVM/B3)
-- ------------------------------------------------------------
-- Carrega CSV de proventos no formato:
--   ticker;cd_cvm;dt_aprovacao;valor;tipo;dt_ex;dt_pagamento
--
-- Uso: CALL sp_extract_dividendos('proventos_2023.csv');
-- ------------------------------------------------------------

DROP PROCEDURE IF EXISTS sp_extract_dividendos$$

CREATE PROCEDURE sp_extract_dividendos(
    IN p_arquivo VARCHAR(500)
)
BEGIN
    DECLARE v_id_carga BIGINT;
    DECLARE v_registros BIGINT;
    DECLARE v_erro_msg TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_erro_msg = MESSAGE_TEXT;

        UPDATE etl_controle_carga
        SET ds_status = 'ERRO', dt_fim_carga = NOW(), ds_erro = v_erro_msg
        WHERE id_carga = v_id_carga;

        INSERT INTO etl_log_erros (id_carga, ds_etapa, ds_fonte, ds_procedure, ds_erro)
        VALUES (v_id_carga, 'EXTRACT', 'B3_DIVIDENDOS', 'sp_extract_dividendos', v_erro_msg);

        RESIGNAL;
    END;

    INSERT INTO etl_controle_carga (ds_fonte, ds_arquivo, ds_tabela_destino, ds_status)
    VALUES ('B3_DIVIDENDOS', p_arquivo, 'stg_dividendos', 'EXECUTANDO');

    SET v_id_carga = LAST_INSERT_ID();

    DELETE FROM stg_dividendos WHERE fl_processado = 0;

    LOAD DATA INFILE '/var/lib/mysql-files/mercado_financeiro/eventos/dummy.csv'
    INTO TABLE stg_dividendos
    CHARACTER SET utf8mb4
    FIELDS TERMINATED BY ';'
    OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES
    (ticker, cd_cvm, dt_aprovacao, vl_provento, ds_tipo, dt_ex, dt_pagamento);

    SET v_registros = ROW_COUNT();

    UPDATE etl_controle_carga
    SET ds_status = 'SUCESSO', dt_fim_carga = NOW(), nr_registros_carga = v_registros
    WHERE id_carga = v_id_carga;

    SELECT v_id_carga AS id_carga, 'B3_DIVIDENDOS' AS fonte,
           v_registros AS registros_carregados, 'SUCESSO' AS status;

END$$


-- ------------------------------------------------------------
-- 4.6 EXTRAÇÃO: DESDOBRAMENTOS (B3)
-- ------------------------------------------------------------
-- Carrega CSV de splits/grupamentos no formato:
--   ticker;data;tipo;fator;descricao
--
-- Uso: CALL sp_extract_desdobramentos('desdobramentos_2023.csv');
-- ------------------------------------------------------------

DROP PROCEDURE IF EXISTS sp_extract_desdobramentos$$

CREATE PROCEDURE sp_extract_desdobramentos(
    IN p_arquivo VARCHAR(500)
)
BEGIN
    DECLARE v_id_carga BIGINT;
    DECLARE v_registros BIGINT;
    DECLARE v_erro_msg TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_erro_msg = MESSAGE_TEXT;

        UPDATE etl_controle_carga
        SET ds_status = 'ERRO', dt_fim_carga = NOW(), ds_erro = v_erro_msg
        WHERE id_carga = v_id_carga;

        INSERT INTO etl_log_erros (id_carga, ds_etapa, ds_fonte, ds_procedure, ds_erro)
        VALUES (v_id_carga, 'EXTRACT', 'B3_DESDOBRAMENTO', 'sp_extract_desdobramentos', v_erro_msg);

        RESIGNAL;
    END;

    INSERT INTO etl_controle_carga (ds_fonte, ds_arquivo, ds_tabela_destino, ds_status)
    VALUES ('B3_DESDOBRAMENTO', p_arquivo, 'stg_desdobramento', 'EXECUTANDO');

    SET v_id_carga = LAST_INSERT_ID();

    DELETE FROM stg_desdobramento WHERE fl_processado = 0;

    LOAD DATA INFILE '/var/lib/mysql-files/mercado_financeiro/eventos/dummy.csv'
    INTO TABLE stg_desdobramento
    CHARACTER SET utf8mb4
    FIELDS TERMINATED BY ';'
    OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES
    (ticker, dt_evento, ds_tipo, vl_fator, ds_descricao);

    SET v_registros = ROW_COUNT();

    UPDATE etl_controle_carga
    SET ds_status = 'SUCESSO', dt_fim_carga = NOW(), nr_registros_carga = v_registros
    WHERE id_carga = v_id_carga;

    SELECT v_id_carga AS id_carga, 'B3_DESDOBRAMENTO' AS fonte,
           v_registros AS registros_carregados, 'SUCESSO' AS status;

END$$


-- ============================================================
-- 5. PROCEDURE ORQUESTRADORA — EXTRAÇÃO COMPLETA
-- ============================================================
-- Executa todas as extrações na ordem correta.
-- Pode ser chamada por um scheduler (cron, Airflow, etc.)
--
-- Uso: CALL sp_extract_full();
-- ============================================================

DROP PROCEDURE IF EXISTS sp_extract_full$$

CREATE PROCEDURE sp_extract_full()
BEGIN
    DECLARE v_erro_msg TEXT;
    DECLARE v_etapa VARCHAR(100) DEFAULT '';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_erro_msg = MESSAGE_TEXT;

        INSERT INTO etl_log_erros (ds_etapa, ds_fonte, ds_procedure, ds_erro, ds_dados)
        VALUES ('EXTRACT', 'ORQUESTRADOR', 'sp_extract_full',
                v_erro_msg, CONCAT('Falha na etapa: ', v_etapa));

        -- Não bloqueia as demais cargas; apenas registra o erro
        SELECT CONCAT('ERRO na etapa: ', v_etapa, ' — ', v_erro_msg) AS resultado;
    END;

    SELECT '=============================================' AS log;
    SELECT 'INÍCIO DA EXTRAÇÃO COMPLETA' AS log;
    SELECT NOW() AS dt_inicio;
    SELECT '=============================================' AS log;

    -- ---------------------------------------------------------
    -- ETAPA 1: Cotações históricas (Kaggle/B3)
    -- ---------------------------------------------------------
    SET v_etapa = 'COTACOES';
    SELECT CONCAT('>> Extraindo: ', v_etapa) AS log;
    CALL sp_extract_cotacoes('ibovespa_stocks.csv');

    -- ---------------------------------------------------------
    -- ETAPA 2: Indicadores Macroeconômicos (BCB)
    -- ---------------------------------------------------------
    SET v_etapa = 'BCB_SELIC';
    SELECT CONCAT('>> Extraindo: ', v_etapa) AS log;
    CALL sp_extract_indicador_bcb('SELIC', '11', 'selic_serie_11.csv');

    SET v_etapa = 'BCB_IPCA';
    SELECT CONCAT('>> Extraindo: ', v_etapa) AS log;
    CALL sp_extract_indicador_bcb('IPCA', '433', 'ipca_serie_433.csv');

    SET v_etapa = 'BCB_CAMBIO';
    SELECT CONCAT('>> Extraindo: ', v_etapa) AS log;
    CALL sp_extract_indicador_bcb('CAMBIO', '1', 'cambio_serie_1.csv');

    SET v_etapa = 'BCB_CDI';
    SELECT CONCAT('>> Extraindo: ', v_etapa) AS log;
    CALL sp_extract_indicador_bcb('CDI', '12', 'cdi_serie_12.csv');

    -- ---------------------------------------------------------
    -- ETAPA 3: Cadastro de Empresas (CVM)
    -- ---------------------------------------------------------
    SET v_etapa = 'CVM_CADASTRO';
    SELECT CONCAT('>> Extraindo: ', v_etapa) AS log;
    CALL sp_extract_cadastro_empresa('cad_cia_aberta.csv');

    -- ---------------------------------------------------------
    -- ETAPA 4: Demonstrações Financeiras (CVM DFP)
    -- ---------------------------------------------------------
    SET v_etapa = 'CVM_DFP_DRE';
    SELECT CONCAT('>> Extraindo: ', v_etapa) AS log;
    CALL sp_extract_dem_financeira('dfp_cia_aberta_DRE_con_2024.csv', 'DRE');

    SET v_etapa = 'CVM_DFP_BPA';
    SELECT CONCAT('>> Extraindo: ', v_etapa) AS log;
    CALL sp_extract_dem_financeira('dfp_cia_aberta_BPA_con_2024.csv', 'BPA');

    SET v_etapa = 'CVM_DFP_BPP';
    SELECT CONCAT('>> Extraindo: ', v_etapa) AS log;
    CALL sp_extract_dem_financeira('dfp_cia_aberta_BPP_con_2024.csv', 'BPP');

    -- ---------------------------------------------------------
    -- ETAPA 5: Dividendos
    -- ---------------------------------------------------------
    SET v_etapa = 'DIVIDENDOS';
    SELECT CONCAT('>> Extraindo: ', v_etapa) AS log;
    CALL sp_extract_dividendos('proventos_2024.csv');

    -- ---------------------------------------------------------
    -- ETAPA 6: Desdobramentos
    -- ---------------------------------------------------------
    SET v_etapa = 'DESDOBRAMENTOS';
    SELECT CONCAT('>> Extraindo: ', v_etapa) AS log;
    CALL sp_extract_desdobramentos('desdobramentos_2024.csv');

    SELECT '=============================================' AS log;
    SELECT 'EXTRAÇÃO COMPLETA FINALIZADA' AS log;
    SELECT NOW() AS dt_fim;
    SELECT '=============================================' AS log;

END$$


-- ============================================================
-- 6. VIEWS DE MONITORAMENTO DA EXTRAÇÃO
-- ============================================================

DELIMITER ;

-- Vista: resumo das últimas cargas por fonte
DROP VIEW IF EXISTS vw_etl_resumo_cargas;

CREATE VIEW vw_etl_resumo_cargas AS
SELECT
    ds_fonte,
    ds_tabela_destino,
    ds_status,
    nr_registros_carga,
    nr_registros_erro,
    dt_inicio_carga,
    dt_fim_carga,
    TIMESTAMPDIFF(SECOND, dt_inicio_carga, dt_fim_carga) AS duracao_segundos
FROM etl_controle_carga
ORDER BY dt_inicio_carga DESC;


-- Vista: contagem de registros pendentes por staging
DROP VIEW IF EXISTS vw_etl_staging_pendentes;

CREATE VIEW vw_etl_staging_pendentes AS
SELECT 'stg_cotacao' AS tabela,
       COUNT(*) AS total,
       SUM(CASE WHEN fl_processado = 0 THEN 1 ELSE 0 END) AS pendentes,
       SUM(CASE WHEN fl_processado = 1 THEN 1 ELSE 0 END) AS processados,
       SUM(CASE WHEN fl_processado = 2 THEN 1 ELSE 0 END) AS com_erro
FROM stg_cotacao
UNION ALL
SELECT 'stg_indicadores_macro',
       COUNT(*),
       SUM(CASE WHEN fl_processado = 0 THEN 1 ELSE 0 END),
       SUM(CASE WHEN fl_processado = 1 THEN 1 ELSE 0 END),
       SUM(CASE WHEN fl_processado = 2 THEN 1 ELSE 0 END)
FROM stg_indicadores_macro
UNION ALL
SELECT 'stg_dem_financeira',
       COUNT(*),
       SUM(CASE WHEN fl_processado = 0 THEN 1 ELSE 0 END),
       SUM(CASE WHEN fl_processado = 1 THEN 1 ELSE 0 END),
       SUM(CASE WHEN fl_processado = 2 THEN 1 ELSE 0 END)
FROM stg_dem_financeira
UNION ALL
SELECT 'stg_cadastro_empresa',
       COUNT(*),
       SUM(CASE WHEN fl_processado = 0 THEN 1 ELSE 0 END),
       SUM(CASE WHEN fl_processado = 1 THEN 1 ELSE 0 END),
       SUM(CASE WHEN fl_processado = 2 THEN 1 ELSE 0 END)
FROM stg_cadastro_empresa
UNION ALL
SELECT 'stg_dividendos',
       COUNT(*),
       SUM(CASE WHEN fl_processado = 0 THEN 1 ELSE 0 END),
       SUM(CASE WHEN fl_processado = 1 THEN 1 ELSE 0 END),
       SUM(CASE WHEN fl_processado = 2 THEN 1 ELSE 0 END)
FROM stg_dividendos
UNION ALL
SELECT 'stg_desdobramento',
       COUNT(*),
       SUM(CASE WHEN fl_processado = 0 THEN 1 ELSE 0 END),
       SUM(CASE WHEN fl_processado = 1 THEN 1 ELSE 0 END),
       SUM(CASE WHEN fl_processado = 2 THEN 1 ELSE 0 END)
FROM stg_desdobramento;


-- Vista: erros recentes do ETL
DROP VIEW IF EXISTS vw_etl_erros_recentes;

CREATE VIEW vw_etl_erros_recentes AS
SELECT
    e.id_erro,
    e.ds_etapa,
    e.ds_fonte,
    e.ds_procedure,
    e.ds_erro,
    e.dt_erro,
    c.ds_arquivo
FROM etl_log_erros e
LEFT JOIN etl_controle_carga c ON e.id_carga = c.id_carga
ORDER BY e.dt_erro DESC
LIMIT 100;


-- ============================================================
-- 7. SCRIPT DE DOWNLOAD DE DADOS (Referência)
-- ============================================================
-- Este bloco é comentado e serve como referência para o
-- script de download que deve ser executado ANTES da carga SQL.
-- Recomenda-se usar Python, curl ou wget para baixar os CSVs.
-- ============================================================

/*
-- ============================================================
-- download_dados.sh (executar antes do SQL)
-- ============================================================

#!/bin/bash
BASE_DIR="/var/lib/mysql-files/mercado_financeiro"

# Criar estrutura de diretórios
mkdir -p "$BASE_DIR/cotacoes"
mkdir -p "$BASE_DIR/bcb"
mkdir -p "$BASE_DIR/cvm/dfp"
mkdir -p "$BASE_DIR/cvm/cad"
mkdir -p "$BASE_DIR/eventos"

# --- BCB: Indicadores Macroeconômicos ---
echo "Baixando Selic (série 11)..."
curl -o "$BASE_DIR/bcb/selic_serie_11.csv" \
  "https://api.bcb.gov.br/dados/serie/bcdata.sgs.11/dados?formato=csv"

echo "Baixando IPCA (série 433)..."
curl -o "$BASE_DIR/bcb/ipca_serie_433.csv" \
  "https://api.bcb.gov.br/dados/serie/bcdata.sgs.433/dados?formato=csv"

echo "Baixando Câmbio USD/BRL (série 1)..."
curl -o "$BASE_DIR/bcb/cambio_serie_1.csv" \
  "https://api.bcb.gov.br/dados/serie/bcdata.sgs.1/dados?formato=csv"

echo "Baixando CDI (série 12)..."
curl -o "$BASE_DIR/bcb/cdi_serie_12.csv" \
  "https://api.bcb.gov.br/dados/serie/bcdata.sgs.12/dados?formato=csv"

# --- CVM: Cadastro de Empresas ---
echo "Baixando cadastro de companhias abertas..."
curl -o "$BASE_DIR/cvm/cad/cad_cia_aberta.csv" \
  "https://dados.cvm.gov.br/dados/CIA_ABERTA/CAD/DADOS/cad_cia_aberta.csv"

# --- CVM: Demonstrações Financeiras (DFP) ---
# Ajustar o ano conforme necessário
YEAR=2024
echo "Baixando DFP DRE consolidado $YEAR..."
curl -o "$BASE_DIR/cvm/dfp/dfp_cia_aberta_DRE_con_${YEAR}.csv" \
  "https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/dfp_cia_aberta_DRE_con_${YEAR}.csv"

echo "Baixando DFP BPA consolidado $YEAR..."
curl -o "$BASE_DIR/cvm/dfp/dfp_cia_aberta_BPA_con_${YEAR}.csv" \
  "https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/dfp_cia_aberta_BPA_con_${YEAR}.csv"

echo "Baixando DFP BPP consolidado $YEAR..."
curl -o "$BASE_DIR/cvm/dfp/dfp_cia_aberta_BPP_con_${YEAR}.csv" \
  "https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/dfp_cia_aberta_BPP_con_${YEAR}.csv"

# --- Kaggle: Cotações B3 ---
# Requer kaggle CLI configurado (pip install kaggle)
echo "Baixando cotações do Kaggle..."
kaggle datasets download -d felsal/ibovespa-stocks -p "$BASE_DIR/cotacoes/" --unzip

echo "Download concluído!"
*/


-- ============================================================
-- FIM DO SCRIPT DE EXTRAÇÃO
-- ============================================================
-- Próximo passo: executar o script de TRANSFORM (02_transform.sql)
-- que irá ler os dados das tabelas stg_* e popular as tabelas
-- de dimensão e fato do modelo dimensional.
-- ============================================================
