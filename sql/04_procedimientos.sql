-- =====================================================================
-- Proyecto : Desarrollo de la base de datos para la funcionalidad
--            "Registro de Licitaciones de Servicios" - TECNOSERVI S.R.L.
-- Gestor   : PostgreSQL
-- Archivo  : 04_procedimientos.sql  (procedimientos almacenados)
-- Uso      : Query Tool abierto sobre "bd_licitaciones". Ejecutar todo (F5).
--            Requiere 01_crear_tablas.sql. Puede volver a ejecutarse.
--
-- El aplicativo NO escribe directamente en las tablas: toda inserción,
-- modificación o eliminación pasa por uno de estos procedimientos.
-- Convención de nombres:
--     sp_<tabla>_insertar    sp_<tabla>_actualizar    sp_<tabla>_eliminar
-- Los parámetros llevan el prefijo p_ para no confundirse con las columnas.
-- Las reglas de negocio que deben cumplirse siempre (vengan del aplicativo
-- o de otra herramienta) están en los triggers de 05_triggers.sql.
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
-- 1. EMPRESA
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_empresa_insertar(
    p_numero_ruc               char(11),
    p_razon_social             varchar,
    p_estado_contribuyente     varchar,
    p_condicion_contribuyente  varchar,
    p_domicilio_fiscal         varchar,
    p_fecha_verificacion_sunat date)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO empresa (numero_ruc, razon_social, estado_contribuyente,
                         condicion_contribuyente, domicilio_fiscal, fecha_verificacion_sunat)
    VALUES (p_numero_ruc, p_razon_social, p_estado_contribuyente,
            p_condicion_contribuyente, p_domicilio_fiscal, p_fecha_verificacion_sunat);
END $$;

CREATE OR REPLACE PROCEDURE sp_empresa_actualizar(
    p_numero_ruc               char(11),
    p_razon_social             varchar,
    p_estado_contribuyente     varchar,
    p_condicion_contribuyente  varchar,
    p_domicilio_fiscal         varchar,
    p_fecha_verificacion_sunat date)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE empresa
       SET razon_social             = p_razon_social,
           estado_contribuyente     = p_estado_contribuyente,
           condicion_contribuyente  = p_condicion_contribuyente,
           domicilio_fiscal         = p_domicilio_fiscal,
           fecha_verificacion_sunat = p_fecha_verificacion_sunat
     WHERE numero_ruc = p_numero_ruc;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe una empresa con RUC %', p_numero_ruc;
    END IF;
END $$;

CREATE OR REPLACE PROCEDURE sp_empresa_eliminar(p_numero_ruc char(11))
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM empresa WHERE numero_ruc = p_numero_ruc;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe una empresa con RUC %', p_numero_ruc;
    END IF;
END $$;


-- =====================================================================
-- 2. CUENTA BANCARIA
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_cuenta_bancaria_insertar(
    p_codigo_cci       char(20),
    p_entidad_bancaria varchar,
    p_ruc_titular      char(11))
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO cuenta_bancaria (codigo_cci, entidad_bancaria, ruc_titular)
    VALUES (p_codigo_cci, p_entidad_bancaria, p_ruc_titular);
END $$;

CREATE OR REPLACE PROCEDURE sp_cuenta_bancaria_actualizar(
    p_codigo_cci       char(20),
    p_entidad_bancaria varchar,
    p_ruc_titular      char(11))
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE cuenta_bancaria
       SET entidad_bancaria = p_entidad_bancaria,
           ruc_titular      = p_ruc_titular
     WHERE codigo_cci = p_codigo_cci;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe la cuenta con CCI %', p_codigo_cci;
    END IF;
END $$;

CREATE OR REPLACE PROCEDURE sp_cuenta_bancaria_eliminar(p_codigo_cci char(20))
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM cuenta_bancaria WHERE codigo_cci = p_codigo_cci;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe la cuenta con CCI %', p_codigo_cci;
    END IF;
END $$;


