-- =============================================================================
-- ARQUIVO  : 04_views/views.sql
-- PROJETO  : Mercado Financeiro B3
-- AUTOR    : Ailton Santos Dantas
-- DESCRIÇÃO: 5 views analíticas — interface de consumo para relatórios e BI.
-- BANCO    : SQL Server 2017+ (T-SQL)
-- =============================================================================

USE MercadoFinanceiro;
GO

-- =============================================================================
-- VIEW 1: vw_cotacao_diaria
-- Preços diários completos com nome da empresa, ticker e setor.
-- Interface principal para dashboards e relatórios de cotação.
-- =============================================================================

IF OBJECT_ID(N'dbo.vw_cotacao_diaria', N'V') IS NOT NULL
    DROP VIEW dbo.vw_cotacao_diaria;
GO

CREATE VIEW dbo.vw_cotacao_diaria AS
SELECT
    fc.id_cotacao,
    da.cd_ticker,
    de.ds_razao_social,
    de.ds_nome_pregao,
    ds.ds_setor,
    dd.dt_data          AS dt_pregao,
    dd.nr_ano,
    dd.nr_mes,
    fc.vl_abertura,
    fc.vl_fechamento,
    fc.vl_maximo,
    fc.vl_minimo,
    fc.vl_volume,
    fc.vl_retorno_diario,
    fc.vl_amplitude
FROM dbo.fato_cotacao   fc
JOIN dbo.dim_acao       da ON da.id_acao    = fc.id_acao
JOIN dbo.dim_empresa    de ON de.id_empresa = da.id_empresa
JOIN dbo.dim_setor      ds ON ds.id_setor   = de.id_setor
JOIN dbo.dim_data       dd ON dd.id_data    = fc.id_data;
GO


-- =============================================================================
-- VIEW 2: vw_retorno_mensal
-- Retorno mensal calculado por ação, agregando os retornos diários.
-- =============================================================================

IF OBJECT_ID(N'dbo.vw_retorno_mensal', N'V') IS NOT NULL
    DROP VIEW dbo.vw_retorno_mensal;
GO

CREATE VIEW dbo.vw_retorno_mensal AS
SELECT
    da.cd_ticker,
    de.ds_razao_social,
    ds.ds_setor,
    dd.nr_ano,
    dd.nr_mes,
    -- Retorno mensal composto: produto dos (1 + retorno_diario) - 1
    -- Aproximação: soma dos retornos diários do mês
    SUM(fc.vl_retorno_diario)                       AS retorno_mensal_soma,
    AVG(fc.vl_retorno_diario)                       AS retorno_diario_medio,
    MAX(fc.vl_fechamento)                           AS vl_maximo_mes,
    MIN(fc.vl_fechamento)                           AS vl_minimo_mes,
    MAX(fc.vl_fechamento) - MIN(fc.vl_fechamento)   AS amplitude_mes,
    SUM(fc.vl_volume)                               AS volume_total_mes,
    COUNT(*)                                        AS nr_pregoes
FROM dbo.fato_cotacao   fc
JOIN dbo.dim_acao       da ON da.id_acao    = fc.id_acao
JOIN dbo.dim_empresa    de ON de.id_empresa = da.id_empresa
JOIN dbo.dim_setor      ds ON ds.id_setor   = de.id_setor
JOIN dbo.dim_data       dd ON dd.id_data    = fc.id_data
WHERE fc.vl_retorno_diario IS NOT NULL
GROUP BY
    da.cd_ticker,
    de.ds_razao_social,
    ds.ds_setor,
    dd.nr_ano,
    dd.nr_mes;
GO


-- =============================================================================
-- VIEW 3: vw_selic_vs_acoes
-- Comparativo mensal entre a Selic e o retorno médio das ações financeiras.
-- =============================================================================

IF OBJECT_ID(N'dbo.vw_selic_vs_acoes', N'V') IS NOT NULL
    DROP VIEW dbo.vw_selic_vs_acoes;
GO

CREATE VIEW dbo.vw_selic_vs_acoes AS
WITH retorno_fin AS (
    SELECT
        dd.nr_ano,
        dd.nr_mes,
        AVG(fc.vl_retorno_diario) * 21  AS retorno_mensal_fin
    FROM dbo.fato_cotacao   fc
    JOIN dbo.dim_acao       da ON da.id_acao    = fc.id_acao
    JOIN dbo.dim_empresa    de ON de.id_empresa = da.id_empresa
    JOIN dbo.dim_setor      ds ON ds.id_setor   = de.id_setor
    JOIN dbo.dim_data       dd ON dd.id_data    = fc.id_data
    WHERE ds.cd_setor = 'FIN'
      AND fc.vl_retorno_diario IS NOT NULL
    GROUP BY dd.nr_ano, dd.nr_mes
),
selic_men AS (
    SELECT
        dd.nr_ano,
        dd.nr_mes,
        AVG(fim.vl_indicador)           AS selic_media_mensal
    FROM dbo.fato_indicador_macro       fim
    JOIN dbo.dim_indicador_macro        dim ON dim.id_indicador = fim.id_indicador
    JOIN dbo.dim_data                   dd  ON dd.id_data       = fim.id_data
    WHERE dim.cd_indicador = 'SELIC'
    GROUP BY dd.nr_ano, dd.nr_mes
)
SELECT
    r.nr_ano,
    r.nr_mes,
    ROUND(r.retorno_mensal_fin * 100, 4)                            AS retorno_acoes_fin_pct,
    ROUND(s.selic_media_mensal, 4)                                  AS selic_pct,
    ROUND((r.retorno_mensal_fin * 100) - s.selic_media_mensal, 4)  AS diferenca_pct,
    CASE
        WHEN (r.retorno_mensal_fin * 100) > s.selic_media_mensal THEN 'Acoes superam Selic'
        ELSE 'Selic supera Acoes'
    END AS resultado
