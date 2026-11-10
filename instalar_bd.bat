@echo off
REM =====================================================================
REM  Instala (o reinstala desde cero) la base bd_licitaciones.
REM  Ejecuta los scripts de la carpeta sql en el orden correcto:
REM    00 crear base (solo si no existe)  01 tablas  02 datos
REM    04 procedimientos  05 triggers  06 reportes
REM  ATENCION: 01_crear_tablas.sql borra el esquema y todos sus datos.
REM
REM  Variables opcionales (si no se definen se usan los valores por defecto):
REM    PGBIN   carpeta de psql.exe   (C:\Program Files\PostgreSQL\18\bin)
REM    PGHOST  servidor              (localhost)
REM    PGPORT  puerto                (5432)
REM    PGUSER  usuario               (postgres)
REM  psql pedira la contrasena en cada paso salvo que se defina PGPASSWORD.
REM =====================================================================
setlocal
chcp 65001 >nul
if "%PGBIN%"=="" set "PGBIN=C:\Program Files\PostgreSQL\18\bin"
if "%PGHOST%"=="" set "PGHOST=localhost"
if "%PGPORT%"=="" set "PGPORT=5432"
if "%PGUSER%"=="" set "PGUSER=postgres"
set "PGCLIENTENCODING=UTF8"
set "SQLDIR=%~dp0sql"
set "PSQL="%PGBIN%\psql.exe" -X -q -v ON_ERROR_STOP=1"

if not exist "%PGBIN%\psql.exe" (
    echo No se encontro psql.exe en "%PGBIN%". Defina PGBIN con la carpeta bin de PostgreSQL.
    exit /b 1
)

if /I not "%1"=="/s" (
    echo Se va a REINSTALAR bd_licitaciones en %PGHOST%:%PGPORT% con el usuario %PGUSER%.
    echo Se borraran los datos actuales del esquema "licitaciones".
    choice /M "Continuar"
    if errorlevel 2 exit /b 1
)

echo [0/5] Verificando que exista la base...
%PSQL% -d postgres -ltA | findstr /b /c:"bd_licitaciones|" >nul
if errorlevel 1 (
    %PSQL% -d postgres -f "%SQLDIR%\00_crear_base.sql" || goto :error
)

echo [1/5] Tablas...
%PSQL% -1 -d bd_licitaciones -f "%SQLDIR%\01_crear_tablas.sql" || goto :error
echo [2/5] Datos de prueba...
%PSQL% -1 -d bd_licitaciones -f "%SQLDIR%\02_insertar_datos.sql" || goto :error
echo [3/5] Procedimientos...
%PSQL% -1 -d bd_licitaciones -f "%SQLDIR%\04_procedimientos.sql" || goto :error
echo [4/5] Triggers...
%PSQL% -1 -d bd_licitaciones -f "%SQLDIR%\05_triggers.sql" || goto :error
echo [5/5] Reportes...
%PSQL% -1 -d bd_licitaciones -f "%SQLDIR%\06_reportes.sql" || goto :error

echo.
echo Base de datos instalada correctamente.
exit /b 0

:error
echo.
echo *** La instalacion se detuvo por un error (ver el mensaje de arriba). ***
exit /b 1
