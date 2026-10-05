// Reviz hors ligne, dans le navigateur — et surtout sur iPhone, où l'app web
// installée (« Sur l'écran d'accueil ») tient lieu d'application.
//
// Sans lui, la version web avait besoin du réseau pour s'ouvrir : le
// chargeur de Flutter n'enregistre aucun service worker (et celui qu'il
// fabrique, `flutter_service_worker.js`, ne fait que se désinscrire).
//
// Trois règles :
// - **L'application** (index, moteur Dart, polices, images) est gardée en
//   entier à l'installation, dans un cache qui porte la version : une
//   nouvelle compilation remplace l'ancienne d'un coup, sans mélange.
// - **Le moteur de rendu** (CanvasKit, sur www.gstatic.com) et les polices
//   de secours de Google sont gardés au premier passage : ils dépendent du
//   navigateur, on ne sait pas d'avance lequel servira.
// - **Les données** (Supabase, /api) ne passent jamais par ici : elles ont
//   leur propre copie, par compte (`lib/donnees/cache.dart`).
//
// `scripts/web.mjs` remplace VERSION et FICHIERS à chaque `npm run web`.

const VERSION = '__VERSION__';
const FICHIERS = __FICHIERS__;

const CACHE_APP = `reviz-app-${VERSION}`;
const CACHE_MOTEUR = 'reviz-moteur';

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE_APP);
      // Un par un plutôt que `addAll` : un fichier qui échoue sur une 3G
      // ne doit pas faire échouer toute l'installation.
      await Promise.all(
        FICHIERS.map(async (f) => {
          try {
            const reponse = await fetch(new Request(f, { cache: 'reload' }));
            if (reponse.ok) await cache.put(f, reponse);
          } catch (_) {}
        }),
      );
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      for (const nom of await caches.keys()) {
        if (nom.startsWith('reviz-app-') && nom !== CACHE_APP) {
          await caches.delete(nom);
        }
      }
      await self.clients.claim();
    })(),
  );
});

// Au tout premier passage, la page charge le moteur de rendu avant que ce
// service worker ne la contrôle : il ne le voit pas passer. La page lui
// donne donc la liste de ce qu'elle a réellement chargé (la variante de
// CanvasKit dépend du navigateur), et il le garde — le plus souvent depuis
// le cache HTTP du navigateur, sans retélécharger.
self.addEventListener('message', (event) => {
  const donnees = event.data;
  if (!donnees || donnees.type !== 'garder-moteur' || !Array.isArray(donnees.urls)) return;
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE_MOTEUR);
      for (const url of donnees.urls) {
        try {
          if (!estMoteur(new URL(url)) || (await cache.match(url))) continue;
          const reponse = await fetch(url, { mode: 'cors' });
          if (reponse.ok) await cache.put(url, reponse);
        } catch (_) {}
      }
    })(),
  );
});

// ------------------------------------------------------------ Notifications
//
// Le Web Push (lib/notifications/webpush.ts) : sur iPhone, l'app web
// installée reçoit ainsi « cours prêt », « copie corrigée », « paiement
// confirmé »… Apple exige qu'un push affiche une notification : on
// l'affiche toujours, et on prévient la page ouverte pour qu'elle relise.

self.addEventListener('push', (event) => {
  let m = {};
  try {
    m = event.data ? event.data.json() : {};
  } catch (_) {
    m = { titre: 'Reviz', corps: event.data ? event.data.text() : '' };
  }
  event.waitUntil(
    (async () => {
      await self.registration.showNotification(m.titre || 'Reviz', {
        body: m.corps || '',
        icon: 'icons/Icon-192.png',
        badge: 'icons/Icon-192.png',
        tag: m.id || undefined,
        data: { lien: m.lien || '/accueil' },
      });
      for (const client of await self.clients.matchAll({ type: 'window' })) {
        client.postMessage({ type: 'reviz-push', evenement: 'recu' });
      }
    })(),
  );
});

// Toucher la notification ouvre Reviz sur la bonne page : la fenêtre déjà
// ouverte si elle existe, sinon une nouvelle.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const lien = (event.notification.data && event.notification.data.lien) || '/accueil';
  event.waitUntil(
    (async () => {
      const fenetres = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      for (const client of fenetres) {
        if ('focus' in client) {
          await client.focus();
          client.postMessage({ type: 'reviz-push', evenement: 'ouvrir', lien });
          return;
        }
      }
      const base = self.registration.scope.replace(/\/?$/, '');
      await self.clients.openWindow(`${base}#${lien}`);
    })(),
  );
});

/** Le moteur de rendu et les polices de Google : gardés au premier passage. */
function estMoteur(url) {
  return (
    (url.hostname === 'www.gstatic.com' && url.pathname.startsWith('/flutter-canvaskit/')) ||
    url.hostname === 'fonts.gstatic.com' ||
    url.hostname === 'fonts.googleapis.com'
  );
}

self.addEventListener('fetch', (event) => {
  const requete = event.request;
  if (requete.method !== 'GET') return;
  const url = new URL(requete.url);

  if (estMoteur(url)) {
    event.respondWith(
      (async () => {
        const cache = await caches.open(CACHE_MOTEUR);
        const garde = await cache.match(requete);
        if (garde) return garde;
        const reponse = await fetch(requete);
        if (reponse.ok || reponse.type === 'opaque') {
          cache.put(requete, reponse.clone());
        }
        return reponse;
      })(),
    );
    return;
  }

  // Seulement l'application elle-même : /web et ce qui est dessous. Les
  // données et les routes passent tout droit.
  const portee = new URL(self.registration.scope);
  const base = portee.pathname.replace(/\/$/, '');
  const dansLApp =
    url.origin === portee.origin &&
    !url.pathname.startsWith('/api/') &&
    (base === '' || url.pathname === base || url.pathname.startsWith(base + '/'));
  if (!dansLApp) return;

  // La page : le réseau d'abord (pour voir arriver une nouvelle version),
  // la copie sans réseau — mais pas plus de quatre secondes d'attente.
  if (requete.mode === 'navigate') {
    event.respondWith(
      (async () => {
        const cache = await caches.open(CACHE_APP);
        try {
          const reponse = await Promise.race([
            fetch(requete),
            new Promise((_, rejeter) => setTimeout(rejeter, 4000)),
          ]);
          // Une redirection (/web/ vers /web) ne se garde pas : servie à
          // une navigation, le navigateur la refuserait.
          if (reponse.ok && !reponse.redirected && reponse.type === 'basic') {
            cache.put('index.html', reponse.clone());
          }
          return reponse;
        } catch (_) {
          return (await cache.match('index.html')) || Response.error();
        }
      })(),
    );
    return;
  }

  // Le reste de l'application : la copie de cette version, sinon le réseau.
  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE_APP);
      const garde = await cache.match(requete, { ignoreSearch: true });
      if (garde) return garde;
      const reponse = await fetch(requete);
      if (reponse.ok) cache.put(requete, reponse.clone());
      return reponse;
    })(),
  );
});
