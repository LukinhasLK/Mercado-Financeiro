-- =============================================================================
-- ARQUIVO  : 08_dcl/roles_e_permissoes_sqlserver.sql
-- PROJETO  : Mercado Financeiro B3
-- AUTOR    : Luigi Sapucaia de Lima
-- DESCRIÇÃO: Criação de 3 perfis de acesso (Roles) usando T-SQL,
--            com GRANT, DENY e REVOKE conforme princípio do menor privilégio.
-- BANCO    : SQL Server (T-SQL)
-- =============================================================================

USE MercadoFinanceiro;
GO

-- =============================================================================
-- BLOCO 1 — CRIAÇÃO DAS ROLES
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'role_leitura' AND type = 'R')
    CREATE ROLE role_leitura;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'role_analista' AND type = 'R')
    CREATE ROLE role_analista;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'role_admin' AND type = 'R')
    CREATE ROLE role_admin;
GO


-- =============================================================================
-- BLOCO 2 — PERMISSÕES: role_leitura
-- Perfil: consumidor básico (BI, stakeholder)
-- Pode: SELECT nas views e tabelas fato/dimensão
-- Não pode: INSERT, UPDATE, DELETE, EXECUTE, DDL
-- =============================================================================

-- Tabelas fato
GRANT SELECT ON dbo.fato_cotacao           TO role_leitura;
GRANT SELECT ON dbo.fato_indicadores       TO role_leitura;

-- Tabelas dimensão
GRANT SELECT ON dbo.dim_empresa            TO role_leitura;
GRANT SELECT ON dbo.dim_setor              TO role_leitura;
GRANT SELECT ON dbo.dim_data               TO role_leitura;
GRANT SELECT ON dbo.dim_indicador_macro    TO role_leitura;

-- Views (interface principal de consumo)
GRANT SELECT ON dbo.vw_cotacao_diaria          TO role_leitura;
GRANT SELECT ON dbo.vw_retorno_mensal          TO role_leitura;
GRANT SELECT ON dbo.vw_selic_vs_acoes          TO role_leitura;
GRANT SELECT ON dbo.vw_empresas_resilientes    TO role_leitura;
GRANT SELECT ON dbo.vw_volume_por_setor        TO role_leitura;

-- Nega explicitamente qualquer escrita (DENY sobrepõe GRANT)
DENY INSERT ON dbo.fato_cotacao            TO role_leitura;
DENY UPDATE ON dbo.fato_cotacao            TO role_leitura;
DENY DELETE ON dbo.fato_cotacao            TO role_leitura;
DENY INSERT ON dbo.fato_indicadores        TO role_leitura;
DENY UPDATE ON dbo.fato_indicadores        TO role_leitura;
DENY DELETE ON dbo.fato_indicadores        TO role_leitura;

-- Nega acesso ao log de auditoria
DENY SELECT ON dbo.log_auditoria           TO role_leitura;
GO


-- =============================================================================
-- BLOCO 3 — PERMISSÕES: role_analista
-- Perfil: analista / cientista de dados
-- Pode: tudo do role_leitura + EXECUTE nas SPs e Functions + SELECT em auditoria
-- Não pode: modificar dados, DDL
-- =============================================================================

-- Herda permissões de leitura
ALTER ROLE role_leitura ADD MEMBER role_analista;

-- Execução das Stored Procedures analíticas
GRANT EXECUTE ON dbo.usp_selic_vs_retorno_financeiras   TO role_analista;
GRANT EXECUTE ON dbo.usp_empresas_resilientes_covid      TO role_analista;

-- Execução das Functions
GRANT EXECUTE ON dbo.fn_retorno_acumulado                TO role_analista;
GRANT EXECUTE ON dbo.fn_volatilidade_historica           TO role_analista;

-- Leitura do log de auditoria
GRANT SELECT ON dbo.log_auditoria                        TO role_analista;

-- Nega escrita mesmo herdando role_leitura (reforço explícito)
DENY INSERT ON dbo.fato_cotacao        TO role_analista;
DENY UPDATE ON dbo.fato_cotacao        TO role_analista;
DENY DELETE ON dbo.fato_cotacao        TO role_analista;

-- Nega execução do ETL
DENY EXECUTE ON dbo.usp_etl_executar_pipeline            TO role_analista;
GO


-- =============================================================================
-- BLOCO 4 — PERMISSÕES: role_admin
-- Perfil: DBA / engenheiro de dados
-- Pode: controle total — INSERT, UPDATE, DELETE, EXECUTE, DDL
-- =============================================================================

-- Controle total sobre objetos do schema dbo
GRANT CONTROL ON SCHEMA::dbo                             TO role_admin;

-- Permissões explícitas de DDL no banco
GRANT CREATE TABLE  TO role_admin;
GRANT CREATE VIEW   TO role_admin;
GRANT CREATE PROCEDURE TO role_admin;
GRANT CREATE FUNCTION  TO role_admin;
GO


-- =============================================================================
-- BLOCO 5 — CRIAÇÃO DE LOGINS E USUÁRIOS DE EXEMPLO
-- =============================================================================

-- --- Usuário de leitura (ex.: Power BI / Looker Studio) ---
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'usr_bi')
BEGIN
    CREATE LOGIN usr_bi WITH PASSWORD = 'SenhaForte@BI2024',
        CHECK_EXPIRATION = ON,
        CHECK_POLICY = ON;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_bi')
BEGIN
    CREATE USER usr_bi FOR LOGIN usr_bi;
END;
GO

ALTER ROLE role_leitura ADD MEMBER usr_bi;
GO


-- --- Usuário analista (ex.: membro do time de analytics) ---
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'usr_analista')
BEGIN
    CREATE LOGIN usr_analista WITH PASSWORD = 'SenhaForte@Analista2024',
        CHECK_EXPIRATION = ON,
        CHECK_POLICY = ON;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_analista')
BEGIN
    CREATE USER usr_analista FOR LOGIN usr_analista;
END;
GO

ALTER ROLE role_analista ADD MEMBER usr_analista;
GO


-- --- Usuário administrador (ex.: DBA / engenheiro de dados) ---
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'usr_admin')
BEGIN
    CREATE LOGIN usr_admin WITH PASSWORD = 'SenhaForte@Admin2024',
        CHECK_EXPIRATION = ON,
        CHECK_POLICY = ON;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_admin')
BEGIN
    CREATE USER usr_admin FOR LOGIN usr_admin;
END;
GO

ALTER ROLE role_admin ADD MEMBER usr_admin;
GO


-- =============================================================================
-- BLOCO 6 — REVOGAÇÕES EXPLÍCITAS
-- =============================================================================

-- role_leitura não tem EXECUTE no pipeline de ETL (nunca foi concedido)
GO


-- =============================================================================
-- BLOCO 7 — VERIFICAÇÃO
-- =============================================================================

-- Ver todos os membros de cada role:
/*
SELECT
    r.name  AS role_name,
    m.name  AS membro
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
ORDER BY r.name, m.name;

-- Ver permissões concedidas a cada role:
SELECT
    pr.name         AS role_name,
    p.class_desc,
    p.permission_name,
    p.state_desc    AS grant_or_deny
FROM sys.database_permissions p
JOIN sys.database_principals pr ON pr.principal_id = p.grantee_principal_id
WHERE pr.type = 'R'
ORDER BY pr.name, p.permission_name;
*/
