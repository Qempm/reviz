import { redirect } from 'next/navigation'
import { Card } from '@/components/ui'
import { createClient } from '@/lib/supabase/server'
import { fr } from '@/lib/i18n/fr'
import { FormulaireCorrection } from '@/components/reviz/formulaire-correction'

/**
 * Écran 6 — Correction de copie.
 *
 * Upload de copie (requise) + sujet (optionnel) pour correction par IA.
 * Crée un job correct_copy qui appelle DeepSeek vision.
 */
export default async function Corriger() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/connexion')

  return (
    <div className="flex flex-col gap-space-20">
      <header className="flex flex-col gap-space-4">
        <h1 className="text-headline-xl text-reviz-ink">{fr.corriger.titre}</h1>
        <p className="text-body-md text-reviz-muted">
          {fr.corriger.aucuneCorrectionDetail}
        </p>
      </header>

      <Card>
        <FormulaireCorrection />
      </Card>
    </div>
  )
}
