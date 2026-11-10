-- =====================================================================
-- Proyecto : Desarrollo de la base de datos para la funcionalidad
--            "Registro de Licitaciones de Servicios" - TECNOSERVI S.R.L.
-- Gestor   : PostgreSQL
-- Archivo  : 05_triggers.sql  (tablas de historial, funciones y triggers)
-- Uso      : Query Tool abierto sobre "bd_licitaciones". Ejecutar todo (F5).
--            Requiere 01, 02 y 04. Puede volver a ejecutarse.
--
-- IMPORTANTE: ejecutar DESPUÉS de cargar los datos (02_insertar_datos.sql).
-- Los triggers aplican reglas de negocio que los datos históricos de prueba
-- no siempre cumplen (por ejemplo, la propuesta PROP-2026-0009 usa un
-- equipo cuyo certificado ya venció; la consulta C06 lo detecta). Para
-- recargar los datos desde cero use instalar_bd.bat, que ejecuta los
-- scripts en el orden correcto.
--
-- PostgreSQL ejecuta los triggers de un mismo momento (BEFORE / AFTER) en
-- orden alfabético de nombre; por eso llevan un número:
--   tg_10_normalizar   BEFORE  limpia y pasa a mayúsculas los textos
--   tg_20_...          BEFORE  reglas de negocio y códigos automáticos
--   tg_80_...          AFTER   historiales y cambios de estado derivados
--   tg_90_auditoria    AFTER   bitácora de todas las operaciones
-- =====================================================================

DO $$
BEGIN
    IF current_database() <> 'bd_licitaciones' THEN
        RAISE EXCEPTION 'Abra el Query Tool sobre la base bd_licitaciones (ahora está en %)',
            current_database();
    END IF;
END $$;

SET search_path TO licitaciones, public;


