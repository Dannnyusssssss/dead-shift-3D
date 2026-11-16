"""Prueba de humo del export web con Chromium (Playwright).

Sirve build/web en 127.0.0.1, abre el juego por URL directa y dentro de un iframe
servido desde otro origen local (como lo haria el portal), y falla si hay errores de
consola, violaciones de CSP, errores de pagina o peticiones fuera del servidor local.
Opcionalmente guarda capturas fuera del repositorio.
En PC tambien mide el nivel de salida del audio ya dentro de la partida: si el motor
reproduce sonidos pero a la salida del navegador solo llega silencio, la prueba falla.

Uso: python tools/web_smoke.py <carpeta_build_web> <carpeta_capturas> [--touch]
"""

import functools
import http.server
import pathlib
import sys
import tempfile
import threading

from playwright.sync_api import sync_playwright

GAME_PORT = 8060
HOST_PORT = 8061
WAIT_MS = 8000
LOCAL_PREFIXES = ("http://127.0.0.1:%d/" % GAME_PORT, "http://127.0.0.1:%d/" % HOST_PORT)

IFRAME_PAGE = """<!DOCTYPE html><html lang="es"><head><meta charset="utf-8"><title>iframe</title>
<style>html,body{margin:0;height:100%%;background:#222}iframe{border:0;width:960px;height:540px}</style>
</head><body><iframe src="http://127.0.0.1:%d/index.html" allow="fullscreen; autoplay"
sandbox="allow-scripts allow-same-origin allow-pointer-lock"></iframe></body></html>
""" % GAME_PORT

# Pico minimo de salida para dar el audio por bueno (el ambiente y la musica suenan siempre).
MIN_AUDIO_PEAK = 0.005

# Desvia lo que se conecta a la salida del contexto de audio a traves de un analizador y
# guarda el pico; cuenta tambien las reproducciones de muestras iniciadas.
AUDIO_PROBE = r"""
(() => {
  window.__audioProbe = {starts: 0, peak: 0};
  const connect = AudioNode.prototype.connect;
  AudioNode.prototype.connect = function (target, ...rest) {
    if (target instanceof AudioDestinationNode) {
      const ctx = target.context;
      if (!ctx.__probeAnalyser) {
        const analyser = ctx.createAnalyser();
        analyser.fftSize = 2048;
        connect.call(analyser, target);
        const samples = new Float32Array(2048);
        setInterval(() => {
          analyser.getFloatTimeDomainData(samples);
          for (const value of samples) {
            const level = Math.abs(value);
            if (level > window.__audioProbe.peak) { window.__audioProbe.peak = level; }
          }
        }, 50);
        ctx.__probeAnalyser = analyser;
      }
      return connect.call(this, ctx.__probeAnalyser, ...rest);
    }
    return connect.call(this, target, ...rest);
  };
  const start = AudioBufferSourceNode.prototype.start;
  AudioBufferSourceNode.prototype.start = function (...args) {
    window.__audioProbe.starts++;
    return start.apply(this, args);
  };
})();
"""


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def serve(directory, port):
    handler = functools.partial(QuietHandler, directory=str(directory))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def watch(page, problems, label):
    def on_console(msg):
        if msg.type == "error":
            problems.append("%s consola: %s" % (label, msg.text))
        elif "Content Security Policy" in msg.text or "Refused to" in msg.text:
            problems.append("%s CSP: %s" % (label, msg.text))

    def on_request(request):
        url = request.url
        if not (url.startswith(LOCAL_PREFIXES) or url.startswith(("data:", "blob:"))):
            problems.append("%s peticion externa: %s" % (label, url))

    page.on("console", on_console)
    page.on("pageerror", lambda err: problems.append("%s error de pagina: %s" % (label, err)))
    page.on("request", on_request)


