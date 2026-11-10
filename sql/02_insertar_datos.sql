-- =====================================================================
-- Proyecto : Desarrollo de la base de datos para la funcionalidad
--            "Registro de Licitaciones de Servicios" - TECNOSERVI S.R.L.
-- Gestor   : PostgreSQL
-- Archivo  : 02_insertar_datos.sql  (carga de datos de prueba)
-- Uso      : Query Tool abierto sobre "bd_licitaciones". Ejecutar todo (F5).
--            Se ejecuta como una sola transacción y puede repetirse:
--            primero vacía las tablas y luego vuelve a cargarlas.
--
-- Origen de los datos:
--   [DOC] = tomado de los documentos del contacto (Consulta RUC y
--           Constancia RNP del 01/10/2025, certificado GBMA-1847-2023,
--           propuesta, declaración jurada y carta del 22/10/2025).
--   [REF] = dato real de la entidad, pero RUC, dirección o teléfono
--           referenciales: reemplazar con Consulta RUC si se requiere.
--   [ILU] = caso ilustrativo, coherente con el giro de la empresa,
--           los montos de contrato menor (8 UIT) y los certificados.
-- =====================================================================
SET search_path TO licitaciones, public;

-- Vaciar todas las tablas (permite volver a ejecutar el script)
TRUNCATE TABLE propuesta_maquinaria, armada_pago, item_propuesta,
               propuesta_comercial, licitacion, telefono_entidad,
               entidad_contratante, certificado_maquinaria, maquinaria,
               modelo_equipo, representante_legal, habilitacion_rnp,
               cuenta_bancaria, empresa;

-- ---------------------------------------------------------------------
-- 1. Empresas
-- ---------------------------------------------------------------------
INSERT INTO empresa (numero_ruc, razon_social, estado_contribuyente,
                     condicion_contribuyente, domicilio_fiscal, fecha_verificacion_sunat)
VALUES
 ('20216292783', 'TECNOSERVI S.R.L.', 'ACTIVO', 'HABIDO',
  'MZA. E LOTE. 10 URB. NUEVO PERU AREQUIPA - AREQUIPA - PAUCARPATA', '2025-10-01'),   -- [DOC]
 ('20602187455', 'HIDRAULIC CRANES TURPO S.R.L.', 'ACTIVO', 'HABIDO',
  'AREQUIPA - AREQUIPA - CERRO COLORADO', '2025-10-01');                                 -- [REF] propietaria de AEJ-831

-- ---------------------------------------------------------------------
-- 2. Habilitación RNP, cuenta y representante de la empresa postora [DOC]
-- ---------------------------------------------------------------------
INSERT INTO habilitacion_rnp (numero_ruc, tipo_registro, fecha_inicio_vigencia,
                              estado_inscripcion, fecha_verificacion)
VALUES ('20216292783', 'PROVEEDOR DE SERVICIOS', '2018-03-22', 'VIGENTE', '2025-10-01');

INSERT INTO cuenta_bancaria (codigo_cci, entidad_bancaria, ruc_titular)
VALUES ('00221517081758701021', 'BANCO DE CREDITO DEL PERU', '20216292783');

INSERT INTO representante_legal (dni, nombres, apellido_paterno, apellido_materno, cargo,
                                 correo_notificacion, telefono, ruc_empresa)
VALUES ('70008259', 'JOSE BLADIMIRO', 'VILCA', 'BEGAZO', 'SUBGERENTE',
        'JOSEBVB@GMAIL.COM', '958338311', '20216292783');

-- ---------------------------------------------------------------------
-- 3. Modelos, maquinaria y certificados
-- ---------------------------------------------------------------------
INSERT INTO modelo_equipo (marca, modelo, tipo_equipo, capacidad_ton)
VALUES
 ('FASSI', 'F660.XP.26', 'GRÚA ARTICULADA SOBRE CAMIÓN',      22.00),  -- [DOC] certificado
 ('XCMG',  'SQ8SK3Q',    'GRÚA TELESCÓPICA SOBRE CAMIÓN',      8.00),  -- ficha técnica del fabricante
 ('ALTEC', 'AT37G',      'PLUMA TELESCÓPICA CON CANASTILLA',   0.16);  -- ficha técnica (canastilla de 159 kg)

