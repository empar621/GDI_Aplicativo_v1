-- =====================================================================
-- Proyecto : Desarrollo de la base de datos para la funcionalidad
--            "Registro de Licitaciones de Servicios" - TECNOSERVI S.R.L.
-- Gestor   : PostgreSQL
-- Archivo  : 01_crear_tablas.sql  (script de creación de la base de datos)
-- Uso      : Query Tool abierto sobre "bd_licitaciones". Ejecutar todo (F5).
--            Se ejecuta como una sola transacción: si algo falla, no se
--            crea nada. Puede volver a ejecutarse: borra y recrea el esquema
--            (¡también borra los datos cargados!).
-- =====================================================================

-- Control: evita crear las tablas en otra base por error
DO $$
BEGIN
    IF current_database() <> 'bd_licitaciones' THEN
        RAISE EXCEPTION 'Abra el Query Tool sobre la base bd_licitaciones (ahora está en %)',
            current_database();
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- 1. Esquema
-- ---------------------------------------------------------------------
DROP SCHEMA IF EXISTS licitaciones CASCADE;
CREATE SCHEMA licitaciones;
ALTER DATABASE bd_licitaciones SET search_path = licitaciones, public;
SET search_path TO licitaciones, public;

-- ---------------------------------------------------------------------
-- 2. Tablas (en orden de dependencia)
-- ---------------------------------------------------------------------

-- Contribuyentes con RUC que intervienen en el proceso
CREATE TABLE empresa (
    numero_ruc               char(11)     NOT NULL,
    razon_social             varchar(150) NOT NULL,
    estado_contribuyente     varchar(25)  NOT NULL,
    condicion_contribuyente  varchar(15)  NOT NULL,
    domicilio_fiscal         varchar(255) NOT NULL,
    fecha_verificacion_sunat date         NOT NULL,
    CONSTRAINT pk_empresa PRIMARY KEY (numero_ruc),
    CONSTRAINT ck_empresa_ruc CHECK (numero_ruc ~ '^[0-9]{11}$'),
    CONSTRAINT ck_empresa_razon_social CHECK (razon_social = upper(razon_social)),
    CONSTRAINT ck_empresa_estado CHECK (estado_contribuyente IN
        ('ACTIVO', 'SUSPENSIÓN TEMPORAL', 'BAJA PROVISIONAL', 'BAJA DEFINITIVA', 'BAJA DE OFICIO')),
    CONSTRAINT ck_empresa_condicion CHECK (condicion_contribuyente IN
        ('HABIDO', 'NO HABIDO', 'NO HALLADO')),
    CONSTRAINT ck_empresa_fecha_verif CHECK (fecha_verificacion_sunat <= CURRENT_DATE)
);

-- Cuentas en las que se autoriza abonar los pagos
CREATE TABLE cuenta_bancaria (
    codigo_cci       char(20)     NOT NULL,
    entidad_bancaria varchar(100) NOT NULL,
    ruc_titular      char(11)     NOT NULL,
    CONSTRAINT pk_cuenta_bancaria PRIMARY KEY (codigo_cci),
    CONSTRAINT fk_cuenta_empresa FOREIGN KEY (ruc_titular)
        REFERENCES empresa (numero_ruc) ON DELETE RESTRICT,
    CONSTRAINT ck_cuenta_cci CHECK (codigo_cci ~ '^[0-9]{20}$')
);

