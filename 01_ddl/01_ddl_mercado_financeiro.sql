-- ============================================================
-- PROJETO FINAL: BANCO DE DADOS MERCADO FINANCEIRO
-- Disciplina: Gerenciamento de Banco de Dados
-- Grupo: LukinhasLK
-- Data: 2026-03-11
-- ============================================================

-- ============================================================
-- 1. CRIAÇÃO DO BANCO DE DADOS
-- ============================================================
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'MercadoFinanceiro')
BEGIN
    CREATE DATABASE MercadoFinanceiro;
END
GO

USE MercadoFinanceiro;
GO

-- ============================================================
-- 2. TABELAS DE STAGING (ETL - Área de pouso dos dados brutos)
-- ============================================================

IF OBJECT_ID('staging.cotacao', 'U') IS NOT NULL DROP TABLE staging.cotacao;
IF OBJECT_ID('staging.indicadores_macro', 'U') IS NOT NULL DROP TABLE staging.indicadores_macro;
IF OBJECT_ID('staging.dem_financeira', 'U') IS NOT NULL DROP TABLE staging.dem_financeira;

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'staging')
    EXEC('CREATE SCHEMA staging');
GO

CREATE TABLE staging.cotacao (
    id_staging      INT IDENTITY(1,1) PRIMARY KEY,
    ticker          VARCHAR(10),
    dt_pregao       VARCHAR(20),
    vl_abertura     VARCHAR(20),
    vl_fechamento   VARCHAR(20),
    vl_maximo       VARCHAR(20),
    vl_minimo       VARCHAR(20),
    vl_volume       VARCHAR(30),
    dt_carga        DATETIME DEFAULT GETDATE()
);
GO

CREATE TABLE staging.indicadores_macro (
    id_staging      INT IDENTITY(1,1) PRIMARY KEY,
    cd_indicador    VARCHAR(20),
    dt_referencia   VARCHAR(20),
    vl_indicador    VARCHAR(30),
    dt_carga        DATETIME DEFAULT GETDATE()
);
GO

CREATE TABLE staging.dem_financeira (
    id_staging      INT IDENTITY(1,1) PRIMARY KEY,
    cd_cvm          VARCHAR(20),
    ds_conta        VARCHAR(200),
    cd_conta        VARCHAR(50),
    vl_conta        VARCHAR(30),
    dt_referencia   VARCHAR(20),
    dt_carga        DATETIME DEFAULT GETDATE()
);
GO

-- ============================================================
-- 3. TABELAS DE DIMENSÃO
-- ============================================================

-- 3.1 Dimensão Setor
IF OBJECT_ID('dbo.dim_setor', 'U') IS NOT NULL DROP TABLE dbo.dim_setor;
CREATE TABLE dbo.dim_setor (
    id_setor        INT IDENTITY(1,1) PRIMARY KEY,
    cd_setor        VARCHAR(20)         NOT NULL UNIQUE,
    ds_setor        VARCHAR(100)        NOT NULL,
    ds_descricao    VARCHAR(500)        NULL,
    dt_criacao      DATETIME            DEFAULT GETDATE(),
    dt_atualizacao  DATETIME            DEFAULT GETDATE()
);
GO

-- 3.2 Dimensão Subsetor
IF OBJECT_ID('dbo.dim_subsetor', 'U') IS NOT NULL DROP TABLE dbo.dim_subsetor;
CREATE TABLE dbo.dim_subsetor (
    id_subsetor     INT IDENTITY(1,1) PRIMARY KEY,
    id_setor        INT                 NOT NULL,
    cd_subsetor     VARCHAR(20)         NOT NULL UNIQUE,
    ds_subsetor     VARCHAR(100)        NOT NULL,
    dt_criacao      DATETIME            DEFAULT GETDATE(),
    CONSTRAINT FK_subsetor_setor FOREIGN KEY (id_setor) REFERENCES dbo.dim_setor(id_setor)
);
GO

-- 3.3 Dimensão Segmento de Listagem
IF OBJECT_ID('dbo.dim_segmento_listagem', 'U') IS NOT NULL DROP TABLE dbo.dim_segmento_listagem;
CREATE TABLE dbo.dim_segmento_listagem (
    id_segmento     INT IDENTITY(1,1) PRIMARY KEY,
    cd_segmento     VARCHAR(20)         NOT NULL UNIQUE,
    ds_segmento     VARCHAR(100)        NOT NULL,
    ds_descricao    VARCHAR(500)        NULL,
    dt_criacao      DATETIME            DEFAULT GETDATE()
);
GO

