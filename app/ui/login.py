"""Ventana de conexión a PostgreSQL."""

import tkinter as tk
from tkinter import ttk

from .. import NOMBRE, config, errores
from . import estilo


class VentanaLogin(tk.Toplevel):
    """Pide los datos de conexión; llama a al_conectar() cuando la conexión funciona."""

    CAMPOS = [("host", "Servidor"), ("puerto", "Puerto"), ("base", "Base de datos"),
              ("usuario", "Usuario")]

    def __init__(self, raiz, db, al_conectar):
        super().__init__(raiz)
        self.raiz, self.db, self.al_conectar = raiz, db, al_conectar
        self.title("Conectar - " + NOMBRE)
        self.configure(background=estilo.FONDO)
        self.resizable(False, False)
        self.protocol("WM_DELETE_WINDOW", raiz.destroy)  # cerrar el login cierra el programa

        cuerpo = ttk.Frame(self, padding=(24, 20, 24, 16))
        cuerpo.pack(fill="both")
        ttk.Label(cuerpo, text="Registro de Licitaciones", style="Titulo.TLabel").grid(
            row=0, column=0, columnspan=2, sticky="w")
        ttk.Label(cuerpo, text="TECNOSERVI S.R.L. — conexión a PostgreSQL",
                  style="Secundario.TLabel").grid(row=1, column=0, columnspan=2, sticky="w", pady=(0, 14))

        guardado = config.cargar()
        self.variables = {}
        fila = 2
        for clave, etiqueta in self.CAMPOS:
            ttk.Label(cuerpo, text=etiqueta).grid(row=fila, column=0, sticky="w", pady=3, padx=(0, 12))
            self.variables[clave] = tk.StringVar(value=guardado[clave])
            ttk.Entry(cuerpo, textvariable=self.variables[clave], width=30).grid(row=fila, column=1, pady=3)
            fila += 1
        ttk.Label(cuerpo, text="Contraseña").grid(row=fila, column=0, sticky="w", pady=3)
        self.clave = tk.StringVar()
        self.entrada_clave = ttk.Entry(cuerpo, textvariable=self.clave, show="•", width=30)
        self.entrada_clave.grid(row=fila, column=1, pady=3)
        fila += 1

        self.mensaje = ttk.Label(cuerpo, style="Error.TLabel", wraplength=estilo.px(self, 340),
                                 justify="left")
        self.mensaje.grid(row=fila, column=0, columnspan=2, sticky="w", pady=(8, 0))
        fila += 1
        self.boton = ttk.Button(cuerpo, text="Conectar", style="Accion.TButton", command=self.conectar)
        self.boton.grid(row=fila, column=0, columnspan=2, sticky="e", pady=(12, 0))

        self.bind("<Return>", lambda e: self.conectar())
        self.update_idletasks()
        x = (self.winfo_screenwidth() - self.winfo_width()) // 2
        y = (self.winfo_screenheight() - self.winfo_height()) // 3
        self.geometry(f"+{x}+{y}")
        self.entrada_clave.focus_set()

    def conectar(self):
        datos = {clave: variable.get().strip() for clave, variable in self.variables.items()}
        self.mensaje.configure(text="Conectando…", style="Secundario.TLabel")
        self.boton.state(["disabled"])
        self.configure(cursor="watch")
        self.update()
        try:
            self.db.conectar(datos["host"], datos["puerto"], datos["base"], datos["usuario"],
                             self.clave.get())
        except Exception as error:  # noqa: BLE001
            self.mensaje.configure(text=errores.mensaje(error), style="Error.TLabel")
            self.boton.state(["!disabled"])
            self.configure(cursor="")
            self.entrada_clave.focus_set()
            return
        config.guardar(datos)
        self.destroy()
        self.al_conectar()
