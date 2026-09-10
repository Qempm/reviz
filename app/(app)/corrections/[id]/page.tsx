import Link from 'next/link'
import { redirect } from 'next/navigation'
import { Button, Card, Icon, ProgressBar } from '@/components/ui'
import { createClient } from '@/lib/supabase/server'
import { fr } from '@/lib/i18n/fr'

/**
 * Écran de suivi de correction.
 *
 * Affiche l'état de traitement, puis le résultat (note + rubrique + feedback).
 */
export default async function SuiviCorrection({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/connexion')

  // Récupère la correction
  const { data: correction, error } = await supabase
    .from('corrections')
    .select('id, status, grade, max_grade, rubric, feedback, created_at')
    .eq('id', id)
    .eq('user_id', user.id)
    .maybeSingle()

  if (error || !correction) redirect('/corriger')

  const enTraitement = correction.status === 'pending'
  const termine = correction.status === 'ready'
  const echoue = correction.status === 'failed'

  const taux = correction.max_grade ? Math.round((correction.grade ?? 0) / correction.max_grade * 100) : 0

  return (
    <div className="flex flex-col gap-space-20">
      <header className="flex flex-col gap-space-4">
        <h1 className="text-headline-xl text-reviz-ink">
          {enTraitement ? 'Correction en cours' : 'Résultat'}
        </h1>
        <p className="text-body-md text-reviz-muted">
          {enTraitement
            ? 'Votre copie est en cours de correction par IA.'
            : echoue
              ? 'La correction a échoué. Réessayez.'
              : 'Voici le résultat détaillé de votre correction.'}
        </p>
      </header>

      {/* En traitement */}
      {enTraitement && (
        <Card>
          <div className="flex flex-col items-center gap-space-16 py-space-20">
            <div className="animate-spin">
              <Icon name="hourglass_top" size={48} className="text-primary" filled />
            </div>
            <p className="text-center text-body-md text-reviz-muted">
              Merci de patienter. Cela prend généralement 1-2 minutes.
            </p>
            <p className="text-center text-label-sm text-reviz-muted">
              Vous pouvez fermer la page et revenir plus tard.
            </p>

            {/* Auto-refresh */}
            <script dangerouslySetInnerHTML={{
              __html: `
                setTimeout(() => {
                  window.location.reload();
                }, 5000);
              `,
            }} />
          </div>
        </Card>
      )}

      {/* Échec */}
      {echoue && (
        <Card>
          <div className="flex flex-col items-center gap-space-12">
            <Icon name="error" size={48} className="text-reviz-danger" filled />
            <p className="text-center text-headline-md text-reviz-ink">
              Erreur de traitement
            </p>
            <p className="text-center text-body-md text-reviz-muted">
              La correction n'a pas pu être complétée. Veuillez réessayer.
            </p>
          </div>
        </Card>
      )}

      {/* Résultat */}
      {termine && (
        <>
          {/* Note */}
          <Card>
            <div className="flex items-center justify-between">
              <span className="text-label-lg text-reviz-muted">Votre note</span>
              <span className="text-display-hero-mobile text-reviz-ink">
                {correction.grade ?? '—'}/{correction.max_grade}
              </span>
            </div>
            <ProgressBar value={taux / 100} label={`${taux}%`} />
          </Card>

          {/* Rubrique (feedback) */}
          {correction.feedback && (
            <Card>
              <span className="text-label-lg text-reviz-ink">Retour détaillé</span>
              <div className="mt-space-12 flex flex-col gap-space-8 text-body-sm text-reviz-ink">
                {typeof correction.feedback === 'object' && correction.feedback !== null && (
                  Object.entries(correction.feedback).map(([key, value]) => (
                    <div key={key} className="flex flex-col gap-space-4">
                      <span className="font-600 text-reviz-ink capitalize">
                        {key.replace(/_/g, ' ')}
                      </span>
                      <span className="text-reviz-muted">
                        {typeof value === 'string' ? value : String(value)}
                      </span>
                    </div>
                  ))
                )}
              </div>
            </Card>
          )}

          {/* Rubrique (critères) */}
          {correction.rubric && (
            <Card>
              <span className="text-label-lg text-reviz-ink">Critères d'évaluation</span>
              <div className="mt-space-12 flex flex-col gap-space-8">
                {typeof correction.rubric === 'object' && correction.rubric !== null && (
                  Object.entries(correction.rubric).map(([key, value]) => (
                    <div key={key} className="flex flex-col gap-space-4">
                      <div className="flex items-center justify-between">
                        <span className="text-label-md text-reviz-ink capitalize">
                          {key.replace(/_/g, ' ')}
                        </span>
                        <span className="text-label-sm text-reviz-muted">
                          {typeof value === 'object' && value !== null && 'score' in value
                            ? `${(value as any).score}/10`
                            : String(value)}
                        </span>
                      </div>
                      {typeof value === 'object' && value !== null && 'comment' in value && (
                        <span className="text-label-sm text-reviz-muted">
                          {String((value as any).comment)}
                        </span>
                      )}
                    </div>
                  ))
                )}
              </div>
            </Card>
          )}
        </>
      )}

      {/* Actions */}
      <div className="flex flex-col gap-space-12">
        {!enTraitement && (
          <Link href="/corriger" className="w-full">
            <Button icon="add_a_photo" variant="secondary">
              Envoyer une autre copie
            </Button>
          </Link>
        )}

        <Link href="/corriger" className="w-full">
          <Button icon="arrow_back" variant="secondary">
            Retourner
          </Button>
        </Link>
      </div>
    </div>
  )
}