-- Inscripciones de cada empresa en los registros del RNP (entidad débil)
CREATE TABLE habilitacion_rnp (
    numero_ruc            char(11)    NOT NULL,
    tipo_registro         varchar(25) NOT NULL,
    fecha_inicio_vigencia date        NOT NULL,
    estado_inscripcion    varchar(12) NOT NULL,
    fecha_verificacion    date        NOT NULL,
    CONSTRAINT pk_habilitacion_rnp PRIMARY KEY (numero_ruc, tipo_registro),
    CONSTRAINT fk_habilitacion_empresa FOREIGN KEY (numero_ruc)
        REFERENCES empresa (numero_ruc) ON DELETE CASCADE,
    CONSTRAINT ck_habilitacion_tipo CHECK (tipo_registro IN
        ('PROVEEDOR DE BIENES', 'PROVEEDOR DE SERVICIOS', 'CONSULTOR DE OBRAS', 'EJECUTOR DE OBRAS')),
    CONSTRAINT ck_habilitacion_estado CHECK (estado_inscripcion IN
        ('VIGENTE', 'SUSPENDIDA', 'NO VIGENTE')),
    CONSTRAINT ck_habilitacion_fechas CHECK (fecha_verificacion >= fecha_inicio_vigencia)
);

-- Personas con poder para suscribir documentos de una empresa
CREATE TABLE representante_legal (
    dni                 char(8)      NOT NULL,
    nombres             varchar(60)  NOT NULL,
    apellido_paterno    varchar(40)  NOT NULL,
    apellido_materno    varchar(40),
    cargo               varchar(50)  NOT NULL,
    correo_notificacion varchar(100) NOT NULL,
    telefono            varchar(15),
    ruc_empresa         char(11)     NOT NULL,
    CONSTRAINT pk_representante_legal PRIMARY KEY (dni),
    CONSTRAINT fk_representante_empresa FOREIGN KEY (ruc_empresa)
        REFERENCES empresa (numero_ruc) ON DELETE RESTRICT,
    CONSTRAINT ck_representante_dni CHECK (dni ~ '^[0-9]{8}$'),
    CONSTRAINT ck_representante_correo CHECK (correo_notificacion ~ '^[^@ ]+@[^@ ]+\.[^@ ]+$'),
    CONSTRAINT ck_representante_telefono CHECK (telefono ~ '^[0-9]+$')
);

-- Especificaciones técnicas de cada modelo de fabricante
CREATE TABLE modelo_equipo (
    marca         varchar(50)  NOT NULL,
    modelo        varchar(50)  NOT NULL,
    tipo_equipo   varchar(60)  NOT NULL,
    capacidad_ton numeric(6,2) NOT NULL,
    CONSTRAINT pk_modelo_equipo PRIMARY KEY (marca, modelo),
    CONSTRAINT ck_modelo_capacidad CHECK (capacidad_ton > 0)
);

-- Unidades de equipo, propias o subcontratadas
CREATE TABLE maquinaria (
    placa           varchar(10) NOT NULL,
    marca           varchar(50) NOT NULL,
    modelo          varchar(50) NOT NULL,
    serie           varchar(30),
    marca_vehiculo  varchar(50),
    ruc_propietario char(11)    NOT NULL,
    CONSTRAINT pk_maquinaria PRIMARY KEY (placa),
    CONSTRAINT fk_maquinaria_modelo FOREIGN KEY (marca, modelo)
        REFERENCES modelo_equipo (marca, modelo) ON DELETE RESTRICT,
    CONSTRAINT fk_maquinaria_empresa FOREIGN KEY (ruc_propietario)
        REFERENCES empresa (numero_ruc) ON DELETE RESTRICT,
    CONSTRAINT ck_maquinaria_placa CHECK (placa ~ '^[A-Z0-9-]+$')
);

-- Certificados de inspección de cada unidad
CREATE TABLE certificado_maquinaria (
    codigo_certificado    varchar(50)  NOT NULL,
    entidad_certificadora varchar(100) NOT NULL,
    normativa             varchar(100) NOT NULL,
    fecha_inspeccion      date         NOT NULL,
    fecha_caducidad       date         NOT NULL,
    placa                 varchar(10)  NOT NULL,
    CONSTRAINT pk_certificado_maquinaria PRIMARY KEY (codigo_certificado),
    CONSTRAINT fk_certificado_maquinaria FOREIGN KEY (placa)
        REFERENCES maquinaria (placa) ON DELETE RESTRICT,
    CONSTRAINT ck_certificado_fechas CHECK (fecha_caducidad > fecha_inspeccion)
);

