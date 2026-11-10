"""Controles de formulario, uno por cada tipo de Campo del catálogo.

Todos los controles ofrecen la misma interfaz:
    obtener()        valor listo para enviar al procedimiento (o None).
                     Lanza ValueError con un mensaje si el texto no es válido.
    establecer(v)    muestra un valor leído de la base.
    bloquear(si)     impide o permite editarlo.
    al_cambiar(f)    llama a f() cuando el usuario cambia el valor.
    enfocar()        pone el cursor en el control.

La validación aquí es solo de FORMATO (número, fecha). Las reglas de
negocio las aplica la base de datos (CHECK, triggers y procedimientos).
"""

import calendar
import tkinter as tk
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from tkinter import ttk

from . import estilo

SEPARADOR = "  —  "  # entre el valor y la descripción en las listas de referencia


class Control:
    """Clase base: un marco que contiene el widget de entrada."""

    def __init__(self, padre, campo, db=None):
        self.campo = campo
        self.db = db
        self.marco = ttk.Frame(padre)

    def obtener(self):
        raise NotImplementedError

    def establecer(self, valor):
        raise NotImplementedError

    def bloquear(self, si: bool = True):
        raise NotImplementedError

    def al_cambiar(self, funcion):
        pass

    def enfocar(self):
        pass


class ControlTexto(Control):
    """Una línea de texto."""

    def __init__(self, padre, campo, db=None):
        super().__init__(padre, campo, db)
        self.variable = tk.StringVar()
        ancho = min(max(campo.largo or 30, 12), 60)
        self.entrada = ttk.Entry(self.marco, textvariable=self.variable, width=ancho)
        self.entrada.pack(side="left", fill="x", expand=True)

    def obtener(self):
        texto = self.variable.get().strip()
        if self.campo.largo and len(texto) > self.campo.largo:
            raise ValueError(f"admite como máximo {self.campo.largo} caracteres (tiene {len(texto)}).")
        return texto or None

    def establecer(self, valor):
        self.variable.set("" if valor is None else str(valor).strip())

    def bloquear(self, si=True):
        self.entrada.state(["disabled"] if si else ["!disabled"])

    def enfocar(self):
        self.entrada.focus_set()


class ControlTextoLargo(Control):
    """Texto de varias líneas (por ejemplo, el objeto de la licitación)."""

    def __init__(self, padre, campo, db=None):
        super().__init__(padre, campo, db)
        self.texto = tk.Text(self.marco, height=3, width=56, wrap="word", font=(estilo.FUENTE, 10),
                             relief="solid", borderwidth=1, highlightthickness=0)
        self.texto.pack(side="left", fill="x", expand=True)
        # Tab pasa al siguiente control en lugar de escribir una tabulación
        self.texto.bind("<Tab>", lambda e: (e.widget.tk_focusNext().focus_set(), "break")[1])

    def obtener(self):
        texto = " ".join(self.texto.get("1.0", "end").split())
        if self.campo.largo and len(texto) > self.campo.largo:
            raise ValueError(f"admite como máximo {self.campo.largo} caracteres (tiene {len(texto)}).")
        return texto or None

    def establecer(self, valor):
        self.texto.delete("1.0", "end")
        if valor is not None:
            self.texto.insert("1.0", str(valor))

    def bloquear(self, si=True):
        self.texto.configure(state="disabled" if si else "normal")

    def enfocar(self):
        self.texto.focus_set()


class ControlNumero(ControlTexto):
    """Número entero o decimal (acepta coma o punto como separador decimal)."""

    def __init__(self, padre, campo, db=None):
        super().__init__(padre, campo, db)
        self.entrada.configure(width=14, justify="right")
        self.entrada.pack_configure(fill="none", expand=False)

    def obtener(self):
        texto = self.variable.get().strip().replace(" ", "")
        if not texto:
            return None
        if "," in texto and "." in texto:      # 1,500.50 -> 1500.50
            texto = texto.replace(",", "")
        texto = texto.replace(",", ".")        # 1500,50 -> 1500.50
        if self.campo.tipo == "entero":
            try:
                return int(texto)
            except ValueError:
                raise ValueError("debe ser un número entero.") from None
        try:
            return Decimal(texto)
        except InvalidOperation:
            raise ValueError("debe ser un número (por ejemplo 1500.50).") from None

    def establecer(self, valor):
        self.variable.set("" if valor is None else str(valor))