-- =====================================================================
-- 3. HABILITACIÓN RNP (clave compuesta: numero_ruc + tipo_registro)
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_habilitacion_rnp_insertar(
    p_numero_ruc            char(11),
    p_tipo_registro         varchar,
    p_fecha_inicio_vigencia date,
    p_estado_inscripcion    varchar,
    p_fecha_verificacion    date)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO habilitacion_rnp (numero_ruc, tipo_registro, fecha_inicio_vigencia,
                                  estado_inscripcion, fecha_verificacion)
    VALUES (p_numero_ruc, p_tipo_registro, p_fecha_inicio_vigencia,
            p_estado_inscripcion, p_fecha_verificacion);
END $$;

CREATE OR REPLACE PROCEDURE sp_habilitacion_rnp_actualizar(
    p_numero_ruc            char(11),
    p_tipo_registro         varchar,
    p_fecha_inicio_vigencia date,
    p_estado_inscripcion    varchar,
    p_fecha_verificacion    date)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE habilitacion_rnp
       SET fecha_inicio_vigencia = p_fecha_inicio_vigencia,
           estado_inscripcion    = p_estado_inscripcion,
           fecha_verificacion    = p_fecha_verificacion
     WHERE numero_ruc = p_numero_ruc
       AND tipo_registro = p_tipo_registro;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La empresa % no tiene habilitación como %', p_numero_ruc, p_tipo_registro;
    END IF;
END $$;

CREATE OR REPLACE PROCEDURE sp_habilitacion_rnp_eliminar(
    p_numero_ruc    char(11),
    p_tipo_registro varchar)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM habilitacion_rnp
     WHERE numero_ruc = p_numero_ruc
       AND tipo_registro = p_tipo_registro;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La empresa % no tiene habilitación como %', p_numero_ruc, p_tipo_registro;
    END IF;
END $$;


-- =====================================================================
-- 4. REPRESENTANTE LEGAL
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_representante_legal_insertar(
    p_dni                 char(8),
    p_nombres             varchar,
    p_apellido_paterno    varchar,
    p_apellido_materno    varchar,
    p_cargo               varchar,
    p_correo_notificacion varchar,
    p_telefono            varchar,
    p_ruc_empresa         char(11))
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO representante_legal (dni, nombres, apellido_paterno, apellido_materno, cargo,
                                     correo_notificacion, telefono, ruc_empresa)
    VALUES (p_dni, p_nombres, p_apellido_paterno, p_apellido_materno, p_cargo,
            p_correo_notificacion, p_telefono, p_ruc_empresa);
END $$;

CREATE OR REPLACE PROCEDURE sp_representante_legal_actualizar(
    p_dni                 char(8),
    p_nombres             varchar,
    p_apellido_paterno    varchar,
    p_apellido_materno    varchar,
    p_cargo               varchar,
    p_correo_notificacion varchar,
    p_telefono            varchar,
    p_ruc_empresa         char(11))
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE representante_legal
       SET nombres             = p_nombres,
           apellido_paterno    = p_apellido_paterno,
           apellido_materno    = p_apellido_materno,
           cargo               = p_cargo,
           correo_notificacion = p_correo_notificacion,
           telefono            = p_telefono,
           ruc_empresa         = p_ruc_empresa
     WHERE dni = p_dni;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe un representante con DNI %', p_dni;
    END IF;
END $$;

CREATE OR REPLACE PROCEDURE sp_representante_legal_eliminar(p_dni char(8))
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM representante_legal WHERE dni = p_dni;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe un representante con DNI %', p_dni;
    END IF;
END $$;


-- =====================================================================
-- 5. MODELO DE EQUIPO (clave compuesta: marca + modelo)
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_modelo_equipo_insertar(
    p_marca         varchar,
    p_modelo        varchar,
    p_tipo_equipo   varchar,
    p_capacidad_ton numeric)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO modelo_equipo (marca, modelo, tipo_equipo, capacidad_ton)
    VALUES (p_marca, p_modelo, p_tipo_equipo, p_capacidad_ton);
END $$;

CREATE OR REPLACE PROCEDURE sp_modelo_equipo_actualizar(
    p_marca         varchar,
    p_modelo        varchar,
    p_tipo_equipo   varchar,
    p_capacidad_ton numeric)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE modelo_equipo
       SET tipo_equipo   = p_tipo_equipo,
           capacidad_ton = p_capacidad_ton
     WHERE marca = upper(p_marca)
       AND modelo = upper(p_modelo);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el modelo % %', p_marca, p_modelo;
    END IF;
