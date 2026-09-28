/**
 * Les avatars que l'application accepte.
 *
 * CLAUDE.md prévoit 24 PNG dans `public/avatars/`. Ils n'existent pas, et le
 * dossier non plus : l'écran web construisait `/avatars/${avatar_key}.png` et
 * récoltait des 404. En attendant, un avatar est une **initiale sur un fond
 * tiré de la palette du design system** — cela ne demande aucun asset, et
 * donne quelque chose à choisir dès maintenant.
 *
 * Les clés sont stables : le jour où les images arrivent, `ton-03` désigne un
 * fichier au lieu d'une couleur, sans migration ni écran à réécrire.
 *
 * La liste est ici et non dans la route, pour une raison : `avatar_key` est
 * une colonne `text` libre, et la route acceptait **n'importe quelle chaîne de
 * cent caractères**. Une liste blanche est le seul moyen de garantir que ce
 * que lit un écran est bien un avatar.
 */

export const CLES_AVATAR = [
  'ton-01',
  'ton-02',
  'ton-03',
  'ton-04',
  'ton-05',
  'ton-06',
  'ton-07',
  'ton-08',
  'ton-09',
  'ton-10',
  'ton-11',
  'ton-12',
] as const

export type CleAvatar = (typeof CLES_AVATAR)[number]

export function estCleAvatar(valeur: unknown): valeur is CleAvatar {
  return (
    typeof valeur === 'string' && (CLES_AVATAR as readonly string[]).includes(valeur)
  )
}
