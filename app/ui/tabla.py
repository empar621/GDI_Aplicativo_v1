"""Tabla de datos reutilizable (ttk.Treeview con barras de desplazamiento).

Funciones: columnas configurables, filas alternadas, ordenar al hacer clic
en un encabezado, filtro de texto y acceso a la fila seleccionada como
diccionario con los valores originales (no el texto formateado).
"""

import tkinter as tk
from tkinter import ttk

from . import estilo, formato


class TablaDatos(ttk.Frame):
    """Muestra filas (diccionarios) en columnas."""

    def __init__(self, padre, al_doble_clic=None):
        super().__init__(padre)
        self.arbol = ttk.Treeview(self, show="headings", selectmode="browse")
        barra_v = ttk.Scrollbar(self, orient="vertical", command=self.arbol.yview)
        barra_h = ttk.Scrollbar(self, orient="horizontal", command=self.arbol.xview)
        self.arbol.configure(yscrollcommand=barra_v.set, xscrollcommand=barra_h.set)
        self.arbol.grid(row=0, column=0, sticky="nsew")
        barra_v.grid(row=0, column=1, sticky="ns")
        barra_h.grid(row=1, column=0, sticky="ew")
        self.rowconfigure(0, weight=1)
        self.columnconfigure(0, weight=1)

        self.arbol.tag_configure("par", background=estilo.FILA_ALTERNA)
        if al_doble_clic:
            self.arbol.bind("<Double-1>", lambda e: al_doble_clic() if self.arbol.identify_row(e.y) else None)
            self.arbol.bind("<Return>", lambda e: al_doble_clic())

        self.columnas = []        # [(nombre, encabezado, ancho)]
        self.filas = []           # todas las filas (dict)
        self.visibles = {}        # iid -> fila
        self._filtro = ""
        self._orden = (None, False)

    # ------------------------------------------------------------------
    def configurar_columnas(self, columnas):
        """columnas: lista de (nombre, encabezado, ancho_en_pixeles)."""
        self.columnas = list(columnas)
        nombres = [c[0] for c in self.columnas]
        self.arbol.configure(columns=nombres, displaycolumns=nombres)
        for nombre, titulo, ancho in self.columnas:
            self.arbol.heading(nombre, text=titulo, command=lambda n=nombre: self.ordenar_por(n))
            ultima = nombre == self.columnas[-1][0]  # la última columna ocupa el espacio libre
            self.arbol.column(nombre, width=estilo.px(self, ancho), minwidth=40, stretch=ultima)
        self._orden = (None, False)

    def columnas_automaticas(self, nombres, filas):
        """Calcula anchos a partir del contenido (para reportes)."""
        columnas = []
        for nombre in nombres:
            titulo = formato.encabezado(nombre)
            muestras = [len(formato.a_texto(f.get(nombre))) for f in filas[:200]]
            caracteres = max([len(titulo)] + muestras)
            columnas.append((nombre, titulo, min(max(caracteres * 8 + 16, 70), 420)))
        self.configurar_columnas(columnas)

    def cargar(self, filas):
        """Reemplaza las filas mostradas."""
        self.filas = list(filas)
        columna, descendente = self._orden
        if columna:
            self.filas.sort(key=lambda f: formato.clave_orden(f.get(columna)), reverse=descendente)
        self._dibujar()

    def filtrar(self, texto: str):
        """Muestra solo las filas que contienen el texto en alguna columna visible."""
        self._filtro = texto.strip().lower()
        self._dibujar()

    def ordenar_por(self, columna):
        anterior, descendente = self._orden
        descendente = not descendente if anterior == columna else False
        self._orden = (columna, descendente)
        self.filas.sort(key=lambda f: formato.clave_orden(f.get(columna)), reverse=descendente)
        for nombre, titulo, _ in self.columnas:
            flecha = (" ▼" if descendente else " ▲") if nombre == columna else ""
            self.arbol.heading(nombre, text=titulo + flecha)
        self._dibujar()

    def _dibujar(self):
        seleccion = self.seleccion()
        self.arbol.delete(*self.arbol.get_children())
        self.visibles = {}
        nombres = [c[0] for c in self.columnas]
        for fila in self.filas:
            textos = [formato.a_texto(fila.get(n)) for n in nombres]
            if self._filtro and not any(self._filtro in t.lower() for t in textos):
                continue
            etiqueta = ("par",) if len(self.visibles) % 2 else ()
            iid = self.arbol.insert("", "end", values=textos, tags=etiqueta)
            self.visibles[iid] = fila
        for nombre in nombres:  # alinear números a la derecha
            muestra = next((f.get(nombre) for f in self.filas if f.get(nombre) is not None), None)
            self.arbol.column(nombre, anchor="e" if formato.es_numero(muestra) else "w")
        if seleccion is not None:
            self.seleccionar(lambda f: f is seleccion)

    # ------------------------------------------------------------------
    def seleccion(self) -> dict | None:
        """Fila seleccionada (valores originales) o None."""
        elegidos = self.arbol.selection()
        return self.visibles.get(elegidos[0]) if elegidos else None

    def seleccionar(self, condicion) -> bool:
        """Selecciona la primera fila que cumple condicion(fila)."""
        for iid, fila in self.visibles.items():
            if condicion(fila):
                self.arbol.selection_set(iid)
                self.arbol.focus(iid)
                self.arbol.see(iid)
                return True
        return False

    @property
    def cantidad_visible(self) -> int:
        return len(self.visibles)