FROM retorno_fin r
JOIN selic_men   s ON s.nr_ano = r.nr_ano AND s.nr_mes = r.nr_mes;
GO


-- =============================================================================
-- VIEW 4: vw_empresas_resilientes
-- Empresas com retorno positivo tanto em 2019 quanto em 2020 (COVID).
-- =============================================================================

IF OBJECT_ID(N'dbo.vw_empresas_resilientes', N'V') IS NOT NULL
    DROP VIEW dbo.vw_empresas_resilientes;
GO

CREATE VIEW dbo.vw_empresas_resilientes AS
WITH retorno_anual AS (
    SELECT
        da.cd_ticker,
        de.ds_razao_social,
        ds.ds_setor,
        sl.ds_segmento,
        dd.nr_ano,
        SUM(fc.vl_retorno_diario) AS retorno_anual
    FROM dbo.fato_cotacao           fc
    JOIN dbo.dim_acao               da  ON da.id_acao    = fc.id_acao
    JOIN dbo.dim_empresa            de  ON de.id_empresa = da.id_empresa
    JOIN dbo.dim_setor              ds  ON ds.id_setor   = de.id_setor
    JOIN dbo.dim_segmento_listagem  sl  ON sl.id_segmento = de.id_segmento
    JOIN dbo.dim_data               dd  ON dd.id_data    = fc.id_data
    WHERE fc.vl_retorno_diario IS NOT NULL
      AND dd.nr_ano IN (2019, 2020, 2021)
    GROUP BY
        da.cd_ticker,
        de.ds_razao_social,
        ds.ds_setor,
        sl.ds_segmento,
        dd.nr_ano
),
pivot_retorno AS (
    SELECT
        cd_ticker,
        ds_razao_social,
        ds_setor,
        ds_segmento,
        MAX(CASE WHEN nr_ano = 2019 THEN retorno_anual END) AS ret_2019,
        MAX(CASE WHEN nr_ano = 2020 THEN retorno_anual END) AS ret_2020,
        MAX(CASE WHEN nr_ano = 2021 THEN retorno_anual END) AS ret_2021
    FROM retorno_anual
    GROUP BY cd_ticker, ds_razao_social, ds_setor, ds_segmento
)
SELECT
    cd_ticker,
    ds_razao_social,
    ds_setor,
    ds_segmento,
    ROUND(ret_2019 * 100, 2) AS retorno_2019_pct,
    ROUND(ret_2020 * 100, 2) AS retorno_2020_pct,
    ROUND(ret_2021 * 100, 2) AS retorno_2021_pct,
    CASE
        WHEN ret_2020 >= 0 THEN 'Alta na crise'
        WHEN ret_2020 > ret_2019 * 0.8 THEN 'Resiliente'
        ELSE 'Impactada'
    END AS classificacao
FROM pivot_retorno
WHERE ret_2019 IS NOT NULL
  AND ret_2020 IS NOT NULL;
GO


-- =============================================================================
-- VIEW 5: vw_volume_por_setor
-- Volume financeiro total agregado por setor e mês.
-- =============================================================================

IF OBJECT_ID(N'dbo.vw_volume_por_setor', N'V') IS NOT NULL
    DROP VIEW dbo.vw_volume_por_setor;
GO

CREATE VIEW dbo.vw_volume_por_setor AS
SELECT
    ds.cd_setor,
    ds.ds_setor,
    dd.nr_ano,
    dd.nr_mes,
    dd.dt_data          AS dt_pregao,
    COUNT(DISTINCT da.id_acao)          AS nr_acoes_ativas,
    SUM(fc.vl_volume)                   AS vl_volume_total,
    AVG(fc.vl_volume)                   AS vl_volume_medio,
    SUM(fc.vl_volume * fc.vl_fechamento) AS vl_financeiro_total
FROM dbo.fato_cotacao   fc
JOIN dbo.dim_acao       da ON da.id_acao    = fc.id_acao
JOIN dbo.dim_empresa    de ON de.id_empresa = da.id_empresa
JOIN dbo.dim_setor      ds ON ds.id_setor   = de.id_setor
JOIN dbo.dim_data       dd ON dd.id_data    = fc.id_data
GROUP BY
    ds.cd_setor,
    ds.ds_setor,
    dd.nr_ano,
    dd.nr_mes,
    dd.dt_data;
GO


-- =============================================================================
-- VERIFICAÇÃO — listar as views criadas
-- =============================================================================

/*
SELECT
    name        AS view_name,
    create_date,
    modify_date
FROM sys.views
WHERE name LIKE 'vw_%'
ORDER BY name;
*/
