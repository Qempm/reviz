/**
 * Numéros de téléphone d'Afrique de l'Ouest francophone.
 *
 * Reviz vise le Bénin, le Togo, la Côte d'Ivoire, le Sénégal et le Burkina
 * (CLAUDE.md). L'étudiant saisit son numéro comme il le dit à l'oral —
 * « 97 12 34 56 » — et non au format international. C'est à nous de
 * normaliser, pas à lui d'apprendre le E.164.
 *
 * Fonctions pures : la normalisation sert au client pour l'affichage et au
 * serveur pour l'unicité, elle doit donner exactement le même résultat des
 * deux côtés.
 */

export type Pays = {
  code: string
  /** Indicatif international, sans le +. */
  indicatif: string
  nom: string
  /** Longueurs admises pour le numéro national, sans indicatif. */
  longueurs: number[]
  /** Exemple affiché en aide de saisie. */
  exemple: string
  emoji: string
}

/** Ordre d'affichage : le Bénin d'abord, c'est le marché de départ. */
export const PAYS: Pays[] = [
  { code: 'BJ', indicatif: '229', nom: 'Bénin', longueurs: [8, 10], exemple: '97 12 34 56', emoji: '🇧🇯' },
  { code: 'TG', indicatif: '228', nom: 'Togo', longueurs: [8], exemple: '90 12 34 56', emoji: '🇹🇬' },
  { code: 'CI', indicatif: '225', nom: "Côte d'Ivoire", longueurs: [10], exemple: '07 12 34 56 78', emoji: '🇨🇮' },
  { code: 'SN', indicatif: '221', nom: 'Sénégal', longueurs: [9], exemple: '77 123 45 67', emoji: '🇸🇳' },
  { code: 'BF', indicatif: '226', nom: 'Burkina Faso', longueurs: [8], exemple: '70 12 34 56', emoji: '🇧🇫' },
]

export const PAYS_PAR_DEFAUT = PAYS[0]

export function paysParCode(code: string): Pays | undefined {
  return PAYS.find((p) => p.code === code)
}

export function paysParIndicatif(indicatif: string): Pays | undefined {
  return PAYS.find((p) => p.indicatif === indicatif)
}

/** Ne garde que les chiffres. */
function chiffres(saisie: string): string {
  return saisie.replace(/\D/g, '')
}

export type ResultatNormalisation =
  | { ok: true; e164: string; pays: Pays; national: string }
  | { ok: false; raison: 'vide' | 'pays_inconnu' | 'longueur' }

/**
 * Met un numéro au format E.164 (`+22997123456`), celui qu'attend Supabase.
 *
 * Accepte les formes réellement tapées par les étudiants : avec espaces,
 * tirets ou points, avec ou sans indicatif, avec `+`, avec `00`, ou avec un
 * zéro initial hérité des habitudes françaises.
 */
export function normaliserTelephone(
  saisie: string,
  paysParDefaut: Pays = PAYS_PAR_DEFAUT,
): ResultatNormalisation {
  let n = chiffres(saisie)
  if (n.length === 0) return { ok: false, raison: 'vide' }

  // `00229…` est la forme composée depuis un fixe.
  if (n.startsWith('00')) n = n.slice(2)

  // Le numéro porte-t-il déjà un indicatif connu ?
  const avecIndicatif = PAYS.find((p) => n.startsWith(p.indicatif))

  if (avecIndicatif) {
    const national = n.slice(avecIndicatif.indicatif.length)
    if (!avecIndicatif.longueurs.includes(national.length)) {
      return { ok: false, raison: 'longueur' }
    }
    return {
      ok: true,
      e164: `+${avecIndicatif.indicatif}${national}`,
      pays: avecIndicatif,
      national,
    }
  }

  // Sinon on applique le pays choisi dans l'interface.
  // Un zéro initial est un réflexe hérité : on le retire s'il rend la
  // longueur valide, sans le retirer aveuglément.
  let national = n
  if (
    national.startsWith('0') &&
    !paysParDefaut.longueurs.includes(national.length) &&
    paysParDefaut.longueurs.includes(national.length - 1)
  ) {
    national = national.slice(1)
  }

  if (!paysParDefaut.longueurs.includes(national.length)) {
    return { ok: false, raison: 'longueur' }
  }

  return {
    ok: true,
    e164: `+${paysParDefaut.indicatif}${national}`,
    pays: paysParDefaut,
    national,
  }
}

/**
 * Découpe un numéro national pour l'affichage, selon l'usage de chaque pays.
 *
 * Le découpage doit correspondre à `Pays.exemple` : un formatage qui
 * s'écarterait de l'aide à la saisie affichée juste au-dessus ferait douter
 * l'étudiant de ce qu'il a tapé.
 */
export function formaterNational(national: string, pays: Pays): string {
  const n = chiffres(national)
  if (n.length === 0) return ''

  // Sénégal : 9 chiffres en 2-3-2-2, soit « 77 123 45 67 ».
  if (pays.code === 'SN') {
    const groupes = [n.slice(0, 2), n.slice(2, 5), n.slice(5, 7), n.slice(7, 9)]
    return groupes.filter(Boolean).join(' ')
  }

  // Partout ailleurs : groupes de deux.
  return (n.match(/.{1,2}/g) ?? []).join(' ')
}

/** Masque un numéro pour l'affichage : `+229 97 •• •• 56`. */
export function masquerTelephone(e164: string): string {
  const pays = PAYS.find((p) => e164.startsWith(`+${p.indicatif}`))
  if (!pays) return e164

  const national = e164.slice(pays.indicatif.length + 1)
  if (national.length < 4) return e164

  const debut = national.slice(0, 2)
  const fin = national.slice(-2)
  const milieu = '•'.repeat(Math.max(0, national.length - 4))

  return `+${pays.indicatif} ${debut} ${milieu} ${fin}`.replace(/\s+/g, ' ')
}
