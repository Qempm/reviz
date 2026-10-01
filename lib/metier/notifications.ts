/**
 * Ce qu'une notification dit, et où elle mène.
 *
 * Les lignes de `notifications` sont écrites par des déclencheurs SQL
 * (`20261001120000_notifications.sql`) avec une sorte (`kind`) et quelques
 * données ; le texte se rend ensuite, deux fois :
 *
 *  - ici, pour le push (`lib/notifications/envoyer.ts`) ;
 *  - dans l'application, pour le centre de notifications
 *    (`apps/mobile/lib/metier/notifications.dart`, textes dans `fr.dart`).
 *
 * C'est une duplication voulue : l'application doit afficher son centre sans
 * aller-retour, et hors ligne. Les deux rendus sont tenus ensemble par un
 * même fichier de cas, `notifications.cas.json`, que les deux suites de
 * tests vérifient.
 */

export const SORTES = [
  'cours_pret',
  'cours_echoue',
  'correction_prete',
  'correction_illisible',
  'correction_echouee',
  'paiement_reussi',
  'paiement_echoue',
  'commission_recue',
  'retrait_paye',
  'retrait_refuse',
  'carte_verifiee',
  'carte_refusee',
  'ligue_cloturee',
] as const

export type Sorte = (typeof SORTES)[number]

export type Categorie = 'cours' | 'argent' | 'compte' | 'ligue'

export const CATEGORIES: readonly Categorie[] = ['cours', 'argent', 'compte', 'ligue']

export const CATEGORIE: Record<Sorte, Categorie> = {
  cours_pret: 'cours',
  cours_echoue: 'cours',
  correction_prete: 'cours',
  correction_illisible: 'cours',
  correction_echouee: 'cours',
  paiement_reussi: 'argent',
  paiement_echoue: 'argent',
  commission_recue: 'argent',
  retrait_paye: 'argent',
  retrait_refuse: 'argent',
  carte_verifiee: 'compte',
  carte_refusee: 'compte',
  ligue_cloturee: 'ligue',
}

export function estSorte(s: string): s is Sorte {
  return (SORTES as readonly string[]).includes(s)
}

export type Donnees = Record<string, unknown>

const PACKS: Record<string, string> = {
  decouverte: 'Découverte',
  controle: 'Contrôle',
  partiel: 'Partiel',
  rattrapage: 'Rattrapage',
  semestre: 'Semestre',
}

const DIVISIONS = ['Bronze', 'Argent', 'Or', 'Saphir', 'Rubis', 'Diamant']

function texte(v: unknown): string | null {
  return typeof v === 'string' && v.trim().length > 0 ? v.trim() : null
}

function nombre(v: unknown): number | null {
  const n = typeof v === 'string' ? Number(v) : v
  return typeof n === 'number' && Number.isFinite(n) ? n : null
}

/** « 1 500 », espace fine insécable ; « 27,5 » avec la virgule française. */
function lisible(n: number): string {
  return n.toLocaleString('fr-FR', { maximumFractionDigits: 2 }).replace(/\s/g, ' ')
}

function rang(r: number): string {
  return r === 1 ? '1re' : `${r}e`
}

