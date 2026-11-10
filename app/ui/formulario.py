"""Ventana para registrar un registro nuevo o modificar uno existente.

El formulario se arma a partir de la descripción de la tabla en
catalogo.py. Al pulsar «Guardar» entrega los valores a una función
(al_guardar) que llama al procedimiento almacenado; si la base rechaza la
operación, se muestra el motivo y el formulario sigue abierto para corregir.
"""

import tkinter as tk
from tkinter import messagebox, ttk

from .. import errores
from . import campos, estilo


class Formulario(tk.Toplevel):
    """Formulario modal de una entidad del catálogo."""

    def __init__(self, padre, entidad, db, al_guardar, original: dict | None = None):
        super().__init__(padre)
        self.entidad = entidad
        self.al_guardar = al_guardar
        self.original = original
        self.nuevo = original is None
        self.controles = {}

        accion = "Registrar" if self.nuevo else "Modificar"
        self.title(f"{accion} {entidad.singular.lower()}")
        self.configure(background=estilo.FONDO)
        self.transient(padre.winfo_toplevel())
        self.resizable(True, False)

        cuerpo = ttk.Frame(self, padding=(18, 14, 18, 8))
        cuerpo.pack(fill="both", expand=True)
        ttk.Label(cuerpo, text=f"{accion} {entidad.singular.lower()}",
                  style="Titulo.TLabel").grid(row=0, column=0, columnspan=2, sticky="w")
        ttk.Label(cuerpo, text="Los campos marcados con * son obligatorios.",
                  style="Secundario.TLabel").grid(row=1, column=0, columnspan=2, sticky="w", pady=(0, 10))

        fila = 2
        for campo in entidad.campos:
            texto = campo.etiqueta + (" *" if campo.obligatorio else "")
            ttk.Label(cuerpo, text=texto).grid(row=fila, column=0, sticky="nw", padx=(0, 12), pady=(5, 0))
            control = campos.crear(cuerpo, campo, db)
            control.marco.grid(row=fila, column=1, sticky="we", pady=(3, 0))
            self.controles[campo.nombre] = control
            fila += 1
            if campo.ayuda:
                ttk.Label(cuerpo, text=campo.ayuda, style="Ayuda.TLabel").grid(
                    row=fila, column=1, sticky="w")
                fila += 1
        cuerpo.columnconfigure(1, weight=1)

        self._enlazar_dependencias()
        self._cargar_valores()

        botones = ttk.Frame(self, padding=(18, 6, 18, 14))
        botones.pack(fill="x")
        ttk.Button(botones, text="Cancelar", command=self.destroy).pack(side="right")
        ttk.Button(botones, text="Guardar", style="Accion.TButton",
                   command=self.guardar).pack(side="right", padx=(0, 8))

        self.bind("<Return>", lambda e: self.guardar() if not isinstance(e.widget, tk.Text) else None)
        self.bind("<Escape>", lambda e: self.destroy())
        self._centrar(padre)
        self.grab_set()
        self._primer_control_editable().enfocar()

    # ------------------------------------------------------------------
    def _enlazar_dependencias(self):
        """Un campo con depende_de recarga su lista cuando cambia el campo del que depende."""
        for campo in self.entidad.campos:
            if campo.depende_de:
                padre = self.controles[campo.depende_de]
                hijo = self.controles[campo.nombre]
                padre.al_cambiar(lambda p=padre, h=hijo: h.recargar(p.obtener()))

    def _cargar_valores(self):
        """Valores iniciales: los del registro (modificar) o los por defecto (nuevo)."""
        for campo in self.entidad.campos:
            control = self.controles[campo.nombre]
            if self.nuevo:
                valor = campo.valor_inicial()
            else:
                valor = self.original.get(campo.nombre)
            if campo.depende_de:
                padre_valor = (self.controles[campo.depende_de].obtener() if self.nuevo
                               else self.original.get(campo.depende_de))
                control.recargar(padre_valor.strip() if isinstance(padre_valor, str) else padre_valor)
            if valor is not None:
                control.establecer(valor)
            # La clave primaria no se cambia al modificar (salvo excepciones del catálogo)
            if not self.nuevo and campo.clave and not campo.editable_en_clave:
                control.bloquear()

    def _primer_control_editable(self):
        for campo in self.entidad.campos:
            if self.nuevo or not campo.clave or campo.editable_en_clave:
                return self.controles[campo.nombre]
        return next(iter(self.controles.values()))

    def _centrar(self, padre):
        self.update_idletasks()
        ventana = padre.winfo_toplevel()
        x = ventana.winfo_rootx() + (ventana.winfo_width() - self.winfo_width()) // 2
        y = ventana.winfo_rooty() + max((ventana.winfo_height() - self.winfo_height()) // 3, 0)
        self.geometry(f"+{max(x, 0)}+{max(y, 0)}")

    # ------------------------------------------------------------------
    def valores(self) -> dict | None:
        """Lee y valida el formato de cada control. Devuelve None si hay un error."""
        valores = {}
        for campo in self.entidad.campos:
            control = self.controles[campo.nombre]
            try:
                valor = control.obtener()
            except ValueError as error:
                self._avisar(control, f"«{campo.etiqueta}» {error}")
                return None
            if valor is None and campo.obligatorio and not campo.auto:
                self._avisar(control, f"Complete el campo «{campo.etiqueta}».")
                return None
            valores[campo.nombre] = valor
        return valores

    def _avisar(self, control, texto):
        messagebox.showwarning("Revise el formulario", texto, parent=self)
        control.enfocar()

    def guardar(self):
        valores = self.valores()
        if valores is None:
            return
        try:
            self.configure(cursor="watch")
            self.update_idletasks()
            self.al_guardar(valores)
        except Exception as error:  # noqa: BLE001 - se informa cualquier rechazo de la base
            operacion = "insertar" if self.nuevo else "actualizar"
            messagebox.showerror("No se pudo guardar", errores.mensaje(error, operacion), parent=self)
            return
        finally:
            if self.winfo_exists():
                self.configure(cursor="")
        self.destroy()
