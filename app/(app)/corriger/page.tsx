import { Button, Card, EmptyState } from '@/components/ui'
import { fr } from '@/lib/i18n/fr'

/** Écran 6 — Correction de copie. Dépend du job correct_copy. */
export default function Corriger() {
  return (
    <div className="flex flex-col gap-space-20">
      <h1 className="text-headline-xl text-reviz-ink">{fr.corriger.titre}</h1>
      <Card>
        <EmptyState
          icon="photo_camera"
          title={fr.corriger.aucuneCorrection}
          description={fr.corriger.aucuneCorrectionDetail}
          action={<Button icon="add_a_photo" disabled>{fr.corriger.deposer}</Button>}
        />
        <p className="text-center text-label-sm text-reviz-muted">
          {fr.commun.bientot}
        </p>
      </Card>
    </div>
  )
}
