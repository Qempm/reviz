import { redirect } from 'next/navigation'
import { BottomNav, Icon } from '@/components/ui'
import { createClient } from '@/lib/supabase/server'

/**
 * Coquille des écrans connectés : header collant, contenu, navigation basse.
 *
 * La garde d'accès est ici et non dans le middleware : elle a besoin du
 * profil, pas seulement de la session. Un compte sans profil doit finir son
 * inscription avant de voir quoi que ce soit.
 */
export default async function LayoutApp({
  children,
}: {
  children: React.ReactNode
}) {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) redirect('/connexion')

  const { data: profil } = await supabase
    .from('profiles')
    .select('first_name, xp_total, current_streak, last_validated_on')
    .eq('id', user.id)
    .maybeSingle()

  if (!profil) redirect('/inscription')

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-app flex-col bg-surface">
      <header className="pt-safe fixed inset-x-0 top-0 z-50 mx-auto w-full max-w-app bg-surface/85 shadow-header backdrop-blur-xl">
        <div className="flex h-header items-center justify-between px-screen-margin-mobile">
          <span className="text-headline-lg tracking-tight text-reviz-ink">Reviz</span>

          <div className="flex items-center gap-space-12">
            <span className="flex items-center gap-space-4 rounded-full bg-surface-container px-space-8 py-space-4">
              <Icon
                name="local_fire_department"
                size={18}
                filled
                className="text-reviz-orange"
              />
              <span className="text-label-sm text-reviz-ink">
                {profil.current_streak}j
              </span>
            </span>

            <span className="flex items-center gap-space-4 rounded-full bg-reviz-yellow px-space-8 py-space-4 shadow-tactile-sm">
              <Icon name="stars" size={16} filled className="text-reviz-on-yellow" />
              <span className="text-label-sm text-reviz-on-yellow">
                {profil.xp_total.toLocaleString('fr-FR')} XP
              </span>
            </span>
          </div>
        </div>
      </header>

      <main className="flex flex-1 flex-col px-screen-margin-mobile pb-[96px] pt-[calc(theme(height.header)+theme(spacing.space-16))]">
        {children}
      </main>

      <BottomNav />
    </div>
  )
}
