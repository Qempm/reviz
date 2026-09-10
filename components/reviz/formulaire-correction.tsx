'use client'

import { useState, useRef, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { Button, Icon } from '@/components/ui'
import { deposerCorrection } from '@/app/(app)/corriger/actions'
import { fr } from '@/lib/i18n/fr'

/**
 * Formulaire de dépôt de copie pour correction.
 *
 * - Camera ou galerie pour la copie (requise)
 * - Camera ou galerie pour le sujet (optionnel mais conseillé pour le contexte)
 * - Upload vers Supabase Storage
 * - Création du job correct_copy
 */
export function FormulaireCorrection() {
  const [copie, setCopie] = useState<File | null>(null)
  const [sujet, setSujet] = useState<File | null>(null)
  const [erreur, setErreur] = useState<string>('')
  const [enCours, demarrer] = useTransition()
  const router = useRouter()

  const cameraRefCopie = useRef<HTMLInputElement>(null)
  const galerieRefCopie = useRef<HTMLInputElement>(null)
  const cameraRefSujet = useRef<HTMLInputElement>(null)
  const galerieRefSujet = useRef<HTMLInputElement>(null)

  const handleFileSelect = (file: File | null, setter: (f: File | null) => void) => {
    if (!file) return
    // Validate image
    if (!file.type.startsWith('image/')) {
      setErreur('Doit être une image (JPG, PNG, etc.)')
      return
    }
    if (file.size > 10 * 1024 * 1024) {
      // 10MB max
      setErreur('Fichier trop gros (max 10 MB)')
      return
    }
    setErreur('')
    setter(file)
  }

  const handleSubmit = async () => {
    if (!copie) {
      setErreur('La copie est requise')
      return
    }

    demarrer(async () => {
      setErreur('')
      const r = await deposerCorrection(copie, sujet || undefined)

      if (!r.ok) {
        setErreur(
          r.error === 'session'
            ? 'Session expirée'
            : r.error === 'pack'
              ? 'Pas d\'accès ou corrections épuisées'
              : 'Erreur serveur. Réessayez.',
        )
        return
      }

      // Rediriger vers la page de suivi
      router.push(`/corrections/${r.correctionId}`)
    })
  }

  return (
    <div className="flex flex-col gap-space-16">
      {/* Copie (requise) */}
      <div className="flex flex-col gap-space-8">
        <label className="text-label-lg text-reviz-ink">
          Copie (requise)
        </label>
        <div className="flex gap-space-12">
          <button
            type="button"
            onClick={() => cameraRefCopie.current?.click()}
            className="flex-1 flex items-center justify-center gap-space-8 rounded-xl border-2 border-reviz-border bg-reviz-cream py-space-16 text-label-md text-reviz-ink hover:bg-reviz-yellow-soft"
          >
            <Icon name="camera_alt" size={20} />
            Caméra
          </button>
          <button
            type="button"
            onClick={() => galerieRefCopie.current?.click()}
            className="flex-1 flex items-center justify-center gap-space-8 rounded-xl border-2 border-reviz-border bg-reviz-cream py-space-16 text-label-md text-reviz-ink hover:bg-reviz-yellow-soft"
          >
            <Icon name="image" size={20} />
            Galerie
          </button>
        </div>

        <input
          ref={cameraRefCopie}
          type="file"
          accept="image/*"
          capture="environment"
          onChange={(e) => handleFileSelect(e.target.files?.[0] ?? null, setCopie)}
          hidden
        />
        <input
          ref={galerieRefCopie}
          type="file"
          accept="image/*"
          onChange={(e) => handleFileSelect(e.target.files?.[0] ?? null, setCopie)}
          hidden
        />

        {copie && (
          <div className="flex items-center justify-between rounded-xl bg-reviz-yellow-soft px-space-12 py-space-8">
            <span className="text-label-sm text-reviz-ink">{copie.name}</span>
            <button
              type="button"
              onClick={() => setCopie(null)}
              className="text-reviz-muted hover:text-reviz-ink"
            >
              <Icon name="close" size={18} />
            </button>
          </div>
        )}
      </div>

      {/* Sujet (optionnel) */}
      <div className="flex flex-col gap-space-8">
        <label className="text-label-lg text-reviz-ink">
          Sujet de l'examen (optionnel)
        </label>
        <div className="flex gap-space-12">
          <button
            type="button"
            onClick={() => cameraRefSujet.current?.click()}
            className="flex-1 flex items-center justify-center gap-space-8 rounded-xl border-2 border-reviz-border bg-reviz-cream py-space-16 text-label-md text-reviz-ink hover:bg-reviz-yellow-soft"
          >
            <Icon name="camera_alt" size={20} />
            Caméra
          </button>
          <button
            type="button"
            onClick={() => galerieRefSujet.current?.click()}
            className="flex-1 flex items-center justify-center gap-space-8 rounded-xl border-2 border-reviz-border bg-reviz-cream py-space-16 text-label-md text-reviz-ink hover:bg-reviz-yellow-soft"
          >
            <Icon name="image" size={20} />
            Galerie
          </button>
        </div>

        <input
          ref={cameraRefSujet}
          type="file"
          accept="image/*"
          capture="environment"
          onChange={(e) => handleFileSelect(e.target.files?.[0] ?? null, setSujet)}
          hidden
        />
        <input
          ref={galerieRefSujet}
          type="file"
          accept="image/*"
          onChange={(e) => handleFileSelect(e.target.files?.[0] ?? null, setSujet)}
          hidden
        />

        {sujet && (
          <div className="flex items-center justify-between rounded-xl bg-reviz-blue-soft px-space-12 py-space-8">
            <span className="text-label-sm text-reviz-ink">{sujet.name}</span>
            <button
              type="button"
              onClick={() => setSujet(null)}
              className="text-reviz-muted hover:text-reviz-ink"
            >
              <Icon name="close" size={18} />
            </button>
          </div>
        )}
      </div>

      {/* Erreur */}
      {erreur && (
        <p className="text-center text-label-sm text-reviz-danger">{erreur}</p>
      )}

      {/* Bouton */}
      <Button
        icon="check"
        disabled={enCours || !copie}
        onClick={handleSubmit}
      >
        {enCours ? 'Traitement...' : 'Envoyer pour correction'}
      </Button>
    </div>
  )
}
