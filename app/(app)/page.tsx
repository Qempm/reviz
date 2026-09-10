import Link from 'next/link'
import { redirect } from 'next/navigation'
import {
  Button,
  Card,
  EmptyState,
  Icon,
  ProgressBar,
  StreakCard,
} from '@/components/ui'
import { createClient } from '@/lib/supabase/server'
import { fr } from '@/lib/i18n/fr'
import { etatSerie, resteAvantObjectif } from '@/lib/xp/serie'

/**
 * Écran 3 — Tableau de bord.
 *
 * Rendu côté serveur : l'étudiant ouvre l'app la nuit avant un contrôle, sur
 * une connexion instable. Tout ce qui peut arriver dans la première réponse
 * doit y arriver, plutôt qu'en cascade de requêtes après l'hydratation.
 */
export default async function TableauDeBord() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/connexion')

  const [{ data: profil }, { data: semaine }, { data: objectif }, { data: matieres }] =
    await Promise.all([
      supabase
        .from('profiles')
        .select('first_name, current_streak, last_validated_on, faculty_id')
        .eq('id', user.id)
        .maybeSingle(),
      supabase.rpc('streak_week'),
      // L'objectif est une fonction SQL pour être ajustable sans migration :
      // on le lit, on ne le recopie pas.
      supabase.rpc('daily_goal'),
      supabase
        .from('subject_stats')
        .select('subject_id, subject_name, questions_answered, average_score, is_weak')
        .order('questions_answered', { ascending: false })
        .limit(4),
    ])

  if (!profil) redirect('/inscription')

  const jours = (semaine ?? []).map((j) => ({
    weekday: j.weekday,
    isValidated: j.is_validated,
    isToday: j.is_today,
  }))

  const aujourdhui = (semaine ?? []).find((j) => j.is_today)
  const xpDuJour = aujourdhui?.xp_earned ?? 0
  const repondues = aujourdhui?.questions_answered ?? 0
  const but = objectif ?? 10

  const serie = etatSerie({
    current: profil.current_streak,
    lastValidatedOn: profil.last_validated_on,
  })

  // Un seul message, choisi par ce qui est en jeu maintenant.
  const message = serie.rompue
    ? fr.tableauDeBord.serieRompue
    : serie.enJeu
      ? fr.tableauDeBord.serieEnJeu(resteAvantObjectif(repondues, but))
      : undefined

  return (
    <div className="flex flex-col gap-space-20 pb-space-32">
      <header className="flex flex-col gap-space-4">
        <h1 className="text-headline-xl text-reviz-ink">
          {fr.tableauDeBord.salutation(profil.first_name ?? '')}
        </h1>
        <p className="text-body-md text-reviz-muted">
          {fr.tableauDeBord.sousTitre}
        </p>
      </header>

      {/* Série de révision : présente même à zéro, c'est ce qui donne envie
          de revenir demain. */}
      {jours.length > 0 ? (
        <StreakCard
          streak={serie.jours}
          rompue={serie.rompue}
          xpToday={xpDuJour}
          objectif={{ repondues, total: but }}
          days={jours}
          message={message}
        />
      ) : null}

      {/* Matières ---------------------------------------------------------- */}
      <section className="flex flex-col gap-space-12">
        <div className="flex items-baseline justify-between">
          <h2 className="text-headline-lg text-reviz-ink">
            {fr.tableauDeBord.mesMatieres}
          </h2>
          {matieres && matieres.length > 0 ? (
            <Link href="/reviser" className="text-label-md text-primary">
              {fr.commun.voirTout}
            </Link>
          ) : null}
        </div>

        {matieres && matieres.length > 0 ? (
          <div className="flex flex-col gap-space-12">
            {matieres.map((m) => (
              <Card key={m.subject_id} size="sm">
                <div className="flex items-center justify-between gap-space-12">
                  <span className="text-label-lg text-reviz-ink">
                    {m.subject_name}
                  </span>
                  {m.is_weak ? (
                    <span className="flex items-center gap-space-4 rounded-full bg-reviz-danger-soft px-space-8 py-space-2 text-caption text-reviz-on-danger-soft">
                      <Icon name="priority_high" size={14} />
                      {fr.tableauDeBord.pointFaible}
                    </span>
                  ) : null}
                </div>
                <ProgressBar value={Number(m.average_score ?? 0)} />
                <span className="text-label-sm text-reviz-muted">
                  {fr.tableauDeBord.questionsFaites(m.questions_answered ?? 0)}
                </span>
              </Card>
            ))}
          </div>
        ) : (
          <Card>
            <EmptyState
              icon="menu_book"
              title={fr.tableauDeBord.aucuneMatiere}
              description={fr.tableauDeBord.aucuneMatiereDetail}
              action={
                <Link href="/reviser/ajouter" className="w-full">
                  <Button icon="add">{fr.tableauDeBord.ajouterCours}</Button>
                </Link>
              }
            />
          </Card>
        )}
      </section>
    </div>
  )
}
