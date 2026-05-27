-- =============================================================================
-- ARQUIVO  : 06_functions/fn_volatilidade_historica.sql
-- PROJETO  : Mercado Financeiro B3
-- AUTOR    : Ailton
-- DESCRIÇÃO: Calcula a volatilidade histórica (desvio padrão dos retornos
--            diários) de uma ação em um período.
--            Para anualizar: multiplique por SQRT(252).
-- BANCO    : SQL Server 2017+ (T-SQL)
-- =============================================================================

USE MercadoFinanceiro;
GO

IF OBJECT_ID(N'dbo.fn_volatilidade_historica', N'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_volatilidade_historica;
GO

CREATE FUNCTION dbo.fn_volatilidade_historica
(
    @cd_ticker  NVARCHAR(10),
    @dt_inicio  DATE,
    @dt_fim     DATE
)
RETURNS DECIMAL(18, 6)
AS
BEGIN
    -- ==========================================================================
    -- Calcula o desvio padrão dos retornos diários no período.
    -- Retorno diário = (fechamento_hoje - fechamento_ontem) / fechamento_ontem
    -- Retorna NULL se não houver dados suficientes (mínimo 2 pregões).
    -- ==========================================================================

    DECLARE @volatilidade DECIMAL(18, 6);

    SELECT
        @volatilidade = STDEV(retorno_diario)
    FROM (
        SELECT
            (fc.vl_fechamento
                - LAG(fc.vl_fechamento) OVER (ORDER BY dd.dt_data))
            / NULLIF(LAG(fc.vl_fechamento) OVER (ORDER BY dd.dt_data), 0)
            AS retorno_diario
        FROM dbo.fato_cotacao fc
        JOIN dbo.dim_acao     da ON da.id_acao = fc.id_acao
        JOIN dbo.dim_data     dd ON dd.id_data = fc.id_data
        WHERE da.cd_ticker = @cd_ticker
          AND dd.dt_data  BETWEEN @dt_inicio AND @dt_fim
    ) AS retornos
    WHERE retorno_diario IS NOT NULL;

    RETURN @volatilidade;
END;
GO


-- =============================================================================
-- EXEMPLOS DE USO
-- =============================================================================

/*
-- Volatilidade diária de VALE3 em 2023
SELECT dbo.fn_volatilidade_historica('VALE3', '2023-01-02', '2023-12-29') AS vol_diaria;

-- Volatilidade anualizada (multiplicar por SQRT(252))
SELECT
    dbo.fn_volatilidade_historica('VALE3', '2023-01-02', '2023-12-29')
    * SQRT(252) AS vol_anualizada;

-- Comparativo de volatilidade entre ações do setor financeiro
SELECT
    da.cd_ticker,
    ROUND(dbo.fn_volatilidade_historica(da.cd_ticker, '2023-01-02', '2023-12-29'), 6)          AS vol_diaria,
    ROUND(dbo.fn_volatilidade_historica(da.cd_ticker, '2023-01-02', '2023-12-29') * SQRT(252), 6) AS vol_anualizada
FROM dbo.dim_acao    da
JOIN dbo.dim_empresa de ON de.id_empresa = da.id_empresa
JOIN dbo.dim_setor   ds ON ds.id_setor   = de.id_setor
WHERE ds.cd_setor = 'FIN';
*/
