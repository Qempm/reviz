'use client'

import { useRef, useState } from 'react'
import { cn } from '@/lib/utils'
import { Icon } from './icon'

export type FichierChoisi = {
  file: File
  /** Aperçu en `blob:` pour les images, sinon null. */
  apercu: string | null
}

export type FileDropzoneProps = {
  /** Types acceptés, au format de l'attribut `accept`. */
  accept?: string
  multiple?: boolean
  /** Taille maximale par fichier, en octets. */
  tailleMax?: number
  /** Ouvre directement l'appareil photo sur mobile. */
  capture?: boolean
  onChange: (fichiers: FichierChoisi[]) => void
  disabled?: boolean
  /** Libellé principal de la zone. */
  label: string
  hint?: string
}

/**
 * Choix de fichiers.
 *
 * Le glisser-déposer n'existe pas sur mobile : la zone est avant tout un
 * grand bouton. On garde le dépôt pour l'usage au clavier et sur ordinateur,
 * sans en faire l'interaction principale.
 */
export function FileDropzone({
  accept,
  multiple,
  tailleMax,
  capture,
  onChange,
  disabled,
  label,
  hint,
}: FileDropzoneProps) {
  const input = useRef<HTMLInputElement>(null)
  const [survol, setSurvol] = useState(false)
  const [erreur, setErreur] = useState<string | null>(null)

  function traiter(liste: FileList | null) {
    if (!liste || liste.length === 0) return
    const fichiers = Array.from(liste)

    if (tailleMax) {
      const trop = fichiers.find((f) => f.size > tailleMax)
      if (trop) {
        const mo = Math.round(tailleMax / 1048576)
        setErreur(`« ${trop.name} » dépasse ${mo} Mo.`)
        return
      }
    }

    setErreur(null)
    onChange(
      fichiers.map((file) => ({
        file,
        apercu: file.type.startsWith('image/') ? URL.createObjectURL(file) : null,
      })),
    )
  }

  return (
    <div className="flex flex-col gap-space-8">
      <button
        type="button"
        disabled={disabled}
        onClick={() => input.current?.click()}
        onDragOver={(e) => {
          e.preventDefault()
          setSurvol(true)
        }}
        onDragLeave={() => setSurvol(false)}
        onDrop={(e) => {
          e.preventDefault()
          setSurvol(false)
          traiter(e.dataTransfer.files)
        }}
        className={cn(
          'flex min-h-[140px] flex-col items-center justify-center gap-space-8 rounded-card border-2 border-dashed px-space-16 py-space-20 transition-colors',
          'disabled:opacity-50',
          erreur
            ? 'border-reviz-danger bg-reviz-danger-soft/40'
            : survol
              ? 'border-reviz-yellow bg-reviz-yellow-soft/40'
              : 'border-reviz-border bg-reviz-card',
        )}
      >
        <span className="flex h-14 w-14 items-center justify-center rounded-full bg-reviz-yellow-soft text-primary">
          <Icon name={capture ? 'photo_camera' : 'upload_file'} size={28} filled />
        </span>
        <span className="text-label-lg text-reviz-ink">{label}</span>
        {hint ? <span className="text-label-sm text-reviz-muted">{hint}</span> : null}
      </button>

      <input
        ref={input}
        type="file"
        accept={accept}
        multiple={multiple}
        {...(capture ? { capture: 'environment' as const } : {})}
        onChange={(e) => {
          traiter(e.target.files)
          // Permet de resélectionner le même fichier après une erreur.
          e.target.value = ''
        }}
        className="hidden"
      />

      {erreur ? (
        <span role="alert" className="text-label-sm text-reviz-danger">
          {erreur}
        </span>
      ) : null}
    </div>
  )
}
