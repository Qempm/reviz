import { describe, expect, it } from 'vitest'
import {
  formaterNational,
  masquerTelephone,
  normaliserTelephone,
  paysParCode,
  PAYS,
  PAYS_PAR_DEFAUT,
} from './phone'

const BJ = PAYS_PAR_DEFAUT
const CI = paysParCode('CI')!
const SN = paysParCode('SN')!

describe('normalisation des numéros', () => {
  it('accepte les formes réellement tapées par un étudiant béninois', () => {
    // Toutes ces saisies désignent le même numéro.
    for (const saisie of [
      '97123456',
      '97 12 34 56',
      '97-12-34-56',
      '97.12.34.56',
      ' 97 12 34 56 ',
      '+22997123456',
      '+229 97 12 34 56',
      '22997123456',
      '0022997123456',
    ]) {
      const r = normaliserTelephone(saisie, BJ)
      expect(r.ok, `échec sur « ${saisie} »`).toBe(true)
      if (r.ok) expect(r.e164).toBe('+22997123456')
    }
  })

  it('retire le zéro initial hérité des habitudes françaises', () => {
    const r = normaliserTelephone('097123456', BJ)
    expect(r.ok).toBe(true)
    if (r.ok) expect(r.e164).toBe('+22997123456')
  })

  it('ne retire pas un zéro qui fait partie du numéro', () => {
    // En Côte d'Ivoire les numéros à 10 chiffres commencent par 0.
    const r = normaliserTelephone('0712345678', CI)
    expect(r.ok).toBe(true)
    if (r.ok) expect(r.e164).toBe('+2250712345678')
  })

  it('reconnaît l’indicatif même si un autre pays est sélectionné', () => {
    // L'étudiant a collé un numéro sénégalais alors que le Bénin est choisi.
    const r = normaliserTelephone('+221771234567', BJ)
    expect(r.ok).toBe(true)
    if (r.ok) {
      expect(r.pays.code).toBe('SN')
      expect(r.e164).toBe('+221771234567')
    }
  })

  it('refuse une longueur invalide', () => {
    for (const saisie of ['9712', '971234567890123']) {
      const r = normaliserTelephone(saisie, BJ)
      expect(r.ok).toBe(false)
      if (!r.ok) expect(r.raison).toBe('longueur')
    }
  })

  it('refuse une saisie vide ou sans chiffre', () => {
    for (const saisie of ['', '   ', 'abc', '+++']) {
      const r = normaliserTelephone(saisie, BJ)
      expect(r.ok).toBe(false)
      if (!r.ok) expect(r.raison).toBe('vide')
    }
  })

  it('couvre les cinq pays visés', () => {
    const exemples: Record<string, string> = {
      BJ: '97123456',
      TG: '90123456',
      CI: '0712345678',
      SN: '771234567',
      BF: '70123456',
    }
    for (const pays of PAYS) {
      const r = normaliserTelephone(exemples[pays.code], pays)
      expect(r.ok, `échec pour ${pays.code}`).toBe(true)
      if (r.ok) expect(r.e164.startsWith(`+${pays.indicatif}`)).toBe(true)
    }
  })

  it('produit toujours du E.164 : un plus, puis des chiffres', () => {
    const r = normaliserTelephone('97 12 34 56', BJ)
    expect(r.ok).toBe(true)
    if (r.ok) expect(r.e164).toMatch(/^\+[1-9]\d{7,14}$/)
  })

  it('l’exemple affiché de chaque pays est lui-même valide', () => {
    // Un exemple d'aide à la saisie que le validateur refuserait serait
    // le plus sûr moyen de faire douter l'étudiant.
    for (const pays of PAYS) {
      const r = normaliserTelephone(pays.exemple, pays)
      expect(r.ok, `exemple invalide pour ${pays.nom} : ${pays.exemple}`).toBe(true)
    }
  })
})

describe('affichage', () => {
  it('groupe selon l’usage de chaque pays', () => {
    expect(formaterNational('97123456', BJ)).toBe('97 12 34 56')
    expect(formaterNational('0712345678', CI)).toBe('07 12 34 56 78')
    expect(formaterNational('771234567', SN)).toBe('77 123 45 67')
  })

  it('formate exactement comme l’exemple affiché, pour les cinq pays', () => {
    // Le garde-fou qui compte : si le formateur et l'aide à la saisie
    // divergent, l'étudiant croit s'être trompé.
    for (const pays of PAYS) {
      const r = normaliserTelephone(pays.exemple, pays)
      expect(r.ok).toBe(true)
      if (r.ok) {
        expect(formaterNational(r.national, pays), `divergence pour ${pays.nom}`)
          .toBe(pays.exemple)
      }
    }
  })

  it('formate un numéro en cours de frappe sans le déformer', () => {
    expect(formaterNational('9', BJ)).toBe('9')
    expect(formaterNational('971', BJ)).toBe('97 1')
    expect(formaterNational('77123', SN)).toBe('77 123')
  })

  it('masque le milieu du numéro', () => {
    expect(masquerTelephone('+22997123456')).toBe('+229 97 •••• 56')
  })

  it('laisse intact un numéro non reconnu', () => {
    expect(masquerTelephone('+33612345678')).toBe('+33612345678')
  })
})
