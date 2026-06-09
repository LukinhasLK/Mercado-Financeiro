-- ============================================================
-- PROJETO: MERCADO FINANCEIRO B3
-- ARQUIVO: queries_powerbi.sql
-- DESCRIÇÃO: Queries otimizadas para importação no Power BI
--
-- COMO USAR NO POWER BI:
--   1. Abra o Power BI Desktop
--   2. Página inicial > Obter Dados > SQL Server
--   3. Servidor: <nome_do_servidor>  Banco: MercadoFinanceiro
--   4. Para cada seção abaixo, use "Consulta SQL Nativa" ou
--      importe as views diretamente pelo navegador de tabelas.
--
-- ESTRUTURA DO DASHBOARD (páginas sugeridas):
--   Página 1 — Visão Geral (KPIs + resumo)
--   Página 2 — Q1: Selic vs Setor Financeiro
--   Página 3 — Q2: Resiliência COVID-2020
-- ============================================================

USE MercadoFinanceiro;
GO


-- ============================================================
-- PÁGINA 1 — VISÃO GERAL
-- ============================================================
-- Importar como tabela: "KPI_Geral"
-- Visuais sugeridos: cartões (cards) de KPI
-- ============================================================

-- 1.1 KPIs gerais do banco
SELECT
    (SELECT COUNT(DISTINCT cd_ticker)
        FROM dbo.dim_acao WHERE fl_ativa = 1)               AS total_acoes_ativas,

    (SELECT COUNT(DISTINCT id_empresa)
        FROM dbo.dim_empresa WHERE fl_ativa = 1)            AS total_empresas,

    (SELECT COUNT(*)
        FROM dbo.fato_cotacao)                              AS total_registros_cotacao,

    (SELECT MIN(dt_data)
        FROM dbo.dim_data
        WHERE id_data IN (SELECT id_data FROM dbo.fato_cotacao)) AS dt_inicio_serie,

    (SELECT MAX(dt_data)
        FROM dbo.dim_data
        WHERE id_data IN (SELECT id_data FROM dbo.fato_cotacao)) AS dt_fim_serie,

    (SELECT COUNT(DISTINCT cd_setor)
        FROM dbo.dim_setor)                                 AS total_setores;
GO


-- 1.2 Quantidade de ações por setor
-- Importar como tabela: "Acoes_por_Setor"
-- Visual sugerido: gráfico de barras horizontais
SELECT
    s.ds_setor,
    s.cd_setor,
    COUNT(DISTINCT a.id_acao)   AS nr_acoes,
    COUNT(DISTINCT e.id_empresa) AS nr_empresas
FROM dbo.dim_setor    s
LEFT JOIN dbo.dim_empresa e ON e.id_setor = s.id_setor AND e.fl_ativa = 1
LEFT JOIN dbo.dim_acao    a ON a.id_empresa = e.id_empresa AND a.fl_ativa = 1
GROUP BY s.ds_setor, s.cd_setor
ORDER BY nr_acoes DESC;
GO


-- 1.3 Volume financeiro total por ano e setor
-- Importar como tabela: "Volume_Anual_Setor"
-- Visual sugerido: gráfico de área empilhada (eixo X = ano)
SELECT
    ds.ds_setor,
    dd.nr_ano,
    SUM(CAST(fc.vl_volume AS BIGINT))               AS volume_total,
    SUM(fc.vl_volume * fc.vl_fechamento) / 1000000  AS volume_financeiro_MM
FROM dbo.fato_cotacao   fc
JOIN dbo.dim_acao       da ON da.id_acao    = fc.id_acao
JOIN dbo.dim_empresa    de ON de.id_empresa = da.id_empresa
JOIN dbo.dim_setor      ds ON ds.id_setor   = de.id_setor
JOIN dbo.dim_data       dd ON dd.id_data    = fc.id_data
GROUP BY ds.ds_setor, dd.nr_ano
ORDER BY dd.nr_ano, volume_financeiro_MM DESC;
GO


-- ============================================================
-- PÁGINA 2 — Q1: SELIC VS SETOR FINANCEIRO
-- ============================================================
-- Pergunta: Ações do setor financeiro superam a Selic em
--           janelas de alta de juros?
-- ============================================================

