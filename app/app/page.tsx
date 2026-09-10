import Link from 'next/link'
import { Button, Card, Icon } from '@/components/ui'

/**
 * Ecran - Telechargement APK.
 *
 * Page publique pour telecharger l'APK Android directement.
 * Affiche infos version, compatibilite, et lien de telechargement.
 */
export default function TelechargerApp() {
  const apkSize = '12.5 MB' // Estime
  const minAndroid = '7.0' // API 24

  return (
    <div className="flex flex-col gap-space-20 px-space-20 py-space-24 min-h-screen">
      {/* Header */}
      <div className="flex flex-col gap-space-4">
        <h1 className="text-headline-xl text-reviz-ink">Reviz - Application Android</h1>
        <p className="text-body-md text-reviz-muted">
          Telecharge l'app pour acceder a tes revisions n'importe ou.
        </p>
      </div>

      {/* Visuels */}
      <div className="flex justify-center">
        <div className="flex h-64 w-32 items-center justify-center rounded-2xl bg-gradient-to-b from-reviz-yellow-soft to-reviz-blue-soft">
          <Icon name="android" size={80} className="text-primary" filled />
        </div>
      </div>

      {/* Infos */}
      <Card>
        <div className="space-y-space-12">
          <div className="flex items-center gap-space-12">
            <Icon name="info" size={24} className="text-primary" />
            <div>
              <span className="text-label-lg text-reviz-ink font-600 block">Version 1.0.0</span>
              <span className="text-label-sm text-reviz-muted">Publiee le 10 septembre 2026</span>
            </div>
          </div>

          <div className="space-y-space-8 border-t border-reviz-border pt-space-12">
            <div className="flex justify-between">
              <span className="text-label-sm text-reviz-muted">Taille</span>
              <span className="text-label-sm text-reviz-ink font-600">{apkSize}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-label-sm text-reviz-muted">Android minimum</span>
              <span className="text-label-sm text-reviz-ink font-600">{minAndroid}+</span>
            </div>
            <div className="flex justify-between">
              <span className="text-label-sm text-reviz-muted">Architecture</span>
              <span className="text-label-sm text-reviz-ink font-600">arm64-v8a</span>
            </div>
          </div>
        </div>
      </Card>

      {/* Caracteristiques */}
      <Card>
        <span className="text-label-lg text-reviz-ink font-600 block mb-space-12">
          Fonctionnalites incluses
        </span>
        <ul className="space-y-space-8 text-body-sm text-reviz-ink">
          <li className="flex items-start gap-space-8">
            <Icon name="check_circle" size={20} className="text-primary flex-shrink-0 mt-space-2" />
            <span>Acces complet a tes cours et QCM</span>
          </li>
          <li className="flex items-start gap-space-8">
            <Icon name="check_circle" size={20} className="text-primary flex-shrink-0 mt-space-2" />
            <span>Correction de copies par IA vision</span>
          </li>
          <li className="flex items-start gap-space-8">
            <Icon name="check_circle" size={20} className="text-primary flex-shrink-0 mt-space-2" />
            <span>Paiements Mobile Money securises</span>
          </li>
          <li className="flex items-start gap-space-8">
            <Icon name="check_circle" size={20} className="text-primary flex-shrink-0 mt-space-2" />
            <span>Classement et gains de parrainage</span>
          </li>
          <li className="flex items-start gap-space-8">
            <Icon name="check_circle" size={20} className="text-primary flex-shrink-0 mt-space-2" />
            <span>Fonctionnement hors ligne (cache local)</span>
          </li>
        </ul>
      </Card>

      {/* CTA Telechargement */}
      <a
        href="https://reviz.vercel.app/reviz-1.0.0.apk"
        target="_blank"
        rel="noopener noreferrer"
        className="w-full"
      >
        <Button icon="download">
          Telecharger l\'APK (v1.0.0)
        </Button>
      </a>

      {/* Instructions */}
      <Card>
        <span className="text-label-lg text-reviz-ink font-600 block mb-space-12">
          Guide d\'installation
        </span>
        <ol className="space-y-space-8 text-body-sm text-reviz-muted">
          <li className="flex gap-space-12">
            <span className="flex h-6 w-6 items-center justify-center rounded-full bg-reviz-yellow text-label-md font-600 text-reviz-on-yellow flex-shrink-0">
              1
            </span>
            <span>Telecharge l\'APK sur ton telephone</span>
          </li>
          <li className="flex gap-space-12">
            <span className="flex h-6 w-6 items-center justify-center rounded-full bg-reviz-yellow text-label-md font-600 text-reviz-on-yellow flex-shrink-0">
              2
            </span>
            <span>Ouvre l\'app \"Fichiers\" et localise le fichier reviz-1.0.0.apk</span>
          </li>
          <li className="flex gap-space-12">
            <span className="flex h-6 w-6 items-center justify-center rounded-full bg-reviz-yellow text-label-md font-600 text-reviz-on-yellow flex-shrink-0">
              3
            </span>
            <span>Appuie sur le fichier pour lancer l\'installation</span>
          </li>
          <li className="flex gap-space-12">
            <span className="flex h-6 w-6 items-center justify-center rounded-full bg-reviz-yellow text-label-md font-600 text-reviz-on-yellow flex-shrink-0">
              4
            </span>
            <span>Approuve les permissions Android et lance l\'app</span>
          </li>
        </ol>
      </Card>

      {/* Note de securite */}
      <Card size="sm">
        <div className="flex gap-space-12">
          <Icon name="shield" size={20} className="text-reviz-ink flex-shrink-0" />
          <div>
            <p className="text-label-sm text-reviz-ink font-600 mb-space-4">
              Securite verifiee
            </p>
            <p className="text-label-sm text-reviz-muted">
              L\'APK est signataire et provient directement du serveur officiel Reviz.
            </p>
          </div>
        </div>
      </Card>

      {/* Lien vers web */}
      <Link href="/" className="w-full">
        <Button variant="secondary">
          Retourner a la version web
        </Button>
      </Link>

      {/* Footer */}
      <div className="text-center text-label-sm text-reviz-muted">
        <p>Version web disponible a <span className="font-600">reviz.vercel.app</span></p>
        <p className="mt-space-4">© 2026 Reviz. Tous droits reserves.</p>
      </div>
    </div>
  )
}
