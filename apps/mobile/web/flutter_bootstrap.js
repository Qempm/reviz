{{flutter_js}}
{{flutter_build_config}}

// Le démarrage par défaut de Flutter, plus une chose : l'écran de chargement
// d'index.html part quand l'application a dessiné sa première image.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    const chargement = document.getElementById('chargement');
    if (chargement) chargement.remove();
    // Le moteur de rendu se garde pour le hors-ligne (index.html, sw.js).
    if (window.revizGarderMoteur) window.revizGarderMoteur();
  },
});
