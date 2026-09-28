import { createHash } from 'node:crypto'
import type { StudentCardPayload } from '@/lib/ai/schemas'

/**
 * Vérification d'une carte étudiante — la décision, sans la base.
 *
 * **C'est la seule barrière « un compte par personne ».** Depuis que le
 * téléphone est facultatif et non vérifié (9 septembre 2026), rien d'autre
 * n'empêche une personne d'ouvrir dix comptes, de se parrainer elle-même et
 * d'encaisser 25 % de ses propres paiements. La règle métier 3 repose
 * entièrement sur l'unicité de l'empreinte calculée ici, tenue par l'index
 * `profiles_student_card_hash_idx`.
 *
 * D'où deux principes qui expliquent les choix ci-dessous :
 *
 *  1. **Échouer fermé.** Un doute produit `pending`, jamais `verified` : une
 *     vérification accordée à tort ne se détecte pas, un refus se réclame.
 *  2. **Ne rien décider sur une lecture floue.** Le modèle rend une
 *     confiance ; en dessous du seuil, on attend un humain plutôt que de
 *     signer.
 */

export type IssueVerification = 'verifiee' | 'a_revoir' | 'refusee'

export type MotifRefus =
  | 'illisible'
  | 'sans-numero'
  | 'carte-expiree'
  | 'deja-utilisee'

export type Verification =
  | {
      issue: 'verifiee'
      /** Empreinte à écrire dans `profiles.student_card_hash`. */
      empreinte: string
      /** Fin de validité à écrire dans `profiles.verified_until`. */
      valideJusqua: Date
      lecture: LectureCarte
    }
  | {
      issue: 'a_revoir'
      /** Pourquoi un humain doit regarder. */
      raison: string
      /** Calculée quand c'est possible : elle sert dès la revue. */
      empreinte: string | null
      lecture: LectureCarte
    }
  | { issue: 'refusee'; motif: MotifRefus; raison: string }

/** Ce que le modèle a lu, conservé pour les journaux et la revue humaine. */
export type LectureCarte = {
  nom: string | null
  universite: string | null
  faculte: string | null
  numero: string | null
  confiance: number
}

/**
 * En dessous, on ne signe pas.
 *
 * 0,7 et non 0,9 : une carte étudiante béninoise est souvent une photocopie
 * plastifiée, photographiée le soir. Exiger la quasi-certitude renverrait la
 * majorité des cartes légitimes en revue manuelle, qui n'existe pas encore.
 */
export const CONFIANCE_MINIMALE = 0.7

/** Un numéro plus court que cela ne distingue personne. */
export const LONGUEUR_NUMERO_MINIMALE = 4

/** Validité par défaut, à défaut de date sur la carte : une année scolaire. */
export const VALIDITE_PAR_DEFAUT_JOURS = 365

/**
 * Normalise un numéro d'étudiant.
 *
 * Deux photos de la même carte doivent donner la même chaîne : on enlève les
 * accents, les espaces, les tirets et la casse. « 21-A/0453 » et
 * « 21 a 0453 » deviennent tous deux « 21A0453 ».
 */
export function normaliserNumero(brut: string): string {
  return brut
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '')
}

/**
 * Empreinte d'une carte.
 *
 * **Le numéro d'étudiant seul**, et non le numéro plus l'université. C'est un
 * arbitrage, et il mérite d'être écrit :
 *
 *  * Ajouter l'université lue **sur la carte** rendrait l'empreinte instable :
 *    le modèle écrit tantôt « UAC », tantôt « Université d'Abomey-Calavi », et
 *    la même carte ouvrirait deux comptes.
 *  * Ajouter l'université **déclarée par l'étudiant** la rendrait
 *    contournable : il suffirait de déclarer une autre université au deuxième
 *    compte pour changer l'empreinte.
 *  * Le numéro seul peut, en théorie, collisionner entre deux universités.
 *    Une collision produit alors un refus « carte déjà utilisée » pour un
 *    étudiant légitime — désagréable, mais réclamable, et le message le dit.
 *
 * Entre un refus injuste qui se réclame et une vérification accordée à tort
 * qui ne se détecte pas, on prend le premier.
 *
 * Pas de poivre : cette colonne ne quitte jamais le serveur, et un poivre qui
 * changerait casserait silencieusement l'unicité de toutes les empreintes
 * déjà écrites — le contraire d'une barrière.
 */