INSERT INTO maquinaria (placa, marca, modelo, serie, marca_vehiculo, ruc_propietario)
VALUES
 ('AEJ-831', 'FASSI', 'F660.XP.26', '0105',       'VOLVO',    '20602187455'),  -- [DOC] subcontratada
 ('AJR-547', 'FASSI', 'F660.XP.26', '0231',       'VOLVO',    '20602187455'),  -- [ILU] subcontratada
 ('V8A-516', 'XCMG',  'SQ8SK3Q',    'XCT0841',    'SINOTRUK', '20216292783'),  -- [ILU] propia
 ('V5H-219', 'ALTEC', 'AT37G',      '1018BT2193', 'FORD',     '20216292783');  -- [ILU] propia

INSERT INTO certificado_maquinaria (codigo_certificado, entidad_certificadora, normativa,
                                    fecha_inspeccion, fecha_caducidad, placa)
VALUES
 ('GBMA-1847-2023', 'GRUPO B''MA S.A.C.', 'ASME B30.22',     '2023-11-15', '2024-11-15', 'AEJ-831'),  -- [DOC]
 ('GBMA-2391-2024', 'GRUPO B''MA S.A.C.', 'ANSI/SAIA A92.2', '2024-10-08', '2025-10-08', 'V5H-219'),  -- [ILU]
 ('GBMA-2433-2024', 'GRUPO B''MA S.A.C.', 'ASME B30.22',     '2024-11-12', '2025-11-12', 'AEJ-831'),  -- [ILU] renovación
 ('GBMA-2510-2025', 'GRUPO B''MA S.A.C.', 'ASME B30.5',      '2025-02-20', '2026-02-20', 'V8A-516'),  -- [ILU]
 ('GBMA-2902-2025', 'GRUPO B''MA S.A.C.', 'ANSI/SAIA A92.2', '2025-10-07', '2026-10-07', 'V5H-219'),  -- [ILU] vence el 07/10/2026
 ('GBMA-2948-2025', 'GRUPO B''MA S.A.C.', 'ASME B30.22',     '2025-11-10', '2026-11-10', 'AEJ-831'),  -- [ILU] renovación
 ('GBMA-3075-2026', 'GRUPO B''MA S.A.C.', 'ASME B30.5',      '2026-02-18', '2027-02-18', 'V8A-516'),  -- [ILU] renovación
 ('GBMA-3101-2026', 'GRUPO B''MA S.A.C.', 'ASME B30.22',     '2026-03-02', '2027-03-02', 'AJR-547');  -- [ILU]

-- ---------------------------------------------------------------------
-- 4. Entidades contratantes y teléfonos
-- ---------------------------------------------------------------------
INSERT INTO entidad_contratante (ruc_entidad, razon_social, direccion)
VALUES
 ('20173932147', 'MUNICIPALIDAD DISTRITAL DE SACHACA',
  'AV. FERNANDINI S/N (ESTADIO DE SACHACA) - SACHACA - AREQUIPA'),                      -- [DOC] dirección / [REF] RUC
 ('20159317421', 'MUNICIPALIDAD PROVINCIAL DE AREQUIPA',
  'PLAZA DE ARMAS S/N (PORTAL MUNICIPAL) - CERCADO - AREQUIPA'),                        -- [REF]
 ('20172845631', 'MUNICIPALIDAD DISTRITAL DE CAYMA',
  'PLAZA PRINCIPAL DE CAYMA S/N - CAYMA - AREQUIPA'),                                   -- [REF]
 ('20172640584', 'MUNICIPALIDAD DISTRITAL DE YANAHUARA',
  'PLAZA PRINCIPAL DE YANAHUARA S/N - YANAHUARA - AREQUIPA'),                           -- [REF]
 ('20154378163', 'MUNICIPALIDAD DISTRITAL DE JOSÉ LUIS BUSTAMANTE Y RIVERO',
  'AV. DOLORES S/N - JOSÉ LUIS BUSTAMANTE Y RIVERO - AREQUIPA'),                        -- [REF]
 ('20498123768', 'GOBIERNO REGIONAL DE AREQUIPA',
  'AV. UNIÓN 200 - PAUCARPATA - AREQUIPA'),                                             -- [REF]
 ('20163604818', 'UNIVERSIDAD NACIONAL DE SAN AGUSTÍN DE AREQUIPA',
  'CALLE SANTA CATALINA 117 - CERCADO - AREQUIPA');                                     -- [REF]

