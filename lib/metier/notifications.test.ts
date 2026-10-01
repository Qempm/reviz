import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import {
  CATEGORIE,
  CATEGORIES,
  estSorte,
  lienDe,
  pushAutorise,
  SORTES,
  textePush,
} from './notifications'

const CAS: Array<{
  kind: string
  reference: string | null
  data: Record<string, unknown>
  titre: string
  corps: string
  lien: string
}> = JSON.parse(readFileSync('lib/metier/notifications.cas.json', 'utf8'))

describe('notifications', () => {
  it('rend chaque cas partagé avec l’application, mot pour mot', () => {
    for (const c of CAS) {
      expect(estSorte(c.kind), c.kind).toBe(true)
      if (!estSorte(c.kind)) continue
      expect(textePush(c.kind, c.data), c.kind).toEqual({ titre: c.titre, corps: c.corps })
      expect(lienDe(c.kind, c.reference), c.kind).toBe(c.lien)
    }
  })

  it('chaque sorte a une catégorie, un texte et un cas', () => {
    for (const s of SORTES) {
      expect(CATEGORIES).toContain(CATEGORIE[s])
      const t = textePush(s, {})
      expect(t.titre.length, s).toBeGreaterThan(0)
      expect(t.corps.length, s).toBeGreaterThan(0)
      expect(CAS.some((c) => c.kind === s), `cas manquant : ${s}`).toBe(true)
    }
  })

  it('la liste des sortes est celle de la contrainte SQL', () => {
    const sql = readFileSync('supabase/migrations/20261001120000_notifications.sql', 'utf8')
    const bloc = sql.slice(sql.indexOf('kind text not null check'), sql.indexOf(')),'))
    const enBase = [...bloc.matchAll(/'([a-z_]+)'/g)].map((m) => m[1]).sort()
    expect(enBase).toEqual([...SORTES].sort())
  })

  it('les préférences coupent une catégorie, et rien d’autre', () => {
    expect(pushAutorise({}, 'cours_pret')).toBe(true)
    expect(pushAutorise(null, 'cours_pret')).toBe(true)
    expect(pushAutorise({ cours: false }, 'cours_pret')).toBe(false)
    expect(pushAutorise({ cours: false }, 'correction_prete')).toBe(false)
    expect(pushAutorise({ cours: false }, 'paiement_reussi')).toBe(true)
    expect(pushAutorise({ ligue: 'non' }, 'ligue_cloturee')).toBe(true)
  })

  it('ne promet plus de WhatsApp', () => {
    for (const s of SORTES) expect(JSON.stringify(textePush(s, {}))).not.toMatch(/WhatsApp/i)
  })
})
