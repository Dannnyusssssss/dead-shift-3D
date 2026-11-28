"""Banco de rendimiento del dibujo en Chromium (Playwright), sobre el export "Web banco".

Sirve la carpeta del export en 127.0.0.1, abre el juego (que arranca solo la sesion de
medicion) y copia a la salida las lineas de consola con el prefijo [banco-web] hasta la
linea "fin". Por defecto usa el render por software (SwiftShader), que se parece a un
equipo sin grafica dedicada; con --gpu usa la grafica de esta maquina. No pasa ni falla:
sirve para comparar antes y despues.

Con --sin-preparar el juego se salta la preparacion de materiales (para comparar).

Uso: python tools/web_bench.py <carpeta_build_bench> [--gpu] [--sin-preparar] [--size ANCHOxALTO]
"""

import functools
import http.server
import pathlib
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
    args = [] if use_gpu else ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"]
    lines = []
    done = threading.Event()

    def on_console(msg):
        text = msg.text
        if text.startswith(PREFIX):
            line = text[len(PREFIX):]
            print(line, flush=True)
            lines.append(line)
            if line == "fin":
                done.set()
        elif msg.type == "error":
            print("consola: " + text, flush=True)

    server = serve(build)
    try:
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=not use_gpu, args=args)
            context = browser.new_context(viewport={"width": width, "height": height})
            page = context.new_page()
            page.on("console", on_console)
            page.on("pageerror", lambda err: print("error de pagina: %s" % err, flush=True))
            renderer = "software (SwiftShader)" if not use_gpu else "grafica de esta maquina"
            print("render: %s, ventana %dx%d" % (renderer, width, height), flush=True)
            query = "?sin_preparar" if "--sin-preparar" in sys.argv[2:] else ""
            page.goto("http://127.0.0.1:%d/index.html%s" % (PORT, query))
            started = time.time()
            while not done.is_set() and time.time() - started < TIMEOUT_S:
                page.wait_for_timeout(1000)
            browser.close()
    finally:
        server.shutdown()
    if not done.is_set():
        print("sin terminar: se agoto el tiempo")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
