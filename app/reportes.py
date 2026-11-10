"""Catálogo de los 13 reportes del aplicativo.

Cada reporte es una vista de sql/06_reportes.sql. Si el reporte tiene un
parámetro (por ejemplo, la propuesta a imprimir), el aplicativo lo aplica
como filtro WHERE sobre una columna de la vista.
"""

from dataclasses import dataclass

from .catalogo import REF_EMPRESAS, REF_LICITACIONES, REF_PROPUESTAS


@dataclass
class Parametro:
    """Filtro opcional u obligatorio de un reporte."""

    columna: str          # columna de la vista sobre la que se filtra
    etiqueta: str
    referencia: str       # SELECT valor, descripcion para la lista desplegable
    obligatorio: bool = False


@dataclass
class Reporte:
    codigo: str
    titulo: str
    pregunta: str         # la necesidad de información que responde
    vista: str
    usa_join: bool
    orden: str = ""       # ORDER BY aplicado por el aplicativo
    parametro: Parametro | None = None


REPORTES = [
    Reporte("R01", "Agenda de licitaciones abiertas",
            "¿Qué requerimientos tengo pendientes y cuántos días me quedan para presentar cada uno?",
            "vw_rep01_agenda_licitaciones", True,
            orden="fecha_limite NULLS LAST"),
    Reporte("R02", "Datos para la DJ y la carta de autorización",
            "¿Con qué datos lleno la declaración jurada y la carta de autorización de una licitación?",
            "vw_rep02_datos_dj_carta", True,
            orden="codigo_licitacion",
            parametro=Parametro("codigo_licitacion", "Licitación", REF_LICITACIONES)),
    Reporte("R03", "Formato de propuesta económica",
            "¿Cuál es el detalle, el total, el plazo y la forma de pago de una propuesta?",
            "vw_rep03_formato_propuesta", True,
            orden="codigo_propuesta, nro_item",
            parametro=Parametro("codigo_propuesta", "Propuesta", REF_PROPUESTAS, obligatorio=True)),
    Reporte("R04", "Habilitación para postular (SUNAT y RNP)",
            "¿Está la empresa habilitada para presentar hoy y cuándo se verificó por última vez?",
            "vw_rep04_habilitacion_empresa", True,
            orden="razon_social",
            parametro=Parametro("numero_ruc", "Empresa", REF_EMPRESAS)),
    Reporte("R05", "Estado de certificación de los equipos",
            "¿Qué equipos tienen su certificado vencido o por vencer?",
            "vw_rep05_certificacion_equipos", True,
            orden="dias_para_vencer NULLS FIRST"),
    Reporte("R06", "Alertas del expediente (RA2, RA3, RA5)",
            "¿Hay algún expediente con datos inconsistentes antes de presentarlo?",
            "vw_rep06_alertas_expediente", True,
            orden="regla, codigo_licitacion"),
    Reporte("R07", "Resultados por entidad contratante",
            "¿Con qué entidades nos va mejor y cuánto nos han adjudicado?",
            "vw_rep07_resultados_entidad", True,
            orden="monto_adjudicado DESC, entidad"),
    Reporte("R08", "Monto ofertado y adjudicado por trimestre",
            "¿Cuánto hemos ofertado y cuánto hemos ganado en cada trimestre?",
            "vw_rep08_montos_trimestre", True,
            orden="trimestre"),
    Reporte("R09", "Historial de precios unitarios",
            "¿A qué precio hemos cotizado cada servicio, y a cuánto cuando ganamos o perdimos?",
            "vw_rep09_historial_precios", True,
            orden="veces_cotizado DESC, descripcion"),
    Reporte("R10", "Uso de la maquinaria en las propuestas",
            "¿Qué equipos ofertamos más, cuáles son propios o subcontratados y cuántas veces ganamos?",
            "vw_rep10_uso_maquinaria", True,
            orden="veces_ofertado DESC, placa"),
    Reporte("R11", "Historial de estados de licitación",
            "¿Cuándo cambió de estado cada licitación y quién hizo el cambio?",
            "vw_rep11_historial_estados", True,
            orden="codigo_licitacion DESC, fecha_cambio",
            parametro=Parametro("codigo_licitacion", "Licitación", REF_LICITACIONES)),
    Reporte("R12", "Historial de verificaciones SUNAT / RNP",
            "¿Cómo ha variado la situación tributaria y de RNP de cada empresa?",
            "vw_rep12_historial_verificaciones", True,
            orden="razon_social, fecha_registro",
            parametro=Parametro("numero_ruc", "Empresa", REF_EMPRESAS)),
    Reporte("R13", "Bitácora de operaciones",
            "¿Qué inserciones, modificaciones y eliminaciones se hicieron, cuándo y por quién?",
            "vw_rep13_bitacora", False,
            orden="id_bitacora DESC"),
]
