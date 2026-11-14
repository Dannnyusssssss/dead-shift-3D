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
