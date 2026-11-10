-- =====================================================================
-- Proyecto : Desarrollo de la base de datos para la funcionalidad
--            "Registro de Licitaciones de Servicios" - TECNOSERVI S.R.L.
-- Gestor   : PostgreSQL
-- Archivo  : 03_consultas.sql  (10 consultas de la funcionalidad)
-- Uso      : Query Tool abierto sobre "bd_licitaciones".
--            Ejecute CADA consulta por separado: selecciónela y pulse F5
--            (si ejecuta todo el archivo, pgAdmin solo muestra el último
--            resultado). Las consultas C01, C04 y C05 usan la fecha actual
--            (CURRENT_DATE), por lo que sus resultados cambian con el día.
-- =====================================================================
SET search_path TO licitaciones, public;


-- ---------------------------------------------------------------------
-- C01. Agenda de licitaciones abiertas
-- Pregunta: ¿Qué requerimientos tengo pendientes y cuántos días me quedan
--           para presentar cada uno?
-- Tarea   : Registro del requerimiento / seguimiento
-- ---------------------------------------------------------------------
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
JOIN entidad_contratante e     ON e.ruc_entidad = l.ruc_entidad
LEFT JOIN propuesta_comercial p ON p.codigo_licitacion = l.codigo_licitacion
WHERE l.estado IN ('REGISTRADA', 'EN PREPARACIÓN')
ORDER BY l.fecha_limite_presentacion NULLS LAST;


-- ---------------------------------------------------------------------
-- C02. Datos para la declaración jurada y la carta de autorización
-- Pregunta: ¿Con qué datos lleno la DJ y la carta de autorización del
--           requerimiento 00001340 de la Municipalidad de Sachaca?
-- Tarea   : Información corporativa y financiera / habilitaciones legales
-- ---------------------------------------------------------------------
SELECT ec.razon_social                                              AS entidad,
       l.dependencia_destino                                        AS atencion,
       l.nro_requerimiento,
       p.codigo_propuesta,
       p.fecha_emision,
       em.razon_social                                              AS postor,
       em.numero_ruc                                                AS ruc_postor,
       concat_ws(' ', r.nombres, r.apellido_paterno, r.apellido_materno) AS representante,
       r.dni,
       r.cargo,
       r.correo_notificacion,
       r.telefono,
       cb.codigo_cci,
       cb.entidad_bancaria
FROM licitacion l
JOIN entidad_contratante ec ON ec.ruc_entidad = l.ruc_entidad
JOIN propuesta_comercial p  ON p.codigo_licitacion = l.codigo_licitacion
JOIN representante_legal r  ON r.dni = p.dni_suscriptor
JOIN empresa em             ON em.numero_ruc = r.ruc_empresa
LEFT JOIN cuenta_bancaria cb ON cb.codigo_cci = p.cci_abono
WHERE ec.razon_social = 'MUNICIPALIDAD DISTRITAL DE SACHACA'
  AND l.nro_requerimiento = '00001340';


-- ---------------------------------------------------------------------
-- C03. Formato de propuesta económica
-- Pregunta: ¿Cuál es el detalle, el total, el plazo y la forma de pago de
--           la propuesta PROP-2025-0008?
-- Tarea   : Elaboración de las propuestas económicas
-- ---------------------------------------------------------------------
SELECT i.nro_item,
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
WHERE i.codigo_propuesta = 'PROP-2025-0008'
ORDER BY i.nro_item;


-- ---------------------------------------------------------------------
-- C04. Habilitación de la empresa para postular (SUNAT y RNP)
-- Pregunta: ¿Está la empresa habilitada para presentar hoy y cuándo se
--           verificó por última vez?
-- Tarea   : Información corporativa / validación de habilitaciones legales
-- ---------------------------------------------------------------------
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
WHERE e.numero_ruc = '20216292783';


-- ---------------------------------------------------------------------
-- C05. Estado de certificación de cada equipo
-- Pregunta: ¿Qué equipos tienen su certificado vencido o por vencer?
-- Tarea   : Control de certificaciones de maquinaria
-- ---------------------------------------------------------------------
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


-- ---------------------------------------------------------------------
-- C06. Alertas de control del expediente (reglas RA2, RA3 y RA5)
-- Pregunta: ¿Hay algún expediente con datos inconsistentes antes de
--           presentarlo?
-- Tarea   : Control de certificaciones / elaboración de propuestas
-- ---------------------------------------------------------------------
-- RA2: equipo asignado sin certificado vigente a la fecha de la propuesta
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
-- RA3: cuenta de abono que no pertenece a la empresa del suscriptor
SELECT 'RA3',
       p.codigo_propuesta,
       p.codigo_licitacion,
       'La cuenta ' || p.cci_abono || ' no pertenece a la empresa del suscriptor'
FROM propuesta_comercial p
JOIN representante_legal r ON r.dni = p.dni_suscriptor
JOIN cuenta_bancaria cb    ON cb.codigo_cci = p.cci_abono
WHERE cb.ruc_titular <> r.ruc_empresa
UNION ALL
-- RA5: licitación presentada o con resultado, pero sin propuesta registrada
SELECT 'RA5',
       NULL,
       l.codigo_licitacion,
       'Figura como ' || l.estado || ' pero no tiene propuesta registrada'
FROM licitacion l
WHERE l.estado IN ('PRESENTADA', 'ADJUDICADA', 'NO ADJUDICADA')
  AND NOT EXISTS (SELECT 1 FROM propuesta_comercial p
                  WHERE p.codigo_licitacion = l.codigo_licitacion)
ORDER BY regla, codigo_licitacion;


-- ---------------------------------------------------------------------
-- C07. Resultados por entidad contratante
-- Pregunta: ¿Con qué entidades nos va mejor y cuánto nos han adjudicado?
-- Tarea   : Presentación y seguimiento del resultado
-- ---------------------------------------------------------------------
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


-- ---------------------------------------------------------------------
-- C08. Monto ofertado y adjudicado por trimestre
-- Pregunta: ¿Cuánto hemos ofertado y cuánto hemos ganado en cada trimestre?
-- Tarea   : Presentación y seguimiento del resultado
-- ---------------------------------------------------------------------
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


-- ---------------------------------------------------------------------
-- C09. Historial de precios unitarios por servicio
-- Pregunta: ¿A qué precio hemos cotizado cada servicio y a cuánto lo
--           cotizamos cuando ganamos y cuando perdimos?
-- Tarea   : Elaboración de las propuestas económicas (fijar precios)
-- ---------------------------------------------------------------------
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


-- ---------------------------------------------------------------------
-- C10. Uso de la maquinaria en las propuestas
-- Pregunta: ¿Qué equipos ofertamos más, cuáles son propios o
--           subcontratados y cuántas veces ganamos con cada uno?
-- Tarea   : Control de certificaciones / elaboración de propuestas
-- ---------------------------------------------------------------------
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
