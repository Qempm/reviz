import { createClient } from '@supabase/supabase-js'

/**
 * Ce que la page d'accueil publique dit de l'offre : les packs et la FAQ.
 *
 * Les prix viennent de la table `packs` — la même que lit l'application —,
 * relus toutes les heures (`revalidate` de la page). Si la base ne répond
 * pas au moment du rendu, la grille de repli ci-dessous, identique à la
 * graine (`20260908130000_seed.sql`), évite une page sans prix.
 */

export interface PackPublic {
  code: string
  label: string
  description: string
  prixFcfa: number
  jours: number
  corrections: number
  /** `null` : toutes les matières. */
  matieres: number | null
}

export const PACKS_DE_REPLI: PackPublic[] = [
  {
    code: 'decouverte',
    label: 'Découverte',
    description: 'Essaie Reviz sur une matière pendant 3 jours.',
    prixFcfa: 0,
    jours: 3,
    corrections: 1,
    matieres: 1,
  },
  {
    code: 'controle',
    label: 'Contrôle',
    description: 'Une semaine pour préparer un contrôle continu sur deux matières.',
    prixFcfa: 500,
    jours: 7,
    corrections: 3,
    matieres: 2,
  },
  {
    code: 'partiel',
    label: 'Partiel',
    description: 'Un mois sur cinq matières, pour la période des partiels.',
    prixFcfa: 1500,
    jours: 30,
    corrections: 10,
    matieres: 5,
  },
  {
    code: 'rattrapage',
    label: 'Rattrapage',
    description: 'Un mois intensif sur toutes tes matières pour la session de rattrapage.',
    prixFcfa: 2000,
    jours: 30,
    corrections: 15,
    matieres: null,
  },
  {
    code: 'semestre',
    label: 'Semestre',
    description: 'Quatre mois, toutes tes matières, sans limite.',
    prixFcfa: 3500,
    jours: 120,
    corrections: 30,
    matieres: null,
  },
]

/** Le pack mis en avant : le meilleur rapport pour une période d'examens. */
export const PACK_CONSEILLE = 'partiel'

export async function chargerPacks(): Promise<PackPublic[]> {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const cle = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  if (!url || !cle) return PACKS_DE_REPLI
  try {
    const maintenant = new Date().toISOString()
    const { data, error } = await createClient(url, cle, {
      auth: { persistSession: false },
    })
      .from('packs')
      .select(
        'code, label, description, price_fcfa, duration_days, corrections_included, subjects_limit, active_from, active_to',
      )
      .lte('active_from', maintenant)
      .order('price_fcfa')
    if (error || !data || data.length === 0) return PACKS_DE_REPLI
    return data
      .filter((p) => !p.active_to || p.active_to > maintenant)
      .map((p) => ({
        code: p.code,
        label: p.label,
        description: p.description ?? '',
        prixFcfa: p.price_fcfa,
        jours: p.duration_days,
        corrections: p.corrections_included,
        matieres: p.subjects_limit,
      }))
  } catch {
    return PACKS_DE_REPLI
  }
}

/** « 1 500 F », avec l'espace fine insécable du français. */
export function prixLisible(fcfa: number): string {
  if (fcfa === 0) return 'Gratuit'
  return `${fcfa.toLocaleString('fr-FR').replace(/\s/g, ' ')} F`
}

export function dureeLisible(jours: number): string {
  if (jours % 30 === 0 && jours >= 30) {
    const mois = jours / 30
    return mois === 1 ? '1 mois' : `${mois} mois`
  }
  if (jours === 7) return '1 semaine'
  return `${jours} jours`
}

/**
 * La FAQ, l'argent en premier — comme l'écran d'aide de l'application
 * (`apps/mobile/lib/i18n/fr.dart`, `_Aide`), à jour de la 2.5.
 */
export const FAQ: Array<{ question: string; reponse: string }> = [
  {
    question: 'Est-ce que je serai prélevé chaque mois ?',
    reponse:
      'Non. Jamais. Tu paies un pack une fois en Mobile Money, il dure le nombre de jours annoncé, et il s’arrête. Aucun abonnement automatique, rien à résilier. À la fin, tes cours restent à toi et tu continues à réviser gratuitement.',
  },
  {
    question: 'En quoi c’est différent de ChatGPT ?',
    reponse:
      'ChatGPT ne connaît pas ton cours et corrige « dans l’absolu ». Reviz lit ton propre cours, en tire des QCM chapitre par chapitre, se souvient de tes erreurs, et corrige ta copie d’après ce que ton professeur a enseigné et le niveau de ton année.',
  },
  {
    question: 'C’est gratuit pour commencer ?',
    reponse:
      'Oui : le pack Découverte s’active en un appui, sans payer, pour essayer sur une matière pendant 3 jours avec une correction de copie. Réviser les cours déjà déposés reste gratuit, même sans pack.',
  },
  {
    question: 'Comment marche le parrainage ?',
    reponse:
      'Tu donnes ton code. Quand ton filleul paie un pack, 25 % du montant vont dans ton portefeuille, à chacun de ses paiements pendant douze mois. Le retrait part en Mobile Money dès 3 000 F.',
  },
  {
    question: 'Ça marche sans réseau ?',
    reponse:
      'Oui pour réviser : une série finie hors ligne est gardée sur ton téléphone et part toute seule quand la connexion revient, avec tes XP et ta série. Il faut du réseau pour déposer un cours ou faire corriger une copie.',
  },
  {
    question: 'Pourquoi l’application n’est pas sur le Play Store ?',
    reponse:
      'Elle y arrive. En attendant, elle s’installe depuis un fichier signé, publié sur notre page de téléchargement avec son empreinte, pour que tu puisses vérifier que c’est bien le nôtre.',
  },
  {
    question: 'Pourquoi vous demandez ma carte étudiante ?',
    reponse:
      'Pour qu’un compte corresponde à une personne : une carte ne vaut que pour un seul compte. Sans cela, quelqu’un pourrait ouvrir dix comptes et se parrainer lui-même.',
  },
]