-- Entidades públicas que convocan los procesos
CREATE TABLE entidad_contratante (
    ruc_entidad  char(11)     NOT NULL,
    razon_social varchar(150) NOT NULL,
    direccion    varchar(255) NOT NULL,
    CONSTRAINT pk_entidad_contratante PRIMARY KEY (ruc_entidad),
    CONSTRAINT ck_entidad_ruc CHECK (ruc_entidad ~ '^20[0-9]{9}$')
);

-- Teléfonos de cada entidad contratante (atributo multivaluado)
CREATE TABLE telefono_entidad (
    ruc_entidad char(11)    NOT NULL,
    telefono    varchar(15) NOT NULL,
    CONSTRAINT pk_telefono_entidad PRIMARY KEY (ruc_entidad, telefono),
    CONSTRAINT fk_telefono_entidad FOREIGN KEY (ruc_entidad)
        REFERENCES entidad_contratante (ruc_entidad) ON DELETE CASCADE,
    CONSTRAINT ck_telefono_formato CHECK (telefono ~ '^[0-9]+(-[0-9]+)*$')
);

-- Procesos de contratación que la empresa registra y sigue
CREATE TABLE licitacion (
    codigo_licitacion         char(13)     NOT NULL,
    nro_requerimiento         varchar(20)  NOT NULL,
    tipo_proceso              varchar(30)  NOT NULL,
    objeto                    varchar(500) NOT NULL,
    dependencia_destino       varchar(100),
    fecha_registro            date         NOT NULL DEFAULT CURRENT_DATE,
    fecha_limite_presentacion date,
    estado                    varchar(15)  NOT NULL DEFAULT 'REGISTRADA',
    ruc_entidad               char(11)     NOT NULL,
    CONSTRAINT pk_licitacion PRIMARY KEY (codigo_licitacion),
    CONSTRAINT uq_licitacion_entidad_req UNIQUE (ruc_entidad, nro_requerimiento),
    CONSTRAINT fk_licitacion_entidad FOREIGN KEY (ruc_entidad)
        REFERENCES entidad_contratante (ruc_entidad) ON DELETE RESTRICT,
    CONSTRAINT ck_licitacion_codigo CHECK (codigo_licitacion ~ '^LIC-[0-9]{4}-[0-9]{4}$'),
    CONSTRAINT ck_licitacion_tipo CHECK (tipo_proceso IN
        ('CONTRATO MENOR', 'LICITACIÓN PÚBLICA', 'LICITACIÓN PÚBLICA ABREVIADA',
         'CONCURSO PÚBLICO', 'CONCURSO PÚBLICO ABREVIADO', 'COMPARACIÓN DE PRECIOS', 'OTRO')),
    CONSTRAINT ck_licitacion_estado CHECK (estado IN
        ('REGISTRADA', 'EN PREPARACIÓN', 'PRESENTADA', 'ADJUDICADA', 'NO ADJUDICADA', 'CANCELADA')),
    CONSTRAINT ck_licitacion_fechas CHECK (fecha_limite_presentacion >= fecha_registro)
);

-- Ofertas económicas presentadas por la empresa (1:1 con licitacion)
CREATE TABLE propuesta_comercial (
    codigo_propuesta     char(14) NOT NULL,
    fecha_emision        date     NOT NULL,
    plazo_ejecucion_dias smallint NOT NULL,
    cumple_tdr           boolean  NOT NULL,
    codigo_licitacion    char(13) NOT NULL,
    dni_suscriptor       char(8)  NOT NULL,
    cci_abono            char(20),
    CONSTRAINT pk_propuesta_comercial PRIMARY KEY (codigo_propuesta),
    CONSTRAINT uq_propuesta_licitacion UNIQUE (codigo_licitacion),
    CONSTRAINT fk_propuesta_licitacion FOREIGN KEY (codigo_licitacion)
        REFERENCES licitacion (codigo_licitacion) ON DELETE RESTRICT,
    CONSTRAINT fk_propuesta_representante FOREIGN KEY (dni_suscriptor)
        REFERENCES representante_legal (dni) ON DELETE RESTRICT,
    CONSTRAINT fk_propuesta_cuenta FOREIGN KEY (cci_abono)
        REFERENCES cuenta_bancaria (codigo_cci) ON DELETE RESTRICT,
    CONSTRAINT ck_propuesta_codigo CHECK (codigo_propuesta ~ '^PROP-[0-9]{4}-[0-9]{4}$'),
    CONSTRAINT ck_propuesta_plazo CHECK (plazo_ejecucion_dias BETWEEN 1 AND 9999)
);

