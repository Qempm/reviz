import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import {
  dureeLisible,
  FAQ,
  meilleurPrixParJour,
  nombreLisible,
  objectifDe,
  PACK_CONSEILLE,
  PACKS_DE_REPLI,
  phraseConseil,
  prixLisible,
  prixParJour,
} from './offre'

describe('offre publique', () => {
  it('la grille de repli est celle de la graine SQL', () => {
    const graine = readFileSync('supabase/migrations/20260908130000_seed.sql', 'utf8')
    for (const p of PACKS_DE_REPLI) {
      // ('controle', 'Contrôle', '…', 500, 7, 3, 2)
      const motif = new RegExp(
        `\\('${p.code}',[\\s\\S]*?\\n\\s*${p.prixFcfa}, ${p.jours}, ${p.corrections}, ${p.matieres ?? 'null'}\\)`,
      )
      expect(graine, p.code).toMatch(motif)
    }
  })

  it('le pack conseillé existe', () => {
    expect(PACKS_DE_REPLI.some((p) => p.code === PACK_CONSEILLE)).toBe(true)
  })

  it('prix et durées se lisent en français', () => {
    expect(prixLisible(0)).toBe('Gratuit')
    expect(prixLisible(1500)).toBe('1 500 F')
    expect(prixLisible(500)).toBe('500 F')
    expect(dureeLisible(3)).toBe('3 jours')
    expect(dureeLisible(7)).toBe('1 semaine')
    expect(dureeLisible(30)).toBe('1 mois')
    expect(dureeLisible(120)).toBe('4 mois')
  })

  it('la FAQ parle d’argent en premier, et ne promet plus de WhatsApp', () => {
    expect(FAQ[0].question).toMatch(/prélevé/)
    for (const q of FAQ) expect(q.reponse).not.toMatch(/WhatsApp/)
  })

  it('le prix par jour ne ment pas sur l’arrondi', () => {
    expect(prixParJour(1500, 30)).toBe('50 F par jour')
    expect(prixParJour(500, 7)).toBe('≈ 71 F par jour')
    expect(prixParJour(2000, 30)).toBe('≈ 67 F par jour')
    expect(prixParJour(3500, 120)).toBe('≈ 29 F par jour')
    expect(nombreLisible(3500)).toBe('3 500')
  })

  it('le meilleur prix par jour est le Semestre, et jamais le pack gratuit', () => {
    expect(meilleurPrixParJour(PACKS_DE_REPLI)).toBe('semestre')
    expect(meilleurPrixParJour(PACKS_DE_REPLI.filter((p) => p.prixFcfa === 0))).toBeNull()
  })

  it('chaque pack payant a son objectif et sa phrase de conseil', () => {
    const partiel = PACKS_DE_REPLI.find((p) => p.code === 'partiel')!
    expect(phraseConseil(partiel)).toBe(
      'Pour tes partiels, prends le pack Partiel : 1 mois, 5 matières, 10 corrections.',
    )
    const inconnu = { ...partiel, code: 'vacances', label: 'Vacances' }
    expect(objectifDe(inconnu).bouton).toBe('Vacances')
  })
})
