"""Punto de entrada del aplicativo."""

import sys
import tkinter as tk

from .db import BaseDatos
from .ui import estilo
from .ui.login import VentanaLogin
from .ui.principal import VentanaPrincipal


def _nitidez_en_windows() -> None:
    """Evita que Windows muestre el texto borroso en pantallas con escala > 100 %."""
    if sys.platform == "win32":
        try:
            import ctypes
            ctypes.windll.shcore.SetProcessDpiAwareness(1)
        except (AttributeError, OSError):
            pass


def main() -> None:
    _nitidez_en_windows()
    raiz = tk.Tk()
    raiz.withdraw()                 # la ventana principal aparece después de conectar
    estilo.aplicar(raiz)
    db = BaseDatos()

    def al_conectar():
        VentanaPrincipal(raiz, db)
        raiz.deiconify()

    VentanaLogin(raiz, db, al_conectar)
    raiz.mainloop()
    db.cerrar()


if __name__ == "__main__":
    main()