-- 3.4 Dimensão Tipo de Ação
IF OBJECT_ID('dbo.dim_tipo_acao', 'U') IS NOT NULL DROP TABLE dbo.dim_tipo_acao;
CREATE TABLE dbo.dim_tipo_acao (
    id_tipo_acao    INT IDENTITY(1,1) PRIMARY KEY,
    cd_tipo         VARCHAR(10)         NOT NULL UNIQUE,
    ds_tipo         VARCHAR(50)         NOT NULL,
    ds_descricao    VARCHAR(200)        NULL
);
GO

-- 3.5 Dimensão Empresa
IF OBJECT_ID('dbo.dim_empresa', 'U') IS NOT NULL DROP TABLE dbo.dim_empresa;
CREATE TABLE dbo.dim_empresa (
    id_empresa          INT IDENTITY(1,1) PRIMARY KEY,
    cd_cvm              VARCHAR(20)         NOT NULL UNIQUE,
    nr_cnpj             VARCHAR(20)         NULL,
    ds_razao_social     VARCHAR(200)        NOT NULL,
    ds_nome_pregao      VARCHAR(100)        NULL,
    id_setor            INT                 NULL,
    id_subsetor         INT                 NULL,
    id_segmento         INT                 NULL,
    dt_constituicao     DATE                NULL,
    dt_listagem         DATE                NULL,
    fl_ativa            BIT                 DEFAULT 1,
    dt_criacao          DATETIME            DEFAULT GETDATE(),
    dt_atualizacao      DATETIME            DEFAULT GETDATE(),
    CONSTRAINT FK_empresa_setor      FOREIGN KEY (id_setor)     REFERENCES dbo.dim_setor(id_setor),
    CONSTRAINT FK_empresa_subsetor   FOREIGN KEY (id_subsetor)  REFERENCES dbo.dim_subsetor(id_subsetor),
    CONSTRAINT FK_empresa_segmento   FOREIGN KEY (id_segmento)  REFERENCES dbo.dim_segmento_listagem(id_segmento)
);
GO

-- 3.6 Dimensão Ação
IF OBJECT_ID('dbo.dim_acao', 'U') IS NOT NULL DROP TABLE dbo.dim_acao;
CREATE TABLE dbo.dim_acao (
    id_acao         INT IDENTITY(1,1) PRIMARY KEY,
    cd_ticker       VARCHAR(10)         NOT NULL UNIQUE,
    id_empresa      INT                 NOT NULL,
    id_tipo_acao    INT                 NOT NULL,
    ds_acao         VARCHAR(200)        NULL,
    nr_total_acoes  BIGINT              NULL,
    fl_ativa        BIT                 DEFAULT 1,
    dt_criacao      DATETIME            DEFAULT GETDATE(),
    dt_atualizacao  DATETIME            DEFAULT GETDATE(),
    CONSTRAINT FK_acao_empresa   FOREIGN KEY (id_empresa)   REFERENCES dbo.dim_empresa(id_empresa),
    CONSTRAINT FK_acao_tipo      FOREIGN KEY (id_tipo_acao) REFERENCES dbo.dim_tipo_acao(id_tipo_acao)
);
GO

-- 3.7 Dimensão Data
IF OBJECT_ID('dbo.dim_data', 'U') IS NOT NULL DROP TABLE dbo.dim_data;
CREATE TABLE dbo.dim_data (
    id_data         INT                 NOT NULL PRIMARY KEY, -- formato YYYYMMDD
    dt_data         DATE                NOT NULL UNIQUE,
    nr_ano          SMALLINT            NOT NULL,
    nr_mes          TINYINT             NOT NULL,
    nr_dia          TINYINT             NOT NULL,
    nr_trimestre    TINYINT             NOT NULL,
    nr_semestre     TINYINT             NOT NULL,
    ds_dia_semana   VARCHAR(20)         NOT NULL,
    nr_dia_semana   TINYINT             NOT NULL,
    fl_feriado      BIT                 DEFAULT 0,
    fl_dia_util     BIT                 DEFAULT 1,
    ds_mes          VARCHAR(20)         NOT NULL,
    CONSTRAINT CK_mes   CHECK (nr_mes BETWEEN 1 AND 12),
    CONSTRAINT CK_dia   CHECK (nr_dia BETWEEN 1 AND 31)
);
GO

