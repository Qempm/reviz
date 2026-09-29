/**
 * Les opérateurs Mobile Money payables **dans l'application**.
 *
 * FedaPay propose deux façons de payer : sa page hébergée, où l'étudiant
 * choisit tout lui-même, et une demande envoyée directement au téléphone
 * (`POST /v1/{mode}`, « sans redirection »), que l'étudiant valide avec son
 * code secret. Le propriétaire a voulu que tout se passe dans Reviz : seuls
 * les modes de la seconde sorte sont donc proposés.
 *
 * Identifiants relevés dans la doc FedaPay (« Méthodes de paiement ») et le
 * SDK officiel. Wave, Orange et tout le Burkina Faso n'existent **que** sur
 * la page hébergée : ils ne figurent pas ici, et un étudiant de ces réseaux
 * ne se voit rien proposer plutôt qu'un bouton qui le ferait sortir.
 *
 * Porté tel quel dans `apps/mobile/lib/metier/operateurs.dart` : l'écran
 * doit savoir quoi proposer sans aller-retour, mais c'est le serveur qui
 * décide.
 */

export const OPERATEURS = ['mtn', 'moov', 'celtiis', 'togocel', 'free'] as const
export type Operateur = (typeof OPERATEURS)[number]

/** Le mode FedaPay de chaque opérateur, pays par pays. */
const MODES: Record<string, Partial<Record<Operateur, string>>> = {
  BJ: { mtn: 'mtn_open', moov: 'moov', celtiis: 'sbin' },
  TG: { moov: 'moov_tg', togocel: 'togocel' },
  CI: { mtn: 'mtn_ci' },
  SN: { free: 'free_sn' },
}

/**
 * Le seul mode de l'environnement de test depuis le 7 novembre 2025 : les
 * numéros 64000001 et 66000001 y réussissent, tous les autres échouent.
 */
export const MODE_TEST = 'momo_test'

/** Les opérateurs proposés pour un pays, dans l'ordre d'affichage. */
export function operateursDuPays(codePays: string): Operateur[] {
  const modes = MODES[codePays.toUpperCase()] ?? {}
  return OPERATEURS.filter((o) => modes[o] !== undefined)
}

/**
 * Le mode FedaPay à appeler, ou `null` si cet opérateur n'est pas payable
 * dans l'application pour ce pays.
 *
 * En test, le mode est toujours `momo_test` — mais seulement pour une
 * combinaison qui existerait en production : un essai doit refuser ce que la
 * production refuserait.
 */
export function modeFedaPay(
  operateur: string,
  codePays: string,
  sandbox: boolean,
): string | null {
  const mode = MODES[codePays.toUpperCase()]?.[operateur as Operateur]
  if (!mode) return null
  return sandbox ? MODE_TEST : mode
}
