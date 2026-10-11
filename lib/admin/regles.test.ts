import { describe, expect, it } from 'vitest'
import {
  appareilDepuis,
  estAdmin,
  listeAdmins,
  masquerTelephone,
  sourceDepuis,
  telechargementsGithub,
} from './regles'

describe('accès administrateur', () => {
  it('reconnaît une adresse de la liste, sans tenir compte de la casse', () => {
    expect(estAdmin('Proprio@Exemple.com', 'proprio@exemple.com, autre@exemple.com')).toBe(true)
    expect(estAdmin('intrus@exemple.com', 'proprio@exemple.com')).toBe(false)
  })

  it('ferme tout quand la liste est vide ou absente', () => {
    expect(estAdmin('proprio@exemple.com', '')).toBe(false)
    expect(estAdmin('proprio@exemple.com', undefined)).toBe(false)
    expect(estAdmin(null, 'proprio@exemple.com')).toBe(false)
  })

  it('accepte virgules, points-virgules et espaces comme séparateurs', () => {
    expect([...listeAdmins(' a@x.fr ; b@x.fr  c@x.fr,')]).toEqual(['a@x.fr', 'b@x.fr', 'c@x.fr'])
  })
})

describe('masquerTelephone', () => {
  it('garde deux chiffres de chaque côté', () => {
    expect(masquerTelephone('97123412')).toBe('97 •• •• 12')
    expect(masquerTelephone('+229 97 12 34 12')).toBe('22 •• •• 12')
  })

  it('ne montre rien d’un numéro trop court ou absent', () => {
    expect(masquerTelephone('123')).toBe('••')
    expect(masquerTelephone(null)).toBe('—')
  })
})

describe('telechargementsGithub', () => {
  it('somme les APK de toutes les releases, et ceux de la dernière', () => {
    const r = telechargementsGithub([
      { tag_name: 'v2.8.3', assets: [{ name: 'reviz-2.8.3.apk', download_count: 40 }, { name: 'notes.txt', download_count: 900 }] },
      { tag_name: 'v2.8.2', assets: [{ name: 'reviz-2.8.2.APK', download_count: 25 }] },
    ])
    expect(r).toEqual({ total: 65, derniere: 40, version: 'v2.8.3' })
  })

  it('rend zéro sur une réponse inattendue', () => {
    expect(telechargementsGithub({ message: 'API rate limit exceeded' })).toEqual({ total: 0, derniere: 0, version: null })
  })
})

describe('appareil et source', () => {
  it('reconnaît Android, iPhone et ordinateur', () => {
    expect(appareilDepuis('Mozilla/5.0 (Linux; Android 13; SM-A145F)')).toBe('android')
    expect(appareilDepuis('Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)')).toBe('ios')
    expect(appareilDepuis('Mozilla/5.0 (Windows NT 10.0; Win64; x64)')).toBe('ordinateur')
    expect(appareilDepuis('')).toBe('autre')
  })

  it('ne garde que les sources connues', () => {
    expect(sourceDepuis('accueil')).toBe('accueil')
    expect(sourceDepuis('app')).toBe('app')
    expect(sourceDepuis('<script>')).toBe('autre')
  })
})
