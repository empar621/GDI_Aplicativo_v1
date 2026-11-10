# Registro de Licitaciones de Servicios 

Aplicativo de escritorio que demuestra el funcionamiento de la base de datos
`bd_licitaciones` (PostgreSQL 18). Permite registrar, modificar y eliminar los
datos de las 14 tablas del modelo y consultar 13 reportes.

- **Lenguaje:** Python 3 con Tkinter/ttk (biblioteca estándar). No usa frameworks.
- **Gestor:** PostgreSQL 18, conectado con el driver `psycopg` 3.
- **Altas, cambios y bajas:** solo con **procedimientos almacenados** (`CALL sp_<tabla>_<acción>`).
  El aplicativo nunca ejecuta `INSERT`, `UPDATE` ni `DELETE`.
- **Reglas de negocio, historiales y auditoría:** con **triggers**.
- **Reportes:** 13 vistas `vw_rep*`; 12 de ellas usan `JOIN`.

## 1. Instalar la base de datos

Requisito: PostgreSQL 18 instalado (incluye `psql`).

**Opción A — automática.** Doble clic en `instalar_bd.bat`, o desde una consola:

```bat
instalar_bd.bat
```

Pide la contraseña del usuario `postgres` en cada paso (o defina antes
`set PGPASSWORD=...`). Si PostgreSQL no está en `C:\Program Files\PostgreSQL\18\bin`,
defina `PGBIN`. **Atención:** reinstala desde cero (borra los datos del esquema).

**Opción B — pgAdmin.** Ejecute los scripts de `sql/` en este orden, con el Query Tool:

| Orden | Script | Dónde |
|---|---|---|
| 1 | `00_crear_base.sql` | base `postgres` |
| 2 | `01_crear_tablas.sql` | base `bd_licitaciones` |
| 3 | `02_insertar_datos.sql` | base `bd_licitaciones` |
| 4 | `04_procedimientos.sql` | base `bd_licitaciones` |
| 5 | `05_triggers.sql` | base `bd_licitaciones` |
| 6 | `06_reportes.sql` | base `bd_licitaciones` |

`03_consultas.sql` contiene las 10 consultas originales del informe (no se instala;
se ejecuta a mano). Los triggers (paso 5) deben crearse **después** de cargar los
datos: algunos datos históricos de prueba no cumplen las reglas nuevas a propósito
(el reporte R06 los detecta).

## 2. Ejecutar el aplicativo

- **Ejecutable:** `dist\Licitaciones.exe` (no necesita Python instalado).
- **Desde el código fuente:**

  ```bat
  python -m venv .venv
  .venv\Scripts\pip install -r requirements.txt
  .venv\Scripts\python licitaciones.py
  ```

En la ventana de conexión escriba servidor, puerto, base, usuario y contraseña.
Los datos de conexión (sin la contraseña) se recuerdan en
`%APPDATA%\LicitacionesTECNOSERVI\config.ini`.

## 3. Generar el ejecutable

```bat
.venv\Scripts\pyinstaller --noconfirm --clean --onefile --windowed --name Licitaciones --collect-all psycopg_binary licitaciones.py
```

El resultado queda en `dist\Licitaciones.exe`.

## 4. Estructura

```
licitaciones.py            punto de entrada
instalar_bd.bat            instala la base en el orden correcto
sql/
  00_crear_base.sql        CREATE DATABASE
  01_crear_tablas.sql      esquema, 14 tablas, índices, vista de precio total
  02_insertar_datos.sql    145 registros de prueba
  03_consultas.sql         10 consultas del informe (C01–C10)
  04_procedimientos.sql    43 procedimientos (insertar / actualizar / eliminar)
  05_triggers.sql          3 tablas de historial y 37 triggers
  06_reportes.sql          13 vistas de reporte (R01–R13)
app/
  config.py                configuración de conexión
  db.py                    acceso a datos: CALL a procedimientos y SELECT
  errores.py               traduce errores de PostgreSQL a mensajes claros
  catalogo.py              descripción de las 14 tablas (campos, listas, procedimientos)
  reportes.py              descripción de los 13 reportes
  main.py                  arranque
  ui/
    login.py               ventana de conexión
    principal.py           ventana principal y menú lateral
    inicio.py              panel de indicadores
    pantalla_entidad.py    mantenimiento genérico de una tabla
    formulario.py          formulario de alta / modificación
    campos.py              controles (texto, número, fecha con calendario, listas)
    tabla.py               tabla con orden por columna y búsqueda
    pantalla_reportes.py   ejecución y exportación a CSV de reportes
    formato.py, estilo.py  formato de valores y apariencia
```

