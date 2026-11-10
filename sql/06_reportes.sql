-- =====================================================================
-- Proyecto : Desarrollo de la base de datos para la funcionalidad
--            "Registro de Licitaciones de Servicios" - TECNOSERVI S.R.L.
-- Gestor   : PostgreSQL
-- Archivo  : 06_reportes.sql  (vistas de los reportes del aplicativo)
-- Uso      : Query Tool abierto sobre "bd_licitaciones". Ejecutar todo (F5).
--            Requiere 01 y 05. Puede volver a ejecutarse.
--
-- Cada reporte es una vista: el aplicativo hace SELECT sobre ella y, si el
-- reporte tiene parámetro (licitación, propuesta, empresa), lo aplica como
-- filtro WHERE. Las vistas R01-R10 corresponden a las consultas C01-C10 de
-- 03_consultas.sql, sin el valor fijo del filtro. R11-R13 muestran lo que
-- registran los triggers de 05_triggers.sql.
--
--   Reporte                                   JOIN
--   R01 Agenda de licitaciones abiertas       sí
--   R02 Datos para DJ y carta de autorización sí
--   R03 Formato de propuesta económica        sí
--   R04 Habilitación SUNAT y RNP              sí
--   R05 Certificación de cada equipo          sí
--   R06 Alertas del expediente (RA2/RA3/RA5)  sí
--   R07 Resultados por entidad contratante    sí
--   R08 Montos por trimestre                  sí
--   R09 Historial de precios unitarios        sí
--   R10 Uso de la maquinaria                  sí
--   R11 Historial de estados de licitación    sí
--   R12 Historial de verificaciones SUNAT/RNP sí
--   R13 Bitácora de operaciones               no
-- =====================================================================

DO $$
BEGIN
    IF current_database() <> 'bd_licitaciones' THEN
        RAISE EXCEPTION 'Abra el Query Tool sobre la base bd_licitaciones (ahora está en %)',
            current_database();
    END IF;
END $$;

SET search_path TO licitaciones, public;

-- Borra las vistas de reporte anteriores (CREATE OR REPLACE VIEW no admite
-- cambiar el tipo de una columna, así el script siempre puede repetirse).
DO $$
DECLARE
    v_vista text;
BEGIN
    FOR v_vista IN SELECT table_name FROM information_schema.views
                    WHERE table_schema = 'licitaciones' AND table_name LIKE 'vw\_rep%'
    LOOP
        EXECUTE format('DROP VIEW %I', v_vista);
    END LOOP;
END $$;


-- R01. ¿Qué requerimientos tengo pendientes y cuántos días me quedan?
CREATE OR REPLACE VIEW vw_rep01_agenda_licitaciones AS
SELECT l.codigo_licitacion,
       e.razon_social                             AS entidad,
       l.nro_requerimiento,
       l.objeto,
       l.estado,
       l.fecha_limite_presentacion                AS fecha_limite,
       l.fecha_limite_presentacion - CURRENT_DATE AS dias_restantes,
       CASE
           WHEN l.fecha_limite_presentacion IS NULL             THEN 'SIN FECHA LÍMITE'
           WHEN l.fecha_limite_presentacion < CURRENT_DATE      THEN 'VENCIDA'
           WHEN l.fecha_limite_presentacion - CURRENT_DATE <= 7 THEN 'URGENTE'
           ELSE 'EN PLAZO'
       END                                        AS alerta,
       CASE WHEN p.codigo_propuesta IS NULL THEN 'NO' ELSE 'SÍ' END AS propuesta_iniciada
FROM licitacion l
JOIN entidad_contratante e      ON e.ruc_entidad = l.ruc_entidad
LEFT JOIN propuesta_comercial p ON p.codigo_licitacion = l.codigo_licitacion
WHERE l.estado IN ('REGISTRADA', 'EN PREPARACIÓN')
ORDER BY l.fecha_limite_presentacion NULLS LAST;


-- R02. ¿Con qué datos lleno la declaración jurada y la carta de autorización?
--      Parámetro: codigo_licitacion
CREATE OR REPLACE VIEW vw_rep02_datos_dj_carta AS
SELECT l.codigo_licitacion,
       ec.razon_social                                                   AS entidad,
       l.dependencia_destino                                             AS atencion,
       l.nro_requerimiento,
       p.codigo_propuesta,
       p.fecha_emision,
       em.razon_social                                                   AS postor,
       em.numero_ruc                                                     AS ruc_postor,
       concat_ws(' ', r.nombres, r.apellido_paterno, r.apellido_materno) AS representante,
       r.dni,
       r.cargo,
       r.correo_notificacion,
       r.telefono,
       cb.codigo_cci,
       cb.entidad_bancaria
