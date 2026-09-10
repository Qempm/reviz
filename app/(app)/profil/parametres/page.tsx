'use client'

import Link from 'next/link'
import { Button, Card, Icon } from '@/components/ui'

/**
 * Ecran - Parametres.
 *
 * Reglages d'application : langue, notifications, donnees.
 */
export default function Parametres() {
  return (
    <div className="flex flex-col gap-space-20">
      <header className="flex flex-col gap-space-4">
        <Link href="/profil" className="mb-space-8">
          <Icon name="arrow_back" size={24} className="text-reviz-ink" />
        </Link>
        <h1 className="text-headline-xl text-reviz-ink">Parametres</h1>
        <p className="text-body-md text-reviz-muted">Personnalise ton experience Reviz.</p>
      </header>

      {/* Langue */}
      <Card>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-space-12">
            <Icon name="language" size={24} className="text-primary" />
            <span className="text-label-lg text-reviz-ink">Langue</span>
          </div>
          <span className="text-label-sm text-reviz-muted">Francais</span>
        </div>
        <p className="text-label-sm text-reviz-muted mt-space-8">
          Plus de langues en phase 2.
        </p>
      </Card>

      {/* Notifications */}
      <Card>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-space-12">
            <Icon name="notifications_active" size={24} className="text-primary" />
            <span className="text-label-lg text-reviz-ink">Notifications WhatsApp</span>
          </div>
          <span className="text-label-sm text-reviz-muted">Activees</span>
        </div>
        <p className="text-label-sm text-reviz-muted mt-space-8">
          Rappels de revision et mises a jour de compte.
        </p>
      </Card>

      {/* Donnees */}
      <Card>
        <div className="flex items-center gap-space-12">
          <Icon name="storage" size={24} className="text-primary" />
          <span className="flex-1">
            <span className="text-label-lg text-reviz-ink block">Donnees en cache</span>
            <span className="text-label-sm text-reviz-muted block mt-space-4">
              Vider le cache local pour forcer une resynchronisation.
            </span>
          </span>
        </div>
        <div className="mt-space-12">
          <Button variant="secondary">
            Vider le cache
          </Button>
        </div>
      </Card>

      {/* Version */}
      <Card size="sm">
        <div className="flex items-center justify-between">
          <span className="text-label-md text-reviz-muted">Version</span>
          <span className="text-label-md text-reviz-ink font-600">1.0.0</span>
        </div>
      </Card>

      {/* Donnees personnelles */}
      <Link href="/profil/donnees" className="w-full">
        <Button variant="secondary" icon="privacy_tip">
          Mes donnees personnelles
        </Button>
      </Link>

      {/* Suppression compte */}
      <Link href="/profil/supprimer-compte" className="w-full">
        <Button variant="secondary" icon="delete_forever">
          Supprimer mon compte
        </Button>
      </Link>
    </div>
  )
}
