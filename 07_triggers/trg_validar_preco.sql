-- =============================================================================
-- ARQUIVO  : 07_triggers/trg_validar_preco.sql
-- PROJETO  : Mercado Financeiro B3
-- AUTOR    : Luigi Sapucaia de Lima
-- DESCRIÇÃO: Trigger que valida os preços antes de qualquer INSERT ou UPDATE
--            na tabela fato_cotacao. Bloqueia registros inválidos com ROLLBACK.
-- BANCO    : SQL Server 2017+ (T-SQL)
-- =============================================================================

USE MercadoFinanceiro;
GO

IF OBJECT_ID(N'dbo.trg_validar_preco', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_validar_preco;
GO

CREATE TRIGGER dbo.trg_validar_preco
ON dbo.fato_cotacao
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- -------------------------------------------------------------------------
    -- REGRA 1: vl_abertura deve ser maior que zero
    -- -------------------------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE vl_abertura <= 0
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50001, '[trg_validar_preco]: vl_abertura não pode ser negativo ou zero.', 1;
        RETURN;
    END;

    -- -------------------------------------------------------------------------
    -- REGRA 2: vl_fechamento deve ser maior que zero
    -- -------------------------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE vl_fechamento <= 0
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50002, '[trg_validar_preco]: vl_fechamento não pode ser negativo ou zero.', 1;
        RETURN;
    END;

    -- -------------------------------------------------------------------------
    -- REGRA 3: vl_maximo deve ser maior que zero
    -- -------------------------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE vl_maximo <= 0
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50003, '[trg_validar_preco]: vl_maximo não pode ser negativo ou zero.', 1;
        RETURN;
    END;

    -- -------------------------------------------------------------------------
    -- REGRA 4: vl_minimo deve ser maior que zero
    -- -------------------------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE vl_minimo <= 0
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50004, '[trg_validar_preco]: vl_minimo não pode ser negativo ou zero.', 1;
        RETURN;
    END;

    -- -------------------------------------------------------------------------
    -- REGRA 5: vl_maximo não pode ser menor que vl_minimo
    -- -------------------------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE vl_maximo < vl_minimo
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50005, '[trg_validar_preco]: vl_maximo não pode ser menor que vl_minimo.', 1;
        RETURN;
    END;

    -- -------------------------------------------------------------------------
    -- REGRA 6: vl_fechamento deve estar entre vl_minimo e vl_maximo
    -- -------------------------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE vl_fechamento < vl_minimo
           OR vl_fechamento > vl_maximo
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50006, '[trg_validar_preco]: vl_fechamento deve estar entre vl_minimo e vl_maximo.', 1;
        RETURN;
    END;

    -- -------------------------------------------------------------------------
    -- REGRA 7: vl_volume não pode ser negativo
    -- -------------------------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE vl_volume < 0
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50007, '[trg_validar_preco]: vl_volume não pode ser negativo.', 1;
        RETURN;
    END;

END;
GO


-- =============================================================================
-- VERIFICAÇÃO — testar o comportamento do trigger
-- =============================================================================

/*
-- Esta inserção será BLOQUEADA (vl_fechamento negativo):
INSERT INTO dbo.fato_cotacao
    (id_acao, id_data, vl_abertura, vl_fechamento, vl_maximo, vl_minimo, vl_volume)
VALUES
    (1, 1, 10.00, -5.00, 12.00, 8.00, 100000);
-- Erro 50002: [trg_validar_preco]: vl_fechamento não pode ser negativo ou zero.

-- Esta inserção será BLOQUEADA (vl_maximo < vl_minimo):
INSERT INTO dbo.fato_cotacao
    (id_acao, id_data, vl_abertura, vl_fechamento, vl_maximo, vl_minimo, vl_volume)
VALUES
    (1, 1, 10.00, 9.00, 8.00, 11.00, 100000);
-- Erro 50005: [trg_validar_preco]: vl_maximo não pode ser menor que vl_minimo.

-- Verificar triggers ativos
SELECT name, is_disabled, create_date
FROM sys.triggers
WHERE parent_id = OBJECT_ID('dbo.fato_cotacao')
ORDER BY name;
*/
