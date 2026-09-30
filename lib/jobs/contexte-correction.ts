import { z } from 'zod'
import type { ContexteCorrection, TypeEpreuve } from '@/lib/ai/consignes'
import { TYPES_EPREUVE } from '@/lib/metier/corrections-types'

/**
 * Ce que la correction sait de l'étudiant et de son cours.
 *
 * Tout est facultatif : une copie sans cours rattaché, un profil incomplet,
 * une requête qui échoue — la correction part quand même, simplement moins
 * calibrée. Un contexte manquant ne doit jamais coûter une correction.
 */

/** Ce que l'étudiant a précisé au dépôt, relu et revalidé : `feedback` est
 *  écrit par le client, donc rien n'y est cru sur parole. */
const demandeSchema = z
  .object({
    typeEpreuve: z.enum(TYPES_EPREUVE).nullable().catch(null),
    bareme: z.number().int().min(5).max(100).nullable().catch(null),
  })
  .partial()

export function lireDemande(feedback: unknown): {
  typeEpreuve: TypeEpreuve | null
  bareme: number | null
} {
  const brut =
    feedback && typeof feedback === 'object' && 'demande' in feedback
      ? (feedback as { demande: unknown }).demande
      : null
  const d = demandeSchema.safeParse(brut ?? {})
  return {
    typeEpreuve: d.success ? (d.data.typeEpreuve ?? null) : null,
    bareme: d.success ? (d.data.bareme ?? null) : null,
  }
}

/**
 * Les images dans l'ordre de lecture, étiquetées : pages de la copie (`copie`,
 * `copie-2`, `copie-3`…), puis le sujet.
 */
export function ordonnerPages(chemins: string[]): Array<{ chemin: string; etiquette: string }> {
  const nom = (c: string) => c.slice(c.lastIndexOf('/') + 1)
  const rangCopie = (c: string) => {
    const m = /^copie(?:-(\d+))?\./.exec(nom(c))
    return m ? Number(m[1] ?? 1) : null
  }
  const copies = chemins
    .filter((c) => rangCopie(c) !== null)
    .sort((a, b) => (rangCopie(a) ?? 0) - (rangCopie(b) ?? 0))
  const sujets = chemins.filter((c) => nom(c).startsWith('sujet.'))
  const autres = chemins.filter((c) => !copies.includes(c) && !sujets.includes(c))
  return [
    ...[...copies, ...autres].map((chemin, i, tout) => ({
      chemin,
      etiquette: tout.length > 1 ? `Page ${i + 1} de la copie` : 'Copie',
    })),
    ...sujets.map((chemin) => ({ chemin, etiquette: 'Sujet' })),
  ]
}

/**
 * Les chapitres où l'étudiant répond mal : au moins deux questions tentées,
 * moins de la moitié justes, **à la dernière réponse** — même esprit que
 * `lib/metier/maitrise.ts`.
 */
export function chapitresFaibles(
  reponses: Array<{ questionId: string; chapitre: string; juste: boolean; le: string }>,
): string[] {
  const derniere = new Map<string, { chapitre: string; juste: boolean; le: string }>()
  for (const r of reponses) {
    const d = derniere.get(r.questionId)
    if (!d || r.le > d.le) derniere.set(r.questionId, r)
  }
  const parChapitre = new Map<string, { tentees: number; justes: number }>()
  for (const r of derniere.values()) {
    const c = parChapitre.get(r.chapitre) ?? { tentees: 0, justes: 0 }
    c.tentees += 1
    if (r.juste) c.justes += 1
    parChapitre.set(r.chapitre, c)
  }
  return [...parChapitre.entries()]
    .filter(([, c]) => c.tentees >= 2 && c.justes * 2 < c.tentees)
    .map(([chapitre]) => chapitre)
}

type Admin = ReturnType<typeof import('@/lib/supabase/admin').createAdminClient>

export interface ChapitreRattache {
  id: string
  index: number
  titre: string
}

