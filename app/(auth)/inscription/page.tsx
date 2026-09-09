import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { FormulaireInscription } from './formulaire'

/**
 * B2 — Université, filière, année, code parrain, téléphone facultatif.
 *
 * Les établissements sont chargés côté serveur : la liste est en lecture
 * publique, elle change rarement, et un étudiant sur une connexion instable
 * ne doit pas attendre un aller-retour de plus après s'être connecté.
 */
export default async function Inscription() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) redirect('/connexion?suite=/inscription')

  // Profil déjà créé : rien à faire ici.
  const { data: profil } = await supabase
    .from('profiles')
    .select('id')
    .eq('id', user.id)
    .maybeSingle()

  if (profil) redirect('/')

  const [{ data: universites }, { data: facultes }] = await Promise.all([
    supabase.from('universities').select('id, code, name, city').order('name'),
    supabase.from('faculties').select('id, university_id, code, name').order('name'),
  ])

  return (
    <FormulaireInscription
      universites={universites ?? []}
      facultes={facultes ?? []}
    />
  )
}
