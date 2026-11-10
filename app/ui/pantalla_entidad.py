"""Pantalla de mantenimiento genérica de una tabla del catálogo.

Muestra la lista de registros y permite:
    Nuevo      -> formulario vacío     -> CALL sp_<tabla>_insertar(...)
    Modificar  -> formulario con datos -> CALL sp_<tabla>_actualizar(...)
    Eliminar   -> confirmación         -> CALL sp_<tabla>_eliminar(clave)
Los triggers de la base validan cada operación y registran la bitácora.
"""

import tkinter as tk
from tkinter import messagebox, ttk

from .. import errores
from ..catalogo import ESTADOS_LICITACION
from . import estilo, formato
from .formulario import Formulario
from .tabla import TablaDatos


class PantallaEntidad(ttk.Frame):
    """Lista + botones de una entidad."""

    def __init__(self, padre, entidad, db, informar):
        super().__init__(padre, padding=(18, 14, 18, 10))
        self.entidad = entidad
        self.db = db
        self.informar = informar  # función para escribir en la barra de estado

        ttk.Label(self, text=entidad.titulo, style="Titulo.TLabel").pack(anchor="w")
        ttk.Label(self, text=entidad.descripcion, style="Secundario.TLabel",
                  wraplength=estilo.px(self, 900), justify="left").pack(anchor="w", pady=(0, 10))

        barra = ttk.Frame(self)
        barra.pack(fill="x", pady=(0, 8))
        ttk.Button(barra, text="＋ Nuevo", style="Accion.TButton", command=self.nuevo).pack(side="left")
        ttk.Button(barra, text="✎ Modificar", command=self.modificar).pack(side="left", padx=(6, 0))
        ttk.Button(barra, text="🗑 Eliminar", command=self.eliminar).pack(side="left", padx=(6, 0))
        for texto, accion in entidad.acciones:
            ttk.Button(barra, text=texto,
                       command=lambda a=accion: self.ejecutar_accion(a)).pack(side="left", padx=(12, 0))

        ttk.Button(barra, text="⟳ Actualizar", command=self.cargar).pack(side="right")
        self.buscar = tk.StringVar()
        self.buscar.trace_add("write", lambda *a: self._filtrar())
        entrada = ttk.Entry(barra, textvariable=self.buscar, width=28)
        entrada.pack(side="right", padx=(0, 10))
        ttk.Label(barra, text="Buscar:").pack(side="right", padx=(0, 4))

        self.tabla = TablaDatos(self, al_doble_clic=self.modificar)
        self.tabla.configurar_columnas(entidad.columnas_lista)
        self.tabla.pack(fill="both", expand=True)

        self.contador = ttk.Label(self, style="Secundario.TLabel")
        self.contador.pack(anchor="w", pady=(6, 0))

        self.bind("<Control-n>", lambda e: self.nuevo())
        self.tabla.arbol.bind("<Delete>", lambda e: self.eliminar())

    # ------------------------------------------------------------------
    def cargar(self, seleccionar: dict | None = None):
        """Lee los registros de la tabla y los muestra."""
        try:
            filas = self.db.consultar_dict(self.entidad.consulta_lista)
        except Exception as error:  # noqa: BLE001
            messagebox.showerror("Error al leer los datos", errores.mensaje(error), parent=self)
            return
        self.tabla.cargar(filas)
        if seleccionar:
            claves = self.entidad.claves
            self.tabla.seleccionar(lambda f: all(_igual(f.get(c), seleccionar.get(c)) for c in claves))
        self._actualizar_contador()

    def _filtrar(self):
        self.tabla.filtrar(self.buscar.get())
        self._actualizar_contador()

    def _actualizar_contador(self):
        total, visibles = len(self.tabla.filas), self.tabla.cantidad_visible
        texto = f"{total} registros" if total == visibles else f"{visibles} de {total} registros"
        self.contador.configure(text=texto)

    def _seleccion_obligatoria(self) -> dict | None:
        fila = self.tabla.seleccion()
        if fila is None:
            messagebox.showinfo(self.entidad.titulo, "Primero seleccione un registro de la lista.",
                                parent=self)
        return fila

    def _describir(self, fila: dict) -> str:
        return " / ".join(formato.a_texto(fila.get(c)) for c in self.entidad.claves)

    # ------------------------------------------------------------------
    # Operaciones (cada una llama a un procedimiento almacenado)
    # ------------------------------------------------------------------
    def nuevo(self):
        def guardar(valores):
            generados = self.db.llamar(self.entidad.proc_insertar,
                                       self.entidad.argumentos_insertar(valores))
            valores.update(generados)  # códigos o números asignados por los triggers
            detalle = self._describir(valores)
            self.informar(f"Registro guardado: {self.entidad.singular} {detalle}")
            self.cargar(seleccionar=valores)

        Formulario(self, self.entidad, self.db, guardar)

    def modificar(self):
        original = self._seleccion_obligatoria()
        if original is None:
            return

        def guardar(valores):
            self.db.llamar(self.entidad.proc_actualizar,
                           self.entidad.argumentos_actualizar(valores, original))
            self.informar(f"Cambios guardados: {self.entidad.singular} {self._describir(valores)}")
            self.cargar(seleccionar=valores)

        Formulario(self, self.entidad, self.db, guardar, original=original)

    def eliminar(self):
        fila = self._seleccion_obligatoria()
        if fila is None:
            return
        detalle = self._describir(fila)
        if not messagebox.askyesno("Confirmar eliminación",
                                   f"¿Eliminar {self.entidad.singular.lower()} «{detalle}»?\n\n"
                                   "Esta acción no se puede deshacer.", icon="warning", parent=self):
            return
        try:
            self.db.llamar(self.entidad.proc_eliminar, self.entidad.argumentos_eliminar(fila))
        except Exception as error:  # noqa: BLE001
            messagebox.showerror("No se pudo eliminar", errores.mensaje(error, "eliminar"), parent=self)
            return
        self.informar(f"Registro eliminado: {self.entidad.singular} {detalle}")
        self.cargar()

    def ejecutar_accion(self, accion: str):
        if accion == "cambiar_estado":
            fila = self._seleccion_obligatoria()
            if fila is not None:
                DialogoEstado(self, self.db, fila, al_terminar=self._estado_cambiado)

    def _estado_cambiado(self, fila, estado):
        self.informar(f"Licitación {fila['codigo_licitacion']}: estado cambiado a {estado}")
        self.cargar(seleccionar=fila)