INSERT INTO telefono_entidad (ruc_entidad, telefono)
VALUES
 ('20173932147', '054-605690'), ('20173932147', '054-605696'),   -- [DOC]
 ('20159317421', '054-380050'), ('20159317421', '054-380051'),   -- [REF]
 ('20172845631', '054-255520'),
 ('20172640584', '054-271420'),
 ('20154378163', '054-424040'),
 ('20498123768', '054-382860'), ('20498123768', '054-382861'),
 ('20163604818', '054-237808');

-- ---------------------------------------------------------------------
-- 5. Licitaciones (24): marzo 2025 - octubre 2026
--    Contrato menor: hasta 8 UIT (S/ 42 800 en 2025; S/ 44 000 en 2026)
-- ---------------------------------------------------------------------
INSERT INTO licitacion (codigo_licitacion, nro_requerimiento, tipo_proceso, objeto,
                        dependencia_destino, fecha_registro, fecha_limite_presentacion,
                        estado, ruc_entidad)
VALUES
 ('LIC-2025-0001', '00000318', 'CONTRATO MENOR',
  'SERVICIO DE ALQUILER DE CAMIÓN GRÚA CON OPERADOR PARA TRASLADO DE MOBILIARIO URBANO',
  'SUBGERENCIA DE LOGÍSTICA', '2025-03-10', '2025-03-14', 'ADJUDICADA', '20159317421'),
 ('LIC-2025-0002', '00000127', 'CONTRATO MENOR',
  'SERVICIO DE MANTENIMIENTO DE JUEGOS INFANTILES METÁLICOS EN PARQUES DEL DISTRITO',
  'SUBGERENCIA DE LOGÍSTICA', '2025-04-02', '2025-04-08', 'NO ADJUDICADA', '20172845631'),
 ('LIC-2025-0003', '00000896', 'CONCURSO PÚBLICO ABREVIADO',
  'SERVICIO DE ALQUILER DE CAMIÓN GRÚA CON OPERADOR POR TRES MESES',
  'OFICINA DE ABASTECIMIENTO', '2025-04-21', '2025-05-06', 'ADJUDICADA', '20498123768'),
 ('LIC-2025-0004', '00002231', 'CONTRATO MENOR',
  'SERVICIO DE PINTURA ANTICORROSIVA DE LA COBERTURA METÁLICA DEL COMEDOR UNIVERSITARIO',
  'UNIDAD DE ABASTECIMIENTO', '2025-05-19', '2025-05-23', 'ADJUDICADA', '20163604818'),
 ('LIC-2025-0005', '00000412', 'CONTRATO MENOR',
  'SERVICIO DE MANTENIMIENTO DE LUMINARIAS CON CAMIÓN CANASTILLA',
  'SUBGERENCIA DE LOGÍSTICA', '2025-06-09', '2025-06-13', 'NO ADJUDICADA', '20172640584'),
 ('LIC-2025-0006', '00000587', 'CONTRATO MENOR',
  'SERVICIO DE IZAJE Y MONTAJE DE ESTRUCTURAS METÁLICAS EN EL MERCADO SAN CAMILO',
  'SUBGERENCIA DE LOGÍSTICA', '2025-07-07', '2025-07-11', 'NO ADJUDICADA', '20159317421'),
 ('LIC-2025-0007', '00000233', 'CONTRATO MENOR',
  'SERVICIO DE REPARACIÓN DE BARANDAS METÁLICAS EN PARQUES DEL DISTRITO',
  'SUBGERENCIA DE LOGÍSTICA', '2025-08-04', '2025-08-08', 'CANCELADA', '20154378163'),
 ('LIC-2025-0008', '00001158', 'CONTRATO MENOR',
  'SERVICIO DE INSPECCIÓN Y EVALUACIÓN ESTRUCTURAL DE TIJERALES METÁLICOS DEL ALMACÉN REGIONAL',
  'OFICINA DE ABASTECIMIENTO', '2025-09-01', '2025-09-05', 'ADJUDICADA', '20498123768'),
 ('LIC-2025-0009', '00001340', 'CONTRATO MENOR',                                    -- [DOC] requerimiento real
  'SERVICIO DE ALQUILER DE PLUMA TELESCÓPICA CON CANASTILLA',
  'SUBGERENCIA DE LOGÍSTICA', '2025-10-15', '2025-10-22', 'PRESENTADA', '20173932147'),
 ('LIC-2025-0010', '00002876', 'CONTRATO MENOR',
  'SERVICIO DE MANTENIMIENTO DE ESTRUCTURAS METÁLICAS DE GRADERÍAS DEL ESTADIO UNIVERSITARIO',
  'UNIDAD DE ABASTECIMIENTO', '2025-11-10', '2025-11-14', 'NO ADJUDICADA', '20163604818'),
 ('LIC-2025-0011', '00000498', 'CONTRATO MENOR',
  'SERVICIO DE ALQUILER DE CAMIÓN GRÚA CON OPERADOR PARA INSTALACIÓN DE ADORNOS NAVIDEÑOS',
  'SUBGERENCIA DE LOGÍSTICA', '2025-12-01', '2025-12-04', 'ADJUDICADA', '20172845631'),
 ('LIC-2026-0001', '00000097', 'CONTRATO MENOR',
  'SERVICIO DE MANTENIMIENTO DE LUMINARIAS ORNAMENTALES DEL CENTRO HISTÓRICO CON CAMIÓN CANASTILLA',
  'SUBGERENCIA DE LOGÍSTICA', '2026-01-19', '2026-01-23', 'ADJUDICADA', '20159317421'),
 ('LIC-2026-0002', '00000211', 'CONTRATO MENOR',
  'SERVICIO DE ALQUILER DE PLUMA TELESCÓPICA CON CANASTILLA PARA PODA DE ÁRBOLES',
  'SUBGERENCIA DE LOGÍSTICA', '2026-02-16', '2026-02-20', 'ADJUDICADA', '20173932147'),
 ('LIC-2026-0003', '00000342', 'CONCURSO PÚBLICO ABREVIADO',
  'SERVICIO DE MANTENIMIENTO INTEGRAL DE COBERTURAS METÁLICAS DE LA SEDE REGIONAL',
  'OFICINA DE ABASTECIMIENTO', '2026-03-09', '2026-03-24', 'NO ADJUDICADA', '20498123768'),
 ('LIC-2026-0004', '00000163', 'CONTRATO MENOR',
  'SERVICIO DE ALQUILER DE CAMIÓN GRÚA CON OPERADOR PARA RETIRO DE ESTRUCTURAS PUBLICITARIAS',
  'SUBGERENCIA DE LOGÍSTICA', '2026-04-13', '2026-04-17', 'ADJUDICADA', '20172640584'),
 ('LIC-2026-0005', '00000281', 'CONTRATO MENOR',
  'SERVICIO DE FABRICACIÓN Y COLOCACIÓN DE REJAS METÁLICAS DE PROTECCIÓN EN ÁREAS VERDES',
  'SUBGERENCIA DE LOGÍSTICA', '2026-05-18', '2026-05-22', 'NO ADJUDICADA', '20154378163'),
 ('LIC-2026-0006', '00001045', 'CONTRATO MENOR',
  'SERVICIO DE PINTURA ANTICORROSIVA DE ESTRUCTURAS METÁLICAS DEL AUDITORIO UNIVERSITARIO',
  'UNIDAD DE ABASTECIMIENTO', '2026-06-15', '2026-06-19', 'ADJUDICADA', '20163604818'),
 ('LIC-2026-0007', '00000733', 'CONCURSO PÚBLICO ABREVIADO',
  'SERVICIO DE ALQUILER DE CAMIÓN GRÚA CON OPERADOR POR TRES MESES',
  'SUBGERENCIA DE LOGÍSTICA', '2026-08-03', '2026-08-18', 'PRESENTADA', '20159317421'),
 ('LIC-2026-0008', '00000716', 'CONTRATO MENOR',
  'SERVICIO DE MANTENIMIENTO DE PUENTES PEATONALES METÁLICOS',
  'SUBGERENCIA DE LOGÍSTICA', '2026-09-14', '2026-09-18', 'PRESENTADA', '20172845631'),
 ('LIC-2026-0009', '00001198', 'CONTRATO MENOR',
  'SERVICIO DE ALQUILER DE PLUMA TELESCÓPICA CON CANASTILLA PARA MANTENIMIENTO DE ALUMBRADO PÚBLICO',
  'SUBGERENCIA DE LOGÍSTICA', '2026-10-12', '2026-10-27', 'EN PREPARACIÓN', '20173932147'),
 ('LIC-2026-0010', '00001377', 'CONTRATO MENOR',
  'SERVICIO DE IZAJE DE EQUIPOS DE AIRE ACONDICIONADO EN LA SEDE REGIONAL',
  'OFICINA DE ABASTECIMIENTO', '2026-10-19', '2026-10-30', 'EN PREPARACIÓN', '20498123768'),
 ('LIC-2026-0011', '00001022', 'CONTRATO MENOR',
  'SERVICIO DE MANTENIMIENTO DE PÉRGOLAS METÁLICAS EN PARQUES DEL CERCADO',
  'SUBGERENCIA DE LOGÍSTICA', '2026-10-20', '2026-11-04', 'REGISTRADA', '20159317421'),
 ('LIC-2026-0012', '00001590', 'CONTRATO MENOR',
  'SERVICIO DE INSPECCIÓN ESTRUCTURAL DE TIJERALES METÁLICOS DE LA BIBLIOTECA CENTRAL',
  'UNIDAD DE ABASTECIMIENTO', '2026-10-21', '2026-11-06', 'REGISTRADA', '20163604818'),
 ('LIC-2026-0013', '00000402', 'CONTRATO MENOR',
  'SERVICIO DE ALQUILER DE CAMIÓN GRÚA CON OPERADOR PARA TRASLADO DE CONTENEDORES',
  'SUBGERENCIA DE LOGÍSTICA', '2026-10-22', '2026-11-13', 'REGISTRADA', '20154378163');