END $$;

CREATE OR REPLACE PROCEDURE sp_modelo_equipo_eliminar(
    p_marca  varchar,
    p_modelo varchar)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM modelo_equipo
     WHERE marca = upper(p_marca)
       AND modelo = upper(p_modelo);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el modelo % %', p_marca, p_modelo;
    END IF;
END $$;


-- =====================================================================
-- 6. MAQUINARIA
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_maquinaria_insertar(
    p_placa           varchar,
    p_marca           varchar,
    p_modelo          varchar,
    p_serie           varchar,
    p_marca_vehiculo  varchar,
    p_ruc_propietario char(11))
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO maquinaria (placa, marca, modelo, serie, marca_vehiculo, ruc_propietario)
    VALUES (p_placa, p_marca, p_modelo, p_serie, p_marca_vehiculo, p_ruc_propietario);
END $$;

CREATE OR REPLACE PROCEDURE sp_maquinaria_actualizar(
    p_placa           varchar,
    p_marca           varchar,
    p_modelo          varchar,
    p_serie           varchar,
    p_marca_vehiculo  varchar,
    p_ruc_propietario char(11))
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE maquinaria
       SET marca           = p_marca,
           modelo          = p_modelo,
           serie           = p_serie,
           marca_vehiculo  = p_marca_vehiculo,
           ruc_propietario = p_ruc_propietario
     WHERE placa = upper(p_placa);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe un equipo con placa %', p_placa;
    END IF;
END $$;

CREATE OR REPLACE PROCEDURE sp_maquinaria_eliminar(p_placa varchar)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM maquinaria WHERE placa = upper(p_placa);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe un equipo con placa %', p_placa;
    END IF;
END $$;


-- =====================================================================
-- 7. CERTIFICADO DE MAQUINARIA
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_certificado_maquinaria_insertar(
    p_codigo_certificado    varchar,
    p_entidad_certificadora varchar,
    p_normativa             varchar,
    p_fecha_inspeccion      date,
    p_fecha_caducidad       date,
    p_placa                 varchar)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO certificado_maquinaria (codigo_certificado, entidad_certificadora, normativa,
                                        fecha_inspeccion, fecha_caducidad, placa)
    VALUES (p_codigo_certificado, p_entidad_certificadora, p_normativa,
            p_fecha_inspeccion, p_fecha_caducidad, p_placa);
END $$;

CREATE OR REPLACE PROCEDURE sp_certificado_maquinaria_actualizar(
    p_codigo_certificado    varchar,
    p_entidad_certificadora varchar,
    p_normativa             varchar,
    p_fecha_inspeccion      date,
    p_fecha_caducidad       date,
    p_placa                 varchar)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE certificado_maquinaria
       SET entidad_certificadora = p_entidad_certificadora,
           normativa             = p_normativa,
           fecha_inspeccion      = p_fecha_inspeccion,
           fecha_caducidad       = p_fecha_caducidad,
           placa                 = p_placa
     WHERE codigo_certificado = upper(p_codigo_certificado);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el certificado %', p_codigo_certificado;
    END IF;
END $$;

CREATE OR REPLACE PROCEDURE sp_certificado_maquinaria_eliminar(p_codigo_certificado varchar)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM certificado_maquinaria WHERE codigo_certificado = upper(p_codigo_certificado);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el certificado %', p_codigo_certificado;
    END IF;
END $$;


-- =====================================================================
-- 8. ENTIDAD CONTRATANTE
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_entidad_contratante_insertar(
    p_ruc_entidad  char(11),
    p_razon_social varchar,
    p_direccion    varchar)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO entidad_contratante (ruc_entidad, razon_social, direccion)
    VALUES (p_ruc_entidad, p_razon_social, p_direccion);
END $$;

CREATE OR REPLACE PROCEDURE sp_entidad_contratante_actualizar(
    p_ruc_entidad  char(11),
    p_razon_social varchar,
    p_direccion    varchar)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE entidad_contratante
       SET razon_social = p_razon_social,
           direccion    = p_direccion
     WHERE ruc_entidad = p_ruc_entidad;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe una entidad con RUC %', p_ruc_entidad;
    END IF;