-- 2.1 Comparativo mensal: retorno das financeiras vs Selic
-- Importar como tabela: "Q1_Selic_vs_Financeiras"
-- Visual sugerido: gráfico de linhas duplas (eixo X = Ano/Mês)
--   - Linha 1: retorno_acoes_fin_pct  (cor azul)
--   - Linha 2: selic_pct              (cor laranja)
--   - Área de diferença: diferenca_pct
SELECT
    nr_ano,
    nr_mes,
    CAST(nr_ano AS VARCHAR) + '-' + RIGHT('0' + CAST(nr_mes AS VARCHAR), 2) AS ano_mes,
    retorno_acoes_fin_pct,
    selic_pct,
    diferenca_pct,
    resultado,
    -- Flag para colorir pontos no visual
    CASE WHEN diferenca_pct > 0 THEN 1 ELSE 0 END AS acoes_superaram
FROM dbo.vw_selic_vs_acoes
ORDER BY nr_ano, nr_mes;
GO


-- 2.2 Resumo anual: % de meses em que ações superaram a Selic
-- Importar como tabela: "Q1_Resumo_Anual"
-- Visual sugerido: gráfico de colunas agrupadas + linha de meta (50%)
SELECT
    nr_ano,
    COUNT(*)                                                        AS total_meses,
    SUM(CASE WHEN diferenca_pct > 0 THEN 1 ELSE 0 END)             AS meses_acoes_superiores,
    ROUND(
        100.0 * SUM(CASE WHEN diferenca_pct > 0 THEN 1 ELSE 0 END)
              / NULLIF(COUNT(*), 0), 1)                            AS pct_meses_superiores,
    ROUND(AVG(retorno_acoes_fin_pct), 4)                           AS retorno_medio_anual,
    ROUND(AVG(selic_pct), 4)                                       AS selic_media_anual,
    ROUND(AVG(diferenca_pct), 4)                                   AS spread_medio
FROM dbo.vw_selic_vs_acoes
GROUP BY nr_ano
ORDER BY nr_ano;
GO


-- 2.3 Top 10 meses com maior spread positivo (ações x Selic)
-- Importar como tabela: "Q1_Top_Spreads"
-- Visual sugerido: tabela ou gráfico de barras
SELECT TOP 10
    CAST(nr_ano AS VARCHAR) + '-' + RIGHT('0' + CAST(nr_mes AS VARCHAR), 2) AS ano_mes,
    retorno_acoes_fin_pct,
    selic_pct,
    diferenca_pct
FROM dbo.vw_selic_vs_acoes
WHERE diferenca_pct > 0
ORDER BY diferenca_pct DESC;
GO


-- 2.4 Evolução da Selic acumulada por ano (contexto de juros)
-- Importar como tabela: "Q1_Selic_Contexto"
-- Visual sugerido: gráfico de área (para mostrar ciclos de juros)
SELECT
    dd.nr_ano,
    dd.nr_mes,
    CAST(dd.nr_ano AS VARCHAR) + '-' + RIGHT('0' + CAST(dd.nr_mes AS VARCHAR), 2) AS ano_mes,
    ROUND(AVG(fim.vl_indicador), 6)     AS selic_diaria_media,
    ROUND(AVG(fim.vl_indicador) * 252, 4) AS selic_anualizada_pct
FROM dbo.fato_indicador_macro       fim
JOIN dbo.dim_indicador_macro        dim ON dim.id_indicador = fim.id_indicador
JOIN dbo.dim_data                   dd  ON dd.id_data = fim.id_data
WHERE dim.cd_indicador = 'SELIC'
GROUP BY dd.nr_ano, dd.nr_mes
ORDER BY dd.nr_ano, dd.nr_mes;
GO


-- ============================================================
-- PÁGINA 3 — Q2: RESILIÊNCIA COVID-2020
-- ============================================================
-- Pergunta: Quais empresas e setores foram mais resilientes
--           durante a crise de 2020?
-- ============================================================

-- 3.1 Classificação de todas as ações: 2019 vs 2020 vs 2021
-- Importar como tabela: "Q2_Empresas_Resilientes"
-- Visual sugerido: gráfico de dispersão (X=ret_2019, Y=ret_2020)
--   colorido por 'classificacao', tamanho por volume
SELECT
    v.cd_ticker,
    v.ds_razao_social,
    v.ds_setor,
    v.ds_segmento,
    v.retorno_2019_pct,
    v.retorno_2020_pct,
    v.retorno_2021_pct,
    v.classificacao,
    -- Retorno acumulado 2019-2021 (visão completa da crise)
    ROUND(v.retorno_2019_pct + v.retorno_2020_pct + v.retorno_2021_pct, 2) AS retorno_acum_3anos
FROM dbo.vw_empresas_resilientes v
ORDER BY v.retorno_2020_pct DESC;
GO


