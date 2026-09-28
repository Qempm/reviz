import { describe, expect, it } from 'vitest'
import {
  APK,
  DATE,
  tailleLisible,
  VERSION,
  VERSION_MINIMALE,
} from './publication'

/**
 * Tests de ce qu'on publie.
 *
 * Un seul de ces tests compte vraiment, et c'est le premier : un
 * `VERSION_MINIMALE` supérieur à la version téléchargeable **arrête tout le
 * parc sans issue**. L'application affiche « mise à jour exigée », le lien
 * mène à une version que le fichier déclare périmée, et plus personne
 * n'entre — y compris ceux qui viennent d'installer. C'est une panne qu'on ne
 * répare qu'en repoussant le serveur, et une faute d'inattention suffit à la
 * provoquer.
 */

/** Même comparaison que `apps/mobile/lib/metier/version.dart`. */
function comparer(a: string, b: string): number {
  const seg = (v: string) =>
    v
      .split(/[+\-\s]/)[0]
      .split('.')
      .map((s) => Number.parseInt(s.replace(/[^0-9]/g, ''), 10) || 0)

  const ga = seg(a)
  const gb = seg(b)

  for (let i = 0; i < Math.max(ga.length, gb.length); i++) {
    const x = ga[i] ?? 0
    const y = gb[i] ?? 0
    if (x !== y) return x < y ? -1 : 1
  }

  return 0
}

describe('les seuils publiés', () => {
  it('n’exige jamais plus que ce qu’on peut installer', () => {
    expect(comparer(VERSION_MINIMALE, VERSION)).toBeLessThanOrEqual(0)
  })

  it('porte des versions de la forme attendue', () => {
    // `etatVersion()` tolère une chaîne mal formée en la traitant comme
    // 0.0.0 — ce qui, pour un minimum, désactiverait silencieusement le
    // blocage.
    for (const v of [VERSION, VERSION_MINIMALE]) {
      expect(v).toMatch(/^\d+\.\d+\.\d+$/)
    }
  })

  it('date la publication au format que lit l’application', () => {
    expect(DATE).toMatch(/^\d{4}-\d{2}-\d{2}$/)
  })
})

describe('le fichier', () => {
  it('ne s’annonce publié qu’avec une URL, une taille et une empreinte', () => {
    // Le seul état à moitié rempli qu'on pourrait écrire par distraction :
    // `publie: true` avec une URL vide met un bouton mort sur la page.
    if (!APK.publie) {
      expect(APK.publie).toBe(false)
      return
    }

    expect(APK.url).toMatch(/^https:\/\//)
    expect(APK.tailleOctets).toBeGreaterThan(1_000_000)
    expect(APK.sha256).toMatch(/^[0-9a-f]{64}$/)
  })
})

describe('taille lisible', () => {
  it('écrit les mégaoctets à la française', () => {
    expect(tailleLisible(18_400_000)).toBe('18,4 Mo')
    expect(tailleLisible(9_000_000)).toBe('9,0 Mo')
  })
})
