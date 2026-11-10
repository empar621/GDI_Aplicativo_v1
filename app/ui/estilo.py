"""Colores, fuentes y estilos ttk del aplicativo."""

import tkinter as tk
from tkinter import font, ttk

# Paleta
AZUL = "#1F4E79"          # barra lateral y títulos
AZUL_CLARO = "#DCE6F1"    # selección
FONDO = "#F5F7FA"         # fondo de las pantallas
BLANCO = "#FFFFFF"
GRIS = "#5F6B7A"          # textos secundarios
FILA_ALTERNA = "#F2F5F9"  # filas pares de las tablas
ROJO = "#B3261E"
AMBAR = "#9A6700"
VERDE = "#1E7A3C"

FUENTE = "Segoe UI"


def escala(raiz: tk.Misc) -> float:
    """Factor de escala de pantalla (1.0 = 96 ppp)."""
    return raiz.winfo_fpixels("1i") / 96.0


def px(raiz: tk.Misc, pixeles: int) -> int:
    """Convierte píxeles de diseño (a 96 ppp) a píxeles reales."""
    return int(pixeles * escala(raiz))


def aplicar(raiz: tk.Tk) -> None:
    """Configura el tema y los estilos con nombre usados en las pantallas."""
    for nombre in ("TkDefaultFont", "TkTextFont", "TkMenuFont", "TkHeadingFont"):
        font.nametofont(nombre).configure(family=FUENTE, size=10)

    estilo = ttk.Style(raiz)
    estilo.theme_use("clam")  # tema que permite personalizar colores en todas las plataformas

    estilo.configure(".", background=FONDO, font=(FUENTE, 10))
    estilo.configure("TFrame", background=FONDO)
    estilo.configure("TLabel", background=FONDO)
    estilo.configure("TCheckbutton", background=FONDO)
    estilo.configure("TButton", padding=(10, 4))
    estilo.configure("Accion.TButton", foreground=BLANCO, background=AZUL)
    estilo.map("Accion.TButton", background=[("active", "#2B6CA3"), ("disabled", "#9DB3C8")])

    estilo.configure("Titulo.TLabel", font=(FUENTE, 16, "bold"), foreground=AZUL)
    estilo.configure("Subtitulo.TLabel", font=(FUENTE, 11, "bold"), foreground=AZUL)
    estilo.configure("Secundario.TLabel", foreground=GRIS)
    estilo.configure("Ayuda.TLabel", foreground=GRIS, font=(FUENTE, 8))
    estilo.configure("Error.TLabel", foreground=ROJO)
    estilo.configure("Estado.TLabel", background="#E4E9F0", foreground=GRIS, padding=(8, 3))

    # Tablas
    estilo.configure("Treeview", rowheight=px(raiz, 24), background=BLANCO,
                     fieldbackground=BLANCO, font=(FUENTE, 10))
    estilo.configure("Treeview.Heading", font=(FUENTE, 9, "bold"), background="#E4E9F0",
                     foreground="#24303F", padding=(4, 4))
    estilo.map("Treeview", background=[("selected", AZUL_CLARO)], foreground=[("selected", "#000000")])

    # Navegación lateral
    estilo.configure("Nav.Treeview", background=AZUL, fieldbackground=AZUL, foreground=BLANCO,
                     rowheight=px(raiz, 28), font=(FUENTE, 10), borderwidth=0)
    estilo.map("Nav.Treeview", background=[("selected", "#2B6CA3")], foreground=[("selected", BLANCO)])
    estilo.layout("Nav.Treeview", [("Nav.Treeview.treearea", {"sticky": "nswe"})])

    # Tarjetas del panel de inicio
    estilo.configure("Tarjeta.TFrame", background=BLANCO, relief="solid", borderwidth=1)
    estilo.configure("TarjetaTitulo.TLabel", background=BLANCO, foreground=GRIS, font=(FUENTE, 9))
    estilo.configure("TarjetaValor.TLabel", background=BLANCO, foreground=AZUL, font=(FUENTE, 24, "bold"))
    estilo.configure("TarjetaDetalle.TLabel", background=BLANCO, foreground=GRIS, font=(FUENTE, 9))
