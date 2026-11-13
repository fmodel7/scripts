import math
import queue
import re
import struct
import threading
import time
import tkinter as tk
import wave
import winsound
from datetime import datetime
from pathlib import Path
from tkinter import ttk

import pystray
from PIL import Image, ImageDraw
from playwright.sync_api import sync_playwright

SNOW_URL = "https://example.service-now.com"
INTERVALO_LEITURA = 5
INTERVALO_REFRESH = 60
LIMITE_FALHA = 60
PERFIL = Path.home() / "snow_monitor_edge_v5"
SIRENE = Path.home() / "snow_monitor_sirene_v5.wav"
PADRAO_INC = re.compile(r"^INC\d{6,10}$", re.I)


def criar_sirene():
    if SIRENE.exists():
        return
    taxa, duracao, amplitude = 22050, 5, 14000
    dados = bytearray()
    for i in range(taxa * duracao):
        t = i / taxa
        frequencia = 800 if int(t / 0.4) % 2 == 0 else 1450
        valor = int(amplitude * math.sin(2 * math.pi * frequencia * t))
        dados.extend(struct.pack("<h", valor))
    with wave.open(str(SIRENE), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(taxa)
        wav.writeframes(dados)


def sirene():
    winsound.PlaySound(str(SIRENE), winsound.SND_FILENAME | winsound.SND_ASYNC)


def ler_incidentes(pagina):
    # A tabela do ServiceNow Classic pode estar dentro de um iframe.
    for frame in pagina.frames:
        try:
            resposta = frame.evaluate(r"""() => {
                for (const tabela of document.querySelectorAll('table')) {
                    const ths = [...tabela.querySelectorAll('th, [role="columnheader"]')];
                    if (!ths.some(th => th.innerText.trim().toLowerCase() === 'number')) continue;
                    const encontrados = new Set();
                    for (const linha of tabela.querySelectorAll('tr, [role="row"]')) {
                        for (const link of linha.querySelectorAll('a')) {
                            const numero = link.innerText.trim();
                            if (/^INC\d{6,10}$/i.test(numero)) encontrados.add(numero.toUpperCase());
                        }
                    }
                    return {encontrada: true, numeros: [...encontrados]};
                }
                return {encontrada: false, numeros: []};
            }""")
            if resposta["encontrada"]:
                return {n.upper() for n in resposta["numeros"] if PADRAO_INC.fullmatch(n)}
        except Exception:
            # Durante o refresh, os frames podem desaparecer momentaneamente.
            pass
    return None


def localizar_aba(contexto):
    """Preferir a aba cuja tabela esteja realmente disponivel."""
    abertas = [p for p in contexto.pages if not p.is_closed()]
    for pagina in abertas:
        try:
            if ler_incidentes(pagina) is not None:
                return pagina
        except Exception:
            pass
    for pagina in abertas:
        if "incident_list" in pagina.url.lower():
            return pagina
    for pagina in abertas:
        if "example.service-now.com" in pagina.url.lower():
            return pagina
    return None


def diagnosticar_abas(contexto):
    """Loga apenas metadados tecnicos, sem divulgar dados dos incidentes."""
    infos = []
    for pagina in contexto.pages:
        if pagina.is_closed():
            continue
        try:
            frames = len(pagina.frames)
            lidos = ler_incidentes(pagina)
            status = "tabela encontrada" if lidos is not None else "tabela nao encontrada"
            infos.append(f"aba={pagina.url.split('?')[0][:110]} frames={frames} {status}")
        except Exception as erro:
            infos.append(f"erro na aba: {type(erro).__name__}")
    return infos or ["Nenhuma aba aberta no Edge automatizado"]


def trabalhador(eventos, parar):
    conhecidos, candidatos = set(), set()
    iniciado = False
    inicio_falha = None
    falha_avisada = False
    ultimo_refresh = time.monotonic()
    ultimo_diagnostico = 0

    def enviar(tipo, dado):
        eventos.put((tipo, dado))

    try:
        enviar("status", "Iniciando Microsoft Edge...")
        with sync_playwright() as p:
            contexto = p.chromium.launch_persistent_context(
                user_data_dir=str(PERFIL), channel="msedge",
                headless=False, no_viewport=True
            )
            try:
                pagina = contexto.pages[0] if contexto.pages else contexto.new_page()
                pagina.goto(SNOW_URL, wait_until="domcontentloaded", timeout=30000)
                enviar("status", "Abra sua fila no Edge. Aguardando tabela...")
                while not parar.is_set():
                    pagina = localizar_aba(contexto)
                    agora = time.monotonic()
                    if pagina is not None and agora - ultimo_refresh >= INTERVALO_REFRESH:
                        enviar("log", "Refresh automático iniciado")
                        candidatos.clear()
                        try:
                            pagina.reload(wait_until="domcontentloaded", timeout=30000)
                            enviar("log", "Refresh solicitado")
                        except Exception as erro:
                            enviar("log", f"Falha no refresh: {type(erro).__name__}")
                        ultimo_refresh = time.monotonic()

                    atuais = ler_incidentes(pagina) if pagina is not None else None
                    if atuais is None and time.monotonic() - ultimo_diagnostico >= 30:
                        for item in diagnosticar_abas(contexto):
                            enviar("log", "DIAGNOSTICO: " + item)
                        ultimo_diagnostico = time.monotonic()
                    if atuais is None:
                        candidatos.clear()
                        if inicio_falha is None:
                            inicio_falha = time.monotonic()
                        if time.monotonic() - inicio_falha >= LIMITE_FALHA and not falha_avisada:
                            enviar("falha", "Tabela indisponível por 60 segundos")
                            falha_avisada = True
                        enviar("status", "Aguardando tabela / verificando sessão...")
                    else:
                        if inicio_falha is not None:
                            enviar("log", "Leitura recuperada")
                        inicio_falha, falha_avisada = None, False
                        if not iniciado:
                            if atuais:  # Não iniciar a partir de tabela vazia transitória.
                                conhecidos.update(atuais)
                                iniciado = True
                                enviar("log", f"Base inicial: {len(conhecidos)} INC(s)")
                        elif atuais:
                            desconhecidos = atuais - conhecidos
                            confirmados = desconhecidos & candidatos
                            if confirmados:
                                conhecidos.update(confirmados)
                                enviar("novo", sorted(confirmados))
                            candidatos = desconhecidos - confirmados
                        else:
                            candidatos.clear()
                        enviar("contagem", (len(atuais), len(conhecidos)))
                        enviar("status", "Monitorando" if iniciado else "Aguardando primeira lista com INCs")
                    parar.wait(INTERVALO_LEITURA)
            finally:
                contexto.close()
    except Exception as erro:
        enviar("erro", f"{type(erro).__name__}: {erro}")
    finally:
        enviar("parado", None)


def imagem_icone():
    img = Image.new("RGB", (64, 64), "#172033")
    d = ImageDraw.Draw(img)
    d.ellipse((9, 9, 55, 55), fill="#df394b")
    d.rectangle((29, 18, 35, 40), fill="white")
    d.ellipse((29, 44, 35, 50), fill="white")
    return img


class Aplicativo:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("SNOW Edge Monitor v5")
        self.root.geometry("520x400")
        self.root.minsize(460, 340)
        self.root.protocol("WM_DELETE_WINDOW", self.ocultar)
        self.eventos = queue.Queue()
        self.parar = threading.Event()
        self.thread = None
        self.fechando = False
        self.alerta = None
        self.pendentes = set()

        self.estado = tk.StringVar(value="Parado")
        self.contagem = tk.StringVar(value="INCs visíveis: — | Conhecidos: —")
        ttk.Label(self.root, text="SNOW EDGE MONITOR v5", font=("Segoe UI", 17, "bold")).pack(pady=15)
        ttk.Label(self.root, textvariable=self.estado, font=("Segoe UI", 12)).pack(pady=5)
        ttk.Label(self.root, textvariable=self.contagem).pack(pady=5)
        barra = ttk.Frame(self.root)
        barra.pack(pady=12)
        ttk.Button(barra, text="Iniciar", command=self.iniciar).pack(side="left", padx=5)
        ttk.Button(barra, text="Parar", command=self.solicitar_parada).pack(side="left", padx=5)
        ttk.Button(barra, text="Testar alerta", command=self.teste).pack(side="left", padx=5)
        self.logs = tk.Text(self.root, height=11, width=65, state="disabled", wrap="word")
        self.logs.pack(fill="both", expand=True, padx=14, pady=8)
        ttk.Label(self.root, text="Fechar a janela apenas a oculta. Use Sair para encerrar.").pack(pady=5)

        self.icone = pystray.Icon(
            "snow_monitor_v5", imagem_icone(), "SNOW Edge Monitor v5",
            menu=pystray.Menu(
                pystray.MenuItem("Mostrar painel", lambda *_: self.eventos.put(("mostrar", None)), default=True),
                pystray.MenuItem("Iniciar", lambda *_: self.eventos.put(("iniciar", None))),
                pystray.MenuItem("Parar", lambda *_: self.eventos.put(("parar_cmd", None))),
                pystray.MenuItem("Testar alerta", lambda *_: self.eventos.put(("teste", None))),
                pystray.MenuItem("Sair", lambda *_: self.eventos.put(("sair", None)))
            )
        )
        # Em Windows, pystray pode rodar em thread separada; Tk fica na principal.
        threading.Thread(target=self.icone.run, daemon=True).start()
        self.root.after(150, self.processar_eventos)

    def registrar(self, mensagem):
        self.logs.configure(state="normal")
        self.logs.insert("end", f"[{datetime.now():%H:%M:%S}] {mensagem}\n")
        self.logs.see("end")
        self.logs.configure(state="disabled")

    def iniciar(self):
        if self.thread and self.thread.is_alive():
            self.registrar("Monitor já está em execução")
            return
        self.parar = threading.Event()
        self.thread = threading.Thread(target=trabalhador, args=(self.eventos, self.parar), daemon=True)
        self.thread.start()
        self.registrar("Inicializando. Faça login e abra a lista no Edge.")

    def solicitar_parada(self):
        self.parar.set()
        self.estado.set("Parando... (aguarde o Edge encerrar)")
        self.registrar("Parada solicitada")

    def ocultar(self):
        self.root.withdraw()

    def mostrar(self):
        self.root.deiconify()
        self.root.lift()

    def mostrar_alerta(self, numeros):
        self.pendentes.update(numeros)
        if self.alerta and self.alerta.winfo_exists():
            self.rotulo_alerta.config(text="\n".join(sorted(self.pendentes)))
            self.alerta.lift()
            return
        self.alerta = tk.Toplevel(self.root)
        self.alerta.title("SNOW - NOVO INCIDENTE")
        self.alerta.geometry("490x260")
        self.alerta.configure(bg="#172033")
        self.alerta.attributes("-topmost", True)
        tk.Label(self.alerta, text="NOVO INCIDENTE NO SNOW!", fg="white", bg="#172033", font=("Segoe UI", 16, "bold")).pack(pady=24)
        self.rotulo_alerta = tk.Label(self.alerta, text="\n".join(sorted(self.pendentes)), fg="#ffcc33", bg="#172033", font=("Segoe UI", 17, "bold"), wraplength=430)
        self.rotulo_alerta.pack(pady=15)
        tk.Button(self.alerta, text="OK - ENTENDIDO", command=self.fechar_alerta, bg="#df394b", fg="white", width=22).pack(pady=15)
        self.alerta.protocol("WM_DELETE_WINDOW", self.fechar_alerta)
        self.alerta.lift()

    def fechar_alerta(self):
        if self.alerta and self.alerta.winfo_exists():
            self.alerta.destroy()
        self.alerta = None
        self.pendentes.clear()

    def teste(self):
        sirene()
        self.mostrar_alerta(["INC9999999"])
        self.registrar("Alerta de teste (INC fictício)")

    def sair(self):
        self.fechando = True
        self.solicitar_parada()

    def processar_eventos(self):
        try:
            while True:
                tipo, dado = self.eventos.get_nowait()
                if tipo == "status":
                    self.estado.set(dado)
                elif tipo == "contagem":
                    self.contagem.set(f"INCs visíveis: {dado[0]} | Conhecidos: {dado[1]}")
                elif tipo == "log":
                    self.registrar(dado)
                elif tipo == "novo":
                    self.registrar("NOVO(S) INC(S): " + ", ".join(dado))
                    sirene()
                    self.mostrar_alerta(dado)
                elif tipo == "falha":
                    self.registrar("ALERTA: " + dado)
                    winsound.MessageBeep(winsound.MB_ICONHAND)
                elif tipo == "erro":
                    self.registrar("ERRO: " + dado)
                    self.estado.set("Erro — verifique o painel")
                elif tipo == "parado":
                    if not self.fechando:
                        self.estado.set("Parado")
                    self.registrar("Monitor encerrado")
                elif tipo == "mostrar":
                    self.mostrar()
                elif tipo == "iniciar":
                    self.iniciar()
                elif tipo == "parar_cmd":
                    self.solicitar_parada()
                elif tipo == "teste":
                    self.teste()
                elif tipo == "sair":
                    self.sair()
        except queue.Empty:
            pass
        if self.fechando and (not self.thread or not self.thread.is_alive()):
            self.icone.stop()
            self.root.destroy()
            return
        self.root.after(150, self.processar_eventos)

    def executar(self):
        self.root.mainloop()


if __name__ == "__main__":
    criar_sirene()
    Aplicativo().executar()
