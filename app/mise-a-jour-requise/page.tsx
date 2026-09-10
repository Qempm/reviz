import Link from 'next/link'
import { Button, Icon } from '@/components/ui'

/**
 * Ecran - Mise a jour requise.
 *
 * Affiche lorsque la version locale est inferieure au minimumVersion.
 * Force l'utilisateur a mettre a jour avant de continuer.
 */
export default async function MiseAJourRequise({
  searchParams,
}: {
  searchParams: Promise<{ version?: string; type?: 'critical' | 'maintenance' }>
}) {
  const params = await searchParams
  const isCritical = params.type === 'critical'

  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-space-20 px-space-20 py-space-24">
      {/* Icone */}
      <div className="flex h-32 w-32 items-center justify-center rounded-full bg-reviz-orange-soft text-on-secondary-fixed">
        <Icon name={isCritical ? 'security_update' : 'system_update'} size={64} filled />
      </div>

      {/* Titre et description */}
      <div className="flex flex-col gap-space-12 text-center">
        <h1 className="text-headline-xl text-reviz-ink">
          {isCritical ? 'Mise a jour securite requise' : 'Nouvelle version disponible'}
        </h1>
        <p className="text-body-md text-reviz-muted max-w-xs">
          {isCritical
            ? 'Une mise a jour de securite importante est requise. Veuillez mettre a jour l\'application immediatement.'
            : 'Une nouvelle version de Reviz est disponible avec des ameliorations et des corrections. Mettez a jour pour une meilleure experience.'}
        </p>
      </div>

      {/* Infos version */}
      <div className="w-full rounded-xl bg-reviz-cream px-space-16 py-space-12">
        <div className="flex items-center justify-between text-label-sm text-reviz-muted">
          <span>Version actuelle</span>
          <span className="font-600 text-reviz-ink">{params.version ?? '1.0.0'}</span>
        </div>
      </div>

      {/* CTA */}
      <div className="w-full space-y-space-12">
        <a href="https://play.google.com/store/apps/details?id=com.reviz.app" target="_blank" rel="noopener noreferrer" className="w-full">
          <Button>
            Mettre a jour maintenant
          </Button>
        </a>

        {!isCritical && (
          <Link href="/" className="w-full">
            <Button variant="secondary">
              Plus tard
            </Button>
          </Link>
        )}
      </div>

      {/* Info supplementaire */}
      <p className="text-label-sm text-reviz-muted text-center max-w-xs">
        La mise a jour est gratuite et prend quelques secondes.
      </p>
    </div>
  )
}
