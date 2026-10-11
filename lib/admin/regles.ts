/**
 * L'espace administrateur : les règles, sans base ni réseau.
 *
 * `/admin` est réservé au propriétaire. L'accès se décide sur l'e-mail du
 * compte connecté, comparé à `ADMIN_EMAILS` (variable serveur, adresses
 * séparées par des virgules). Ni rôle en base ni drapeau sur le profil : une
 * variable d'environnement se change sur Vercel sans migration, et ne peut
 * pas être écrite par un client.
 */

/** Les adresses autorisées, en minuscules, sans espaces ni doublons. */
export function listeAdmins(valeur: string | undefined | null): Set<string> {
  return new Set(
    (valeur ?? '')
      .split(/[,;\s]+/)
      .map((e) => e.trim().toLowerCase())
      .filter((e) => e.includes('@')),
  )
}

/**
 * Cet e-mail ouvre-t-il l'administration ? Une liste vide ferme tout :
 * oublier la variable ne doit pas ouvrir la porte.
 */
export function estAdmin(email: string | undefined | null, liste: string | undefined | null): boolean {
  if (!email) return false
  const admins = listeAdmins(liste)
  return admins.size > 0 && admins.has(email.trim().toLowerCase())
}

/**
 * Un numéro Mobile Money lisible sans être recopiable : les deux premiers
 * et les deux derniers chiffres. « 97123412 » → « 97 •• •• 12 ».
 */
export function masquerTelephone(numero: string | null | undefined): string {
  const chiffres = (numero ?? '').replace(/\D/g, '')
  if (chiffres.length < 6) return chiffres ? '••' : '—'
  return `${chiffres.slice(0, 2)} •• •• ${chiffres.slice(-2)}`
}

/** Une release GitHub, réduite à ce qui compte ici. */
export interface ReleaseGithub {
  tag_name?: string
  assets?: Array<{ name?: string; download_count?: number }>
}

/**
 * Les téléchargements de l'APK selon GitHub : la somme des compteurs des
 * fichiers `.apk` de toutes les releases, et ceux de la plus récente.
 */
export function telechargementsGithub(releases: unknown): { total: number; derniere: number; version: string | null } {
  if (!Array.isArray(releases)) return { total: 0, derniere: 0, version: null }
  const apk = (r: ReleaseGithub) =>
    (r.assets ?? [])
      .filter((a) => (a.name ?? '').toLowerCase().endsWith('.apk'))
      .reduce((s, a) => s + (Number.isFinite(a.download_count) ? Number(a.download_count) : 0), 0)
  const liste = releases as ReleaseGithub[]
  return {
    total: liste.reduce((s, r) => s + apk(r), 0),
    derniere: liste.length > 0 ? apk(liste[0]) : 0,
    version: liste[0]?.tag_name ?? null,
  }
}

export type Appareil = 'android' | 'ios' | 'ordinateur' | 'autre'

/** La famille d'appareil d'après le navigateur. Rien de plus n'est gardé. */
export function appareilDepuis(userAgent: string | null | undefined): Appareil {
  const ua = (userAgent ?? '').toLowerCase()
  if (!ua) return 'autre'
  if (ua.includes('android')) return 'android'
  if (/iphone|ipad|ipod/.test(ua)) return 'ios'
  if (/windows|macintosh|linux|cros/.test(ua)) return 'ordinateur'
  return 'autre'
}

export type SourceTelechargement = 'accueil' | 'app' | 'autre'

export function sourceDepuis(valeur: string | null | undefined): SourceTelechargement {
  return valeur === 'accueil' || valeur === 'app' ? valeur : 'autre'
}
