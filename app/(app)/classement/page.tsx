import { redirect } from 'next/navigation'
import { Card, Icon, Podium, EmptyState } from '@/components/ui'
import { createClient } from '@/lib/supabase/server'

/**
 * Écran 52 — Classement global et par matiere.
 *
 * - Global : top 10 par XP total
 * - Par matiere : classement local (parmi la meme faculte)
 */
export default async function Classement() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/connexion')

  // Recupere le profil pour la faculte
  const { data: profil } = await supabase
    .from('profiles')
    .select('faculty_id, is_ambassador')
    .eq('id', user.id)
    .maybeSingle()

  // Classement global : top 10 par XP (tous les utilisateurs)
  const { data: topGlobalRaw } = await supabase
    .from('profiles')
    .select('id, first_name, xp_total, avatar_key')
    .gt('xp_total', 0)
    .order('xp_total', { ascending: false })
    .limit(10)

  const topGlobal = (topGlobalRaw ?? []).map((p) => ({
    id: p.id,
    name: p.first_name ?? '—',
    xp: p.xp_total ?? 0,
    avatarUrl: p.avatar_key ? `/avatars/${p.avatar_key}.png` : undefined,
  }))

  // Position de l'utilisateur courant
  const { data: userRank } = await supabase.rpc('get_user_rank', {
    target_user_id: user.id,
  })

  const positionGlobal = typeof userRank === 'number' ? userRank : -1

  // Classement par matière (faculté de l'utilisateur)
  const bySubjectQuery = profil?.faculty_id
    ? await supabase
        .from('subject_stats')
        .select(
          'subject_name, average_score, user_id, profiles:profiles(first_name, avatar_key)',
        )
        .eq('faculty_id', profil.faculty_id)
        .not('average_score', 'is', null)
        .order('subject_name', { ascending: true })
    : { data: null }
  const { data: bySubject } = bySubjectQuery

  // Grouper par matière
  const subjectsMap = new Map<
    string,
    Array<{ name: string; score: number; userId: string; avatar?: string }>
  >()
  for (const row of bySubject ?? []) {
    if (!row.subject_name || !row.user_id) continue
    if (!subjectsMap.has(row.subject_name)) subjectsMap.set(row.subject_name, [])
    subjectsMap.get(row.subject_name)!.push({
      name: (row.profiles as any)?.first_name ?? '—',
      score: Math.round(row.average_score ?? 0),
      userId: row.user_id,
      avatar: (row.profiles as any)?.avatar_key,
    })
  }

  // Classer chaque matière
  for (const arr of subjectsMap.values()) {
    arr.sort((a, b) => b.score - a.score)
  }

  return (
    <div className="flex flex-col gap-space-20">
      <header className="flex flex-col gap-space-4">
        <h1 className="text-headline-xl text-reviz-ink">Le classement</h1>
        <p className="text-body-md text-reviz-muted">Vois ou tu en es par rapport a ta faculte.</p>
      </header>

      {/* Classement global */}
      <Card>
        <span className="text-label-lg text-reviz-ink">Classement global</span>

        {positionGlobal > 0 && (
          <div className="mt-space-12 flex items-center gap-space-12 rounded-xl bg-reviz-yellow-soft px-space-12 py-space-8">
            <Icon name="military_tech" size={20} className="text-primary" filled />
            <div className="flex-1">
              <span className="text-label-sm text-reviz-ink">
                Tu es classe <strong>#{positionGlobal}</strong>
              </span>
            </div>
          </div>
        )}

        <div className="mt-space-16 flex flex-col gap-space-12">
          {topGlobal.length > 0 ? (
            <>
              {/* Podium (top 3) */}
              {topGlobal.length >= 3 && (
                <Podium
                  first={topGlobal[0]}
                  second={topGlobal[1]}
                  third={topGlobal[2]}
                />
              )}

              {/* Reste du classement */}
              {topGlobal.length > 3 && (
                <div className="space-y-space-8">
                  {topGlobal.slice(3).map((p, i) => (
                    <div
                      key={p.id}
                      className="flex items-center justify-between rounded-lg bg-reviz-cream px-space-12 py-space-8"
                    >
                      <div className="flex items-center gap-space-8">
                        <span className="text-label-lg text-reviz-muted font-600">
                          #{i + 4}
                        </span>
                        <span className="text-body-sm text-reviz-ink">{p.name}</span>
                      </div>
                      <span className="text-label-md text-primary font-700">
                        {p.xp} XP
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </>
          ) : (
            <EmptyState
              icon="leaderboard"
              title="Pas encore de classement"
              description="Reponds a des questions pour entrer au classement."
            />
          )}
        </div>
      </Card>

      {/* Par matiere */}
      {subjectsMap.size > 0 && (
        <Card>
          <span className="text-label-lg text-reviz-ink">Par matiere</span>

          <div className="mt-space-12 space-y-space-16">
            {Array.from(subjectsMap.entries()).map(([subject, scores]) => (
              <div key={subject} className="flex flex-col gap-space-8">
                <h3 className="text-label-md text-reviz-ink font-600">{subject}</h3>

                <div className="space-y-space-4">
                  {scores.slice(0, 3).map((score, idx) => (
                    <div
                      key={score.userId}
                      className="flex items-center justify-between rounded-lg px-space-12 py-space-6"
                      style={{
                        backgroundColor:
                          idx === 0 ? '#fff3c1' : idx === 1 ? '#e6f2ff' : '#fff5e6',
                      }}
                    >
                      <div className="flex items-center gap-space-8">
                        <span
                          className="text-label-md font-700"
                          style={{
                            color: idx === 0 ? '#785a00' : idx === 1 ? '#4a5fa5' : '#8b6914',
                          }}
                        >
                          #{idx + 1}
                        </span>
                        <span className="text-body-sm text-reviz-ink">{score.name}</span>
                      </div>
                      <span className="text-label-sm font-600" style={{ color: '#785a00' }}>
                        {score.score}%
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </Card>
      )}
    </div>
  )
}