class DialogoEstado(tk.Toplevel):
    """Cambia el estado de una licitación con sp_licitacion_cambiar_estado."""

    def __init__(self, padre, db, fila, al_terminar):
        super().__init__(padre)
        self.db, self.fila, self.al_terminar = db, fila, al_terminar
        self.title("Cambiar estado")
        self.configure(background=estilo.FONDO)
        self.transient(padre.winfo_toplevel())
        self.resizable(False, False)

        cuerpo = ttk.Frame(self, padding=18)
        cuerpo.pack(fill="both")
        ttk.Label(cuerpo, text=f"Licitación {fila['codigo_licitacion']}",
                  style="Subtitulo.TLabel").pack(anchor="w")
        ttk.Label(cuerpo, text=f"Estado actual: {fila['estado']}",
                  style="Secundario.TLabel").pack(anchor="w", pady=(0, 10))
        self.estado = tk.StringVar(value=fila["estado"])
        ttk.Combobox(cuerpo, textvariable=self.estado, values=ESTADOS_LICITACION,
                     state="readonly", width=24).pack(anchor="w")
        ttk.Label(cuerpo, wraplength=estilo.px(self, 340), justify="left", style="Ayuda.TLabel",
                  text="Flujo: REGISTRADA → EN PREPARACIÓN → PRESENTADA → ADJUDICADA / "
                       "NO ADJUDICADA. Para presentar se necesita una propuesta (RA5).").pack(
            anchor="w", pady=(8, 0))

        botones = ttk.Frame(cuerpo)
        botones.pack(fill="x", pady=(14, 0))
        ttk.Button(botones, text="Cancelar", command=self.destroy).pack(side="right")
        ttk.Button(botones, text="Cambiar", style="Accion.TButton",
                   command=self.guardar).pack(side="right", padx=(0, 8))
        self.bind("<Escape>", lambda e: self.destroy())
        self.grab_set()

    def guardar(self):
        estado = self.estado.get()
        try:
            self.db.llamar("sp_licitacion_cambiar_estado", [self.fila["codigo_licitacion"], estado])
        except Exception as error:  # noqa: BLE001
            messagebox.showerror("No se pudo cambiar el estado", errores.mensaje(error), parent=self)
            return
        self.destroy()
        self.al_terminar(self.fila, estado)


def _igual(a, b) -> bool:
    """Compara claves ignorando espacios de relleno (columnas char)."""
    if isinstance(a, str) and isinstance(b, str):
        return a.strip().upper() == b.strip().upper()
    return a == b