-- 3.8 Dimensão Período de Crise
IF OBJECT_ID('dbo.dim_periodo_crise', 'U') IS NOT NULL DROP TABLE dbo.dim_periodo_crise;
CREATE TABLE dbo.dim_periodo_crise (
    id_crise        INT IDENTITY(1,1) PRIMARY KEY,
    ds_crise        VARCHAR(100)        NOT NULL,
    dt_inicio       DATE                NOT NULL,
    dt_fim          DATE                NOT NULL,
    ds_descricao    VARCHAR(500)        NULL,
    CONSTRAINT CK_crise_datas CHECK (dt_fim >= dt_inicio)
);
GO

-- 3.9 Dimensão Indicador Macroeconômico
IF OBJECT_ID('dbo.dim_indicador_macro', 'U') IS NOT NULL DROP TABLE dbo.dim_indicador_macro;
CREATE TABLE dbo.dim_indicador_macro (
    id_indicador    INT IDENTITY(1,1) PRIMARY KEY,
    cd_indicador    VARCHAR(20)         NOT NULL UNIQUE,
    ds_indicador    VARCHAR(100)        NOT NULL,
    ds_unidade      VARCHAR(50)         NOT NULL,
    ds_fonte        VARCHAR(100)        NOT NULL,
    cd_serie_bcb    VARCHAR(20)         NULL,
    ds_descricao    VARCHAR(500)        NULL
);
GO

-- ============================================================
-- 4. TABELAS FATO
-- ============================================================

-- 4.1 Fato Cotação (tabela principal)
IF OBJECT_ID('dbo.fato_cotacao', 'U') IS NOT NULL DROP TABLE dbo.fato_cotacao;
CREATE TABLE dbo.fato_cotacao (
    id_cotacao          BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_acao             INT                 NOT NULL,
    id_data             INT                 NOT NULL,
    vl_abertura         DECIMAL(18,4)       NOT NULL,
    vl_fechamento       DECIMAL(18,4)       NOT NULL,
    vl_maximo           DECIMAL(18,4)       NOT NULL,
    vl_minimo           DECIMAL(18,4)       NOT NULL,
    vl_volume           BIGINT              NOT NULL,
    vl_retorno_diario   DECIMAL(10,6)       NULL,
    vl_amplitude        DECIMAL(18,4)       NULL,
    dt_carga            DATETIME            DEFAULT GETDATE(),
    CONSTRAINT FK_cotacao_acao FOREIGN KEY (id_acao) REFERENCES dbo.dim_acao(id_acao),
    CONSTRAINT FK_cotacao_data FOREIGN KEY (id_data) REFERENCES dbo.dim_data(id_data),
    CONSTRAINT UQ_cotacao       UNIQUE (id_acao, id_data),
    CONSTRAINT CK_cotacao_vals  CHECK (vl_maximo >= vl_minimo AND vl_volume >= 0)
);
GO

-- 4.2 Fato Indicadores Macroeconômicos
IF OBJECT_ID('dbo.fato_indicador_macro', 'U') IS NOT NULL DROP TABLE dbo.fato_indicador_macro;
CREATE TABLE dbo.fato_indicador_macro (
    id_fato         BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_indicador    INT                 NOT NULL,
    id_data         INT                 NOT NULL,
    vl_indicador    DECIMAL(18,6)       NOT NULL,
    dt_carga        DATETIME            DEFAULT GETDATE(),
    CONSTRAINT FK_macro_indicador FOREIGN KEY (id_indicador) REFERENCES dbo.dim_indicador_macro(id_indicador),
    CONSTRAINT FK_macro_data      FOREIGN KEY (id_data)      REFERENCES dbo.dim_data(id_data),
    CONSTRAINT UQ_macro           UNIQUE (id_indicador, id_data)
);
GO

