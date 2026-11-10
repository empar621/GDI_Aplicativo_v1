-- =====================================================================
-- Proyecto : Desarrollo de la base de datos para la funcionalidad
--            "Registro de Licitaciones de Servicios" - TECNOSERVI S.R.L.
-- Gestor   : PostgreSQL
-- Archivo  : 00_crear_base.sql
-- Uso      : Query Tool abierto sobre la base "postgres". Ejecutar con F5.
--            (CREATE DATABASE no puede ir junto con otras sentencias)
-- =====================================================================

CREATE DATABASE bd_licitaciones
    WITH TEMPLATE = template0
         ENCODING = 'UTF8';