END $$;

CREATE OR REPLACE PROCEDURE sp_entidad_contratante_eliminar(p_ruc_entidad char(11))
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM entidad_contratante WHERE ruc_entidad = p_ruc_entidad;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe una entidad con RUC %', p_ruc_entidad;
    END IF;
END $$;


-- =====================================================================
-- 9. TELÉFONO DE ENTIDAD
--    Todas sus columnas forman la clave, por eso "actualizar" recibe el
--    número anterior y el nuevo.
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_telefono_entidad_insertar(
    p_ruc_entidad char(11),
    p_telefono    varchar)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO telefono_entidad (ruc_entidad, telefono)
    VALUES (p_ruc_entidad, p_telefono);
END $$;

CREATE OR REPLACE PROCEDURE sp_telefono_entidad_actualizar(
    p_ruc_entidad       char(11),
    p_telefono_anterior varchar,
    p_telefono_nuevo    varchar)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE telefono_entidad
       SET telefono = p_telefono_nuevo
     WHERE ruc_entidad = p_ruc_entidad
       AND telefono = p_telefono_anterior;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La entidad % no tiene registrado el teléfono %', p_ruc_entidad, p_telefono_anterior;
    END IF;
END $$;

CREATE OR REPLACE PROCEDURE sp_telefono_entidad_eliminar(
    p_ruc_entidad char(11),
    p_telefono    varchar)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM telefono_entidad
     WHERE ruc_entidad = p_ruc_entidad
       AND telefono = p_telefono;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La entidad % no tiene registrado el teléfono %', p_ruc_entidad, p_telefono;
    END IF;
END $$;


-- =====================================================================
-- 10. LICITACIÓN
--     Si p_codigo_licitacion llega vacío, el trigger tg_licitacion_antes
--     genera el siguiente código del año (LIC-AAAA-NNNN). El parámetro es
--     INOUT: CALL devuelve el código con el que quedó registrada.
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_licitacion_insertar(
    INOUT p_codigo_licitacion      char(13),
    p_nro_requerimiento            varchar,
    p_tipo_proceso                 varchar,
    p_objeto                       varchar,
    p_dependencia_destino          varchar,
    p_fecha_registro               date,
    p_fecha_limite_presentacion    date,
    p_estado                       varchar,
    p_ruc_entidad                  char(11))
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO licitacion (codigo_licitacion, nro_requerimiento, tipo_proceso, objeto,
                            dependencia_destino, fecha_registro, fecha_limite_presentacion,
                            estado, ruc_entidad)
    VALUES (NULLIF(trim(p_codigo_licitacion), ''), p_nro_requerimiento, p_tipo_proceso, p_objeto,
            p_dependencia_destino, COALESCE(p_fecha_registro, CURRENT_DATE),
            p_fecha_limite_presentacion, COALESCE(p_estado, 'REGISTRADA'), p_ruc_entidad)
    RETURNING codigo_licitacion INTO p_codigo_licitacion;
END $$;

CREATE OR REPLACE PROCEDURE sp_licitacion_actualizar(
    p_codigo_licitacion         char(13),
    p_nro_requerimiento         varchar,
    p_tipo_proceso              varchar,
    p_objeto                    varchar,
    p_dependencia_destino       varchar,
    p_fecha_registro            date,
    p_fecha_limite_presentacion date,
    p_estado                    varchar,
    p_ruc_entidad               char(11))
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE licitacion
       SET nro_requerimiento         = p_nro_requerimiento,
           tipo_proceso              = p_tipo_proceso,
           objeto                    = p_objeto,
           dependencia_destino       = p_dependencia_destino,
           fecha_registro            = p_fecha_registro,
           fecha_limite_presentacion = p_fecha_limite_presentacion,
           estado                    = p_estado,
           ruc_entidad               = p_ruc_entidad
     WHERE codigo_licitacion = upper(p_codigo_licitacion);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe la licitación %', p_codigo_licitacion;
    END IF;
END $$;