-- Líneas de detalle de cada propuesta (entidad débil)
CREATE TABLE item_propuesta (
    codigo_propuesta char(14)      NOT NULL,
    nro_item         smallint      NOT NULL,
    descripcion      varchar(500)  NOT NULL,
    unidad_medida    varchar(10)   NOT NULL,
    cantidad         numeric(10,2) NOT NULL,
    precio_unitario  numeric(12,2) NOT NULL,
    CONSTRAINT pk_item_propuesta PRIMARY KEY (codigo_propuesta, nro_item),
    CONSTRAINT fk_item_propuesta FOREIGN KEY (codigo_propuesta)
        REFERENCES propuesta_comercial (codigo_propuesta) ON DELETE CASCADE,
    CONSTRAINT ck_item_nro CHECK (nro_item BETWEEN 1 AND 99),
    CONSTRAINT ck_item_unidad CHECK (unidad_medida IN
        ('HORA', 'DÍA', 'MES', 'UNIDAD', 'SERVICIO', 'GLOBAL')),
    CONSTRAINT ck_item_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_item_precio CHECK (precio_unitario > 0)
);

-- Cuotas de pago de cada propuesta (atributo multivaluado compuesto)
CREATE TABLE armada_pago (
    codigo_propuesta char(14)     NOT NULL,
    nro_armada       smallint     NOT NULL,
    dias_plazo       smallint     NOT NULL,
    condicion        varchar(200) NOT NULL,
    CONSTRAINT pk_armada_pago PRIMARY KEY (codigo_propuesta, nro_armada),
    CONSTRAINT fk_armada_propuesta FOREIGN KEY (codigo_propuesta)
        REFERENCES propuesta_comercial (codigo_propuesta) ON DELETE CASCADE,
    CONSTRAINT ck_armada_nro CHECK (nro_armada BETWEEN 1 AND 99),
    CONSTRAINT ck_armada_dias CHECK (dias_plazo BETWEEN 1 AND 9999)
);

