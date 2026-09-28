/**
 * Ce qui est publié, et où.
 *
 * Un seul endroit pour la version, le seuil de blocage et le fichier à
 * télécharger. Avant, ces faits vivaient à deux endroits qui pouvaient
 * diverger : `public/version.json`, lu par l'application pour décider si
 * elle peut encore servir, et la page `/app`, lue par l'étudiant pour savoir
 * quoi installer. Rien ne les tenait ensemble — et une page qui propose une
 * version que le fichier déclare périmée renvoie l'étudiant en boucle.
 *
 * `public/version.json` est donc remplacé par `app/version.json/route.ts`, qui
 * sert ce module. Publier une version se fait ici, et nulle part ailleurs.
 */

/** La version publiée, telle que `pubspec.yaml` la déclare. */
export const VERSION = '2.0.0'

/**
 * En dessous, l'application refuse de servir.
 *
 * Égal à `VERSION` pour cette publication, et c'est voulu : la 1.0.0 était
 * l'ancienne coquille WebView, qui chargeait des écrans web supprimés au
 * lot D. Elle n'affiche donc plus rien d'utile, et la laisser passer serait
 * pire que la bloquer.
 *
 * Ne jamais poser ici une version supérieure à celle qu'on peut réellement
 * télécharger : tout le parc s'arrêterait sans issue. Le test de
 * `publication.test.ts` le vérifie.
 */
export const VERSION_MINIMALE = '2.0.0'

/** Coupure annoncée. Bloque l'application, sans parler de version. */
export const MAINTENANCE = false

export const NOTES =
  'Reviz devient une vraie application : plus rapide, utilisable hors ligne ' +
  'pour les QCM déjà chargés, et la correction de copie fonctionne.'

/** Date de la publication, au format `AAAA-MM-JJ`. */
export const DATE = '2026-09-28'

/**
 * Le fichier, quand il existe.
 *
 * `publie: false` tant que la clé de signature n'est pas créée : un APK signé
 * avec la clé de débogage est installable mais impossible à mettre à jour
 * ensuite, et annoncer un lien mort vaut moins que dire où l'on en est.
 *
 * L'APK ne vit **pas** dans `public/` : un binaire versionné alourdit
 * l'historique git définitivement, à chaque reconstruction. Il se publie en
 * release GitHub, et c'est cette URL qui va ci-dessous.
 */
export type Apk =
  | { publie: false }
  | {
      publie: true
      /** L'asset de la release GitHub. */
      url: string
      tailleOctets: number
      /** Empreinte du fichier, pour qu'un étudiant méfiant puisse vérifier. */
      sha256: string
    }

export const APK: Apk = { publie: false }

/** « 18,4 Mo », comme on l'écrit en français. */
export function tailleLisible(octets: number): string {
  const mo = octets / 1_000_000
  return `${mo.toFixed(1).replace('.', ',')} Mo`
}
