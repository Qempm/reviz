/**
 * Découper un cours en chapitres.
 *
 * C'est la première moitié de `ingest_course`, et la seule qui n'a pas besoin
 * du réseau — donc la seule qui se teste vraiment. Le découpage décide de tout
 * ce qui suit : un chapitre trop long fait tronquer le JSON du modèle, un
 * chapitre trop court produit des questions creuses, et un découpage qui
 * ignore les titres du document mélange deux sujets dans la même session de
 * QCM.
 *
 * Deux passes :
 *
 *  1. **Les titres du document**, s'il en a. Un polycopié béninois est
 *     structuré — « CHAPITRE II », « TITRE PREMIER », « Section 2 », « I. Les
 *     sources du droit ». Les reconnaître donne des chapitres qui veulent dire
 *     quelque chose, et des titres que l'étudiant reconnaît.
 *  2. **À défaut, la longueur.** On coupe sur des frontières de paragraphe,
 *     jamais au milieu d'une phrase.
 *
 * Aucun appel de modèle ici : demander à une IA de découper un document
 * coûterait un appel de plus par cours pour un résultat qu'une expression
 * régulière obtient.
 */

/** Ce qui sort du découpage, prêt pour la table `chapters`. */
export type Chapitre = {
  /** 1-indexé, comme la colonne `index` de `chapters`. */
  index: number
  title: string
  text: string
  /** Estimation, pour le suivi de coût et le choix du modèle. */
  tokenCount: number
}

/**
 * Taille visée pour un chapitre, en caractères.
 *
 * ~6 000 caractères font environ 1 800 jetons de français : assez pour une
 * question sérieuse, et loin des 8 000 jetons de sortie que `TASK_PARAMS`
 * accorde à la génération de QCM.
 */
export const CIBLE_CARACTERES = 6000

/** Au-delà, on coupe même sans frontière de paragraphe commode. */
export const MAX_CARACTERES = 9000

/**
 * En dessous, le **corps** d'un bloc n'a pas de quoi porter une question : on
 * le recolle au précédent.
 *
 * C'est bien le corps — titre exclu — qui compte, et non la longueur totale.
 * Un seuil sur le tout avalait des chapitres légitimes : un polycopié donne
 * volontiers deux paragraphes par chapitre, soit 250 caractères — court pour
 * un chapitre, largement suffisant pour trois questions. Ce qu'on veut
 * écarter, c'est le titre orphelin et la ligne égarée, pas le chapitre bref.
 */
export const MIN_CORPS = 120

/**
 * Plafond de chapitres par cours.
 *
 * Le plafond SQL est de 200 questions par cours ; à 4 questions par chapitre,
 * 50 chapitres les consomment déjà. Au-delà on ne découpe plus : le document
 * est probablement un recueil, pas un cours.
 */
export const MAX_CHAPITRES = 50

/**
 * Titres de cours, tels qu'on les rencontre dans un polycopié francophone.
 *
 * Volontairement exigeant sur la forme : une ligne courte, isolée, qui
 * commence par un mot de structure ou une numérotation. Un paragraphe qui
 * commence par « Section » au milieu d'une phrase ne passe pas, puisqu'il
 * n'est pas seul sur sa ligne.
 */
const TITRE = new RegExp(
  '^(?:' +
    // « CHAPITRE 2 », « Chapitre II — Les sources », « TITRE PREMIER »
    '(?:chapitre|titre|partie|livre|section|leçon|lecon|module|unité|unite)' +
    '\\s+(?:[0-9]{1,2}|[ivxlc]{1,7}|premier|première|premiere|deuxième|deuxieme|troisième|troisieme)\\b.*' +
    // « I. Les sources du droit », « 2) La coutume », « 3 - Le règlement »
    '|[0-9]{1,2}(?:\\.[0-9]{1,2})*\\s*[).\\-–—]\\s+\\S.*' +
    '|[ivxlc]{1,7}\\s*[).\\-–—]\\s+\\S.*' +
    ')$',
  'i',
)

/** Une ligne peut-elle être un titre ? */
function estTitre(ligne: string): boolean {
  const l = ligne.trim()
  // Un titre tient sur une ligne. Au-delà, c'est une phrase qui commence par
  // un numéro.
  if (l.length === 0 || l.length > 120) return false
  // Une ligne qui finit par un point-virgule ou une virgule continue.
  if (/[,;:]$/.test(l)) return false
  return TITRE.test(l)
}

/** Estimation grossière du nombre de jetons. */
export function estimerJetons(texte: string): number {
  // ~3,3 caractères par jeton en français, d'après les relevés de
  // docs/STACK-IA.md. Une estimation suffit : elle sert au suivi de coût et
  // au choix de découpage, pas à la facturation.
  return Math.ceil(texte.length / 3.3)
}

/** Normalise les blancs sans écraser la structure en paragraphes. */
export function normaliser(brut: string): string {
  return (
    brut
      // Les extracteurs de PDF rendent des retours chariot Windows et des
      // espaces insécables que le modèle n'a pas à voir.
      .replace(/\r\n?/g, '\n')
      .replace(/ /g, ' ')
      // Les ligatures des PDF : « ﬁn » devient illisible dans un QCM.
      .replace(/ﬁ/g, 'fi')
      .replace(/ﬂ/g, 'fl')
      // Trois retours ou plus ne disent rien de plus que deux.
      .replace(/\n{3,}/g, '\n\n')
      .replace(/[ \t]{2,}/g, ' ')
      .split('\n')
      .map((l) => l.trim())
      .join('\n')
      .trim()
  )
}

type Bloc = { titre: string | null; lignes: string[] }