-- ---------------------------------------------------------------------
-- 6. Propuestas comerciales (19)
-- ---------------------------------------------------------------------
INSERT INTO propuesta_comercial (codigo_propuesta, fecha_emision, plazo_ejecucion_dias,
                                 cumple_tdr, codigo_licitacion, dni_suscriptor, cci_abono)
VALUES
 ('PROP-2025-0001', '2025-03-13', 15, TRUE, 'LIC-2025-0001', '70008259', '00221517081758701021'),
 ('PROP-2025-0002', '2025-04-07', 30, TRUE, 'LIC-2025-0002', '70008259', NULL),
 ('PROP-2025-0003', '2025-05-05', 90, TRUE, 'LIC-2025-0003', '70008259', '00221517081758701021'),
 ('PROP-2025-0004', '2025-05-22', 25, TRUE, 'LIC-2025-0004', '70008259', '00221517081758701021'),
 ('PROP-2025-0005', '2025-06-12', 20, TRUE, 'LIC-2025-0005', '70008259', '00221517081758701021'),
 ('PROP-2025-0006', '2025-07-10', 20, TRUE, 'LIC-2025-0006', '70008259', '00221517081758701021'),
 ('PROP-2025-0007', '2025-09-04', 30, TRUE, 'LIC-2025-0008', '70008259', '00221517081758701021'),
 ('PROP-2025-0008', '2025-10-22', 60, TRUE, 'LIC-2025-0009', '70008259', '00221517081758701021'), -- [DOC]
 ('PROP-2025-0009', '2025-11-13', 30, TRUE, 'LIC-2025-0010', '70008259', NULL),
 ('PROP-2025-0010', '2025-12-03', 10, TRUE, 'LIC-2025-0011', '70008259', '00221517081758701021'),
 ('PROP-2026-0001', '2026-01-22', 20, TRUE, 'LIC-2026-0001', '70008259', '00221517081758701021'),
 ('PROP-2026-0002', '2026-02-19', 30, TRUE, 'LIC-2026-0002', '70008259', '00221517081758701021'),
 ('PROP-2026-0003', '2026-03-23', 60, TRUE, 'LIC-2026-0003', '70008259', '00221517081758701021'),
 ('PROP-2026-0004', '2026-04-16', 15, TRUE, 'LIC-2026-0004', '70008259', '00221517081758701021'),
 ('PROP-2026-0005', '2026-05-21', 30, TRUE, 'LIC-2026-0005', '70008259', NULL),
 ('PROP-2026-0006', '2026-06-18', 25, TRUE, 'LIC-2026-0006', '70008259', '00221517081758701021'),
 ('PROP-2026-0007', '2026-08-17', 90, TRUE, 'LIC-2026-0007', '70008259', '00221517081758701021'),
 ('PROP-2026-0008', '2026-09-17', 30, TRUE, 'LIC-2026-0008', '70008259', '00221517081758701021'),
 ('PROP-2026-0009', '2026-10-22', 45, TRUE, 'LIC-2026-0009', '70008259', '00221517081758701021'); -- borrador

