"""Ventana principal: menú lateral, área de trabajo y barra de estado."""

import tkinter as tk
from tkinter import messagebox, ttk

from .. import NOMBRE, VERSION
from ..catalogo import ENTIDADES
from ..reportes import REPORTES
from . import estilo
from .inicio import PanelInicio
from .pantalla_entidad import PantallaEntidad
from .pantalla_reportes import PantallaReportes


class VentanaPrincipal:
    """Arma la ventana raíz una vez conectada la base de datos."""

    def __init__(self, raiz: tk.Tk, db):
        self.raiz = raiz
        self.db = db
        self.pantallas = {}   # clave del menú -> pantalla ya construida
        self.actual = None

        raiz.title(NOMBRE)
        raiz.geometry(f"{estilo.px(raiz, 1280)}x{estilo.px(raiz, 760)}")
        raiz.minsize(estilo.px(raiz, 980), estilo.px(raiz, 600))
        raiz.configure(background=estilo.FONDO)
        raiz.protocol("WM_DELETE_WINDOW", self.salir)
        self._menu()

        self.estado = ttk.Label(raiz, style="Estado.TLabel", anchor="w")
        self.estado.pack(side="bottom", fill="x")

        cuerpo = ttk.Frame(raiz)
        cuerpo.pack(fill="both", expand=True)
        self._navegacion(cuerpo)
        self.contenedor = ttk.Frame(cuerpo)
        self.contenedor.pack(side="left", fill="both", expand=True)

        self.informar(f"Conectado a {db.descripcion}")
        self.nav.selection_set("inicio")

    # ------------------------------------------------------------------
    def _menu(self):
        barra = tk.Menu(self.raiz)
        archivo = tk.Menu(barra, tearoff=False)
        archivo.add_command(label="Actualizar pantalla", accelerator="F5", command=self.refrescar)
        archivo.add_separator()
        archivo.add_command(label="Salir", command=self.salir)
        barra.add_cascade(label="Archivo", menu=archivo)
        ayuda = tk.Menu(barra, tearoff=False)
        ayuda.add_command(label="Acerca de…", command=self.acerca_de)
        barra.add_cascade(label="Ayuda", menu=ayuda)
        self.raiz.configure(menu=barra)
        self.raiz.bind("<F5>", lambda e: self.refrescar())

    def _navegacion(self, padre):
        lateral = tk.Frame(padre, background=estilo.AZUL, width=estilo.px(padre, 300))
        lateral.pack(side="left", fill="y")
        lateral.pack_propagate(False)
        tk.Label(lateral, text="TECNOSERVI S.R.L.", background=estilo.AZUL, foreground=estilo.BLANCO,
                 font=(estilo.FUENTE, 12, "bold"), anchor="w", padx=14, pady=12).pack(fill="x")

        self.nav = ttk.Treeview(lateral, show="tree", style="Nav.Treeview", selectmode="browse")
        self.nav.pack(fill="both", expand=True, padx=(6, 0))
        self.nav.insert("", "end", iid="inicio", text="  Inicio")

        grupos = {}
        for entidad in ENTIDADES:
            if entidad.grupo not in grupos:
                grupos[entidad.grupo] = self.nav.insert("", "end", iid=f"grupo:{entidad.grupo}",
                                                        text=f"  {entidad.grupo}", open=True)
            self.nav.insert(grupos[entidad.grupo], "end", iid=f"tabla:{entidad.tabla}",
                            text=entidad.titulo)

        reportes = self.nav.insert("", "end", iid="grupo:reportes", text="  Reportes", open=True)
        for reporte in REPORTES:
            self.nav.insert(reportes, "end", iid=f"reporte:{reporte.codigo}",
                            text=f"{reporte.codigo}  {reporte.titulo}")

        self.nav.bind("<<TreeviewSelect>>", lambda e: self._al_elegir())

    def _al_elegir(self):
        elegido = self.nav.selection()
        if not elegido:
            return
        clave = elegido[0]
        if clave.startswith("grupo:"):
            hijos = self.nav.get_children(clave)
            if hijos:
                self.nav.selection_set(hijos[0])
            return
        if clave.startswith("reporte:"):
            pantalla = self._mostrar("reportes")
            pantalla.mostrar_reporte(clave.split(":", 1)[1])
        else:
            self._mostrar(clave)

    def _mostrar(self, clave):
        """Muestra la pantalla de una opción del menú (la crea la primera vez)."""
        pantalla = self.pantallas.get(clave)
        primera_vez = pantalla is None
        if primera_vez:
            pantalla = self._crear(clave)
            self.pantallas[clave] = pantalla
        if self.actual is not pantalla:
            if self.actual is not None:
                self.actual.pack_forget()
            pantalla.pack(fill="both", expand=True)
            self.actual = pantalla
            if hasattr(pantalla, "cargar"):
                pantalla.cargar()  # datos al día cada vez que se entra a la pantalla
        return pantalla

    def _crear(self, clave):
        if clave == "inicio":
            return PanelInicio(self.contenedor, self.db, self.abrir_reporte)
        if clave == "reportes":
            return PantallaReportes(self.contenedor, self.db, self.informar)
        tabla = clave.split(":", 1)[1]
        entidad = next(e for e in ENTIDADES if e.tabla == tabla)
        return PantallaEntidad(self.contenedor, entidad, self.db, self.informar)

    # ------------------------------------------------------------------
    def abrir_reporte(self, codigo: str):
        self.nav.selection_set(f"reporte:{codigo}")
        self.nav.see(f"reporte:{codigo}")

    def refrescar(self):
        if self.actual is not None and hasattr(self.actual, "cargar"):
            self.actual.cargar()
        elif isinstance(self.actual, PantallaReportes):
            self.actual.ejecutar()

    def informar(self, texto: str):
        self.estado.configure(text=texto)

    def acerca_de(self):
        messagebox.showinfo(
            "Acerca de",
            f"{NOMBRE}\nVersión {VERSION}\n\n"
            "Aplicativo de demostración de la base de datos bd_licitaciones.\n"
            "Python + Tkinter + PostgreSQL (psycopg).\n\n"
            "Las altas, cambios y bajas se hacen con procedimientos almacenados;\n"
            "las reglas de negocio y la bitácora, con triggers.\n\n"
            f"Conexión: {self.db.descripcion}",
            parent=self.raiz)

    def salir(self):
        self.db.cerrar()
        self.raiz.destroy()