FROM licitacion l
JOIN entidad_contratante ec  ON ec.ruc_entidad = l.ruc_entidad
JOIN propuesta_comercial p   ON p.codigo_licitacion = l.codigo_licitacion
JOIN representante_legal r   ON r.dni = p.dni_suscriptor
JOIN empresa em              ON em.numero_ruc = r.ruc_empresa
LEFT JOIN cuenta_bancaria cb ON cb.codigo_cci = p.cci_abono
ORDER BY l.codigo_licitacion;


-- R03. ¿Cuál es el detalle, total, plazo y forma de pago de una propuesta?
--      Parámetro: codigo_propuesta
CREATE OR REPLACE VIEW vw_rep03_formato_propuesta AS
SELECT i.codigo_propuesta,
       i.nro_item,
       i.descripcion,
       i.unidad_medida,
       i.cantidad,
       i.precio_unitario,
       (i.cantidad * i.precio_unitario)::numeric(12,2) AS subtotal,
       t.precio_total,
       p.plazo_ejecucion_dias,
       (SELECT string_agg('ARMADA ' || a.nro_armada || ' A LOS ' || a.dias_plazo
                          || ' DÍAS: ' || a.condicion, ' / ' ORDER BY a.nro_armada)
          FROM armada_pago a
         WHERE a.codigo_propuesta = p.codigo_propuesta) AS forma_de_pago
FROM item_propuesta i
JOIN propuesta_comercial p ON p.codigo_propuesta = i.codigo_propuesta
JOIN vw_propuesta_total t  ON t.codigo_propuesta = i.codigo_propuesta
ORDER BY i.codigo_propuesta, i.nro_item;


-- R04. ¿Está la empresa habilitada para presentar hoy (SUNAT y RNP)?
--      Parámetro opcional: numero_ruc
CREATE OR REPLACE VIEW vw_rep04_habilitacion_empresa AS
SELECT e.razon_social,
       e.numero_ruc,
       e.estado_contribuyente,
       e.condicion_contribuyente,
       h.estado_inscripcion                         AS rnp_servicios,
       e.fecha_verificacion_sunat,
       h.fecha_verificacion                         AS fecha_verificacion_rnp,
       CURRENT_DATE - LEAST(e.fecha_verificacion_sunat, h.fecha_verificacion)
                                                    AS dias_desde_verificacion,
       CASE
           WHEN e.estado_contribuyente = 'ACTIVO'
            AND e.condicion_contribuyente = 'HABIDO'
            AND h.estado_inscripcion = 'VIGENTE'   THEN 'HABILITADA'
           ELSE 'NO HABILITADA'
       END                                          AS situacion,
       CASE
           WHEN CURRENT_DATE - LEAST(e.fecha_verificacion_sunat, h.fecha_verificacion) > 30
           THEN 'VOLVER A VERIFICAR EN SUNAT Y RNP'
           ELSE 'VERIFICACIÓN AL DÍA'
       END                                          AS accion
FROM empresa e
LEFT JOIN habilitacion_rnp h
       ON h.numero_ruc = e.numero_ruc
      AND h.tipo_registro = 'PROVEEDOR DE SERVICIOS'
ORDER BY e.razon_social;


-- R05. ¿Qué equipos tienen su certificado vencido o por vencer?
CREATE OR REPLACE VIEW vw_rep05_certificacion_equipos AS
SELECT m.placa,
       me.tipo_equipo,
       m.marca || ' ' || m.modelo                  AS equipo,
       me.capacidad_ton,
       em.razon_social                             AS propietario,
       (SELECT count(*) FROM certificado_maquinaria c3
         WHERE c3.placa = m.placa)                 AS certificados_emitidos,
       c.codigo_certificado                        AS ultimo_certificado,
       c.fecha_caducidad,
       c.fecha_caducidad - CURRENT_DATE            AS dias_para_vencer,
       CASE
           WHEN c.codigo_certificado IS NULL             THEN 'SIN CERTIFICADO'
           WHEN c.fecha_caducidad < CURRENT_DATE         THEN 'VENCIDO'
           WHEN c.fecha_caducidad - CURRENT_DATE <= 30   THEN 'POR VENCER'
           ELSE 'VIGENTE'
       END                                         AS estado_vigencia
FROM maquinaria m
JOIN modelo_equipo me ON me.marca = m.marca AND me.modelo = m.modelo
JOIN empresa em       ON em.numero_ruc = m.ruc_propietario
LEFT JOIN certificado_maquinaria c
       ON c.placa = m.placa
      AND c.fecha_caducidad = (SELECT max(c2.fecha_caducidad)
                                 FROM certificado_maquinaria c2
                                WHERE c2.placa = m.placa)
ORDER BY dias_para_vencer NULLS FIRST;


