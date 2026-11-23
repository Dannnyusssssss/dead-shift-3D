// Arranque del motor en la pagina. Lee la configuracion del export desde un atributo data-
// para no necesitar scripts en linea (permite una CSP sin 'unsafe-inline').
'use strict';
(function () {
  var statusBox = document.getElementById('boot-status');
  var progress = document.getElementById('boot-progress');
  var text = document.getElementById('boot-text');

  function showMessage(message) {
    statusBox.hidden = false;
    progress.hidden = true;
    text.textContent = message;
  }

  var config;
  try {
    config = JSON.parse(document.body.dataset.godotConfig || '');
  } catch (error) {
    showMessage('No se pudo iniciar el juego. Recarga la página.');
    return;
  }

  var missing = Engine.getMissingFeatures({ threads: false });
  if (missing.length > 0) {
    showMessage('Este navegador no puede ejecutar el juego. Prueba con una versión reciente de Chrome, Edge, Firefox o Safari.');
    return;
  }

  // Dentro de un iframe el navegador no deja tomar el foco sin un gesto del usuario:
  // el foco se pide aqui (solo fuera de un iframe) y con el primer toque o clic.
  var canvas = document.getElementById('canvas');
  var embedded = window.self !== window.top;
  config.focusCanvas = false;
  canvas.addEventListener('pointerdown', function () {
    canvas.focus();
  });
  // Si el navegador quita la tarjeta grafica al juego (falta de memoria, controlador reiniciado,
  // pestana dormida en el celular), el motor no puede recuperarla: se explica en vez de dejar
  // la pantalla negra. La partida conserva lo guardado en la ultima zona segura.
  canvas.addEventListener('webglcontextlost', function (event) {
    event.preventDefault();
    showMessage('El navegador detuvo los gráficos del juego. Recarga la página para seguir: '
      + 'la partida continúa desde el último guardado.');
  });

  // Zona segura (muescas y bordes curvos): el motor no la conoce en el navegador. Se mide con
  // CSS y se deja en data-safe-area como fracciones del ancho y del alto; el juego la valida.
  var probe = document.createElement('div');
  probe.className = 'safe-probe';
  document.body.appendChild(probe);
  function updateSafeArea() {
    var style = window.getComputedStyle(probe);
    var width = Math.max(window.innerWidth, 1);
    var height = Math.max(window.innerHeight, 1);
    var sides = [
      parseFloat(style.paddingLeft) / width,
      parseFloat(style.paddingTop) / height,
      parseFloat(style.paddingRight) / width,
      parseFloat(style.paddingBottom) / height,
    ].map(function (value) {
      return (isFinite(value) ? Math.min(Math.max(value, 0), 0.25) : 0).toFixed(4);
    });
    document.body.dataset.safeArea = sides.join(',');
  }
  updateSafeArea();
  window.addEventListener('resize', updateSafeArea);
  window.addEventListener('orientationchange', updateSafeArea);

  var engine = new Engine(config);
  engine.startGame({
    onProgress: function (current, total) {
      if (total > 0) {
        progress.value = Math.round((current / total) * 100);
      }
    },
  }).then(function () {
    statusBox.hidden = true;
    if (!embedded) {
      canvas.focus();
    }
  }, function () {
    showMessage('No se pudo iniciar el juego. Recarga la página.');
  });
})();