Arquitectura en tres capas: **presentación** (`app/ui`), **acceso a datos**
(`app/db.py`) y **lógica de negocio en la base de datos** (procedimientos, triggers
y restricciones). Las pantallas de mantenimiento son genéricas: se construyen a
partir de `catalogo.py`.

## 5. Procedimientos y triggers

**Procedimientos** (`04_procedimientos.sql`): `sp_<tabla>_insertar`,
`sp_<tabla>_actualizar` y `sp_<tabla>_eliminar` para las 14 tablas, más
`sp_licitacion_cambiar_estado`. Los de licitación, propuesta, ítem y armada
devuelven (`INOUT`) el código o número generado.

**Triggers** (`05_triggers.sql`):

| Trigger | Tablas | Qué hace |
|---|---|---|
| `tg_10_normalizar` | las 14 | quita espacios, pasa textos a mayúsculas, texto vacío → NULL |
| `tg_20_validar` | licitacion | genera `LIC-AAAA-NNNN`; regla RA5; transiciones de estado válidas; no borra licitaciones presentadas |
| `tg_20_validar` | propuesta_comercial | genera `PROP-AAAA-NNNN`; regla RA3 (cuenta del suscriptor); bloquea propuestas presentadas |
| `tg_20_validar` | item_propuesta, armada_pago | numeración automática; bloquea si la propuesta ya fue presentada |
| `tg_20_validar` | propuesta_maquinaria | regla RA2 (equipo con certificado vigente) |
| `tg_80_estado_licitacion` | propuesta_comercial | crear propuesta → licitación EN PREPARACIÓN (y al revés al borrarla) |
| `tg_80_historial_estado` | licitacion | registra cada cambio de estado |
| `tg_80_verificacion` | empresa, habilitacion_rnp | registra cada verificación SUNAT / RNP |
| `tg_90_auditoria` | las 14 | bitácora de toda inserción, modificación y eliminación |

## 6. Reportes

| Código | Reporte | JOIN |
|---|---|---|
| R01 | Agenda de licitaciones abiertas | sí |
| R02 | Datos para la DJ y la carta de autorización | sí |
| R03 | Formato de propuesta económica | sí |
| R04 | Habilitación para postular (SUNAT y RNP) | sí |
| R05 | Estado de certificación de los equipos | sí |
| R06 | Alertas del expediente (RA2, RA3, RA5) | sí |
| R07 | Resultados por entidad contratante | sí |
| R08 | Monto ofertado y adjudicado por trimestre | sí |
| R09 | Historial de precios unitarios | sí |
| R10 | Uso de la maquinaria en las propuestas | sí |
| R11 | Historial de estados de licitación | sí |
| R12 | Historial de verificaciones SUNAT / RNP | sí |
| R13 | Bitácora de operaciones | no |

## 7. Normas de desarrollo

- Python: **PEP 8** (estilo) y **PEP 257** (docstrings); nombres en español,
  consultas siempre parametrizadas (`psycopg.sql`) para evitar inyección SQL.
- SQL: palabras clave en MAYÚSCULAS, nombres en `snake_case`, prefijos
  `pk_`, `fk_`, `uq_`, `ck_`, `idx_`, `sp_`, `fn_`, `tg_`, `vw_`; cada script
  documentado con encabezado y verificación final.
