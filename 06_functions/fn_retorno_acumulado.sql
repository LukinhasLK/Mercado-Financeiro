-- =============================================================================
-- ARQUIVO  : 06_functions/fn_retorno_acumulado.sql
-- PROJETO  : Mercado Financeiro B3
-- AUTOR    : Ailton
-- DESCRIÇÃO: Calcula o retorno acumulado (decimal) de uma ação em um período.
--            Ex.: retorno de 40% → retorna 0.4000
--            Para exibir em %, multiplique por 100 na consulta.
-- BANCO    : SQL Server 2017+ (T-SQL)
-- =============================================================================

USE MercadoFinanceiro;
GO

IF OBJECT_ID(N'dbo.fn_retorno_acumulado', N'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_retorno_acumulado;
GO

CREATE FUNCTION dbo.fn_retorno_acumulado
(
    @cd_ticker  NVARCHAR(10),
    @dt_inicio  DATE,
    @dt_fim     DATE
)
RETURNS DECIMAL(18, 6)
AS
BEGIN
    -- ==========================================================================
    -- Retorna o retorno acumulado como decimal.
    -- Fórmula: (preco_fim - preco_inicio) / preco_inicio
    -- Retorna NULL se não houver cotações no período.
    -- ==========================================================================

    DECLARE @vl_inicio  DECIMAL(18, 6);
    DECLARE @vl_fim     DECIMAL(18, 6);

    -- Preço de fechamento mais próximo da data de início
    SELECT TOP 1
        @vl_inicio = fc.vl_fechamento
    FROM dbo.fato_cotacao fc
    JOIN dbo.dim_acao     da ON da.id_acao = fc.id_acao
    JOIN dbo.dim_data     dd ON dd.id_data = fc.id_data
    WHERE da.cd_ticker = @cd_ticker
      AND dd.dt_data  >= @dt_inicio
    ORDER BY dd.dt_data ASC;

    -- Preço de fechamento mais próximo da data de fim
    SELECT TOP 1
        @vl_fim = fc.vl_fechamento
    FROM dbo.fato_cotacao fc
    JOIN dbo.dim_acao     da ON da.id_acao = fc.id_acao
    JOIN dbo.dim_data     dd ON dd.id_data = fc.id_data
    WHERE da.cd_ticker = @cd_ticker
      AND dd.dt_data  <= @dt_fim
    ORDER BY dd.dt_data DESC;

    -- Retorna NULL se dados insuficientes
    IF @vl_inicio IS NULL OR @vl_inicio = 0 OR @vl_fim IS NULL
        RETURN NULL;

    RETURN (@vl_fim - @vl_inicio) / @vl_inicio;
END;
GO


-- =============================================================================
-- EXEMPLOS DE USO
-- =============================================================================

/*
-- Retorno de PETR4 em 2022 (em %)
SELECT dbo.fn_retorno_acumulado('PETR4', '2022-01-03', '2022-12-30') * 100 AS retorno_pct;

-- Comparativo de retorno por ação no setor financeiro
SELECT
    da.cd_ticker,
    ROUND(dbo.fn_retorno_acumulado(da.cd_ticker, '2022-01-03', '2022-12-30') * 100, 2) AS retorno_2022_pct,
    ROUND(dbo.fn_retorno_acumulado(da.cd_ticker, '2023-01-02', '2023-12-29') * 100, 2) AS retorno_2023_pct
FROM dbo.dim_acao    da
JOIN dbo.dim_empresa de ON de.id_empresa = da.id_empresa
JOIN dbo.dim_setor   ds ON ds.id_setor   = de.id_setor
WHERE ds.cd_setor = 'FIN';
*/
