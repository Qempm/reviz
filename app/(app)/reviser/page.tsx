import { Button, Card, EmptyState } from '@/components/ui'
import { fr } from '@/lib/i18n/fr'

/** Écran 4 — Mes matières. Le dépôt de cours arrive avec le job ingest_course. */
export default function Reviser() {
  return (
    <div className="flex flex-col gap-space-20">
      <h1 className="text-headline-xl text-reviz-ink">{fr.reviser.titre}</h1>
      <Card>
        <EmptyState
          icon="upload_file"
          title={fr.reviser.aucunCours}
          description={fr.reviser.aucunCoursDetail}
          action={<Button icon="add" disabled>{fr.reviser.ajouterCours}</Button>}
        />
        <p className="text-center text-label-sm text-reviz-muted">
          {fr.commun.bientot}
        </p>
      </Card>
    </div>
  )
}