-- =====================================================================
-- 1. TABLAS QUE LLENAN LOS TRIGGERS
--    Las dos primeras son las propuestas en la sección "Limitación" del
--    informe; la bitácora registra toda inserción, modificación y
--    eliminación hecha en las 14 tablas del modelo.
-- =====================================================================
CREATE TABLE IF NOT EXISTS historial_estado_licitacion (
    id_historial      bigint      GENERATED ALWAYS AS IDENTITY,
    codigo_licitacion char(13)    NOT NULL,
    fecha_cambio      timestamptz NOT NULL DEFAULT now(),
    estado_anterior   varchar(15),
    estado_nuevo      varchar(15) NOT NULL,
    usuario           varchar(63) NOT NULL DEFAULT current_user,
    CONSTRAINT pk_historial_estado PRIMARY KEY (id_historial),
    CONSTRAINT fk_historial_licitacion FOREIGN KEY (codigo_licitacion)
        REFERENCES licitacion (codigo_licitacion) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_historial_estado_licitacion
    ON historial_estado_licitacion (codigo_licitacion, fecha_cambio);

CREATE TABLE IF NOT EXISTS historial_verificacion (
    id_verificacion          bigint      GENERATED ALWAYS AS IDENTITY,
    numero_ruc               char(11)    NOT NULL,
    fecha_registro           timestamptz NOT NULL DEFAULT now(),
    origen                   varchar(5)  NOT NULL,
    estado_contribuyente     varchar(25) NOT NULL,
    condicion_contribuyente  varchar(15) NOT NULL,
    fecha_verificacion_sunat date        NOT NULL,
    estado_rnp               varchar(12),
    fecha_verificacion_rnp   date,
    usuario                  varchar(63) NOT NULL DEFAULT current_user,
    CONSTRAINT pk_historial_verificacion PRIMARY KEY (id_verificacion),
    CONSTRAINT fk_historial_verif_empresa FOREIGN KEY (numero_ruc)
        REFERENCES empresa (numero_ruc) ON DELETE CASCADE,
    CONSTRAINT ck_historial_verif_origen CHECK (origen IN ('SUNAT', 'RNP'))
);
CREATE INDEX IF NOT EXISTS idx_historial_verificacion_ruc
    ON historial_verificacion (numero_ruc, fecha_registro);

CREATE TABLE IF NOT EXISTS bitacora (
    id_bitacora          bigint      GENERATED ALWAYS AS IDENTITY,
    fecha_hora           timestamptz NOT NULL DEFAULT now(),
    usuario              varchar(63) NOT NULL DEFAULT current_user,
    aplicacion           varchar(63),
    tabla                varchar(63) NOT NULL,
    operacion            varchar(12) NOT NULL,
    columnas_modificadas text,
    datos_anteriores     jsonb,
    datos_nuevos         jsonb,
    CONSTRAINT pk_bitacora PRIMARY KEY (id_bitacora),
    CONSTRAINT ck_bitacora_operacion CHECK (operacion IN ('INSERCIÓN', 'MODIFICACIÓN', 'ELIMINACIÓN'))
);
CREATE INDEX IF NOT EXISTS idx_bitacora_fecha ON bitacora (fecha_hora);

COMMENT ON TABLE historial_estado_licitacion IS 'Cambios de estado de cada licitación (lo llena tg_80_historial_estado)';
COMMENT ON TABLE historial_verificacion      IS 'Verificaciones en SUNAT y RNP de cada empresa (lo llenan tg_80_verificacion)';
COMMENT ON TABLE bitacora                    IS 'Auditoría de inserciones, modificaciones y eliminaciones (lo llena tg_90_auditoria)';


-- =====================================================================
-- 2. FUNCIONES DE APOYO
-- =====================================================================

-- Detiene la operación si la propuesta ya fue presentada a la entidad:
-- desde ese momento su contenido es un documento entregado y no cambia.
CREATE OR REPLACE FUNCTION fn_validar_propuesta_editable(p_codigo_propuesta char(14))
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    v_licitacion char(13);
    v_estado     varchar(15);
BEGIN
    SELECT l.codigo_licitacion, l.estado
      INTO v_licitacion, v_estado
      FROM propuesta_comercial p
      JOIN licitacion l ON l.codigo_licitacion = p.codigo_licitacion
     WHERE p.codigo_propuesta = p_codigo_propuesta;

    IF v_estado IN ('PRESENTADA', 'ADJUDICADA', 'NO ADJUDICADA') THEN
        RAISE EXCEPTION 'La propuesta % ya fue presentada (licitación % en estado %): no se puede modificar',
            p_codigo_propuesta, v_licitacion, v_estado;
    END IF;
END $$;

-- Guarda una "foto" de la situación SUNAT + RNP (registro de proveedor de
-- servicios) de una empresa en historial_verificacion.
CREATE OR REPLACE FUNCTION fn_registrar_verificacion(p_numero_ruc char(11), p_origen varchar)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO historial_verificacion (numero_ruc, origen, estado_contribuyente,
                                        condicion_contribuyente, fecha_verificacion_sunat,
                                        estado_rnp, fecha_verificacion_rnp)
    SELECT e.numero_ruc, p_origen, e.estado_contribuyente, e.condicion_contribuyente,
           e.fecha_verificacion_sunat, h.estado_inscripcion, h.fecha_verificacion
      FROM empresa e
      LEFT JOIN habilitacion_rnp h
             ON h.numero_ruc = e.numero_ruc
            AND h.tipo_registro = 'PROVEEDOR DE SERVICIOS'
     WHERE e.numero_ruc = p_numero_ruc;
END $$;


-- =====================================================================
-- 3. FUNCIONES DE TRIGGER GENERALES (se aplican a las 14 tablas)
-- =====================================================================

-- tg_10_normalizar: quita espacios sobrantes, pasa los textos a MAYÚSCULAS
-- (convención de todos los datos del modelo) y convierte el texto vacío en
-- NULL. Recorre las columnas de la fila como JSON, así sirve para cualquier
-- tabla sin nombrar sus columnas.
CREATE OR REPLACE FUNCTION fn_tg_normalizar()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_fila jsonb;
BEGIN
    SELECT jsonb_object_agg(
               key,
               CASE WHEN jsonb_typeof(value) = 'string'
                    THEN COALESCE(to_jsonb(NULLIF(upper(trim(value #>> '{}')), '')), 'null'::jsonb)
                    ELSE value
               END)
      INTO v_fila
      FROM jsonb_each(to_jsonb(NEW));

    NEW := jsonb_populate_record(NEW, v_fila);
    RETURN NEW;
END $$;

-- tg_90_auditoria: deja constancia en la bitácora de quién hizo qué y
-- cuándo, con la fila antes y después del cambio.
CREATE OR REPLACE FUNCTION fn_tg_auditoria()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_anterior jsonb;
    v_nuevo    jsonb;
    v_columnas text;
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        v_anterior := to_jsonb(OLD);
    END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        v_nuevo := to_jsonb(NEW);
    END IF;

    IF TG_OP = 'UPDATE' THEN
        SELECT string_agg(n.key, ', ' ORDER BY n.key)
          INTO v_columnas
          FROM jsonb_each(v_nuevo) n
         WHERE n.value IS DISTINCT FROM v_anterior -> n.key;
        IF v_columnas IS NULL THEN
            RETURN NULL;                     -- no cambió nada: no se registra
        END IF;
    END IF;

    INSERT INTO bitacora (aplicacion, tabla, operacion, columnas_modificadas,
                          datos_anteriores, datos_nuevos)
    VALUES (NULLIF(current_setting('application_name', true), ''),
            TG_TABLE_NAME,
            CASE TG_OP WHEN 'INSERT' THEN 'INSERCIÓN'
                       WHEN 'UPDATE' THEN 'MODIFICACIÓN'
                       ELSE 'ELIMINACIÓN' END,
            v_columnas, v_anterior, v_nuevo);
    RETURN NULL;                             -- trigger AFTER: el valor se ignora
END $$;


-- =====================================================================
-- 4. FUNCIONES DE TRIGGER DE LICITACIÓN
-- =====================================================================

-- tg_20_validar (licitacion, BEFORE INSERT/UPDATE/DELETE)
--   * INSERT sin código: genera el siguiente LIC-AAAA-NNNN del año.
--   * Cambio de estado: aplica la regla RA5 y las transiciones válidas.
--   * DELETE: una licitación ya presentada no se borra, se cancela.
CREATE OR REPLACE FUNCTION fn_tg_licitacion_validar()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_anio      text;
    v_siguiente integer;
BEGIN
    IF TG_OP = 'DELETE' THEN
        IF OLD.estado IN ('PRESENTADA', 'ADJUDICADA', 'NO ADJUDICADA') THEN
            RAISE EXCEPTION 'La licitación % ya fue presentada (estado %): se conserva como antecedente. Si ya no interesa, cambie su estado a CANCELADA',
                OLD.codigo_licitacion, OLD.estado;
        END IF;
        RETURN OLD;
    END IF;

    IF TG_OP = 'INSERT' AND NEW.codigo_licitacion IS NULL THEN
        v_anio := to_char(COALESCE(NEW.fecha_registro, CURRENT_DATE), 'YYYY');
        SELECT COALESCE(max(substr(codigo_licitacion, 10, 4)::integer), 0) + 1
          INTO v_siguiente
          FROM licitacion
         WHERE codigo_licitacion LIKE 'LIC-' || v_anio || '-%';
        NEW.codigo_licitacion := 'LIC-' || v_anio || '-' || lpad(v_siguiente::text, 4, '0');
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.estado IS DISTINCT FROM OLD.estado THEN
        -- RA5: no puede figurar como presentada (o con resultado) sin propuesta
        IF NEW.estado IN ('PRESENTADA', 'ADJUDICADA', 'NO ADJUDICADA')
           AND NOT EXISTS (SELECT 1 FROM propuesta_comercial p
                            WHERE p.codigo_licitacion = NEW.codigo_licitacion) THEN
            RAISE EXCEPTION 'No se puede marcar la licitación % como %: aún no tiene propuesta comercial (regla RA5)',
                NEW.codigo_licitacion, NEW.estado;
        END IF;

        -- El resultado (adjudicada / no adjudicada) solo llega después de presentar
        IF NEW.estado IN ('ADJUDICADA', 'NO ADJUDICADA')
           AND OLD.estado NOT IN ('PRESENTADA', 'ADJUDICADA', 'NO ADJUDICADA') THEN
            RAISE EXCEPTION 'La licitación % está %: solo una licitación PRESENTADA puede pasar a %',
                NEW.codigo_licitacion, OLD.estado, NEW.estado;
        END IF;

        -- Una vez presentada no vuelve a la etapa de preparación
        IF NEW.estado IN ('REGISTRADA', 'EN PREPARACIÓN')
           AND OLD.estado IN ('PRESENTADA', 'ADJUDICADA', 'NO ADJUDICADA') THEN
            RAISE EXCEPTION 'La licitación % ya fue presentada (estado %): no puede volver a %',
                NEW.codigo_licitacion, OLD.estado, NEW.estado;
        END IF;
    END IF;

    RETURN NEW;
END $$;

-- tg_80_historial_estado (licitacion, AFTER INSERT/UPDATE OF estado)
CREATE OR REPLACE FUNCTION fn_tg_licitacion_historial()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO historial_estado_licitacion (codigo_licitacion, estado_anterior, estado_nuevo)
        VALUES (NEW.codigo_licitacion, NULL, NEW.estado);
    ELSIF NEW.estado IS DISTINCT FROM OLD.estado THEN
        INSERT INTO historial_estado_licitacion (codigo_licitacion, estado_anterior, estado_nuevo)
        VALUES (NEW.codigo_licitacion, OLD.estado, NEW.estado);
    END IF;
    RETURN NULL;
END $$;


-- =====================================================================
-- 5. FUNCIONES DE TRIGGER DE PROPUESTA COMERCIAL Y SU DETALLE
-- =====================================================================

-- tg_20_validar (propuesta_comercial, BEFORE INSERT/UPDATE/DELETE)
--   * INSERT sin código: genera el siguiente PROP-AAAA-NNNN del año.
--   * INSERT: solo para licitaciones REGISTRADAS o EN PREPARACIÓN.
--   * UPDATE / DELETE: no si la propuesta ya fue presentada.
--   * RA3: la cuenta de abono debe ser de la empresa del suscriptor.
CREATE OR REPLACE FUNCTION fn_tg_propuesta_validar()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_anio       text;
    v_siguiente  integer;
    v_estado     varchar(15);
    v_titular    char(11);
    v_empresa    char(11);
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        PERFORM fn_validar_propuesta_editable(OLD.codigo_propuesta);
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    IF TG_OP = 'INSERT' THEN
        SELECT estado INTO v_estado
          FROM licitacion
         WHERE codigo_licitacion = NEW.codigo_licitacion;
        IF v_estado NOT IN ('REGISTRADA', 'EN PREPARACIÓN') THEN
            RAISE EXCEPTION 'La licitación % está %: solo se preparan propuestas para licitaciones REGISTRADAS o EN PREPARACIÓN',
                NEW.codigo_licitacion, v_estado;
        END IF;

        IF NEW.codigo_propuesta IS NULL THEN
            v_anio := to_char(COALESCE(NEW.fecha_emision, CURRENT_DATE), 'YYYY');
            SELECT COALESCE(max(substr(codigo_propuesta, 11, 4)::integer), 0) + 1
              INTO v_siguiente
              FROM propuesta_comercial
             WHERE codigo_propuesta LIKE 'PROP-' || v_anio || '-%';
            NEW.codigo_propuesta := 'PROP-' || v_anio || '-' || lpad(v_siguiente::text, 4, '0');
        END IF;
    END IF;

    -- RA3 (solo si la cuenta y el representante existen; si no, responde la FK)
    IF NEW.cci_abono IS NOT NULL THEN
        SELECT ruc_titular INTO v_titular FROM cuenta_bancaria     WHERE codigo_cci = NEW.cci_abono;
        SELECT ruc_empresa INTO v_empresa FROM representante_legal WHERE dni = NEW.dni_suscriptor;
        IF v_titular IS NOT NULL AND v_empresa IS NOT NULL AND v_titular <> v_empresa THEN
            RAISE EXCEPTION 'La cuenta % no pertenece a la empresa del suscriptor % (regla RA3)',
                NEW.cci_abono, NEW.dni_suscriptor;
        END IF;
    END IF;

    RETURN NEW;
END $$;

-- tg_80_estado_licitacion (propuesta_comercial, AFTER INSERT/DELETE)
-- Mantiene el estado de la licitación de acuerdo con su propuesta:
--   crear propuesta  -> REGISTRADA pasa a EN PREPARACIÓN
--   borrar propuesta -> EN PREPARACIÓN vuelve a REGISTRADA
CREATE OR REPLACE FUNCTION fn_tg_propuesta_estado_licitacion()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE licitacion SET estado = 'EN PREPARACIÓN'
         WHERE codigo_licitacion = NEW.codigo_licitacion
           AND estado = 'REGISTRADA';
    ELSE
        UPDATE licitacion SET estado = 'REGISTRADA'
         WHERE codigo_licitacion = OLD.codigo_licitacion
           AND estado = 'EN PREPARACIÓN';
    END IF;
    RETURN NULL;
END $$;

-- tg_20_validar (item_propuesta, BEFORE INSERT/UPDATE/DELETE)
CREATE OR REPLACE FUNCTION fn_tg_item_propuesta_validar()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        PERFORM fn_validar_propuesta_editable(OLD.codigo_propuesta);
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    PERFORM fn_validar_propuesta_editable(NEW.codigo_propuesta);

    IF TG_OP = 'INSERT' AND NEW.nro_item IS NULL THEN       -- siguiente número de ítem
        SELECT COALESCE(max(nro_item), 0) + 1 INTO NEW.nro_item
          FROM item_propuesta
         WHERE codigo_propuesta = NEW.codigo_propuesta;
    END IF;
    RETURN NEW;
END $$;

-- tg_20_validar (armada_pago, BEFORE INSERT/UPDATE/DELETE)
CREATE OR REPLACE FUNCTION fn_tg_armada_pago_validar()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        PERFORM fn_validar_propuesta_editable(OLD.codigo_propuesta);
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    PERFORM fn_validar_propuesta_editable(NEW.codigo_propuesta);

    IF TG_OP = 'INSERT' AND NEW.nro_armada IS NULL THEN     -- siguiente número de armada
        SELECT COALESCE(max(nro_armada), 0) + 1 INTO NEW.nro_armada
          FROM armada_pago
         WHERE codigo_propuesta = NEW.codigo_propuesta;
    END IF;
    RETURN NEW;
END $$;

-- tg_20_validar (propuesta_maquinaria, BEFORE INSERT/UPDATE/DELETE)
--   RA2: el equipo debe tener un certificado vigente en la fecha de emisión
--   de la propuesta.
CREATE OR REPLACE FUNCTION fn_tg_propuesta_maquinaria_validar()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_fecha_emision date;
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        PERFORM fn_validar_propuesta_editable(OLD.codigo_propuesta);
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    PERFORM fn_validar_propuesta_editable(NEW.codigo_propuesta);

    SELECT fecha_emision INTO v_fecha_emision
      FROM propuesta_comercial
     WHERE codigo_propuesta = NEW.codigo_propuesta;

    IF v_fecha_emision IS NOT NULL
       AND EXISTS (SELECT 1 FROM maquinaria WHERE placa = NEW.placa)
       AND NOT EXISTS (SELECT 1
                         FROM certificado_maquinaria c
                        WHERE c.placa = NEW.placa
                          AND v_fecha_emision BETWEEN c.fecha_inspeccion AND c.fecha_caducidad) THEN
        RAISE EXCEPTION 'El equipo % no tiene certificado de inspección vigente al % (regla RA2)',
            NEW.placa, to_char(v_fecha_emision, 'DD/MM/YYYY');
    END IF;
    RETURN NEW;
END $$;


-- =====================================================================
-- 6. FUNCIONES DE TRIGGER DE VERIFICACIÓN SUNAT / RNP
-- =====================================================================

-- tg_80_verificacion (empresa, AFTER INSERT/UPDATE)
CREATE OR REPLACE FUNCTION fn_tg_empresa_verificacion()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT'
       OR NEW.estado_contribuyente     IS DISTINCT FROM OLD.estado_contribuyente
       OR NEW.condicion_contribuyente  IS DISTINCT FROM OLD.condicion_contribuyente
       OR NEW.fecha_verificacion_sunat IS DISTINCT FROM OLD.fecha_verificacion_sunat THEN
        PERFORM fn_registrar_verificacion(NEW.numero_ruc, 'SUNAT');
    END IF;
    RETURN NULL;
END $$;

-- tg_80_verificacion (habilitacion_rnp, AFTER INSERT/UPDATE)
CREATE OR REPLACE FUNCTION fn_tg_habilitacion_verificacion()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.tipo_registro = 'PROVEEDOR DE SERVICIOS'
       AND (TG_OP = 'INSERT'
            OR NEW.estado_inscripcion IS DISTINCT FROM OLD.estado_inscripcion
            OR NEW.fecha_verificacion IS DISTINCT FROM OLD.fecha_verificacion) THEN
        PERFORM fn_registrar_verificacion(NEW.numero_ruc, 'RNP');
    END IF;
    RETURN NULL;
END $$;


-- =====================================================================
-- 7. TRIGGERS
-- =====================================================================

-- 7.1 Generales: normalización y auditoría en las 14 tablas del modelo
DO $$
DECLARE
    v_tabla text;
BEGIN
    FOREACH v_tabla IN ARRAY ARRAY[
        'empresa', 'cuenta_bancaria', 'habilitacion_rnp', 'representante_legal',
        'modelo_equipo', 'maquinaria', 'certificado_maquinaria',
        'entidad_contratante', 'telefono_entidad', 'licitacion',
        'propuesta_comercial', 'item_propuesta', 'armada_pago', 'propuesta_maquinaria']
    LOOP
        EXECUTE format('CREATE OR REPLACE TRIGGER tg_10_normalizar
                            BEFORE INSERT OR UPDATE ON %I
                            FOR EACH ROW EXECUTE FUNCTION fn_tg_normalizar()', v_tabla);
        EXECUTE format('CREATE OR REPLACE TRIGGER tg_90_auditoria
                            AFTER INSERT OR UPDATE OR DELETE ON %I
                            FOR EACH ROW EXECUTE FUNCTION fn_tg_auditoria()', v_tabla);
    END LOOP;
END $$;

-- 7.2 Licitación
CREATE OR REPLACE TRIGGER tg_20_validar
    BEFORE INSERT OR UPDATE OR DELETE ON licitacion
    FOR EACH ROW EXECUTE FUNCTION fn_tg_licitacion_validar();

CREATE OR REPLACE TRIGGER tg_80_historial_estado
    AFTER INSERT OR UPDATE OF estado ON licitacion
    FOR EACH ROW EXECUTE FUNCTION fn_tg_licitacion_historial();

-- 7.3 Propuesta comercial y su detalle
CREATE OR REPLACE TRIGGER tg_20_validar
    BEFORE INSERT OR UPDATE OR DELETE ON propuesta_comercial
    FOR EACH ROW EXECUTE FUNCTION fn_tg_propuesta_validar();

CREATE OR REPLACE TRIGGER tg_80_estado_licitacion
    AFTER INSERT OR DELETE ON propuesta_comercial
    FOR EACH ROW EXECUTE FUNCTION fn_tg_propuesta_estado_licitacion();

CREATE OR REPLACE TRIGGER tg_20_validar
    BEFORE INSERT OR UPDATE OR DELETE ON item_propuesta
    FOR EACH ROW EXECUTE FUNCTION fn_tg_item_propuesta_validar();

CREATE OR REPLACE TRIGGER tg_20_validar
    BEFORE INSERT OR UPDATE OR DELETE ON armada_pago
    FOR EACH ROW EXECUTE FUNCTION fn_tg_armada_pago_validar();

CREATE OR REPLACE TRIGGER tg_20_validar
    BEFORE INSERT OR UPDATE OR DELETE ON propuesta_maquinaria
    FOR EACH ROW EXECUTE FUNCTION fn_tg_propuesta_maquinaria_validar();

-- 7.4 Verificaciones SUNAT / RNP
CREATE OR REPLACE TRIGGER tg_80_verificacion
    AFTER INSERT OR UPDATE ON empresa
    FOR EACH ROW EXECUTE FUNCTION fn_tg_empresa_verificacion();

CREATE OR REPLACE TRIGGER tg_80_verificacion
    AFTER INSERT OR UPDATE ON habilitacion_rnp
    FOR EACH ROW EXECUTE FUNCTION fn_tg_habilitacion_verificacion();


-- ---------------------------------------------------------------------
-- 8. Punto de partida de los historiales: una fila por cada licitación y
--    empresa que ya existe (solo si el historial está vacío).
-- ---------------------------------------------------------------------
INSERT INTO historial_estado_licitacion (codigo_licitacion, fecha_cambio, estado_anterior, estado_nuevo)
SELECT codigo_licitacion, fecha_registro, NULL, estado
  FROM licitacion
 WHERE NOT EXISTS (SELECT 1 FROM historial_estado_licitacion);

INSERT INTO historial_verificacion (numero_ruc, fecha_registro, origen, estado_contribuyente,
                                    condicion_contribuyente, fecha_verificacion_sunat,
                                    estado_rnp, fecha_verificacion_rnp)
SELECT e.numero_ruc, e.fecha_verificacion_sunat, 'SUNAT', e.estado_contribuyente,
       e.condicion_contribuyente, e.fecha_verificacion_sunat,
       h.estado_inscripcion, h.fecha_verificacion
  FROM empresa e
  LEFT JOIN habilitacion_rnp h
         ON h.numero_ruc = e.numero_ruc AND h.tipo_registro = 'PROVEEDOR DE SERVICIOS'
 WHERE NOT EXISTS (SELECT 1 FROM historial_verificacion);


-- ---------------------------------------------------------------------
-- 9. Verificación (resultado esperado: 37 triggers | 3 tablas nuevas)
--    14 de normalización + 14 de auditoría + 9 de reglas e historiales
-- ---------------------------------------------------------------------
SELECT
  (SELECT count(*) FROM pg_trigger t
     JOIN pg_class c ON c.oid = t.tgrelid
    WHERE c.relnamespace = 'licitaciones'::regnamespace
      AND NOT t.tgisinternal)                                   AS triggers,
  (SELECT count(*) FROM information_schema.tables
    WHERE table_schema = 'licitaciones'
      AND table_name IN ('bitacora', 'historial_estado_licitacion',
                         'historial_verificacion'))             AS tablas_nuevas;