/** Charge le contexte ; chaque morceau manquant est simplement omis. */
export async function chargerContexte(
  admin: Admin,
  {
    userId,
    courseId,
    feedback,
  }: { userId: string; courseId: string | null; feedback: unknown },
): Promise<{ contexte: ContexteCorrection; chapitres: ChapitreRattache[] }> {
  const demande = lireDemande(feedback)
  const contexte: ContexteCorrection = { ...demande }
  let chapitres: ChapitreRattache[] = []

  const { data: profil } = await admin
    .from('profiles')
    .select('study_year, faculties(name), universities(name)')
    .eq('id', userId)
    .maybeSingle()
  if (profil) {
    const p = profil as unknown as {
      study_year: number | null
      faculties: { name: string } | null
      universities: { name: string } | null
    }
    contexte.annee = p.study_year
    contexte.filiere = p.faculties?.name ?? null
    contexte.universite = p.universities?.name ?? null
  }

  if (!courseId) return { contexte, chapitres }

  const [cours, lignesChapitres, reponses, precedentes] = await Promise.all([
    admin.from('courses').select('title, subjects(name)').eq('id', courseId).maybeSingle(),
    admin
      .from('chapters')
      .select('id, index, title, text')
      .eq('course_id', courseId)
      .order('index'),
    admin
      .from('attempts')
      .select(
        'question_id, is_correct, answered_at, questions!inner(chapter_id, chapters!inner(course_id))',
      )
      .eq('user_id', userId)
      .eq('questions.chapters.course_id', courseId)
      .order('answered_at', { ascending: false })
      .limit(1000),
    admin
      .from('corrections')
      .select('grade, max_grade, feedback')
      .eq('user_id', userId)
      .eq('course_id', courseId)
      .eq('status', 'ready')
      .order('created_at', { ascending: false })
      .limit(2),
  ])

  if (cours.data) {
    const c = cours.data as unknown as { title: string; subjects: { name: string } | null }
    contexte.coursTitre = c.title
    contexte.matiere = c.subjects?.name ?? null
  }

  const liste = (lignesChapitres.data ?? []) as Array<{
    id: string
    index: number
    title: string | null
    text: string | null
  }>
  chapitres = liste.map((c) => ({ id: c.id, index: c.index, titre: c.title ?? `Chapitre ${c.index}` }))
  contexte.chapitres = liste.map((c) => ({
    index: c.index,
    titre: c.title ?? `Chapitre ${c.index}`,
    texte: c.text ?? '',
  }))

  const titreDe = new Map(chapitres.map((c) => [c.id, c.titre]))
  const lignes = (reponses.data ?? []) as unknown as Array<{
    question_id: string
    is_correct: boolean
    answered_at: string
    questions: { chapter_id: string } | null
  }>
  contexte.chapitresFaibles = chapitresFaibles(
    lignes
      .filter((l) => l.questions?.chapter_id)
      .map((l) => ({
        questionId: l.question_id,
        chapitre: l.questions!.chapter_id,
        juste: l.is_correct,
        le: l.answered_at,
      })),
  )
    .map((id) => titreDe.get(id))
    .filter((t): t is string => Boolean(t))

  contexte.precedentes = ((precedentes.data ?? []) as Array<{
    grade: number | null
    max_grade: number | null
    feedback: unknown
  }>)
    .filter((p) => p.grade !== null && p.max_grade)
    .map((p) => {
      const f = (p.feedback ?? {}) as { improvements?: unknown }
      return {
        note: Number(p.grade),
        sur: Number(p.max_grade),
        aRetravailler: Array.isArray(f.improvements)
          ? f.improvements.filter((x): x is string => typeof x === 'string')
          : [],
      }
    })

  return { contexte, chapitres }
}

/** Les chapitres désignés par leur numéro, rattachés à leur identifiant. */
export function rattacherChapitres(
  numeros: number[],
  chapitres: ChapitreRattache[],
): ChapitreRattache[] {
  const parIndex = new Map(chapitres.map((c) => [c.index, c]))
  const vus = new Set<number>()
  const sortie: ChapitreRattache[] = []
  for (const n of numeros) {
    const c = parIndex.get(n)
    if (c && !vus.has(n)) {
      vus.add(n)
      sortie.push(c)
    }
    if (sortie.length === 3) break
  }
  return sortie
}