-- 3.2 Resumo por setor: % de empresas resilientes em 2020
-- Importar como tabela: "Q2_Resiliencia_por_Setor"
-- Visual sugerido: gráfico de barras 100% empilhadas por setor
SELECT
    ds_setor,
    COUNT(*)                                                                        AS total_empresas,
    SUM(CASE WHEN classificacao = 'Alta na crise' THEN 1 ELSE 0 END)               AS alta_na_crise,
    SUM(CASE WHEN classificacao = 'Resiliente'    THEN 1 ELSE 0 END)               AS resiliente,
    SUM(CASE WHEN classificacao = 'Impactada'     THEN 1 ELSE 0 END)               AS impactada,
    ROUND(AVG(retorno_2020_pct), 2)                                                 AS retorno_medio_2020,
    ROUND(AVG(retorno_2019_pct), 2)                                                 AS retorno_medio_2019
FROM dbo.vw_empresas_resilientes
GROUP BY ds_setor
ORDER BY retorno_medio_2020 DESC;
GO


-- 3.3 Cotação diária durante a crise (Jan/2020 a Dez/2020)
-- Importar como tabela: "Q2_Cotacoes_Covid"
-- Visual sugerido: gráfico de linhas por setor (índice base 100 = Jan/2020)
WITH base_jan AS (
    SELECT
        ds.ds_setor,
        AVG(fc.vl_fechamento) AS preco_base
    FROM dbo.fato_cotacao   fc
    JOIN dbo.dim_acao       da ON da.id_acao    = fc.id_acao
    JOIN dbo.dim_empresa    de ON de.id_empresa = da.id_empresa
    JOIN dbo.dim_setor      ds ON ds.id_setor   = de.id_setor
    JOIN dbo.dim_data       dd ON dd.id_data    = fc.id_data
    WHERE dd.nr_ano = 2020 AND dd.nr_mes = 1
    GROUP BY ds.ds_setor
)
SELECT
    ds.ds_setor,
    dd.dt_data,
    ROUND(AVG(fc.vl_fechamento), 4)                           AS preco_medio,
    ROUND(
        100.0 * AVG(fc.vl_fechamento) / NULLIF(b.preco_base, 0)
    , 2)                                                      AS indice_base100
FROM dbo.fato_cotacao   fc
JOIN dbo.dim_acao       da  ON da.id_acao    = fc.id_acao
JOIN dbo.dim_empresa    de  ON de.id_empresa = da.id_empresa
JOIN dbo.dim_setor      ds  ON ds.id_setor   = de.id_setor
JOIN dbo.dim_data       dd  ON dd.id_data    = fc.id_data
JOIN base_jan           b   ON b.ds_setor    = ds.ds_setor
WHERE dd.nr_ano BETWEEN 2019 AND 2021
GROUP BY ds.ds_setor, dd.dt_data, b.preco_base
ORDER BY ds.ds_setor, dd.dt_data;
GO


-- 3.4 Top 15 empresas mais resilientes em 2020
-- Importar como tabela: "Q2_Top_Resilientes"
-- Visual sugerido: gráfico de barras horizontais ranqueado
SELECT TOP 15
    cd_ticker,
    ds_razao_social,
    ds_setor,
    ds_segmento,
    retorno_2019_pct,
    retorno_2020_pct,
    retorno_2021_pct,
    classificacao
FROM dbo.vw_empresas_resilientes
ORDER BY retorno_2020_pct DESC;
GO


-- 3.5 Piores 15 empresas em 2020 (mais impactadas)
-- Importar como tabela: "Q2_Mais_Impactadas"
-- Visual sugerido: gráfico de barras horizontais ranqueado (negativo)
SELECT TOP 15
    cd_ticker,
    ds_razao_social,
    ds_setor,
    ds_segmento,
    retorno_2019_pct,
    retorno_2020_pct,
    retorno_2021_pct,
    classificacao
FROM dbo.vw_empresas_resilientes
ORDER BY retorno_2020_pct ASC;
GO


-- ============================================================
-- TABELAS DE APOIO (filtros e slicers do dashboard)
-- ============================================================

-- Slicer: lista de setores (para filtrar todas as páginas)
-- Importar como tabela: "Dim_Setor"
SELECT id_setor, cd_setor, ds_setor FROM dbo.dim_setor ORDER BY ds_setor;
GO

-- Slicer: lista de segmentos de listagem
-- Importar como tabela: "Dim_Segmento"
SELECT id_segmento, cd_segmento, ds_segmento FROM dbo.dim_segmento_listagem ORDER BY ds_segmento;
GO

-- Slicer: anos disponíveis
-- Importar como tabela: "Dim_Anos"
SELECT DISTINCT nr_ano FROM dbo.dim_data
WHERE id_data IN (SELECT id_data FROM dbo.fato_cotacao)
ORDER BY nr_ano;
GO
