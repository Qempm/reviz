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
export const VERSION = '2.4.0'

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
 *
 * **Toujours 2.0.0 avec la 2.3.1 publiée**, et c'est voulu : rien n'est cassé
 * dans la 2.0.x. Ses utilisateurs voient le bandeau « mise à jour
 * conseillée », pas un écran bloquant — on ne force une mise à jour que pour
 * une version qui ne sert plus.
 */
export const VERSION_MINIMALE = '2.0.0'

/** Coupure annoncée. Bloque l'application, sans parler de version. */
export const MAINTENANCE = false

export const NOTES =
  'Ton école, ta filière ou ta matière se tapent si elles manquent, le ' +
  'pack gratuit s’active en un appui, et tes séries de questions changent ' +
  'à chaque fois.'

/** Date de la publication, au format `AAAA-MM-JJ`. */
export const DATE = '2026-09-30'

/**
 * Le fichier, quand il existe.
 *
 * 2.3.1 publiée le 30 septembre 2026, signée par la clé de release (`CN=Reviz`,
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
  url: 'https://github.com/Qempm/reviz/releases/download/v2.4.0/reviz-2.4.0.apk',
  tailleOctets: 60_765_442,
  sha256: '9eb943b2eb1490b41a8075f9fc1e06f6b7309b7e7ffd2da4253290d83d426b24',
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
