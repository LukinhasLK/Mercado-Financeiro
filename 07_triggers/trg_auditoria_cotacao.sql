-- =============================================================================
-- ARQUIVO  : 07_triggers/trg_auditoria_cotacao.sql
-- PROJETO  : Mercado Financeiro B3
-- AUTOR    : Luigi Sapucaia de Lima
-- DESCRIÇÃO: Trigger de auditoria que registra toda operação de INSERT,
--            UPDATE e DELETE na tabela fato_cotacao dentro de log_auditoria.
-- BANCO    : SQL Server 2017+ (T-SQL)
-- =============================================================================

USE MercadoFinanceiro;
GO

-- =============================================================================
-- Criação da tabela de log (caso ainda não exista)
-- =============================================================================

IF NOT EXISTS (
    SELECT 1 FROM sys.objects
    WHERE object_id = OBJECT_ID(N'dbo.log_auditoria') AND type = 'U'
)
BEGIN
    CREATE TABLE dbo.log_auditoria (
        id_log          INT             NOT NULL IDENTITY(1,1),
        ds_operacao     VARCHAR(10)     NOT NULL,   -- INSERT / UPDATE / DELETE
        ds_tabela       VARCHAR(100)    NOT NULL,   -- Nome da tabela afetada
        ds_usuario      VARCHAR(100)    NOT NULL,   -- Usuário que executou
        ds_dados_antes  NVARCHAR(MAX)   NULL,       -- Snapshot antes (UPDATE/DELETE)
        ds_dados_depois NVARCHAR(MAX)   NULL,       -- Snapshot depois (INSERT/UPDATE)
        dt_operacao     DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT pk_log_auditoria PRIMARY KEY (id_log)
    );
END;
GO


-- =============================================================================
-- Trigger de auditoria — INSERT
-- =============================================================================

IF OBJECT_ID(N'dbo.trg_auditoria_cotacao_insert', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_auditoria_cotacao_insert;
GO

CREATE TRIGGER dbo.trg_auditoria_cotacao_insert
ON dbo.fato_cotacao
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.log_auditoria
        (ds_operacao, ds_tabela, ds_usuario, ds_dados_antes, ds_dados_depois)
    SELECT
        'INSERT',
        'fato_cotacao',
        SYSTEM_USER,
        NULL,
        CONCAT(
            'id_cotacao=',  i.id_cotacao,
            ' | id_acao=',  i.id_acao,
            ' | id_data=',  i.id_data,
            ' | vl_fechamento=', i.vl_fechamento,
            ' | vl_abertura=',  i.vl_abertura,
            ' | vl_maximo=',    i.vl_maximo,
            ' | vl_minimo=',    i.vl_minimo,
            ' | vl_volume=',    i.vl_volume
        )
    FROM inserted i;
END;
GO


-- =============================================================================
-- Trigger de auditoria — UPDATE
-- =============================================================================

IF OBJECT_ID(N'dbo.trg_auditoria_cotacao_update', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_auditoria_cotacao_update;
GO

CREATE TRIGGER dbo.trg_auditoria_cotacao_update
ON dbo.fato_cotacao
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.log_auditoria
        (ds_operacao, ds_tabela, ds_usuario, ds_dados_antes, ds_dados_depois)
    SELECT
        'UPDATE',
        'fato_cotacao',
        SYSTEM_USER,
        CONCAT(
            'id_cotacao=',  d.id_cotacao,
            ' | vl_fechamento=', d.vl_fechamento,
            ' | vl_abertura=',  d.vl_abertura,
            ' | vl_maximo=',    d.vl_maximo,
            ' | vl_minimo=',    d.vl_minimo,
            ' | vl_volume=',    d.vl_volume
        ),
        CONCAT(
            'id_cotacao=',  i.id_cotacao,
            ' | vl_fechamento=', i.vl_fechamento,
            ' | vl_abertura=',  i.vl_abertura,
            ' | vl_maximo=',    i.vl_maximo,
            ' | vl_minimo=',    i.vl_minimo,
            ' | vl_volume=',    i.vl_volume
        )
    FROM inserted i
    JOIN deleted  d ON d.id_cotacao = i.id_cotacao;
END;
GO


-- =============================================================================
-- Trigger de auditoria — DELETE
-- =============================================================================

IF OBJECT_ID(N'dbo.trg_auditoria_cotacao_delete', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_auditoria_cotacao_delete;
GO

CREATE TRIGGER dbo.trg_auditoria_cotacao_delete
ON dbo.fato_cotacao
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.log_auditoria
        (ds_operacao, ds_tabela, ds_usuario, ds_dados_antes, ds_dados_depois)
    SELECT
        'DELETE',
        'fato_cotacao',
        SYSTEM_USER,
        CONCAT(
            'id_cotacao=',  d.id_cotacao,
            ' | id_acao=',  d.id_acao,
            ' | id_data=',  d.id_data,
            ' | vl_fechamento=', d.vl_fechamento,
            ' | vl_volume=',    d.vl_volume
        ),
        NULL
    FROM deleted d;
END;
GO


-- =============================================================================
-- VERIFICAÇÃO — consultar o log de auditoria
-- =============================================================================

/*
-- Últimas 50 operações
SELECT TOP 50
    id_log, ds_operacao, ds_tabela, ds_usuario,
    ds_dados_antes, ds_dados_depois, dt_operacao
FROM dbo.log_auditoria
ORDER BY dt_operacao DESC;

-- Filtrar por operação
SELECT * FROM dbo.log_auditoria WHERE ds_operacao = 'DELETE' ORDER BY dt_operacao DESC;

-- Verificar triggers ativos na tabela
SELECT name, is_disabled, create_date
FROM sys.triggers
WHERE parent_id = OBJECT_ID('dbo.fato_cotacao')
ORDER BY name;
*/