-- 4.3 Fato Demonstrações Financeiras
IF OBJECT_ID('dbo.fato_dem_financeira', 'U') IS NOT NULL DROP TABLE dbo.fato_dem_financeira;
CREATE TABLE dbo.fato_dem_financeira (
    id_fato             BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_empresa          INT                 NOT NULL,
    id_data             INT                 NOT NULL,
    vl_receita_liquida  DECIMAL(20,2)       NULL,
    vl_lucro_liquido    DECIMAL(20,2)       NULL,
    vl_ebitda           DECIMAL(20,2)       NULL,
    vl_divida_bruta     DECIMAL(20,2)       NULL,
    vl_patrimonio_liq   DECIMAL(20,2)       NULL,
    vl_ativo_total      DECIMAL(20,2)       NULL,
    ds_tipo_dem         VARCHAR(20)         DEFAULT 'ANUAL',
    dt_carga            DATETIME            DEFAULT GETDATE(),
    CONSTRAINT FK_dem_empresa FOREIGN KEY (id_empresa) REFERENCES dbo.dim_empresa(id_empresa),
    CONSTRAINT FK_dem_data    FOREIGN KEY (id_data)    REFERENCES dbo.dim_data(id_data),
    CONSTRAINT CK_tipo_dem    CHECK (ds_tipo_dem IN ('ANUAL', 'TRIMESTRAL'))
);
GO

-- 4.4 Fato Indicadores Calculados (P/L, ROE, DY, etc.)
IF OBJECT_ID('dbo.fato_indicadores', 'U') IS NOT NULL DROP TABLE dbo.fato_indicadores;
CREATE TABLE dbo.fato_indicadores (
    id_fato         BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_acao         INT                 NOT NULL,
    id_data         INT                 NOT NULL,
    vl_pl           DECIMAL(10,4)       NULL,
    vl_roe          DECIMAL(10,6)       NULL,
    vl_dy           DECIMAL(10,6)       NULL,
    vl_ev_ebitda    DECIMAL(10,4)       NULL,
    vl_sharpe       DECIMAL(10,6)       NULL,
    vl_volatilidade DECIMAL(10,6)       NULL,
    vl_market_cap   DECIMAL(20,2)       NULL,
    dt_carga        DATETIME            DEFAULT GETDATE(),
    CONSTRAINT FK_ind_acao FOREIGN KEY (id_acao) REFERENCES dbo.dim_acao(id_acao),
    CONSTRAINT FK_ind_data FOREIGN KEY (id_data) REFERENCES dbo.dim_data(id_data)
);
GO

-- ============================================================
-- 5. TABELAS HISTÓRICAS
-- ============================================================

-- 5.1 Histórico de Dividendos
IF OBJECT_ID('dbo.hist_dividendos', 'U') IS NOT NULL DROP TABLE dbo.hist_dividendos;
CREATE TABLE dbo.hist_dividendos (
    id_dividendo    BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_acao         INT                 NOT NULL,
    id_data         INT                 NOT NULL,
    vl_dividendo    DECIMAL(18,6)       NOT NULL,
    ds_tipo         VARCHAR(50)         NOT NULL,
    dt_ex           DATE                NULL,
    dt_pagamento    DATE                NULL,
    dt_carga        DATETIME            DEFAULT GETDATE(),
    CONSTRAINT FK_div_acao FOREIGN KEY (id_acao) REFERENCES dbo.dim_acao(id_acao),
    CONSTRAINT FK_div_data FOREIGN KEY (id_data) REFERENCES dbo.dim_data(id_data),
    CONSTRAINT CK_div_val  CHECK (vl_dividendo > 0)
);
GO

-- 5.2 Histórico de Desdobramentos
IF OBJECT_ID('dbo.hist_desdobramento', 'U') IS NOT NULL DROP TABLE dbo.hist_desdobramento;
CREATE TABLE dbo.hist_desdobramento (
    id_desdobramento INT IDENTITY(1,1) PRIMARY KEY,
    id_acao         INT                 NOT NULL,
    id_data         INT                 NOT NULL,
    ds_tipo         VARCHAR(20)         NOT NULL,
    vl_fator        DECIMAL(10,4)       NOT NULL,
    ds_descricao    VARCHAR(200)        NULL,
    dt_carga        DATETIME            DEFAULT GETDATE(),
    CONSTRAINT FK_desdobr_acao FOREIGN KEY (id_acao) REFERENCES dbo.dim_acao(id_acao),
    CONSTRAINT FK_desdobr_data FOREIGN KEY (id_data) REFERENCES dbo.dim_data(id_data),
    CONSTRAINT CK_desdobr_tipo CHECK (ds_tipo IN ('SPLIT', 'GRUPAMENTO', 'BONIFICACAO'))
);
GO