-- ---------------------------------------------------------------------
-- 7. Ítems de las propuestas (24)
-- ---------------------------------------------------------------------
INSERT INTO item_propuesta (codigo_propuesta, nro_item, descripcion, unidad_medida,
                            cantidad, precio_unitario)
VALUES
 ('PROP-2025-0001', 1, 'ALQUILER DE CAMIÓN GRÚA CON OPERADOR',                   'HORA',     40,   480.00),
 ('PROP-2025-0001', 2, 'MOVILIZACIÓN Y DESMOVILIZACIÓN DE EQUIPO',               'SERVICIO',  1,   900.00),
 ('PROP-2025-0002', 1, 'MANTENIMIENTO Y PINTURA DE JUEGOS INFANTILES METÁLICOS', 'GLOBAL',    1, 26800.00),
 ('PROP-2025-0003', 1, 'ALQUILER MENSUAL DE CAMIÓN GRÚA CON OPERADOR',           'MES',       3, 36500.00),
 ('PROP-2025-0004', 1, 'PINTURA ANTICORROSIVA DE ESTRUCTURA METÁLICA',           'GLOBAL',    1, 38900.00),
 ('PROP-2025-0005', 1, 'ALQUILER DE CAMIÓN CON CANASTILLA Y OPERADOR',           'DÍA',      12,  1750.00),
 ('PROP-2025-0006', 1, 'ALQUILER DE CAMIÓN GRÚA CON OPERADOR',                   'HORA',     24,   500.00),
 ('PROP-2025-0006', 2, 'MONTAJE DE ESTRUCTURAS METÁLICAS',                       'GLOBAL',    1, 14500.00),
 ('PROP-2025-0007', 1, 'INSPECCIÓN Y EVALUACIÓN ESTRUCTURAL CON INFORME TÉCNICO', 'SERVICIO', 1, 17800.00),
 ('PROP-2025-0008', 1, 'SERVICIO DE ALQUILER DE PLUMA TELESCÓPICA CON CANASTILLA', 'HORA',   60,   500.00), -- [DOC]
 ('PROP-2025-0009', 1, 'MANTENIMIENTO DE ESTRUCTURAS METÁLICAS DE GRADERÍAS',    'GLOBAL',    1, 36200.00),
 ('PROP-2025-0010', 1, 'ALQUILER DE CAMIÓN GRÚA CON OPERADOR',                   'HORA',     30,   470.00),
 ('PROP-2025-0010', 2, 'MOVILIZACIÓN Y DESMOVILIZACIÓN DE EQUIPO',               'SERVICIO',  1,   800.00),
 ('PROP-2026-0001', 1, 'ALQUILER DE CAMIÓN CON CANASTILLA Y OPERADOR',           'DÍA',      15,  1800.00),
 ('PROP-2026-0002', 1, 'SERVICIO DE ALQUILER DE PLUMA TELESCÓPICA CON CANASTILLA', 'HORA',   50,   500.00),
 ('PROP-2026-0003', 1, 'MANTENIMIENTO INTEGRAL DE COBERTURAS METÁLICAS',         'GLOBAL',    1, 92000.00),
 ('PROP-2026-0003', 2, 'ALQUILER DE CAMIÓN GRÚA CON OPERADOR',                   'HORA',      8,   560.00),
 ('PROP-2026-0004', 1, 'ALQUILER DE CAMIÓN GRÚA CON OPERADOR',                   'HORA',     36,   490.00),
 ('PROP-2026-0004', 2, 'MOVILIZACIÓN Y DESMOVILIZACIÓN DE EQUIPO',               'SERVICIO',  1,   850.00),
 ('PROP-2026-0005', 1, 'FABRICACIÓN Y COLOCACIÓN DE REJAS METÁLICAS',            'GLOBAL',    1, 32400.00),
 ('PROP-2026-0006', 1, 'PINTURA ANTICORROSIVA DE ESTRUCTURA METÁLICA',           'GLOBAL',    1, 39600.00),
 ('PROP-2026-0007', 1, 'ALQUILER MENSUAL DE CAMIÓN GRÚA CON OPERADOR',           'MES',       3, 37500.00),
 ('PROP-2026-0008', 1, 'MANTENIMIENTO DE PUENTES PEATONALES METÁLICOS',          'GLOBAL',    1, 41500.00),
 ('PROP-2026-0009', 1, 'SERVICIO DE ALQUILER DE PLUMA TELESCÓPICA CON CANASTILLA', 'HORA',   60,   520.00);

