import { z } from 'zod'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { createAdminClient } from '@/lib/supabase/admin'
import {
  codeDepuisNom,
  nettoyerNom,
  nomValide,
  trouverParNom,
} from '@/lib/metier/referentiel'

/**
 * POST /api/referentiel
 *
 * `{ type: 'universite' | 'filiere' | 'matiere', nom, parentId?, annee? }`
 * → `{ id, nom, cree }`.
 *
 * Ajoute une école, une filière ou une matière que l'étudiant n'a pas
 * trouvée — ou rend celle qui existe déjà sous un nom « le même »
 * (`normaliserNom` : « F.S.E.G » = « FSEG »). Écrit avec le rôle de service :
 * la RLS ne laisse aux étudiants que la lecture de ces tables.
 *
 * Appelée à l'inscription (l'étudiant a une session, pas encore de profil)
 * et au dépôt d'un cours.
 */

const corpsSchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('universite'), nom: z.string().max(120) }),
  z.object({
    type: z.literal('filiere'),
    nom: z.string().max(120),
    parentId: z.string().uuid(),
  }),
  z.object({
    type: z.literal('matiere'),
    nom: z.string().max(120),
    parentId: z.string().uuid(),
    annee: z.coerce.number().int().min(1).max(7).optional(),
  }),
])

const refus = (status: number, error: string) =>
  Response.json({ ok: false, error }, { status })

export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const analyse = corpsSchema.safeParse(await request.json().catch(() => null))
  if (!analyse.success) return refus(400, 'Ta demande n’a pas pu partir. Réessaie.')

  const entree = analyse.data
  const nom = nettoyerNom(entree.nom)
  if (!nomValide(nom)) {
    return refus(400, 'Écris le nom en entier, avec au moins deux lettres.')
  }

  const admin = createAdminClient()
  const ok = (id: string, n: string, cree: boolean) =>
    Response.json({ ok: true, data: { id, nom: n, cree } })

  if (entree.type === 'universite') {
    const { data: toutes } = await admin.from('universities').select('id, name, code')
    const existante = trouverParNom(toutes ?? [], nom)
    if (existante) return ok(existante.id, existante.name, false)

    // `code` est unique : on suffixe s'il est déjà pris (« UP » → « UP2 »).
    const codes = new Set((toutes ?? []).map((u) => u.code))
    const base = codeDepuisNom(nom)
    let code = base
    for (let i = 2; codes.has(code); i++) code = `${base}${i}`

    const { data, error } = await admin
      .from('universities')
      .insert({ name: nom, code })
      .select('id, name')
      .single()
    if (error || !data) {
      console.error('[referentiel] école non créée', error?.message)
      return refus(500, 'On n’a pas pu ajouter ton école. Réessaie.')
    }
    return ok(data.id, data.name, true)
  }

  if (entree.type === 'filiere') {
    const { data: parent } = await admin
      .from('universities')
      .select('id')
      .eq('id', entree.parentId)
      .maybeSingle()
    if (!parent) return refus(404, 'On ne retrouve pas ton école. Choisis-la de nouveau.')

    const { data: soeurs } = await admin
      .from('faculties')
      .select('id, name, code')
      .eq('university_id', entree.parentId)
    const existante = trouverParNom(soeurs ?? [], nom)
    if (existante) return ok(existante.id, existante.name, false)

    const codes = new Set((soeurs ?? []).map((f) => f.code))
    const base = codeDepuisNom(nom)
    let code = base
    for (let i = 2; codes.has(code); i++) code = `${base}${i}`

    const { data, error } = await admin
      .from('faculties')
      .insert({ university_id: entree.parentId, name: nom, code })
      .select('id, name')
      .single()
    if (error || !data) {
      console.error('[referentiel] filière non créée', error?.message)
      return refus(500, 'On n’a pas pu ajouter ta filière. Réessaie.')
    }
    return ok(data.id, data.name, true)
  }

  // Matière
  const { data: parent } = await admin
    .from('faculties')
    .select('id')
    .eq('id', entree.parentId)
    .maybeSingle()
  if (!parent) return refus(404, 'On ne retrouve pas ta filière.')

  const { data: soeurs } = await admin
    .from('subjects')
    .select('id, name')
    .eq('faculty_id', entree.parentId)
  const existante = trouverParNom(soeurs ?? [], nom)
  if (existante) return ok(existante.id, existante.name, false)

  const { data, error } = await admin
    .from('subjects')
    .insert({
      faculty_id: entree.parentId,
      name: nom,
      study_year: entree.annee ?? null,
    })
    .select('id, name')
    .single()
  if (error || !data) {
    console.error('[referentiel] matière non créée', error?.message)
    return refus(500, 'On n’a pas pu ajouter ta matière. Réessaie.')
  }
  return ok(data.id, data.name, true)
}
