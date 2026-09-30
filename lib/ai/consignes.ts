/**
 * La consigne de correction, calibrée sur le cours et le niveau.
 *
 * Le défaut d'un assistant généraliste, et la raison d'être de Reviz : il
 * corrige « dans l'absolu ». Il sanctionne une notion que le professeur n'a
 * jamais enseignée, attend d'un L1 la rigueur d'un M2, et oublie d'une copie
 * à l'autre ce que l'étudiant rate toujours. Ici, la consigne porte :
 *
 *  - la matière, l'année, la filière, l'université, le type d'épreuve ;
 *  - des extraits de **son** cours, chapitre par chapitre, numérotés ;
 *  - les chapitres où ses réponses aux QCM sont faibles ;
 *  - ce que ses dernières corrections lui demandaient de retravailler.
 *
 * Fonction pure : testée sans appel au modèle (`consignes.test.ts`).
 */

import type { TYPES_EPREUVE } from '@/lib/metier/corrections-types'

export type TypeEpreuve = (typeof TYPES_EPREUVE)[number]

export interface ChapitreCours {
  index: number
  titre: string
  texte: string
}

export interface ContexteCorrection {
  matiere?: string | null
  coursTitre?: string | null
  annee?: number | null
  filiere?: string | null
  universite?: string | null
  typeEpreuve?: TypeEpreuve | null
  /** Le barème demandé ; 20 par défaut. */
  bareme?: number | null
  chapitres?: ChapitreCours[]
  /** Titres des chapitres où l'étudiant répond mal aux QCM. */
  chapitresFaibles?: string[]
  /** Ce que ses dernières corrections de ce cours lui demandaient. */
  precedentes?: Array<{ note: number; sur: number; aRetravailler: string[] }>
}

/** Place laissée aux extraits du cours dans la consigne, en caractères. */
export const BUDGET_EXTRAITS = 14_000

const NOMS_EPREUVE: Record<TypeEpreuve, string> = {
  devoir: 'un devoir à la maison',
  interrogation: 'une interrogation écrite',
  partiel: 'un partiel',
  examen: 'un examen de fin de semestre',
  td: 'un exercice de travaux dirigés',
}

function niveau(annee: number): string {
  if (annee <= 3) return `L${annee} (licence, ${annee === 1 ? '1re' : `${annee}e`} année)`
  return `M${annee - 3} (master, ${annee}e année d'études)`
}

/**
 * Les extraits du cours, répartis équitablement entre les chapitres et
 * tenus dans le budget : un cours de trente chapitres ne doit pas faire
 * exploser la consigne, ni un chapitre fleuve avaler toute la place.
 */
export function extraitsDuCours(
  chapitres: ChapitreCours[],
  budget: number = BUDGET_EXTRAITS,
): string {
  if (chapitres.length === 0) return ''
  const parChapitre = Math.max(200, Math.floor(budget / chapitres.length))
  const blocs: string[] = []
  let reste = budget
  for (const c of [...chapitres].sort((a, b) => a.index - b.index)) {
    if (reste <= 0) break
    const place = Math.min(parChapitre, reste)
    const texte = c.texte.replace(/\s+/g, ' ').trim()
    const extrait = texte.length > place ? `${texte.slice(0, place).trimEnd()}…` : texte
    blocs.push(`[Chapitre ${c.index}] ${c.titre}\n${extrait}`)
    reste -= extrait.length
  }
  return blocs.join('\n\n')
}