export function empreinteCarte(numero: string): string | null {
  const normalise = normaliserNumero(numero)
  if (normalise.length < LONGUEUR_NUMERO_MINIMALE) return null

  // Le préfixe versionné permettra de changer de règle un jour sans confondre
  // les anciennes empreintes avec les nouvelles.
  return createHash('sha256').update(`carte:v1:${normalise}`).digest('hex')
}

/**
 * Le chemin déposé appartient-il bien à l'appelant ?
 *
 * Sans ce contrôle, un client pourrait faire vérifier la photo de carte
 * d'un autre étudiant et **s'attribuer son empreinte** : la barrière
 * « un compte par personne » se retournerait alors contre son propriétaire,
 * qui verrait sa propre carte refusée comme « déjà utilisée ».
 *
 * Écrit ici plutôt que dans `depot-carte.ts` pour être testable : ce fichier
 * ne dépend ni du réseau ni de `server-only`.
 */
export function cheminDeSonDossier(chemin: string, userId: string): boolean {
  // Un identifiant vide rendrait le préfixe « / », que n'importe quel chemin
  // absolu satisferait.
  if (userId.length === 0) return false

  // `..` et l'antislash : de quoi remonter d'un dossier, ou faire lire au
  // stockage un chemin qu'on n'a pas relu.
  if (chemin.includes('..') || chemin.includes('\\')) return false

  const reste = chemin.startsWith(`${userId}/`)
    ? chemin.slice(userId.length + 1)
    : null

  // Un fichier, pas un sous-dossier : le traitement lit le chemin tel quel,
  // et une arborescence n'apporterait rien qu'un angle mort.
  return reste !== null && reste.length > 0 && !reste.includes('/')
}

/** `AAAA-MM-JJ` → date, ou `null` si la chaîne ne dit rien d'utile. */
function lireDate(iso: string | null): Date | null {
  if (!iso) return null
  const d = new Date(`${iso}T00:00:00.000Z`)
  return Number.isNaN(d.getTime()) ? null : d
}

/**
 * Que faire de ce que le modèle a lu.
 *
 * `dejaUtilisee` vient de la base : l'empreinte existe déjà sur un autre
 * profil. On le passe en paramètre plutôt que de l'aller chercher, pour que
 * cette fonction reste testable — et parce que la course entre deux dépôts
 * simultanés se règle de toute façon par l'index unique, pas ici.
 */
export function deciderVerification(opts: {
  payload: StudentCardPayload
  now?: Date
}): Verification {
  const now = opts.now ?? new Date()
  const p = opts.payload

  if (!p.isReadable) {
    return {
      issue: 'refusee',
      motif: 'illisible',
      // Le motif du modèle quand il en donne un — il est plus précis que le
      // nôtre : « reflet sur le plastique » vaut mieux que « illisible ».
      raison:
        p.reason ??
        'On n’arrive pas à lire ta carte. Reprends la photo à plat, bien ' +
          'éclairée, sans reflet sur le plastique.',
    }
  }

  const lecture: LectureCarte = {
    nom: p.fullName,
    universite: p.university,
    faculte: p.faculty,
    numero: p.studentId,
    confiance: p.confidence,
  }

  const empreinte = p.studentId ? empreinteCarte(p.studentId) : null

  if (empreinte === null) {
    // Sans numéro exploitable, il n'y a pas d'empreinte — donc pas de
    // barrière. On ne vérifie pas : on demande une revue.
    return {
      issue: 'a_revoir',
      raison:
        'On ne lit pas ton numéro d’étudiant sur la photo. Vérifie qu’il est ' +
        'net et entièrement visible, ou attends qu’on regarde.',
      empreinte: null,
      lecture,
    }
  }

  const expiration = lireDate(p.expiresOn)

  if (expiration !== null && expiration <= now) {
    return {
      issue: 'refusee',
      motif: 'carte-expiree',
      raison:
        'Cette carte n’est plus valable. Dépose celle de l’année en cours.',
    }
  }

  if (p.confidence < CONFIANCE_MINIMALE) {
    return {
      issue: 'a_revoir',
      raison:
        'La photo est lisible mais pas assez nette pour valider tout seul. ' +
        'Reprends-la de plus près, ou attends qu’on regarde.',
      empreinte,
      lecture,
    }
  }

  return {
    issue: 'verifiee',
    empreinte,
    // La date de la carte quand elle en porte une, sinon une année scolaire.
    valideJusqua:
      expiration ??
      new Date(now.getTime() + VALIDITE_PAR_DEFAUT_JOURS * 86_400_000),
    lecture,
  }
}
