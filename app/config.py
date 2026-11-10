"""Configuración de conexión del aplicativo.

Los datos de conexión (servidor, puerto, base y usuario) se guardan en un
archivo INI en la carpeta del usuario, para no volver a escribirlos en cada
inicio. La contraseña NUNCA se guarda.

Ubicación: %APPDATA%\\LicitacionesTECNOSERVI\\config.ini
"""

import configparser
import os
from pathlib import Path

#: Valores usados la primera vez que se abre el aplicativo.
POR_DEFECTO = {
    "host": "localhost",
    "puerto": "5432",
    "base": "bd_licitaciones",
    "usuario": "postgres",
}

_SECCION = "conexion"


def ruta_config() -> Path:
    """Devuelve la ruta del archivo de configuración (crea la carpeta si falta)."""
    base = Path(os.environ.get("APPDATA", Path.home()))
    carpeta = base / "LicitacionesTECNOSERVI"
    carpeta.mkdir(parents=True, exist_ok=True)
    return carpeta / "config.ini"


def cargar() -> dict:
    """Lee la configuración guardada; completa con los valores por defecto."""
    datos = dict(POR_DEFECTO)
    parser = configparser.ConfigParser()
    try:
        parser.read(ruta_config(), encoding="utf-8")
    except (OSError, configparser.Error):
        return datos
    if parser.has_section(_SECCION):
        for clave in POR_DEFECTO:
            datos[clave] = parser.get(_SECCION, clave, fallback=datos[clave])
    return datos


def guardar(datos: dict) -> None:
    """Guarda servidor, puerto, base y usuario (sin la contraseña)."""
    parser = configparser.ConfigParser()
    parser[_SECCION] = {clave: str(datos.get(clave, "")) for clave in POR_DEFECTO}
    try:
        with open(ruta_config(), "w", encoding="utf-8") as archivo:
            parser.write(archivo)
    except OSError:
        pass  # no poder recordar la conexión no impide usar el aplicativo
