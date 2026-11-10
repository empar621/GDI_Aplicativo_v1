"""Traducción de los errores de PostgreSQL a mensajes claros para el usuario.

Hay tres fuentes de error al guardar:
    1. Los triggers y procedimientos (RAISE EXCEPTION): su texto ya está
       redactado para el usuario y se muestra tal cual.
    2. Las restricciones del modelo (CHECK, FOREIGN KEY, UNIQUE, NOT NULL):
       se reconocen por el nombre de la restricción y se explican.
    3. Problemas de conexión.
"""

import psycopg
from psycopg import errors

#: Mensajes de las restricciones CHECK de 01_crear_tablas.sql.
MENSAJES_CHECK = {
    "ck_empresa_ruc": "El RUC debe tener exactamente 11 dígitos.",
    "ck_empresa_razon_social": "La razón social debe escribirse en mayúsculas.",
    "ck_empresa_fecha_verif": "La fecha de verificación en SUNAT no puede ser una fecha futura.",
    "ck_cuenta_cci": "El código CCI debe tener exactamente 20 dígitos.",
    "ck_habilitacion_fechas": "La fecha de verificación no puede ser anterior al inicio de vigencia.",
    "ck_representante_dni": "El DNI debe tener exactamente 8 dígitos.",
    "ck_representante_correo": "El correo de notificación no tiene un formato válido (usuario@dominio.com).",
    "ck_representante_telefono": "El teléfono del representante solo puede contener dígitos.",
    "ck_modelo_capacidad": "La capacidad en toneladas debe ser mayor que cero.",
    "ck_maquinaria_placa": "La placa solo admite letras, números y guiones (ej. AEJ-831).",
    "ck_certificado_fechas": "La fecha de caducidad debe ser posterior a la fecha de inspección.",
    "ck_entidad_ruc": "El RUC de una entidad pública debe tener 11 dígitos y empezar con 20.",
    "ck_telefono_formato": "El teléfono solo admite dígitos separados por guiones (ej. 054-605690).",
    "ck_licitacion_codigo": "El código debe tener el formato LIC-AAAA-NNNN. Déjelo vacío para generarlo.",
    "ck_licitacion_fechas": "La fecha límite de presentación no puede ser anterior a la fecha de registro.",
    "ck_propuesta_codigo": "El código debe tener el formato PROP-AAAA-NNNN. Déjelo vacío para generarlo.",
    "ck_propuesta_plazo": "El plazo de ejecución debe estar entre 1 y 9999 días.",
    "ck_item_nro": "El número de ítem debe estar entre 1 y 99.",
    "ck_item_cantidad": "La cantidad debe ser mayor que cero.",
    "ck_item_precio": "El precio unitario debe ser mayor que cero.",
    "ck_armada_nro": "El número de armada debe estar entre 1 y 99.",
    "ck_armada_dias": "El plazo de la armada debe estar entre 1 y 9999 días.",
}

#: Claves foráneas: restricción -> (registros hijos, registro padre).
CLAVES_FORANEAS = {
    "fk_cuenta_empresa": ("cuentas bancarias", "la empresa titular"),
    "fk_habilitacion_empresa": ("habilitaciones RNP", "la empresa"),
    "fk_representante_empresa": ("representantes legales", "la empresa"),
    "fk_maquinaria_modelo": ("equipos de maquinaria", "el modelo de equipo (marca y modelo)"),
    "fk_maquinaria_empresa": ("equipos de maquinaria", "la empresa propietaria"),
    "fk_certificado_maquinaria": ("certificados de inspección", "el equipo (placa)"),
    "fk_telefono_entidad": ("teléfonos", "la entidad contratante"),
    "fk_licitacion_entidad": ("licitaciones", "la entidad contratante"),
    "fk_propuesta_licitacion": ("una propuesta comercial", "la licitación"),
    "fk_propuesta_representante": ("propuestas comerciales", "el representante suscriptor"),
    "fk_propuesta_cuenta": ("propuestas comerciales", "la cuenta de abono"),
    "fk_item_propuesta": ("ítems", "la propuesta"),
    "fk_armada_propuesta": ("armadas de pago", "la propuesta"),
    "fk_pm_propuesta": ("equipos asignados", "la propuesta"),
    "fk_pm_maquinaria": ("propuestas que usan el equipo", "el equipo (placa)"),
}

#: Restricciones UNIQUE con mensaje propio (las PK usan el mensaje general).
MENSAJES_UNICO = {
    "uq_licitacion_entidad_req": "Esa entidad ya tiene registrado ese número de requerimiento.",
    "uq_propuesta_licitacion": "Esa licitación ya tiene una propuesta comercial (solo se admite una).",
}


def mensaje(error: Exception, operacion: str = "") -> str:
    """Devuelve un mensaje en español para mostrar al usuario.

    operacion: "insertar", "actualizar" o "eliminar" (ajusta el texto de
    las violaciones de clave foránea).
    """
    if isinstance(error, RuntimeError):
        return str(error)
    if not isinstance(error, psycopg.Error):
        return f"Error inesperado: {error}"

    diag = error.diag
    restriccion = diag.constraint_name or ""

    if isinstance(error, errors.RaiseException):
        return diag.message_primary or str(error)

    if isinstance(error, errors.CheckViolation):
        return MENSAJES_CHECK.get(
            restriccion, f"El valor no cumple la regla «{restriccion}» de la base de datos."
        )

    # ON DELETE RESTRICT se informa como RestrictViolation (23001);
    # ON DELETE NO ACTION y las inserciones, como ForeignKeyViolation (23503).
    if isinstance(error, (errors.ForeignKeyViolation, errors.RestrictViolation)):
        hijos, padre = CLAVES_FORANEAS.get(restriccion, ("registros relacionados", "el registro relacionado"))
        if (operacion == "eliminar" or isinstance(error, errors.RestrictViolation)
                or "delete" in (diag.message_primary or "").lower()):
            return f"No se puede eliminar: tiene {hijos} que dependen de este registro."
        return f"El valor elegido para {padre} no existe. Elija uno de la lista."

    if isinstance(error, errors.UniqueViolation):
        if restriccion in MENSAJES_UNICO:
            return MENSAJES_UNICO[restriccion]
        return "Ya existe un registro con esa clave (código, RUC, DNI, placa...)."

    if isinstance(error, errors.NotNullViolation):
        return f"Falta un dato obligatorio: «{diag.column_name}»."

    if isinstance(error, errors.StringDataRightTruncation):
        return "Uno de los textos es más largo de lo permitido."

    if isinstance(error, errors.NumericValueOutOfRange):
        return "Uno de los números está fuera del rango permitido."

    if isinstance(error, errors.UndefinedFunction):
        return ("La base de datos no tiene el procedimiento esperado. "
                "Ejecute instalar_bd.bat o el script sql/04_procedimientos.sql.")

    if isinstance(error, errors.InvalidPassword):
        return "Usuario o contraseña incorrectos."

    if isinstance(error, psycopg.OperationalError):
        texto = str(error).strip().splitlines()[-1] if str(error).strip() else ""
        return f"No se pudo comunicar con el servidor PostgreSQL.\n\n{texto}"

    return diag.message_primary or str(error)
