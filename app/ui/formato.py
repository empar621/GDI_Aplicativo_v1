"""Conversión de los valores que devuelve PostgreSQL a texto para mostrar."""

from datetime import date, datetime
from decimal import Decimal

#: Palabras que se muestran con una grafía especial en los encabezados.
_PALABRAS = {
    "nro": "N.°", "ruc": "RUC", "dni": "DNI", "cci": "CCI", "tdr": "TDR",
    "rnp": "RNP", "sunat": "SUNAT", "pct": "(%)", "dj": "DJ", "id": "ID",
    # tildes que los nombres de columna no pueden llevar
    "codigo": "código", "descripcion": "descripción", "razon": "razón", "direccion": "dirección",
    "telefono": "teléfono", "numero": "número", "item": "ítem", "condicion": "condición",
    "verificacion": "verificación", "emision": "emisión", "ejecucion": "ejecución",
    "inscripcion": "inscripción", "adjudicacion": "adjudicación", "operacion": "operación",
    "aplicacion": "aplicación", "ultimo": "último", "ultima": "última", "dias": "días",
    "min": "mín.", "max": "máx.", "cotizacion": "cotización", "presentacion": "presentación",
    "inspeccion": "inspección", "notificacion": "notificación", "atencion": "atención",
    "accion": "acción", "situacion": "situación", "trimestre": "trimestre",
}


def a_texto(valor) -> str:
    """Valor de la base -> texto legible (fechas DD/MM/AAAA, montos con 2 decimales)."""
    if valor is None:
        return ""
    if isinstance(valor, bool):
        return "Sí" if valor else "No"
    if isinstance(valor, datetime):
        if valor.tzinfo is not None:
            valor = valor.astimezone()  # hora local del equipo
        return valor.strftime("%d/%m/%Y %H:%M:%S")
    if isinstance(valor, date):
        return valor.strftime("%d/%m/%Y")
    if isinstance(valor, Decimal):
        return f"{valor:,.2f}"
    return str(valor)


def a_csv(valor) -> str:
    """Valor de la base -> texto para exportar (sin separador de miles)."""
    if isinstance(valor, Decimal):
        return str(valor)
    return a_texto(valor)


def encabezado(columna: str) -> str:
    """Nombre de columna -> encabezado ("fecha_limite" -> "Fecha limite")."""
    palabras = [_PALABRAS.get(p, p) for p in columna.split("_")]
    texto = " ".join(palabras)
    return texto[:1].upper() + texto[1:]


def clave_orden(valor):
    """Clave para ordenar una columna: los vacíos al final, textos sin mayúsculas."""
    if valor is None:
        return (1, "")
    if isinstance(valor, str):
        return (0, valor.lower())
    return (0, valor)


def es_numero(valor) -> bool:
    return isinstance(valor, (int, float, Decimal)) and not isinstance(valor, bool)
