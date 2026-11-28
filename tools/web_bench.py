"""Banco de rendimiento del dibujo en Chromium (Playwright), sobre el export "Web banco".

Sirve la carpeta del export en 127.0.0.1, abre el juego (que arranca solo la sesion de
medicion) y copia a la salida las lineas de consola con el prefijo [banco-web] hasta la
linea "fin". Por defecto usa el render por software (SwiftShader), que se parece a un
equipo sin grafica dedicada; con --gpu usa la grafica de esta maquina. No pasa ni falla:
sirve para comparar antes y despues.

Con --sin-preparar el juego se salta la preparacion de materiales (para comparar). Con
--scale N la pagina tiene densidad de pixeles N (2 con 1920x1080 simula una pantalla 4K) y con
--channel chrome o msedge usa el navegador instalado en vez del Chromium de pruebas.

Uso: python tools/web_bench.py <carpeta_build_bench> [--gpu] [--sin-preparar] [--size ANCHOxALTO]
     [--scale N] [--channel chrome|msedge]
"""

import functools
import http.server
import os
import pathlib
import re
import shutil
import sys
import threading
import time

from playwright.sync_api import sync_playwright

PORT = 8062
TIMEOUT_S = 1800
PREFIX = "[banco-web] "


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def serve(directory):
    handler = functools.partial(QuietHandler, directory=str(directory))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def main():
    if len(sys.argv) < 2:
        print("uso: web_bench.py <carpeta_build_bench> [--gpu] [--size ANCHOxALTO]")
        return 2
    build = pathlib.Path(sys.argv[1]).resolve()
    root = pathlib.Path(__file__).resolve().parent.parent
    for name in ("boot.js", "boot.css"):
        shutil.copyfile(root / "web" / name, build / name)
    use_gpu = "--gpu" in sys.argv[2:]
    width, height = 1280, 720
    if "--size" in sys.argv:
        size = sys.argv[sys.argv.index("--size") + 1]
        width, height = (int(part) for part in size.lower().split("x"))
    scale = 1.0
    if "--scale" in sys.argv:
        scale = float(sys.argv[sys.argv.index("--scale") + 1])
    channel = None
    if "--channel" in sys.argv:
        channel = sys.argv[sys.argv.index("--channel") + 1]
        if channel not in ("chrome", "msedge"):
            print("canal no admitido: %s" % channel)
            return 2
    args = [] if use_gpu else ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"]
    lines = []
    pending = []
    done = threading.Event()
    shots = pathlib.Path(os.environ.get("TEMP", str(build.parent))) / "deadshift3d-capturas" / "web"
    shots.mkdir(parents=True, exist_ok=True)

    def on_console(msg):
        text = msg.text
        if text.startswith(PREFIX):
            line = text[len(PREFIX):]
            print(line, flush=True)
            lines.append(line)
            if line == "fin":
                done.set()
            elif line.startswith("captura "):
                pending.append(re.sub(r"[^a-z0-9_]", "", line[len("captura "):]))
        elif msg.type == "error":
            print("consola: " + text, flush=True)

    server = serve(build)
    try:
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=not use_gpu, args=args, channel=channel)
            context = browser.new_context(
                viewport={"width": width, "height": height}, device_scale_factor=scale
            )
            page = context.new_page()
            page.on("console", on_console)
            page.on("pageerror", lambda err: print("error de pagina: %s" % err, flush=True))
            renderer = "software (SwiftShader)" if not use_gpu else "grafica de esta maquina"
            print(
                "render: %s, navegador %s, ventana %dx%d a densidad %.2f"
                % (renderer, channel or "chromium", width, height, scale),
                flush=True,
            )
            query = "?sin_preparar" if "--sin-preparar" in sys.argv[2:] else ""
            page.goto("http://127.0.0.1:%d/index.html%s" % (PORT, query))
            started = time.time()
            while not done.is_set() and time.time() - started < TIMEOUT_S:
                page.wait_for_timeout(200)
                while pending:
                    name = pending.pop(0)
                    page.screenshot(path=str(shots / ("%s_x%.0f.png" % (name, scale))))
            browser.close()
    finally:
        server.shutdown()
    if not done.is_set():
        print("sin terminar: se agoto el tiempo")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