-- Equipos asignados a cada propuesta (relación M:N)
CREATE TABLE propuesta_maquinaria (
    codigo_propuesta char(14)    NOT NULL,
    placa            varchar(10) NOT NULL,
    CONSTRAINT pk_propuesta_maquinaria PRIMARY KEY (codigo_propuesta, placa),
    CONSTRAINT fk_pm_propuesta FOREIGN KEY (codigo_propuesta)
        REFERENCES propuesta_comercial (codigo_propuesta) ON DELETE CASCADE,
    CONSTRAINT fk_pm_maquinaria FOREIGN KEY (placa)
        REFERENCES maquinaria (placa) ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------
-- 3. Índices
--    Las PK y UNIQUE ya crean su índice B-tree automáticamente (16).
--    PostgreSQL NO indexa las claves foráneas: se crean aquí las que no
--    quedan cubiertas por una PK o UNIQUE, más una para la consulta C01.
-- ---------------------------------------------------------------------
CREATE INDEX idx_cuenta_ruc_titular         ON cuenta_bancaria (ruc_titular);
CREATE INDEX idx_representante_ruc_empresa  ON representante_legal (ruc_empresa);
CREATE INDEX idx_maquinaria_modelo          ON maquinaria (marca, modelo);
CREATE INDEX idx_maquinaria_ruc_propietario ON maquinaria (ruc_propietario);
CREATE INDEX idx_certificado_placa          ON certificado_maquinaria (placa, fecha_caducidad);
CREATE INDEX idx_propuesta_dni_suscriptor   ON propuesta_comercial (dni_suscriptor);
CREATE INDEX idx_propuesta_cci_abono        ON propuesta_comercial (cci_abono);
CREATE INDEX idx_pm_placa                   ON propuesta_maquinaria (placa);
CREATE INDEX idx_licitacion_estado_limite   ON licitacion (estado, fecha_limite_presentacion);

-- ---------------------------------------------------------------------
-- 4. Vista para el atributo derivado precio_total (no se almacena)
-- ---------------------------------------------------------------------
CREATE VIEW vw_propuesta_total AS
SELECT p.codigo_propuesta,
       p.codigo_licitacion,
       COALESCE(SUM(i.cantidad * i.precio_unitario), 0)::numeric(12,2) AS precio_total
FROM propuesta_comercial p
LEFT JOIN item_propuesta i ON i.codigo_propuesta = p.codigo_propuesta
GROUP BY p.codigo_propuesta, p.codigo_licitacion;

-- ---------------------------------------------------------------------
-- 5. Comentarios (el diccionario también queda dentro de la base)
-- ---------------------------------------------------------------------
COMMENT ON TABLE empresa                IS 'Contribuyentes con RUC que intervienen en el proceso: postora y propietarias de equipos';
COMMENT ON TABLE cuenta_bancaria        IS 'Cuentas en las que se autoriza abonar los pagos';
COMMENT ON TABLE habilitacion_rnp       IS 'Inscripciones de cada empresa en los registros del RNP';
COMMENT ON TABLE representante_legal    IS 'Personas con poder para suscribir documentos de una empresa';
COMMENT ON TABLE modelo_equipo          IS 'Especificaciones técnicas de cada modelo de fabricante';
COMMENT ON TABLE maquinaria             IS 'Unidades de equipo, propias o subcontratadas';
COMMENT ON TABLE certificado_maquinaria IS 'Certificados de inspección de cada unidad';
COMMENT ON TABLE entidad_contratante    IS 'Entidades públicas que convocan los procesos';
COMMENT ON TABLE telefono_entidad       IS 'Teléfonos de cada entidad contratante';
COMMENT ON TABLE licitacion             IS 'Procesos de contratación que la empresa registra y sigue';
COMMENT ON TABLE propuesta_comercial    IS 'Ofertas económicas presentadas por la empresa';
COMMENT ON TABLE item_propuesta         IS 'Líneas de detalle de cada propuesta';
COMMENT ON TABLE armada_pago            IS 'Cuotas de pago de cada propuesta';
COMMENT ON TABLE propuesta_maquinaria   IS 'Equipos asignados a cada propuesta';
COMMENT ON VIEW  vw_propuesta_total     IS 'Atributo derivado precio_total = suma de cantidad x precio_unitario';

-- ---------------------------------------------------------------------
-- 6. Verificación (resultado esperado: 14 | 1 | 25 | 15 | 29)
-- ---------------------------------------------------------------------
SELECT
  (SELECT count(*) FROM information_schema.tables
    WHERE table_schema = 'licitaciones' AND table_type = 'BASE TABLE') AS tablas,
  (SELECT count(*) FROM information_schema.views
    WHERE table_schema = 'licitaciones')                             AS vistas,
  (SELECT count(*) FROM pg_indexes
    WHERE schemaname = 'licitaciones')                               AS indices,
  (SELECT count(*) FROM information_schema.table_constraints
    WHERE constraint_schema = 'licitaciones'
      AND constraint_type = 'FOREIGN KEY')                           AS claves_foraneas,
  (SELECT count(*) FROM pg_constraint
    WHERE connamespace = 'licitaciones'::regnamespace
      AND contype = 'c')                                             AS restricciones_check;
