"""Acceso a datos: la única puerta del aplicativo hacia PostgreSQL.

Reglas de diseño:
    * Las escrituras (insertar, modificar, eliminar) se hacen SOLO con
      CALL a los procedimientos almacenados sp_<tabla>_<accion> definidos
      en sql/04_procedimientos.sql. El aplicativo no ejecuta INSERT,
      UPDATE ni DELETE.
    * Las lecturas son SELECT sobre las tablas (listados) o sobre las
      vistas vw_rep* (reportes).
    * La conexión trabaja en modo autocommit: cada CALL es una transacción
      completa; si un trigger la rechaza, PostgreSQL deshace todo.
"""

import psycopg
from psycopg import sql

ESQUEMA = "licitaciones"
NOMBRE_APLICACION = "Licitaciones TECNOSERVI"  # aparece en la bitácora


class BaseDatos:
    """Conexión a la base bd_licitaciones y operaciones sobre ella."""

    def __init__(self):
        self.conexion = None
        self.descripcion = ""

    # ------------------------------------------------------------------
    # Conexión
    # ------------------------------------------------------------------
    def conectar(self, host: str, puerto: str, base: str, usuario: str, clave: str) -> None:
        """Abre la conexión. Lanza psycopg.Error si no se puede conectar."""
        self.cerrar()
        self.conexion = psycopg.connect(
            host=host,
            port=puerto,
            dbname=base,
            user=usuario,
            password=clave,
            autocommit=True,
            connect_timeout=5,
            application_name=NOMBRE_APLICACION,
            options=f"-c search_path={ESQUEMA},public",
        )
        self.descripcion = f"{base} en {host}:{puerto} - usuario {usuario}"
        self._verificar_instalacion()

    def _verificar_instalacion(self) -> None:
        """Comprueba que la base tenga los procedimientos y reportes del aplicativo."""
        _, filas = self.consultar(
            "SELECT count(*) FILTER (WHERE p.prokind = 'p'), "
            "       (SELECT count(*) FROM information_schema.views "
            "         WHERE table_schema = %s AND table_name LIKE 'vw_rep%%') "
            "FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace "
            "WHERE n.nspname = %s",
            (ESQUEMA, ESQUEMA),
        )
        procedimientos, vistas = filas[0]
        if procedimientos == 0 or vistas == 0:
            self.cerrar()
            raise RuntimeError(
                "La base no tiene instalados los procedimientos, triggers y reportes.\n"
                "Ejecute instalar_bd.bat (o los scripts 04, 05 y 06 de la carpeta sql)."
            )

    def cerrar(self) -> None:
        """Cierra la conexión si está abierta."""
        if self.conexion is not None:
            try:
                self.conexion.close()
            finally:
                self.conexion = None

    @property
    def conectada(self) -> bool:
        return self.conexion is not None and not self.conexion.closed

    # ------------------------------------------------------------------
    # Lectura
    # ------------------------------------------------------------------
    def consultar(self, consulta, parametros=None):
        """Ejecuta un SELECT y devuelve (nombres_de_columnas, filas)."""
        with self.conexion.cursor() as cursor:
            cursor.execute(consulta, parametros)
            columnas = [c.name for c in cursor.description]
            return columnas, cursor.fetchall()

    def consultar_dict(self, consulta, parametros=None) -> list[dict]:
        """Ejecuta un SELECT y devuelve cada fila como diccionario {columna: valor}."""
        columnas, filas = self.consultar(consulta, parametros)
        return [dict(zip(columnas, fila)) for fila in filas]

    def consultar_vista(self, vista: str, filtro: dict | None = None, orden: str = ""):
        """SELECT * sobre una vista de reporte, con filtros de igualdad opcionales.

        Los nombres de vista y columnas se escriben como identificadores
        (sql.Identifier) y los valores como parámetros: no hay riesgo de
        inyección SQL.
        """
        consulta = sql.SQL("SELECT * FROM {}.{}").format(
            sql.Identifier(ESQUEMA), sql.Identifier(vista)
        )
        valores = []
        if filtro:
            condiciones = []
            for columna, valor in filtro.items():
                condiciones.append(sql.SQL("{} = %s").format(sql.Identifier(columna)))
                valores.append(valor)
            consulta += sql.SQL(" WHERE ") + sql.SQL(" AND ").join(condiciones)
        if orden:
            consulta += sql.SQL(" ORDER BY " + orden)  # texto fijo definido en reportes.py
        return self.consultar(consulta, valores)

    # ------------------------------------------------------------------
    # Escritura (solo procedimientos almacenados)
    # ------------------------------------------------------------------
    def llamar(self, procedimiento: str, argumentos: list):
        """Ejecuta CALL licitaciones.<procedimiento>(argumentos...).

        Devuelve los parámetros INOUT como diccionario sin el prefijo p_
        (por ejemplo {"codigo_licitacion": "LIC-2026-0014"} para una
        licitación nueva) o un diccionario vacío si no hay parámetros de
        salida.
        """
        consulta = sql.SQL("CALL {}.{}({})").format(
            sql.Identifier(ESQUEMA),
            sql.Identifier(procedimiento),
            sql.SQL(", ").join(sql.Placeholder() * len(argumentos)),
        )
        with self.conexion.cursor() as cursor:
            cursor.execute(consulta, argumentos)
            if not cursor.description:
                return {}
            fila = cursor.fetchone()
            return {c.name.removeprefix("p_"): v for c, v in zip(cursor.description, fila)}