export function consigneCorrection(c: ContexteCorrection): string {
  const bareme = c.bareme && c.bareme > 0 ? c.bareme : 20
  const situation: string[] = []
  if (c.matiere) situation.push(`Matière : ${c.matiere}.`)
  if (c.coursTitre) situation.push(`Cours : « ${c.coursTitre} ».`)
  if (c.annee) situation.push(`Niveau de l'étudiant : ${niveau(c.annee)}.`)
  if (c.filiere) situation.push(`Filière : ${c.filiere}.`)
  if (c.universite) situation.push(`Université : ${c.universite}.`)
  if (c.typeEpreuve) situation.push(`Il s'agit d'${NOMS_EPREUVE[c.typeEpreuve]}.`)

  const extraits = extraitsDuCours(c.chapitres ?? [])
  const faibles = (c.chapitresFaibles ?? []).filter(Boolean)
  const precedentes = (c.precedentes ?? []).filter((p) => p.sur > 0)

  const parties = [
    `Tu es un professeur d'université d'Afrique francophone qui corrige la copie d'un de tes étudiants.`,
    situation.length ? `\n${situation.join('\n')}` : '',
    `
Les images sont étiquetées : « Page N de la copie », et « Sujet » s'il y en a un.

Si tu n'arrives pas à lire la copie — photo floue, trop sombre, cadrage qui
coupe le texte, page blanche — ne devine pas de note. Réponds :
{"isReadable": false, "reason": "<ce que l'étudiant doit corriger, en une phrase, en le tutoyant>"}`,
    extraits
      ? `
Voici le cours que l'étudiant a reçu, par extraits numérotés. **Juge la copie
par rapport à ce cours** : attends ce qui y est enseigné, avec les mots et les
méthodes du cours ; ne sanctionne pas l'absence d'une notion qui n'y figure
pas.

---
${extraits}
---`
      : '',
    faibles.length
      ? `
Aux questions de révision, l'étudiant se trompe souvent sur : ${faibles.join(' ; ')}. Vérifie en particulier ces points, et dis-le-lui s'ils reviennent.`
      : '',
    precedentes.length
      ? `
Ses dernières copies sur ce cours : ${precedentes
          .map(
            (p) =>
              `${p.note}/${p.sur}${p.aRetravailler.length ? `, à retravailler : ${p.aRetravailler.slice(0, 3).join(' ; ')}` : ''}`,
          )
          .join(' — ')}. Dis-lui s'il a progressé sur ces points.`
      : '',
    `
Sinon, corrige et réponds :
{
  "isReadable": true,
  "grade": 14,
  "maxGrade": ${bareme},
  "rubric": [
    {"criterion": "Compréhension du sujet", "points": 4, "maxPoints": 5, "comment": "..."}
  ],
  "feedback": {
    "summary": "...",
    "strengths": ["..."],
    "improvements": ["..."]
  },
  "chapters": [2, 5],
  "missedNotions": ["..."]
}

Règles :
- note sur ${bareme} ; la somme des "points" de la rubrique vaut la note, et la
  somme des "maxPoints" vaut ${bareme} ;
- chaque "points" reste inférieur ou égal à son "maxPoints" ;
- entre 2 et 8 critères, nommés en français ;
- exige ce qu'on attend à ce niveau, ni plus ni moins ;
- "chapters" : les numéros des chapitres du cours que l'étudiant doit revoir
  d'après sa copie (au plus 3, vide si aucun ou sans cours) ;
- "missedNotions" : les notions précises qu'il a manquées ou confondues (au
  plus 5, en quelques mots chacune) ;
- tu t'adresses à l'étudiant en le tutoyant, tu es exigeant et encourageant ;
- rien que du JSON, sans texte avant ni après.`,
  ]
  return parties.filter(Boolean).join('\n')
}

export interface LigneBareme {
  criterion: string
  points: number
  maxPoints: number
  comment?: string
}

/**
 * Remet la note d'aplomb.
 *
 * Le modèle annonce une note **et** un barème détaillé qui, parfois, ne
 * concordent pas ; ou il note sur 20 quand on a demandé 40. Plutôt que de
 * rejeter la réponse — et payer un appel de plus —, on fait foi au détail :
 * la rubrique est ramenée au barème demandé, et la note devient la somme de
 * ses points, arrondie au quart de point.
 */
export function normaliserNote<T extends { grade: number; maxGrade: number; rubric: LigneBareme[] }>(
  copie: T,
  bareme?: number | null,
): T {
  const cible = bareme && bareme > 0 ? bareme : copie.maxGrade
  const totalMax = copie.rubric.reduce((s, l) => s + l.maxPoints, 0)
  const facteur = totalMax > 0 ? cible / totalMax : 1
  const quart = (x: number) => Math.round(x * 4) / 4
  const rubric = copie.rubric.map((l) => {
    const maxPoints = quart(l.maxPoints * facteur)
    return { ...l, maxPoints, points: Math.min(maxPoints, quart(l.points * facteur)) }
  })
  const somme = quart(rubric.reduce((s, l) => s + l.points, 0))
  return { ...copie, rubric, maxGrade: cible, grade: Math.min(cible, Math.max(0, somme)) }
}