-- R06. ¿Hay algún expediente con datos inconsistentes? (RA2, RA3 y RA5)
--      Los triggers impiden que se registren nuevos casos; esta vista
--      detecta los que ya estaban en la base.
CREATE OR REPLACE VIEW vw_rep06_alertas_expediente AS
SELECT * FROM (
    SELECT 'RA2'                                   AS regla,
           p.codigo_propuesta,
           p.codigo_licitacion,
           'El equipo ' || pm.placa || ' no tiene certificado vigente al '
               || to_char(p.fecha_emision, 'DD/MM/YYYY') AS detalle
    FROM propuesta_maquinaria pm
    JOIN propuesta_comercial p ON p.codigo_propuesta = pm.codigo_propuesta
    WHERE NOT EXISTS (SELECT 1
                        FROM certificado_maquinaria c
                       WHERE c.placa = pm.placa
                         AND p.fecha_emision BETWEEN c.fecha_inspeccion AND c.fecha_caducidad)
    UNION ALL
    SELECT 'RA3',
           p.codigo_propuesta,
           p.codigo_licitacion,
           'La cuenta ' || p.cci_abono || ' no pertenece a la empresa del suscriptor'
    FROM propuesta_comercial p
    JOIN representante_legal r ON r.dni = p.dni_suscriptor
    JOIN cuenta_bancaria cb    ON cb.codigo_cci = p.cci_abono
    WHERE cb.ruc_titular <> r.ruc_empresa
    UNION ALL
    SELECT 'RA5',
           NULL,
           l.codigo_licitacion,
           'Figura como ' || l.estado || ' pero no tiene propuesta registrada'
    FROM licitacion l
    WHERE l.estado IN ('PRESENTADA', 'ADJUDICADA', 'NO ADJUDICADA')
      AND NOT EXISTS (SELECT 1 FROM propuesta_comercial p
                       WHERE p.codigo_licitacion = l.codigo_licitacion)
) alertas
ORDER BY regla, codigo_licitacion;


-- R07. ¿Con qué entidades nos va mejor y cuánto nos han adjudicado?
CREATE OR REPLACE VIEW vw_rep07_resultados_entidad AS
SELECT ec.razon_social                                         AS entidad,
       COUNT(*)                                                AS registradas,
       COUNT(t.codigo_propuesta)                               AS con_propuesta,
       COUNT(*) FILTER (WHERE l.estado = 'ADJUDICADA')         AS adjudicadas,
       COUNT(*) FILTER (WHERE l.estado = 'NO ADJUDICADA')      AS no_adjudicadas,
       ROUND(100.0 * COUNT(*) FILTER (WHERE l.estado = 'ADJUDICADA')
             / NULLIF(COUNT(*) FILTER (WHERE l.estado IN ('ADJUDICADA', 'NO ADJUDICADA')), 0), 1)
                                                               AS tasa_adjudicacion_pct,
       COALESCE(SUM(t.precio_total) FILTER (WHERE l.estado = 'ADJUDICADA'), 0)
                                                               AS monto_adjudicado
FROM licitacion l
JOIN entidad_contratante ec    ON ec.ruc_entidad = l.ruc_entidad
LEFT JOIN vw_propuesta_total t ON t.codigo_licitacion = l.codigo_licitacion
GROUP BY ec.razon_social
ORDER BY monto_adjudicado DESC, entidad;


-- R08. ¿Cuánto hemos ofertado y cuánto hemos ganado en cada trimestre?
CREATE OR REPLACE VIEW vw_rep08_montos_trimestre AS
SELECT to_char(p.fecha_emision, 'YYYY') || '-T' || to_char(p.fecha_emision, 'Q') AS trimestre,
       COUNT(*)                                                AS propuestas,
       COUNT(*) FILTER (WHERE l.estado = 'ADJUDICADA')         AS adjudicadas,
       SUM(t.precio_total)                                     AS monto_ofertado,
       COALESCE(SUM(t.precio_total) FILTER (WHERE l.estado = 'ADJUDICADA'), 0)
                                                               AS monto_adjudicado
FROM propuesta_comercial p
JOIN vw_propuesta_total t ON t.codigo_propuesta = p.codigo_propuesta
JOIN licitacion l         ON l.codigo_licitacion = p.codigo_licitacion
GROUP BY trimestre
ORDER BY trimestre;


-- R09. ¿A qué precio cotizamos cada servicio, cuando ganamos y cuando perdimos?
CREATE OR REPLACE VIEW vw_rep09_historial_precios AS
SELECT i.descripcion,
       i.unidad_medida,
       COUNT(*)                                                      AS veces_cotizado,
       MIN(i.precio_unitario)                                        AS precio_min,
       MAX(i.precio_unitario)                                        AS precio_max,
       ROUND(AVG(i.precio_unitario), 2)                              AS precio_promedio,
       ROUND(AVG(i.precio_unitario) FILTER (WHERE l.estado = 'ADJUDICADA'), 2)
                                                                     AS promedio_ganadas,
       ROUND(AVG(i.precio_unitario) FILTER (WHERE l.estado = 'NO ADJUDICADA'), 2)
                                                                     AS promedio_perdidas,
       MAX(p.fecha_emision)                                          AS ultima_cotizacion
