-- ============================================================
-- PROJETO FINAL: BANCO DE DADOS MERCADO FINANCEIRO
-- Disciplina: Gerenciamento de Banco de Dados
-- Grupo: LukinhasLK
-- ============================================================
-- SP: usp_selic_vs_retorno_financeiras
-- Responde Q1: Ações do setor financeiro superam a Selic?
--
-- Retorna, por mês/ano:
--   - retorno médio mensal das ações do setor financeiro (FIN)
--   - Selic média do mesmo período
--   - diferença entre os dois (spread)
--
-- Uso:
--   EXEC dbo.usp_selic_vs_retorno_financeiras;
--   EXEC dbo.usp_selic_vs_retorno_financeiras '2020-01-01', '2023-12-31';
--
-- Dependências:
--   dbo.fato_cotacao, dbo.dim_acao, dbo.dim_data,
--   dbo.dim_empresa, dbo.dim_setor,
--   dbo.fato_indicador_macro, dbo.dim_indicador_macro
--
-- Autor: Lucas Oliveira Martins
-- Data: 2026-04-25
-- ============================================================

USE MercadoFinanceiro;
GO

IF OBJECT_ID('dbo.usp_selic_vs_retorno_financeiras', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_selic_vs_retorno_financeiras;
GO

CREATE PROCEDURE dbo.usp_selic_vs_retorno_financeiras
    @dt_inicio DATE = '2018-01-01',
    @dt_fim    DATE = '2023-12-31'
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH retorno_financeiro AS (
        -- Retorno médio mensal das ações do setor financeiro
        -- Multiplica por 21 (dias úteis/mês) para anualizar na base mensal
        SELECT
            dd.nr_ano,
            dd.nr_mes,
            AVG(fc.vl_retorno_diario) * 21 AS retorno_mensal_medio
        FROM dbo.fato_cotacao      AS fc
        INNER JOIN dbo.dim_acao    AS da ON da.id_acao    = fc.id_acao
        INNER JOIN dbo.dim_data    AS dd ON dd.id_data    = fc.id_data
        INNER JOIN dbo.dim_empresa AS de ON de.id_empresa = da.id_empresa
        INNER JOIN dbo.dim_setor   AS ds ON ds.id_setor   = de.id_setor
        -- ATENÇÃO: código 'FIN' conforme inserido no DDL (dim_setor)
        WHERE ds.cd_setor = 'FIN'
          AND dd.dt_data  BETWEEN @dt_inicio AND @dt_fim
          AND fc.vl_retorno_diario IS NOT NULL
        GROUP BY dd.nr_ano, dd.nr_mes
    ),
    selic_mensal AS (
        -- Selic média mensal (valores diários do BCB, série 11)
        SELECT
            dd.nr_ano,
            dd.nr_mes,
            AVG(fim.vl_indicador) AS selic_media_mensal
        FROM dbo.fato_indicador_macro      AS fim
        INNER JOIN dbo.dim_indicador_macro AS dim ON dim.id_indicador = fim.id_indicador
        INNER JOIN dbo.dim_data            AS dd  ON dd.id_data       = fim.id_data
        WHERE dim.cd_indicador = 'SELIC'
          AND dd.dt_data BETWEEN @dt_inicio AND @dt_fim
        GROUP BY dd.nr_ano, dd.nr_mes
    )
    SELECT
        r.nr_ano,
        r.nr_mes,
        ROUND(r.retorno_mensal_medio * 100, 4) AS retorno_acoes_pct,
        ROUND(s.selic_media_mensal,          4) AS selic_pct,
        ROUND((r.retorno_mensal_medio * 100) - s.selic_media_mensal, 4) AS diferenca
    FROM retorno_financeiro r
    INNER JOIN selic_mensal s
        ON  s.nr_ano = r.nr_ano
        AND s.nr_mes = r.nr_mes
    ORDER BY r.nr_ano, r.nr_mes;

END;
GO