-- 5.3 Histórico de Preço Ajustado
IF OBJECT_ID('dbo.hist_preco_ajustado', 'U') IS NOT NULL DROP TABLE dbo.hist_preco_ajustado;
CREATE TABLE dbo.hist_preco_ajustado (
    id_preco_aj     BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_acao         INT                 NOT NULL,
    id_data         INT                 NOT NULL,
    vl_fechamento_aj DECIMAL(18,4)      NOT NULL,
    vl_retorno_aj   DECIMAL(10,6)       NULL,
    dt_carga        DATETIME            DEFAULT GETDATE(),
    CONSTRAINT FK_precaj_acao FOREIGN KEY (id_acao) REFERENCES dbo.dim_acao(id_acao),
    CONSTRAINT FK_precaj_data FOREIGN KEY (id_data) REFERENCES dbo.dim_data(id_data),
    CONSTRAINT UQ_precaj       UNIQUE (id_acao, id_data)
);
GO

-- ============================================================
-- 6. TABELAS DE CONTROLE E AUDITORIA
-- ============================================================

-- 6.1 Log de Auditoria (populado via Trigger)
IF OBJECT_ID('dbo.log_auditoria', 'U') IS NOT NULL DROP TABLE dbo.log_auditoria;
CREATE TABLE dbo.log_auditoria (
    id_log          BIGINT IDENTITY(1,1) PRIMARY KEY,
    ds_tabela       VARCHAR(100)        NOT NULL,
    ds_operacao     VARCHAR(10)         NOT NULL,
    ds_usuario      VARCHAR(100)        DEFAULT SYSTEM_USER,
    dt_operacao     DATETIME            DEFAULT GETDATE(),
    ds_dados_antes  VARCHAR(MAX)        NULL,
    ds_dados_depois VARCHAR(MAX)        NULL,
    CONSTRAINT CK_log_operacao CHECK (ds_operacao IN ('INSERT', 'UPDATE', 'DELETE'))
);
GO

-- 6.2 Log de Erros ETL
IF OBJECT_ID('dbo.log_erros_etl', 'U') IS NOT NULL DROP TABLE dbo.log_erros_etl;
CREATE TABLE dbo.log_erros_etl (
    id_erro         BIGINT IDENTITY(1,1) PRIMARY KEY,
    ds_procedure    VARCHAR(100)        NOT NULL,
    ds_erro         VARCHAR(MAX)        NOT NULL,
    ds_dados        VARCHAR(MAX)        NULL,
    dt_erro         DATETIME            DEFAULT GETDATE()
);
GO

-- 6.3 Parâmetros do Sistema
IF OBJECT_ID('dbo.parametros_sistema', 'U') IS NOT NULL DROP TABLE dbo.parametros_sistema;
CREATE TABLE dbo.parametros_sistema (
    id_parametro    INT IDENTITY(1,1) PRIMARY KEY,
    cd_parametro    VARCHAR(50)         NOT NULL UNIQUE,
    vl_parametro    VARCHAR(200)        NOT NULL,
    ds_descricao    VARCHAR(500)        NULL,
    dt_atualizacao  DATETIME            DEFAULT GETDATE()
);
GO

-- ============================================================
-- 7. INSERÇÃO DE DADOS INICIAIS
-- ============================================================

-- Segmentos de Listagem
INSERT INTO dbo.dim_segmento_listagem (cd_segmento, ds_segmento, ds_descricao) VALUES
('NM',   'Novo Mercado',     'Maior nível de governança corporativa da B3'),
('N2',   'Nível 2',          'Alto nível de governança, permite ações PN'),
('N1',   'Nível 1',          'Governança básica diferenciada'),
('MA',   'Bovespa Mais',     'Segmento para empresas de menor porte'),
('TRAD', 'Tradicional',      'Segmento padrão sem requisitos adicionais');
GO