-- ---------------------------------------------------------------------
-- 8. Armadas de pago (28)
-- ---------------------------------------------------------------------
INSERT INTO armada_pago (codigo_propuesta, nro_armada, dias_plazo, condicion)
VALUES
 ('PROP-2025-0001', 1, 30, 'A LA CONFORMIDAD DEL SERVICIO'),
 ('PROP-2025-0002', 1, 30, 'A LA CONFORMIDAD DEL SERVICIO'),
 ('PROP-2025-0003', 1, 30, 'PRIMER MES, PREVIA CONFORMIDAD'),
 ('PROP-2025-0003', 2, 60, 'SEGUNDO MES, PREVIA CONFORMIDAD'),
 ('PROP-2025-0003', 3, 90, 'TERCER MES, PREVIA CONFORMIDAD'),
 ('PROP-2025-0004', 1, 15, '50 % CON EL AVANCE DEL 50 % DEL SERVICIO'),
 ('PROP-2025-0004', 2, 30, '50 % A LA CONFORMIDAD FINAL'),
 ('PROP-2025-0005', 1, 30, 'A LA CONFORMIDAD DEL SERVICIO'),
 ('PROP-2025-0006', 1, 30, 'A LA CONFORMIDAD DEL SERVICIO'),
 ('PROP-2025-0007', 1, 30, 'A LA ENTREGA Y CONFORMIDAD DEL INFORME TÉCNICO'),
 ('PROP-2025-0008', 1, 30, 'SEGÚN LAS HORAS TRABAJADAS'),                     -- [DOC]
 ('PROP-2025-0008', 2, 60, 'AL COMPLETAR EL SERVICIO'),                       -- [DOC]
 ('PROP-2025-0009', 1, 30, 'A LA CONFORMIDAD DEL SERVICIO'),
 ('PROP-2025-0010', 1, 15, 'A LA CONFORMIDAD DEL SERVICIO'),
 ('PROP-2026-0001', 1, 30, 'A LA CONFORMIDAD DEL SERVICIO'),
 ('PROP-2026-0002', 1, 30, 'SEGÚN LAS HORAS TRABAJADAS'),
 ('PROP-2026-0003', 1, 30, '50 % CON EL AVANCE DEL 50 % DEL SERVICIO'),
 ('PROP-2026-0003', 2, 60, '50 % A LA CONFORMIDAD FINAL'),
 ('PROP-2026-0004', 1, 30, 'A LA CONFORMIDAD DEL SERVICIO'),
 ('PROP-2026-0005', 1, 30, 'A LA CONFORMIDAD DEL SERVICIO'),
 ('PROP-2026-0006', 1, 15, '50 % CON EL AVANCE DEL 50 % DEL SERVICIO'),
 ('PROP-2026-0006', 2, 30, '50 % A LA CONFORMIDAD FINAL'),
 ('PROP-2026-0007', 1, 30, 'PRIMER MES, PREVIA CONFORMIDAD'),
 ('PROP-2026-0007', 2, 60, 'SEGUNDO MES, PREVIA CONFORMIDAD'),
 ('PROP-2026-0007', 3, 90, 'TERCER MES, PREVIA CONFORMIDAD'),
 ('PROP-2026-0008', 1, 30, 'A LA CONFORMIDAD DEL SERVICIO'),
 ('PROP-2026-0009', 1, 30, 'SEGÚN LAS HORAS TRABAJADAS'),
 ('PROP-2026-0009', 2, 45, 'AL COMPLETAR EL SERVICIO');