def wait_started(frame, problems, label):
    try:
        frame.wait_for_selector("#boot-status", state="hidden", timeout=60000)
    except Exception:  # noqa: BLE001 - se informa como fallo de la prueba
        text = frame.locator("#boot-text").text_content()
        problems.append("%s el motor no arranco: %s" % (label, text))


def main():
    if len(sys.argv) < 3:
        print("uso: web_smoke.py <build_web> <capturas> [--touch]")
        return 2
    build = pathlib.Path(sys.argv[1]).resolve()
    shots = pathlib.Path(sys.argv[2]).resolve()
    touch = "--touch" in sys.argv[3:]
    shots.mkdir(parents=True, exist_ok=True)
    problems = []
    with tempfile.TemporaryDirectory() as host_dir:
        pathlib.Path(host_dir, "index.html").write_text(IFRAME_PAGE, encoding="utf-8")
        game_server = serve(build, GAME_PORT)
        host_server = serve(host_dir, HOST_PORT)
        try:
            with sync_playwright() as pw:
                browser = pw.chromium.launch(args=["--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
                options = {"viewport": {"width": 1280, "height": 720}}
                if touch:
                    options.update({"has_touch": True, "is_mobile": True,
                                    "viewport": {"width": 915, "height": 412}})
                context = browser.new_context(**options)
                # En Windows, el bloqueo del puntero encierra el cursor real en la ventana
                # (invisible) del navegador. En la prueba se anula para no atrapar el raton.
                context.add_init_script(
                    "Element.prototype.requestPointerLock = function () {"
                    " return Promise.resolve(); };"
                )
                if not touch:
                    context.add_init_script(AUDIO_PROBE)

                page = context.new_page()
                watch(page, problems, "directa")
                page.goto(LOCAL_PREFIXES[0] + "index.html")
                wait_started(page, problems, "directa")
                page.wait_for_timeout(WAIT_MS)
                suffix = "-tactil" if touch else ""
                page.screenshot(path=str(shots / ("inicio%s.png" % suffix)))
                # Entra a la partida: el boton Jugar tiene el foco y responde a Intro.
                page.keyboard.press("Enter")
                page.wait_for_timeout(WAIT_MS)
                if touch:
                    # Un toque en la mitad izquierda activa los controles tactiles (palanca).
                    page.touchscreen.tap(150, 300)
                    page.wait_for_timeout(1500)
                else:
                    # Intro elige la dificultad marcada y Espacio salta la intro (Esc pausaria
                    # la partida si la intro ya termino).
                    page.keyboard.press("Enter")
                    page.wait_for_timeout(3000)
                    page.keyboard.press("Space")
                    page.wait_for_timeout(WAIT_MS)
                    page.keyboard.down("w")
                    page.wait_for_timeout(1500)
                    page.keyboard.up("w")
                    page.wait_for_timeout(2000)
                    probe = page.evaluate("window.__audioProbe")
                    print("audio: %d reproducciones, pico de salida %.4f"
                          % (probe["starts"], probe["peak"]))
                    if probe["starts"] == 0:
                        problems.append("directa audio: no se inicio ninguna reproduccion")
                    elif probe["peak"] < MIN_AUDIO_PEAK:
                        problems.append("directa audio: se reproduce pero a la salida llega silencio")
                page.screenshot(path=str(shots / ("juego%s.png" % suffix)))

                framed = context.new_page()
                watch(framed, problems, "iframe")
                framed.goto(LOCAL_PREFIXES[1] + "index.html")
                frame = framed.frame_locator("iframe")
                try:
                    frame.locator("#boot-status").wait_for(state="hidden", timeout=60000)
                except Exception:  # noqa: BLE001
                    problems.append("iframe el motor no arranco")
                framed.wait_for_timeout(WAIT_MS)
                framed.screenshot(path=str(shots / "iframe.png"))
                browser.close()
        finally:
            game_server.shutdown()
            host_server.shutdown()
    for line in problems:
        print("FALLO " + line)
    print("web_smoke: %d problema(s)" % len(problems))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