-- Atajo para el seguimiento: solo cambia el estado (las transiciones
-- permitidas las controla el trigger tg_licitacion_antes).
CREATE OR REPLACE PROCEDURE sp_licitacion_cambiar_estado(
    p_codigo_licitacion char(13),
    p_estado            varchar)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE licitacion
       SET estado = p_estado
     WHERE codigo_licitacion = upper(p_codigo_licitacion);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe la licitación %', p_codigo_licitacion;
    END IF;
END $$;

CREATE OR REPLACE PROCEDURE sp_licitacion_eliminar(p_codigo_licitacion char(13))
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM licitacion WHERE codigo_licitacion = upper(p_codigo_licitacion);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe la licitación %', p_codigo_licitacion;
    END IF;
END $$;


-- =====================================================================
-- 11. PROPUESTA COMERCIAL
--     Igual que la licitación: si el código llega vacío, el trigger
--     tg_propuesta_antes genera PROP-AAAA-NNNN y CALL lo devuelve.
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_propuesta_comercial_insertar(
    INOUT p_codigo_propuesta  char(14),
    p_fecha_emision           date,
    p_plazo_ejecucion_dias    smallint,
    p_cumple_tdr              boolean,
    p_codigo_licitacion       char(13),
    p_dni_suscriptor          char(8),
    p_cci_abono               char(20))
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO propuesta_comercial (codigo_propuesta, fecha_emision, plazo_ejecucion_dias,
                                     cumple_tdr, codigo_licitacion, dni_suscriptor, cci_abono)
    VALUES (NULLIF(trim(p_codigo_propuesta), ''), COALESCE(p_fecha_emision, CURRENT_DATE),
            p_plazo_ejecucion_dias, COALESCE(p_cumple_tdr, TRUE), p_codigo_licitacion,
            p_dni_suscriptor, p_cci_abono)
    RETURNING codigo_propuesta INTO p_codigo_propuesta;
END $$;

CREATE OR REPLACE PROCEDURE sp_propuesta_comercial_actualizar(
    p_codigo_propuesta     char(14),
    p_fecha_emision        date,
    p_plazo_ejecucion_dias smallint,
    p_cumple_tdr           boolean,
    p_codigo_licitacion    char(13),
    p_dni_suscriptor       char(8),
    p_cci_abono            char(20))
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE propuesta_comercial
       SET fecha_emision        = p_fecha_emision,
           plazo_ejecucion_dias = p_plazo_ejecucion_dias,
           cumple_tdr           = p_cumple_tdr,
           codigo_licitacion    = p_codigo_licitacion,
           dni_suscriptor       = p_dni_suscriptor,
           cci_abono            = p_cci_abono
     WHERE codigo_propuesta = upper(p_codigo_propuesta);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe la propuesta %', p_codigo_propuesta;
    END IF;
END $$;

CREATE OR REPLACE PROCEDURE sp_propuesta_comercial_eliminar(p_codigo_propuesta char(14))
LANGUAGE plpgsql AS $$
BEGIN
    -- Sus ítems, armadas y equipos se borran en cascada (ON DELETE CASCADE)
    DELETE FROM propuesta_comercial WHERE codigo_propuesta = upper(p_codigo_propuesta);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe la propuesta %', p_codigo_propuesta;
    END IF;
END $$;


-- =====================================================================
-- 12. ÍTEM DE PROPUESTA (entidad débil)
--     Si p_nro_item llega vacío, el trigger asigna el siguiente número.
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_item_propuesta_insertar(
    p_codigo_propuesta char(14),
    INOUT p_nro_item   smallint,
    p_descripcion      varchar,
    p_unidad_medida    varchar,
    p_cantidad         numeric,
    p_precio_unitario  numeric)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO item_propuesta (codigo_propuesta, nro_item, descripcion, unidad_medida,
                                cantidad, precio_unitario)
    VALUES (p_codigo_propuesta, p_nro_item, p_descripcion, p_unidad_medida,
            p_cantidad, p_precio_unitario)
    RETURNING nro_item INTO p_nro_item;
END $$;

