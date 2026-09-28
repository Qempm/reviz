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
export const DATE = '2026-09-29'

/**
 * Le fichier, quand il existe.
 *
 * Publié le 29 septembre 2026, signé par la clé de release (`CN=Reviz`,
 * empreinte SHA-1 `AF:A1:F6:E8:…:8A:4A`). L'état `publie: false` existait
 * pour la période sans clé : un APK signé avec celle de débogage est
 * installable mais impossible à remplacer ensuite, et annoncer un lien mort
 * vaut moins que dire où l'on en est.
 *
 * L'empreinte SHA-256 est celle du fichier, à afficher sur `/app` : un lien
 * qui se partage de main en main peut être remplacé en route, et c'est ce qui
 * permet à un étudiant méfiant de vérifier (`sha256sum reviz-2.0.0.apk`).
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

export const APK: Apk = {
  publie: true,
  url: 'https://github.com/Qempm/reviz/releases/download/v2.0.0/reviz-2.0.0.apk',
  tailleOctets: 58_507_268,
  sha256: 'd1e903c0487dac8aacf1beaea3ef614ed77f3762617526a6518e0244688c16b3',
}

/**
 * « 18,4 Mo », comme on l'écrit en français.
 *
 * Mégaoctets **décimaux**, et non mébioctets : c'est ce qu'affichent Android,
 * l'application Fichiers et le téléchargement de Chrome. Flutter, lui,
 * annonce la même taille en mébioctets — 58,5 Mo ici valent 55,8 MiB là-bas.
 * Deux chiffres pour un seul fichier inquiètent quelqu'un qui vérifie ce
 * qu'il télécharge, donc on s'aligne sur ce que verra l'étudiant.
 */
export function tailleLisible(octets: number): string {
  const mo = octets / 1_000_000
  return `${mo.toFixed(1).replace('.', ',')} Mo`
}
