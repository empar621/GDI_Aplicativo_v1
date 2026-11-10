"""Pantalla de reportes: elige un reporte, su parámetro, lo ejecuta y exporta."""

import csv
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from .. import errores
from ..reportes import REPORTES
from . import estilo, formato
from .tabla import TablaDatos

TODOS = "(todos)"


class PantallaReportes(ttk.Frame):
    """Lista de reportes a la izquierda y resultado a la derecha."""

    def __init__(self, padre, db, informar):
        super().__init__(padre, padding=(18, 14, 18, 10))
        self.db = db
        self.informar = informar
        self.reporte = None
        self.columnas = []
        self._valores_parametro = {}

        ttk.Label(self, text="Reportes", style="Titulo.TLabel").pack(anchor="w")
        ttk.Label(self, text="Consultas sobre las vistas vw_rep* de la base de datos. "
                             "R01–R12 combinan tablas con JOIN.",
                  style="Secundario.TLabel").pack(anchor="w", pady=(0, 10))

        panel = ttk.PanedWindow(self, orient="horizontal")
        panel.pack(fill="both", expand=True)

        # Lista de reportes
        izquierda = ttk.Frame(panel)
        self.lista = ttk.Treeview(izquierda, show="tree", selectmode="browse")
        self.lista.column("#0", width=estilo.px(self, 300))
        for reporte in REPORTES:
            self.lista.insert("", "end", iid=reporte.codigo, text=f"{reporte.codigo}  {reporte.titulo}")
        self.lista.pack(fill="both", expand=True)
        self.lista.bind("<<TreeviewSelect>>", lambda e: self._elegir())
        panel.add(izquierda, weight=0)

        # Detalle del reporte
        derecha = ttk.Frame(panel, padding=(14, 0, 0, 0))
        panel.add(derecha, weight=1)
        self.titulo = ttk.Label(derecha, style="Subtitulo.TLabel")
        self.titulo.pack(anchor="w")
        self.pregunta = ttk.Label(derecha, style="Secundario.TLabel", wraplength=estilo.px(self, 760),
                                  justify="left")
        self.pregunta.pack(anchor="w", pady=(2, 8))

        barra = ttk.Frame(derecha)
        barra.pack(fill="x", pady=(0, 8))
        self.etiqueta_parametro = ttk.Label(barra)
        self.parametro = tk.StringVar()
        self.combo_parametro = ttk.Combobox(barra, textvariable=self.parametro, state="readonly", width=60)
        self.combo_parametro.bind("<<ComboboxSelected>>", lambda e: self.ejecutar())
        self.boton_exportar = ttk.Button(barra, text="Exportar CSV…", command=self.exportar)
        self.boton_exportar.pack(side="right")
        ttk.Button(barra, text="▶ Ejecutar", style="Accion.TButton",
                   command=self.ejecutar).pack(side="right", padx=(0, 6))

        self.tabla = TablaDatos(derecha)
        self.tabla.pack(fill="both", expand=True)
        self.pie = ttk.Label(derecha, style="Secundario.TLabel")
        self.pie.pack(anchor="w", pady=(6, 0))

    # ------------------------------------------------------------------
    def mostrar_reporte(self, codigo: str):
        """Selecciona un reporte (usado desde el menú lateral y el panel de inicio)."""
        self.lista.selection_set(codigo)
        self.lista.see(codigo)

    def _elegir(self):
        elegido = self.lista.selection()
        if not elegido:
            return
        self.reporte = next(r for r in REPORTES if r.codigo == elegido[0])
        r = self.reporte
        self.titulo.configure(text=f"{r.codigo}. {r.titulo}")
        join = "usa JOIN" if r.usa_join else "sin JOIN"
        self.pregunta.configure(text=f"{r.pregunta}\nVista: {r.vista} ({join})")

        self.etiqueta_parametro.pack_forget()
        self.combo_parametro.pack_forget()
        self.parametro.set("")
        if r.parametro:
            p = r.parametro
            self.etiqueta_parametro.configure(text=p.etiqueta + ":")
            self.etiqueta_parametro.pack(side="left")
            self.combo_parametro.pack(side="left", padx=(6, 0))
            self._cargar_parametro()

        self.tabla.configurar_columnas([])
        self.tabla.cargar([])
        self.pie.configure(text="")
        if not (r.parametro and r.parametro.obligatorio and not self.parametro.get()):
            self.ejecutar()

    def _cargar_parametro(self):
        p = self.reporte.parametro
        try:
            _, filas = self.db.consultar(p.referencia)
        except Exception as error:  # noqa: BLE001
            messagebox.showerror("Error", errores.mensaje(error), parent=self)
            return
        self._valores_parametro = {} if p.obligatorio else {TODOS: None}
        for valor, descripcion in filas:
            valor = valor.strip() if isinstance(valor, str) else valor
            self._valores_parametro[f"{valor}  —  {descripcion}"] = valor
        textos = list(self._valores_parametro)
        self.combo_parametro.configure(values=textos)
        if textos:
            self.parametro.set(textos[0])

    def ejecutar(self):
        r = self.reporte
        if r is None:
            return
        filtro = None
        if r.parametro:
            valor = self._valores_parametro.get(self.parametro.get())
            if valor is None and r.parametro.obligatorio:
                messagebox.showinfo(r.titulo, f"Elija {r.parametro.etiqueta.lower()}.", parent=self)
                return
            if valor is not None:
                filtro = {r.parametro.columna: valor}
        try:
            columnas, filas = self.db.consultar_vista(r.vista, filtro, r.orden)
        except Exception as error:  # noqa: BLE001
            messagebox.showerror("Error al ejecutar el reporte", errores.mensaje(error), parent=self)
            return
        self.columnas = columnas
        registros = [dict(zip(columnas, f)) for f in filas]
        self.tabla.columnas_automaticas(columnas, registros)
        self.tabla.cargar(registros)
        self.pie.configure(text=f"{len(registros)} filas")
        self.informar(f"Reporte {r.codigo} ejecutado: {len(registros)} filas")

    def exportar(self):
        if not self.reporte or not self.columnas:
            messagebox.showinfo("Exportar", "Primero ejecute un reporte.", parent=self)
            return
        nombre = f"{self.reporte.codigo}_{self.reporte.vista.removeprefix('vw_rep')}.csv"
        ruta = filedialog.asksaveasfilename(parent=self, title="Exportar reporte",
                                            defaultextension=".csv", initialfile=nombre,
                                            filetypes=[("CSV (Excel)", "*.csv")])
        if not ruta:
            return
        try:
            # utf-8-sig y ";" para que Excel en español lo abra correctamente
            with open(ruta, "w", newline="", encoding="utf-8-sig") as archivo:
                escritor = csv.writer(archivo, delimiter=";")
                escritor.writerow([formato.encabezado(c) for c in self.columnas])
                for fila in self.tabla.filas:
                    escritor.writerow([formato.a_csv(fila.get(c)) for c in self.columnas])
        except OSError as error:
            messagebox.showerror("Exportar", f"No se pudo guardar el archivo:\n{error}", parent=self)
            return
        self.informar(f"Reporte exportado a {ruta}")