-- Tipos de Ação
INSERT INTO dbo.dim_tipo_acao (cd_tipo, ds_tipo, ds_descricao) VALUES
('ON',   'Ordinária',        'Ação com direito a voto'),
('PN',   'Preferencial',     'Ação com prioridade em dividendos, sem voto'),
('UNIT', 'Unit',             'Certificado de depósito de ações ON e PN');
GO

-- Setores
INSERT INTO dbo.dim_setor (cd_setor, ds_setor) VALUES
('FIN',  'Financeiro e Seguros'),
('CONS', 'Consumo Cíclico'),
('CONB', 'Consumo Não Cíclico'),
('UTIL', 'Utilidade Pública'),
('MATS', 'Materiais Básicos'),
('SAUDE','Saúde'),
('PETRO','Petróleo, Gás e Biocombustíveis'),
('TELE', 'Telecomunicações'),
('TI',   'Tecnologia da Informação'),
('IMOV', 'Imóveis'),
('INDU', 'Bens Industriais'),
('AGRO', 'Agropecuária');
GO

-- Indicadores Macroeconômicos
INSERT INTO dbo.dim_indicador_macro (cd_indicador, ds_indicador, ds_unidade, ds_fonte, cd_serie_bcb) VALUES
('SELIC',  'Taxa de Juros Selic',      '% ao dia',   'Banco Central do Brasil', '11'),
('IPCA',   'IPCA - Inflação',          '% ao mês',   'Banco Central do Brasil', '433'),
('CAMBIO', 'Taxa de Câmbio USD/BRL',   'R$/USD',     'Banco Central do Brasil', '1'),
('CDI',    'Taxa CDI',                 '% ao dia',   'Banco Central do Brasil', '12');
GO

-- Períodos de Crise
INSERT INTO dbo.dim_periodo_crise (ds_crise, dt_inicio, dt_fim, ds_descricao) VALUES
('Crise Financeira Global 2008',    '2008-09-01', '2009-03-31', 'Crise do subprime nos EUA'),
('Crise Política Brasil 2015-2016', '2015-01-01', '2016-12-31', 'Recessão e crise política no Brasil'),
('Lava Jato - Pico 2017',           '2017-05-01', '2017-06-30', 'Gravações JBS e crise política'),
('Pandemia COVID-19',               '2020-02-01', '2020-12-31', 'Crise econômica causada pela pandemia'),
('Alta da Selic 2022-2023',         '2022-01-01', '2023-06-30', 'Ciclo de aperto monetário agressivo');
GO

-- Parâmetros do Sistema
INSERT INTO dbo.parametros_sistema (cd_parametro, vl_parametro, ds_descricao) VALUES
('ULTIMA_CARGA_COTACAO',   '1900-01-01', 'Data da última carga de cotações'),
('ULTIMA_CARGA_MACRO',     '1900-01-01', 'Data da última carga de indicadores macro'),
('ULTIMA_CARGA_DFP',       '1900-01-01', 'Data da última carga de demonstrações financeiras'),
('VERSAO_BANCO',           '1.0.0',      'Versão atual do banco de dados');
GO

-- ============================================================
-- 8. ÍNDICES PARA PERFORMANCE
-- ============================================================

CREATE NONCLUSTERED INDEX IX_cotacao_acao_data 
    ON dbo.fato_cotacao (id_acao, id_data);
GO

CREATE NONCLUSTERED INDEX IX_cotacao_data 
    ON dbo.fato_cotacao (id_data);
GO

CREATE NONCLUSTERED INDEX IX_macro_indicador_data 
    ON dbo.fato_indicador_macro (id_indicador, id_data);
GO

CREATE NONCLUSTERED INDEX IX_dem_empresa_data 
    ON dbo.fato_dem_financeira (id_empresa, id_data);
GO

CREATE NONCLUSTERED INDEX IX_acao_ticker 
    ON dbo.dim_acao (cd_ticker);
GO

CREATE NONCLUSTERED INDEX IX_empresa_cvm 
    ON dbo.dim_empresa (cd_cvm);
GO

PRINT '============================================================';
PRINT 'Banco MercadoFinanceiro criado com sucesso!';
PRINT 'Tabelas criadas: 22';
PRINT 'Índices criados: 6';
PRINT 'Dados iniciais inseridos.';
PRINT '============================================================';
GO
