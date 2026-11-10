"""Panel de inicio: indicadores rápidos calculados con las vistas de reporte."""

from datetime import date
from tkinter import messagebox, ttk

from .. import errores
from . import estilo
from .tabla import TablaDatos


class PanelInicio(ttk.Frame):
    """Cuatro tarjetas con indicadores y la agenda de licitaciones abiertas."""

    def __init__(self, padre, db, abrir_reporte):
        super().__init__(padre, padding=(18, 14, 18, 10))
        self.db = db
        self.abrir_reporte = abrir_reporte

        ttk.Label(self, text="Inicio", style="Titulo.TLabel").pack(anchor="w")
        ttk.Label(self, text="Resumen del día. Haga clic en una tarjeta para ver el reporte completo.",
                  style="Secundario.TLabel").pack(anchor="w", pady=(0, 12))

        fila = ttk.Frame(self)
        fila.pack(fill="x")
        self.tarjetas = {}
        for indice, (clave, titulo, reporte) in enumerate([
            ("abiertas", "Licitaciones abiertas", "R01"),
            ("equipos", "Certificados vencidos o por vencer", "R05"),
            ("alertas", "Alertas en expedientes", "R06"),
            ("adjudicado", f"Monto adjudicado {date.today().year} (S/)", "R08"),
        ]):
            self.tarjetas[clave] = self._tarjeta(fila, titulo, reporte)
            self.tarjetas[clave][0].grid(row=0, column=indice, sticky="nsew",
                                         padx=(0 if indice == 0 else 10, 0))
            fila.columnconfigure(indice, weight=1, uniform="tarjetas")

        ttk.Label(self, text="Agenda de licitaciones abiertas (R01)",
                  style="Subtitulo.TLabel").pack(anchor="w", pady=(18, 6))
        self.agenda = TablaDatos(self)
        self.agenda.configurar_columnas([
            ("codigo_licitacion", "Código", 105), ("alerta", "Alerta", 110),
            ("dias_restantes", "Días", 50), ("fecha_limite", "Límite", 90),
            ("estado", "Estado", 120), ("entidad", "Entidad", 260), ("objeto", "Objeto", 420)])
        self.agenda.arbol.tag_configure("urgente", foreground=estilo.AMBAR)
        self.agenda.arbol.tag_configure("vencida", foreground=estilo.ROJO)
        self.agenda.pack(fill="both", expand=True)

    def _tarjeta(self, padre, titulo, reporte):
        marco = ttk.Frame(padre, style="Tarjeta.TFrame", padding=14, cursor="hand2")
        etiquetas = [
            ttk.Label(marco, text=titulo, style="TarjetaTitulo.TLabel", wraplength=estilo.px(self, 220)),
            ttk.Label(marco, text="—", style="TarjetaValor.TLabel"),
            ttk.Label(marco, text="", style="TarjetaDetalle.TLabel"),
        ]
        for etiqueta in etiquetas:
            etiqueta.pack(anchor="w")
        for widget in [marco] + etiquetas:
            widget.bind("<Button-1>", lambda e, r=reporte: self.abrir_reporte(r))
        return marco, etiquetas[1], etiquetas[2]

    def cargar(self):
        """Recalcula los indicadores."""
        try:
            agenda = self.db.consultar_dict(
                "SELECT * FROM vw_rep01_agenda_licitaciones ORDER BY fecha_limite NULLS LAST")
            _, equipos = self.db.consultar(
                "SELECT count(*) FILTER (WHERE estado_vigencia IN ('VENCIDO', 'SIN CERTIFICADO')), "
                "       count(*) FILTER (WHERE estado_vigencia = 'POR VENCER') "
                "FROM vw_rep05_certificacion_equipos")
            _, alertas = self.db.consultar("SELECT count(*) FROM vw_rep06_alertas_expediente")
            _, montos = self.db.consultar(
                "SELECT COALESCE(sum(monto_adjudicado), 0), COALESCE(sum(adjudicadas), 0) "
                "FROM vw_rep08_montos_trimestre WHERE trimestre LIKE %s", (f"{date.today().year}-%",))
        except Exception as error:  # noqa: BLE001
            messagebox.showerror("Error al leer los indicadores", errores.mensaje(error), parent=self)
            return

        urgentes = sum(1 for a in agenda if a["alerta"] == "URGENTE")
        vencidas = sum(1 for a in agenda if a["alerta"] == "VENCIDA")
        self._poner("abiertas", len(agenda), f"{urgentes} urgentes · {vencidas} con plazo vencido")
        vencidos, por_vencer = equipos[0]
        self._poner("equipos", vencidos + por_vencer, f"{vencidos} vencidos · {por_vencer} por vencer")
        self._poner("alertas", alertas[0][0], "reglas RA2, RA3 y RA5")
        monto, adjudicadas = montos[0]
        self._poner("adjudicado", f"{monto:,.0f}", f"{adjudicadas} propuestas adjudicadas")

        self.agenda.cargar(agenda)
        for iid, fila in self.agenda.visibles.items():
            if fila["alerta"] in ("URGENTE", "VENCIDA"):
                self.agenda.arbol.item(iid, tags=(fila["alerta"].lower(),))

    def _poner(self, clave, valor, detalle):
        _, etiqueta_valor, etiqueta_detalle = self.tarjetas[clave]
        etiqueta_valor.configure(text=str(valor))
        etiqueta_detalle.configure(text=detalle)