/** Le titre et le corps d'une notification, en français. */
export function textePush(kind: Sorte, data: Donnees = {}): { titre: string; corps: string } {
  const titre = texte(data.titre)
  const montant = nombre(data.montant)
  const pack = PACKS[String(data.pack ?? '')] ?? null

  switch (kind) {
    case 'cours_pret':
      return {
        titre: 'Ton cours est prêt',
        corps: titre
          ? `« ${titre} » : tes QCM et tes fiches t’attendent.`
          : 'Tes QCM et tes fiches t’attendent.',
      }
    case 'cours_echoue':
      return {
        titre: 'Ton cours n’a pas pu être préparé',
        corps: titre
          ? `« ${titre} » : dépose-le à nouveau, de préférence en PDF.`
          : 'Dépose-le à nouveau, de préférence en PDF.',
      }
    case 'correction_prete': {
      const note = nombre(data.note)
      const bareme = nombre(data.bareme)
      return {
        titre: 'Ta copie est corrigée',
        corps:
          note !== null && bareme !== null
            ? `Ta note : ${lisible(note)} / ${lisible(bareme)}. Le détail t’attend.`
            : 'Ta note et le détail du barème t’attendent.',
      }
    }
    case 'correction_illisible':
      return {
        titre: 'Ta copie est illisible',
        corps: 'Reprends la photo à plat, bien éclairée. Cette correction ne t’a rien coûté.',
      }
    case 'correction_echouee':
      return {
        titre: 'La correction n’a pas abouti',
        corps: 'Un souci de notre côté. Réessaie dans un moment.',
      }
    case 'paiement_reussi':
      return {
        titre: 'Paiement confirmé',
        corps: pack ? `Ton pack ${pack} est actif. Bonne révision !` : 'Ton pack est actif. Bonne révision !',
      }
    case 'paiement_echoue':
      return {
        titre: 'Le paiement n’est pas passé',
        corps: 'Aucun montant n’a été prélevé. Tu peux réessayer quand tu veux.',
      }
    case 'commission_recue':
      return {
        titre: montant !== null ? `+${lisible(montant)} F de commission` : 'Nouvelle commission',
        corps: 'Un camarade que tu as invité vient de payer son pack.',
      }
    case 'retrait_paye':
      return {
        titre: 'Ton retrait est parti',
        corps:
          montant !== null
            ? `${lisible(montant)} F envoyés sur ton Mobile Money.`
            : 'L’argent est envoyé sur ton Mobile Money.',
      }
    case 'retrait_refuse': {
      const motif = texte(data.motif)
      return {
        titre: 'Ton retrait n’a pas abouti',
        corps: motif ? `${motif} Écris-nous depuis l’aide.` : 'Écris-nous depuis l’aide, on regarde avec toi.',
      }
    }
    case 'carte_verifiee':
      return {
        titre: 'Ta carte étudiante est validée',
        corps: 'Ton compte est vérifié : le parrainage est ouvert.',
      }
    case 'carte_refusee':
      return {
        titre: 'Ta carte n’a pas pu être validée',
        corps: 'Reprends la photo, à plat et bien lisible.',
      }
    case 'ligue_cloturee': {
      const division = Math.min(6, Math.max(1, nombre(data.division) ?? 1))
      const nom = `Ligue ${DIVISIONS[division - 1]}`
      const r = nombre(data.rang)
      switch (data.issue) {
        case 'monte':
          return {
            titre: `Tu montes en ${nom} !`,
            corps: r !== null ? `${rang(r)} de ton groupe cette semaine. Bravo.` : 'Belle semaine. Bravo.',
          }
        case 'descend':
          return {
            titre: `Tu redescends en ${nom}`,
            corps: 'Une bonne semaine suffit pour remonter.',
          }
        default:
          return {
            titre: `Tu restes en ${nom}`,
            corps: 'Nouvelle semaine, nouveau classement.',
          }
      }
    }
  }
}

/** L'écran de l'application que la notification ouvre (`routage.dart`). */
export function lienDe(kind: Sorte, referenceId: string | null): string {
  switch (kind) {
    case 'cours_pret':
      return referenceId ? `/cours/${referenceId}` : '/reviser'
    case 'cours_echoue':
      return '/reviser'
    case 'correction_prete':
    case 'correction_illisible':
    case 'correction_echouee':
      return referenceId ? `/corrections/${referenceId}` : '/corriger'
    case 'paiement_reussi':
      return '/'
    case 'paiement_echoue':
      return '/boutique'
    case 'commission_recue':
    case 'retrait_paye':
    case 'retrait_refuse':
      return '/gains'
    case 'carte_verifiee':
    case 'carte_refusee':
      return '/profil/carte-etudiante'
    case 'ligue_cloturee':
      return '/ligue'
  }
}

/** Préférences de push : une catégorie absente vaut « oui ». */
export function pushAutorise(prefs: unknown, kind: Sorte): boolean {
  if (!prefs || typeof prefs !== 'object') return true
  return (prefs as Record<string, unknown>)[CATEGORIE[kind]] !== false
}