-- ---------------------------------------------------------------------
-- 9. Equipos asignados a las propuestas (13)
-- ---------------------------------------------------------------------
INSERT INTO propuesta_maquinaria (codigo_propuesta, placa)
VALUES
 ('PROP-2025-0001', 'AEJ-831'),
 ('PROP-2025-0003', 'AEJ-831'),
 ('PROP-2025-0005', 'V5H-219'),
 ('PROP-2025-0006', 'AEJ-831'),
 ('PROP-2025-0008', 'V5H-219'),
 ('PROP-2025-0010', 'V8A-516'),
 ('PROP-2026-0001', 'V5H-219'),
 ('PROP-2026-0002', 'V5H-219'),
 ('PROP-2026-0003', 'AJR-547'),
 ('PROP-2026-0004', 'AEJ-831'),
 ('PROP-2026-0007', 'AJR-547'),
 ('PROP-2026-0007', 'V8A-516'),
 ('PROP-2026-0009', 'V5H-219');   -- su certificado venció el 07/10/2026 (la consulta C06 lo detecta)

-- ---------------------------------------------------------------------
-- 10. Resumen de la carga (resultado esperado: 145 filas en total)
-- ---------------------------------------------------------------------
SELECT 'empresa' AS tabla, count(*) AS filas FROM empresa
UNION ALL SELECT 'cuenta_bancaria',        count(*) FROM cuenta_bancaria
UNION ALL SELECT 'habilitacion_rnp',       count(*) FROM habilitacion_rnp
UNION ALL SELECT 'representante_legal',    count(*) FROM representante_legal
UNION ALL SELECT 'modelo_equipo',          count(*) FROM modelo_equipo
UNION ALL SELECT 'maquinaria',             count(*) FROM maquinaria
UNION ALL SELECT 'certificado_maquinaria', count(*) FROM certificado_maquinaria
UNION ALL SELECT 'entidad_contratante',    count(*) FROM entidad_contratante
UNION ALL SELECT 'telefono_entidad',       count(*) FROM telefono_entidad
UNION ALL SELECT 'licitacion',             count(*) FROM licitacion
UNION ALL SELECT 'propuesta_comercial',    count(*) FROM propuesta_comercial
UNION ALL SELECT 'item_propuesta',         count(*) FROM item_propuesta
UNION ALL SELECT 'armada_pago',            count(*) FROM armada_pago
UNION ALL SELECT 'propuesta_maquinaria',   count(*) FROM propuesta_maquinaria;