FROM item_propuesta i
JOIN propuesta_comercial p ON p.codigo_propuesta = i.codigo_propuesta
JOIN licitacion l          ON l.codigo_licitacion = p.codigo_licitacion
WHERE i.unidad_medida <> 'GLOBAL'          -- solo precios unitarios comparables
GROUP BY i.descripcion, i.unidad_medida
HAVING COUNT(*) >= 2
ORDER BY veces_cotizado DESC, i.descripcion;


-- R10. ¿Qué equipos ofertamos más, propios o subcontratados, y cuántas veces ganamos?
CREATE OR REPLACE VIEW vw_rep10_uso_maquinaria AS
SELECT m.placa,
       m.marca || ' ' || m.modelo                          AS equipo,
       me.tipo_equipo,
       em.razon_social                                     AS propietario,
       CASE WHEN m.ruc_propietario = '20216292783'          -- RUC de la empresa postora
            THEN 'PROPIO' ELSE 'SUBCONTRATADO' END         AS origen,
       COUNT(pm.codigo_propuesta)                          AS veces_ofertado,
       COUNT(*) FILTER (WHERE l.estado = 'ADJUDICADA')     AS veces_adjudicado,
       MAX(p.fecha_emision)                                AS ultima_oferta
FROM maquinaria m
JOIN modelo_equipo me             ON me.marca = m.marca AND me.modelo = m.modelo
JOIN empresa em                   ON em.numero_ruc = m.ruc_propietario
LEFT JOIN propuesta_maquinaria pm ON pm.placa = m.placa
LEFT JOIN propuesta_comercial p   ON p.codigo_propuesta = pm.codigo_propuesta
LEFT JOIN licitacion l            ON l.codigo_licitacion = p.codigo_licitacion
GROUP BY m.placa, m.marca, m.modelo, me.tipo_equipo, em.razon_social, m.ruc_propietario
ORDER BY veces_ofertado DESC, m.placa;


-- R11. ¿Cuándo cambió de estado cada licitación y quién lo hizo?
--      Parámetro opcional: codigo_licitacion
CREATE OR REPLACE VIEW vw_rep11_historial_estados AS
SELECT h.codigo_licitacion,
       ec.razon_social                                   AS entidad,
       l.nro_requerimiento,
       h.fecha_cambio,
       COALESCE(h.estado_anterior, '(registro)')         AS estado_anterior,
       h.estado_nuevo,
       h.usuario,
       l.estado                                          AS estado_actual
FROM historial_estado_licitacion h
JOIN licitacion l           ON l.codigo_licitacion = h.codigo_licitacion
JOIN entidad_contratante ec ON ec.ruc_entidad = l.ruc_entidad
ORDER BY h.codigo_licitacion, h.fecha_cambio, h.id_historial;


-- R12. ¿Cómo ha variado la situación SUNAT / RNP de cada empresa?
--      Parámetro opcional: numero_ruc
CREATE OR REPLACE VIEW vw_rep12_historial_verificaciones AS
SELECT v.numero_ruc,
       e.razon_social,
       v.fecha_registro,
       v.origen,
       v.estado_contribuyente,
       v.condicion_contribuyente,
       v.fecha_verificacion_sunat,
       v.estado_rnp,
       v.fecha_verificacion_rnp,
       v.usuario
FROM historial_verificacion v
JOIN empresa e ON e.numero_ruc = v.numero_ruc
ORDER BY e.razon_social, v.fecha_registro, v.id_verificacion;


-- R13. ¿Qué operaciones se hicieron en la base, cuándo y por quién?
CREATE OR REPLACE VIEW vw_rep13_bitacora AS
SELECT b.id_bitacora,
       b.fecha_hora,
       b.usuario,
       b.aplicacion,
       b.tabla,
       b.operacion,
       b.columnas_modificadas,
       b.datos_anteriores::text                          AS datos_anteriores,
       b.datos_nuevos::text                              AS datos_nuevos
FROM bitacora b
ORDER BY b.id_bitacora DESC;


-- ---------------------------------------------------------------------
-- Verificación (resultado esperado: 13 vistas de reporte)
-- ---------------------------------------------------------------------
SELECT count(*) AS vistas_de_reporte
FROM information_schema.views
WHERE table_schema = 'licitaciones'
  AND table_name LIKE 'vw_rep%';
