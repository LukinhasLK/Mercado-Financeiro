-- ============================================================
-- PROJETO FINAL: BANCO DE DADOS MERCADO FINANCEIRO
-- Script de Validação Pós-ETL
-- Executar após EXEC dbo.usp_etl_executar_pipeline
-- Grupo: LukinhasLK
-- ============================================================

USE MercadoFinanceiro;
GO

-- ============================================================
-- 1. CONTAGEM GERAL (alvo mínimo: 200.000 registros em fato_cotacao)
-- ============================================================

PRINT '=== CONTAGEM GERAL DE REGISTROS ===';

SELECT
    'dim_setor'             AS tabela, COUNT(*) AS registros FROM dbo.dim_setor
UNION ALL SELECT 'dim_empresa',              COUNT(*) FROM dbo.dim_empresa
UNION ALL SELECT 'dim_acao',                 COUNT(*) FROM dbo.dim_acao
UNION ALL SELECT 'dim_data',                 COUNT(*) FROM dbo.dim_data
UNION ALL SELECT 'dim_indicador_macro',      COUNT(*) FROM dbo.dim_indicador_macro
UNION ALL SELECT 'fato_cotacao',             COUNT(*) FROM dbo.fato_cotacao
UNION ALL SELECT 'fato_indicador_macro',     COUNT(*) FROM dbo.fato_indicador_macro
UNION ALL SELECT 'fato_dem_financeira',      COUNT(*) FROM dbo.fato_dem_financeira
ORDER BY tabela;
GO

-- ============================================================
-- 2. VALIDAÇÃO CRÍTICA: fato_cotacao >= 200.000
-- ============================================================

PRINT '=== VALIDAÇÃO: fato_cotacao >=200.000 ===';

SELECT
    COUNT(*)                                        AS total_registros,
    CASE WHEN COUNT(*) >= 200000 THEN 'OK'
         ELSE '*** ABAIXO DO MINIMO — verificar carga do CSV de cotacoes ***'
    END                                             AS status
FROM dbo.fato_cotacao;
GO

-- ============================================================
-- 3. PREGÕES POR TICKER (top 20)
-- ============================================================

PRINT '=== TOP 20 TICKERS POR NÚMERO DE PREGÕES ===';

SELECT TOP 20
    da.cd_ticker,
    COUNT(*) AS pregoes,
    MIN(dd.dt_data) AS primeiro_pregao,
    MAX(dd.dt_data) AS ultimo_pregao
FROM dbo.fato_cotacao fc
INNER JOIN dbo.dim_acao  da ON da.id_acao = fc.id_acao
INNER JOIN dbo.dim_data  dd ON dd.id_data = fc.id_data
GROUP BY da.cd_ticker
ORDER BY pregoes DESC;
GO

-- ============================================================
-- 4. INDICADORES MACROECONÔMICOS CARREGADOS
-- ============================================================

PRINT '=== INDICADORES MACRO ===';

SELECT
    dim.cd_indicador,
    dim.ds_indicador,
    COUNT(*)        AS total_registros,
    MIN(dd.dt_data) AS data_mais_antiga,
    MAX(dd.dt_data) AS data_mais_recente
FROM dbo.fato_indicador_macro      AS fim
INNER JOIN dbo.dim_indicador_macro AS dim ON dim.id_indicador = fim.id_indicador
INNER JOIN dbo.dim_data            AS dd  ON dd.id_data       = fim.id_data
GROUP BY dim.cd_indicador, dim.ds_indicador
ORDER BY dim.cd_indicador;
GO

-- ============================================================
-- 5. DISTRIBUIÇÃO POR SETOR
-- ============================================================

PRINT '=== AÇÕES E COTAÇÕES POR SETOR ===';

SELECT
    ds.cd_setor,
    ds.ds_setor,
    COUNT(DISTINCT da.id_acao)  AS total_acoes,
    COUNT(fc.id_cotacao)        AS total_cotacoes
FROM dbo.dim_setor   ds
LEFT JOIN dbo.dim_empresa de  ON de.id_setor   = ds.id_setor
LEFT JOIN dbo.dim_acao    da  ON da.id_empresa = de.id_empresa
LEFT JOIN dbo.fato_cotacao fc ON fc.id_acao    = da.id_acao
GROUP BY ds.cd_setor, ds.ds_setor
ORDER BY total_cotacoes DESC;
GO

-- ============================================================
-- 6. VERIFICAR LOG DE ERROS DO ETL
-- ============================================================

PRINT '=== LOG DE ERROS ETL (últimos 20) ===';

SELECT TOP 20 *
FROM dbo.log_erros_etl
ORDER BY dt_erro DESC;
GO

-- ============================================================
-- 7. TESTE DAS STORED PROCEDURES ANALÍTICAS
-- ============================================================

PRINT '=== TESTE SP1: usp_selic_vs_retorno_financeiras ===';
-- Retorna retorno mensal do setor FIN vs Selic (2018–2023)
EXEC dbo.usp_selic_vs_retorno_financeiras
    @dt_inicio = '2018-01-01',
    @dt_fim    = '2023-12-31';
GO

PRINT '=== TESTE SP2: usp_empresas_resilientes_covid ===';
-- Requer fn_retorno_acumulado (Ailton — 06_functions/)
-- Descomente quando a function estiver criada:
-- EXEC dbo.usp_empresas_resilientes_covid;
GO