CREATE OR REPLACE PROCEDURE sp_item_propuesta_actualizar(
    p_codigo_propuesta char(14),
    p_nro_item         smallint,
    p_descripcion      varchar,
    p_unidad_medida    varchar,
    p_cantidad         numeric,
    p_precio_unitario  numeric)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE item_propuesta
       SET descripcion     = p_descripcion,
           unidad_medida   = p_unidad_medida,
           cantidad        = p_cantidad,
           precio_unitario = p_precio_unitario
     WHERE codigo_propuesta = upper(p_codigo_propuesta)
       AND nro_item = p_nro_item;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La propuesta % no tiene el ítem %', p_codigo_propuesta, p_nro_item;
    END IF;
END $$;

CREATE OR REPLACE PROCEDURE sp_item_propuesta_eliminar(
    p_codigo_propuesta char(14),
    p_nro_item         smallint)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM item_propuesta
     WHERE codigo_propuesta = upper(p_codigo_propuesta)
       AND nro_item = p_nro_item;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La propuesta % no tiene el ítem %', p_codigo_propuesta, p_nro_item;
    END IF;
END $$;


-- =====================================================================
-- 13. ARMADA DE PAGO
--     Si p_nro_armada llega vacío, el trigger asigna el siguiente número.
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_armada_pago_insertar(
    p_codigo_propuesta char(14),
    INOUT p_nro_armada smallint,
    p_dias_plazo       smallint,
    p_condicion        varchar)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO armada_pago (codigo_propuesta, nro_armada, dias_plazo, condicion)
    VALUES (p_codigo_propuesta, p_nro_armada, p_dias_plazo, p_condicion)
    RETURNING nro_armada INTO p_nro_armada;
END $$;

CREATE OR REPLACE PROCEDURE sp_armada_pago_actualizar(
    p_codigo_propuesta char(14),
    p_nro_armada       smallint,
    p_dias_plazo       smallint,
    p_condicion        varchar)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE armada_pago
       SET dias_plazo = p_dias_plazo,
           condicion  = p_condicion
     WHERE codigo_propuesta = upper(p_codigo_propuesta)
       AND nro_armada = p_nro_armada;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La propuesta % no tiene la armada %', p_codigo_propuesta, p_nro_armada;
    END IF;
END $$;

CREATE OR REPLACE PROCEDURE sp_armada_pago_eliminar(
    p_codigo_propuesta char(14),
    p_nro_armada       smallint)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM armada_pago
     WHERE codigo_propuesta = upper(p_codigo_propuesta)
       AND nro_armada = p_nro_armada;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La propuesta % no tiene la armada %', p_codigo_propuesta, p_nro_armada;
    END IF;
END $$;


-- =====================================================================
-- 14. EQUIPO ASIGNADO A UNA PROPUESTA (relación M:N)
--     "Actualizar" reemplaza un equipo por otro en la misma propuesta.
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_propuesta_maquinaria_insertar(
    p_codigo_propuesta char(14),
    p_placa            varchar)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO propuesta_maquinaria (codigo_propuesta, placa)
    VALUES (p_codigo_propuesta, p_placa);
END $$;

CREATE OR REPLACE PROCEDURE sp_propuesta_maquinaria_actualizar(
    p_codigo_propuesta char(14),
    p_placa_anterior   varchar,
    p_placa_nueva      varchar)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE propuesta_maquinaria
       SET placa = p_placa_nueva
     WHERE codigo_propuesta = upper(p_codigo_propuesta)
       AND placa = upper(p_placa_anterior);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La propuesta % no tiene asignado el equipo %', p_codigo_propuesta, p_placa_anterior;
    END IF;
END $$;

CREATE OR REPLACE PROCEDURE sp_propuesta_maquinaria_eliminar(
    p_codigo_propuesta char(14),
    p_placa            varchar)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM propuesta_maquinaria
     WHERE codigo_propuesta = upper(p_codigo_propuesta)
       AND placa = upper(p_placa);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La propuesta % no tiene asignado el equipo %', p_codigo_propuesta, p_placa;
    END IF;
END $$;


-- ---------------------------------------------------------------------
-- Verificación (resultado esperado: 43 procedimientos)
-- ---------------------------------------------------------------------
SELECT count(*) AS procedimientos
FROM pg_proc
WHERE pronamespace = 'licitaciones'::regnamespace
  AND prokind = 'p';
