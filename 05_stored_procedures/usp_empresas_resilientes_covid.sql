-- ============================================================
-- PROJETO FINAL: BANCO DE DADOS MERCADO FINANCEIRO
-- Disciplina: Gerenciamento de Banco de Dados
-- Grupo: LukinhasLK
-- ============================================================
-- SP: usp_empresas_resilientes_covid
-- Responde Q2: Quais empresas foram resilientes na COVID-2020?
--
-- Retorna, por ação:
--   - retorno acumulado em 2019 (base pré-crise)
--   - retorno acumulado em 2020 (durante a crise)
--   - variação entre os dois períodos
--   - classificação: 'Alta na crise' / 'Resiliente' / 'Impactada'
--
-- ⚠️  DEPENDÊNCIA EXTERNA:
--   Requer a function dbo.fn_retorno_acumulado criada pelo Ailton
--   (06_functions/). Confirme com ele antes de executar esta SP.
--
-- Uso:
--   EXEC dbo.usp_empresas_resilientes_covid;
--
-- Dependências:
--   dbo.dim_acao, dbo.dim_empresa, dbo.dim_setor,
--   dbo.fn_retorno_acumulado (06_functions — Ailton)
--
-- Autor: Lucas Oliveira Martins
-- Data: 2026-04-25
-- ============================================================

USE MercadoFinanceiro;
GO

IF OBJECT_ID('dbo.usp_empresas_resilientes_covid', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_empresas_resilientes_covid;
GO

CREATE PROCEDURE dbo.usp_empresas_resilientes_covid
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH retorno_2019 AS (
        SELECT
            da.cd_ticker,
            dbo.fn_retorno_acumulado(da.cd_ticker, '2019-01-01', '2019-12-31') AS ret_2019
        FROM dbo.dim_acao AS da
        WHERE da.fl_ativa = 1
    ),
    retorno_2020 AS (
        SELECT
            da.cd_ticker,
            dbo.fn_retorno_acumulado(da.cd_ticker, '2020-01-01', '2020-12-31') AS ret_2020
        FROM dbo.dim_acao AS da
        WHERE da.fl_ativa = 1
    )
    SELECT
        r19.cd_ticker,
        ds.ds_setor,
        ROUND(r19.ret_2019 * 100, 2)                       AS retorno_2019_pct,
        ROUND(r20.ret_2020 * 100, 2)                       AS retorno_2020_pct,
        ROUND((r20.ret_2020 - r19.ret_2019) * 100, 2)     AS variacao,
        CASE
            WHEN r20.ret_2020 >= 0                     THEN 'Alta na crise'
            WHEN r20.ret_2020 > r19.ret_2019 * 0.8    THEN 'Resiliente'
            ELSE 'Impactada'
        END AS classificacao
    FROM retorno_2019          r19
    INNER JOIN retorno_2020    r20 ON r20.cd_ticker  = r19.cd_ticker
    INNER JOIN dbo.dim_acao    da  ON da.cd_ticker   = r19.cd_ticker
    INNER JOIN dbo.dim_empresa de  ON de.id_empresa  = da.id_empresa
    INNER JOIN dbo.dim_setor   ds  ON ds.id_setor    = de.id_setor
    WHERE r19.ret_2019 IS NOT NULL
      AND r20.ret_2020 IS NOT NULL
    ORDER BY variacao DESC;

END;
GO