class ControlFecha(ControlTexto):
    """Fecha en formato DD/MM/AAAA, con botón de calendario."""

    FORMATOS = ("%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d", "%d/%m/%y")

    def __init__(self, padre, campo, db=None):
        super().__init__(padre, campo, db)
        self.entrada.configure(width=12)
        self.entrada.pack_configure(fill="none", expand=False)
        self.boton = ttk.Button(self.marco, text="📅", width=3, command=self._abrir_calendario)
        self.boton.pack(side="left", padx=(4, 0))
        ttk.Label(self.marco, text="DD/MM/AAAA", style="Ayuda.TLabel").pack(side="left", padx=6)

    def obtener(self):
        texto = self.variable.get().strip()
        if not texto:
            return None
        for formato in self.FORMATOS:
            try:
                return datetime.strptime(texto, formato).date()
            except ValueError:
                continue
        raise ValueError("no es una fecha válida; use DD/MM/AAAA.")

    def establecer(self, valor):
        if isinstance(valor, date):
            valor = valor.strftime("%d/%m/%Y")
        self.variable.set(valor or "")

    def bloquear(self, si=True):
        super().bloquear(si)
        self.boton.state(["disabled"] if si else ["!disabled"])

    def _abrir_calendario(self):
        try:
            inicial = self.obtener() or date.today()
        except ValueError:
            inicial = date.today()
        Calendario(self.entrada, inicial, self.establecer)


class Calendario(tk.Toplevel):
    """Pequeño calendario emergente para elegir una fecha."""

    DIAS = ("Lu", "Ma", "Mi", "Ju", "Vi", "Sá", "Do")
    MESES = ("Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto",
             "Septiembre", "Octubre", "Noviembre", "Diciembre")

    def __init__(self, widget, inicial: date, al_elegir):
        super().__init__(widget)
        self.title("Elegir fecha")
        self.resizable(False, False)
        self.transient(widget.winfo_toplevel())
        self.al_elegir = al_elegir
        self.anio, self.mes = inicial.year, inicial.month
        self.elegida = inicial

        cabecera = ttk.Frame(self, padding=6)
        cabecera.pack(fill="x")
        ttk.Button(cabecera, text="◀", width=3, command=lambda: self._mover(-1)).pack(side="left")
        self.titulo = ttk.Label(cabecera, anchor="center", style="Subtitulo.TLabel")
        self.titulo.pack(side="left", fill="x", expand=True)
        ttk.Button(cabecera, text="▶", width=3, command=lambda: self._mover(1)).pack(side="right")

        self.cuerpo = ttk.Frame(self, padding=(6, 0, 6, 6))
        self.cuerpo.pack()
        ttk.Button(self, text="Hoy", command=lambda: self._elegir(date.today())).pack(pady=(0, 6))

        x = widget.winfo_rootx()
        y = widget.winfo_rooty() + widget.winfo_height()
        self.geometry(f"+{x}+{y}")
        self._dibujar()
        self.bind("<Escape>", lambda e: self.destroy())
        self.grab_set()

    def _mover(self, meses):
        total = self.anio * 12 + (self.mes - 1) + meses
        self.anio, self.mes = divmod(total, 12)
        self.mes += 1
        self._dibujar()

    def _dibujar(self):
        for hijo in self.cuerpo.winfo_children():
            hijo.destroy()
        self.titulo.configure(text=f"{self.MESES[self.mes - 1]} {self.anio}")
        for columna, dia in enumerate(self.DIAS):
            ttk.Label(self.cuerpo, text=dia, style="Secundario.TLabel", anchor="center",
                      width=4).grid(row=0, column=columna)
        for fila, semana in enumerate(calendar.monthcalendar(self.anio, self.mes), start=1):
            for columna, dia in enumerate(semana):
                if dia == 0:
                    continue
                fecha = date(self.anio, self.mes, dia)
                boton = tk.Button(self.cuerpo, text=str(dia), width=3, relief="flat",
                                  command=lambda f=fecha: self._elegir(f))
                if fecha == self.elegida:
                    boton.configure(bg=estilo.AZUL, fg=estilo.BLANCO)
                elif fecha == date.today():
                    boton.configure(bg=estilo.AZUL_CLARO)
                boton.grid(row=fila, column=columna, padx=1, pady=1)

    def _elegir(self, fecha):
        self.al_elegir(fecha)
        self.destroy()


