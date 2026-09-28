import {
  APK,
  DATE,
  MAINTENANCE,
  NOTES,
  VERSION,
  VERSION_MINIMALE,
} from '@/lib/metier/publication'

/**
 * GET /version.json
 *
 * Les seuils de version, lus par l'application à chaque ouverture
 * (`apps/mobile/lib/donnees/version.dart`). Remplace le fichier statique
 * `public/version.json`, pour deux raisons :
 *
 *  1. **Un seul endroit décide.** Le fichier et la page `/app` déclaraient la
 *     même chose séparément ; les deux sortent maintenant de
 *     `lib/metier/publication.ts`.
 *  2. **Le cache.** Un fichier de `public/` est servi par le CDN avec un cache
 *     long, et le client demandait `cache-control: no-cache` sans pouvoir
 *     l'obtenir. Un écran de blocage qu'on ne peut pas lever avant un jour
 *     n'est pas un écran de blocage, c'est une panne.
 *
 * Les clés gardent leurs noms : c'est le contrat que lit déjà
 * `VersionDistante.depuis()`.
 */

/** Cinq minutes : assez pour ne pas marteler, assez court pour lever un blocage. */
const CACHE_S = 300

export async function GET(request: Request) {
  // Dérivée de la requête plutôt qu'écrite en dur : le fichier précédent
  // portait `https://reviz-eight.vercel.app/app`, qui devient faux au premier
  // changement de domaine — et le lien s'ouvre dans un navigateur, donc il
  // doit rester absolu.
  const pageInstallation = new URL('/app', request.url).toString()

  return Response.json(
    {
      version: VERSION,
      minimumVersion: VERSION_MINIMALE,
      latestVersion: VERSION,
      buildDate: DATE,
      releaseNotes: NOTES,
      // La page d'installation, pas l'APK : c'est elle qui porte la consigne
      // de désinstaller l'ancienne version, sans laquelle Android refuse le
      // remplacement et l'étudiant reste bloqué sans savoir pourquoi.
      updateUrl: pageInstallation,
      downloadUrl: APK.publie ? APK.url : null,
      critical: MAINTENANCE,
      maintenance: MAINTENANCE,
    },
    {
      headers: {
        'Cache-Control': `public, max-age=${CACHE_S}, s-maxage=${CACHE_S}`,
      },
    },
  )
}