/** Première passe : découper sur les titres du document. */
function blocsParTitres(lignes: string[]): Bloc[] {
  const blocs: Bloc[] = []
  let courant: Bloc = { titre: null, lignes: [] }

  for (const ligne of lignes) {
    if (estTitre(ligne)) {
      // Un titre ferme le bloc précédent, sauf s'il est vide — deux titres
      // qui se suivent (« CHAPITRE II » puis « Les sources ») forment un
      // seul en-tête.
      if (courant.titre !== null || courant.lignes.some((l) => l !== '')) {
        blocs.push(courant)
      }
      courant = { titre: ligne.trim(), lignes: [] }
      continue
    }
    courant.lignes.push(ligne)
  }

  if (courant.titre !== null || courant.lignes.some((l) => l !== '')) {
    blocs.push(courant)
  }

  return blocs
}

/**
 * Coupe un texte trop long en morceaux, sur des frontières de paragraphe.
 *
 * Et à défaut de paragraphe, sur une fin de phrase : couper au milieu d'une
 * phrase donne une question dont l'énoncé est amputé.
 */
function couper(texte: string): string[] {
  if (texte.length <= MAX_CARACTERES) return [texte]

  const morceaux: string[] = []
  let reste = texte

  while (reste.length > MAX_CARACTERES) {
    const fenetre = reste.slice(0, MAX_CARACTERES)

    // Une frontière de paragraphe, le plus tard possible mais pas trop tôt.
    let coupe = fenetre.lastIndexOf('\n\n')
    if (coupe < CIBLE_CARACTERES / 2) {
      // Une fin de phrase.
      const phrase = fenetre.search(/\.[^.]*$/)
      coupe = phrase > CIBLE_CARACTERES / 2 ? phrase + 1 : MAX_CARACTERES
    }

    morceaux.push(reste.slice(0, coupe).trim())
    reste = reste.slice(coupe).trim()
  }

  if (reste.length > 0) morceaux.push(reste)
  return morceaux
}

/**
 * Découpe un cours en chapitres.
 *
 * `titreDuCours` sert à nommer les chapitres que le document n'a pas nommés :
 * « Droit constitutionnel — partie 2 » vaut mieux que « Chapitre 2 » tout
 * court dans une liste où l'étudiant a trois cours.
 */
export function decouperEnChapitres(
  brut: string,
  titreDuCours: string,
): Chapitre[] {
  const texte = normaliser(brut)
  if (texte.length === 0) return []

  const blocs = blocsParTitres(texte.split('\n'))

  // Aucun titre reconnu : un seul bloc, que la longueur découpera.
  const morceaux: Array<{ titre: string | null; texte: string }> = []

  for (const bloc of blocs) {
    const corps = bloc.lignes.join('\n').trim()
    const entier = bloc.titre ? `${bloc.titre}\n\n${corps}` : corps
    if (entier.trim().length === 0) continue

    for (const part of couper(entier)) {
      morceaux.push({ titre: bloc.titre, texte: part })
    }
  }

  // Recoller les miettes : un titre orphelin, ou une ligne égarée, appartient
  // au chapitre d'à côté plutôt qu'à un chapitre fantôme.
  const recolles: Array<{ titre: string | null; texte: string }> = []
  for (const m of morceaux) {
    const precedent = recolles[recolles.length - 1]
    const corps = m.titre ? m.texte.slice(m.titre.length).trim() : m.texte

    if (
      precedent &&
      corps.length < MIN_CORPS &&
      precedent.texte.length + m.texte.length <= MAX_CARACTERES
    ) {
      precedent.texte = `${precedent.texte}\n\n${m.texte}`
      continue
    }
    recolles.push({ ...m })
  }

  // La couverture n'est pas un chapitre.
  //
  // Un polycopié commence par son intitulé — « DROIT CONSTITUTIONNEL —
  // LICENCE 1 » — avant le premier « CHAPITRE I ». Ce bloc sans titre en tête
  // formait un chapitre fantôme, avec une question par-dessus. On le replie
  // sur le premier vrai chapitre : il lui donne son contexte (la matière, le
  // niveau), ce qui aide le modèle plutôt que de le distraire.
  if (
    recolles.length > 1 &&
    recolles[0].titre === null &&
    recolles[1].titre !== null &&
    recolles[0].texte.length + recolles[1].texte.length <= MAX_CARACTERES
  ) {
    recolles[1].texte = `${recolles[0].texte}\n\n${recolles[1].texte}`
    recolles.shift()
  }

  return recolles.slice(0, MAX_CHAPITRES).map((m, i) => ({
    index: i + 1,
    title: nommer(m.titre, titreDuCours, i, recolles.length),
    text: m.texte,
    tokenCount: estimerJetons(m.texte),
  }))
}

/** Le titre d'un chapitre, quand le document n'en donne pas. */
function nommer(
  titre: string | null,
  titreDuCours: string,
  i: number,
  total: number,
): string {
  if (titre) {
    // Une majuscule intégrale — « CHAPITRE II » — se lit mal dans une liste.
    const propre = titre === titre.toUpperCase() ? enCapitales(titre) : titre
    return propre.slice(0, 200)
  }

  const base = titreDuCours.trim() || 'Cours'
  return (total === 1 ? base : `${base} — partie ${i + 1}`).slice(0, 200)
}

/** « CHAPITRE II — LES SOURCES » → « Chapitre II — Les sources ». */
function enCapitales(titre: string): string {
  return titre
    .toLowerCase()
    .replace(/(^|[\s—–\-().])([a-zà-ÿ])/g, (_, avant, lettre: string) =>
      avant + lettre.toUpperCase(),
    )
}