class ControlBooleano(Control):
    """Casilla Sí / No."""

    def __init__(self, padre, campo, db=None):
        super().__init__(padre, campo, db)
        self.variable = tk.BooleanVar(value=False)
        self.casilla = ttk.Checkbutton(self.marco, variable=self.variable, text="Sí")
        self.casilla.pack(side="left")

    def obtener(self):
        return bool(self.variable.get())

    def establecer(self, valor):
        self.variable.set(bool(valor))

    def bloquear(self, si=True):
        self.casilla.state(["disabled"] if si else ["!disabled"])

    def enfocar(self):
        self.casilla.focus_set()


class ControlLista(Control):
    """Base de las listas desplegables: muestra textos y devuelve valores."""

    def __init__(self, padre, campo, db=None):
        super().__init__(padre, campo, db)
        self.variable = tk.StringVar()
        self.combo = ttk.Combobox(self.marco, textvariable=self.variable, state="readonly", width=58)
        self.combo.pack(side="left", fill="x", expand=True)
        self._valores = {}   # texto mostrado -> valor
        self._textos = {}    # valor -> texto mostrado

    def _cargar(self, pares):
        """pares: lista de (valor, texto). Agrega una opción vacía si no es obligatorio."""
        actual = self.obtener()
        self._valores, self._textos = {}, {}
        if not self.campo.obligatorio:
            self._valores[""] = None
        for valor, texto in pares:
            self._valores[texto] = valor
            self._textos[valor] = texto
        self.combo.configure(values=list(self._valores))
        self.establecer(actual)

    def obtener(self):
        return self._valores.get(self.variable.get())

    def establecer(self, valor):
        if valor is None:
            self.variable.set("")
            return
        if isinstance(valor, str):
            valor = valor.strip()
        if valor not in self._textos:  # valor que no está en la lista: se agrega
            texto = str(valor)
            self._valores[texto] = valor
            self._textos[valor] = texto
            self.combo.configure(values=list(self._valores))
        self.variable.set(self._textos[valor])

    def bloquear(self, si=True):
        self.combo.configure(state="disabled" if si else "readonly")

    def al_cambiar(self, funcion):
        self.combo.bind("<<ComboboxSelected>>", lambda e: funcion(), add="+")

    def enfocar(self):
        self.combo.focus_set()


class ControlOpcion(ControlLista):
    """Lista fija de valores (los mismos del CHECK de la tabla)."""

    def __init__(self, padre, campo, db=None):
        super().__init__(padre, campo, db)
        self.combo.configure(width=34)
        self._cargar([(o, o) for o in campo.opciones])


class ControlReferencia(ControlLista):
    """Valor de otra tabla (clave foránea), elegido de una lista."""

    def __init__(self, padre, campo, db=None):
        super().__init__(padre, campo, db)
        if not campo.depende_de:
            self.recargar()

    def recargar(self, valor_padre=None):
        """Vuelve a leer las opciones; si depende de otro campo, filtra por su valor."""
        if self.campo.depende_de and valor_padre is None:
            pares = []
        else:
            parametros = (valor_padre,) if self.campo.depende_de else None
            _, filas = self.db.consultar(self.campo.referencia, parametros)
            pares = [(fila[0].strip() if isinstance(fila[0], str) else fila[0],
                      self._texto(fila[0], fila[1])) for fila in filas]
        self._cargar(pares)

    @staticmethod
    def _texto(valor, descripcion):
        valor = str(valor).strip()
        if descripcion is None or str(descripcion).strip() == valor:
            return valor
        return f"{valor}{SEPARADOR}{descripcion}"


#: Tipo de campo -> clase de control
CONTROLES = {
    "texto": ControlTexto,
    "texto_largo": ControlTextoLargo,
    "entero": ControlNumero,
    "decimal": ControlNumero,
    "fecha": ControlFecha,
    "booleano": ControlBooleano,
    "opcion": ControlOpcion,
    "referencia": ControlReferencia,
}


def crear(padre, campo, db) -> Control:
    """Crea el control adecuado para el tipo del campo."""
    return CONTROLES[campo.tipo](padre, campo, db)
