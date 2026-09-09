'use client'

import { useState, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { Button, Card, FileDropzone, Icon, TextField } from '@/components/ui'
import type { FichierChoisi } from '@/components/ui'
import {
  annulerDepot,
  confirmerDepot,
  preparerDepot,
} from '@/app/(app)/reviser/ajouter/actions'
import { fr } from '@/lib/i18n/fr'

export type MatiereChoix = { id: string; nom: string }

const ACCEPT =
  'application/pdf,.doc,.docx,application/msword,' +
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document,' +
  'image/jpeg,image/png,image/webp'

/** 25 Mo, comme le bucket `cours`. */
const TAILLE_MAX = 26_214_400

/**
 * Formulaire de dépôt d'un cours.
 *
 * Le fichier monte directement du téléphone vers Supabase Storage, par une
 * URL signée et un simple `fetch` : il ne passe pas par une fonction
 * serverless, qui plafonnerait la charge utile et doublerait la consommation
 * de données de l'étudiant, et le client Supabase n'est pas embarqué —
 * mesuré, il pesait 70 ko sur cette seule route.
 */
export function DepotCours({ matieres }: { matieres: MatiereChoix[] }) {
  const [fichier, setFichier] = useState<File | null>(null)
  const [titre, setTitre] = useState('')
  const [matiere, setMatiere] = useState(matieres[0]?.id ?? '')
  const [examen, setExamen] = useState('')
  const [erreur, setErreur] = useState<string | null>(null)
  const [enCours, demarrer] = useTransition()
  const router = useRouter()

  function choisir(fichiers: FichierChoisi[]) {
    const f = fichiers[0]?.file ?? null
    setFichier(f)
    setErreur(null)

    // Titre proposé depuis le nom du fichier : l'étudiant peut le corriger,
    // mais il n'a pas à le taper.
    if (f && titre.trim() === '') {
      setTitre(f.name.replace(/\.[^.]+$/, '').replace(/[_-]+/g, ' ').slice(0, 200))
    }
  }

  function envoyer() {
    if (!fichier) return setErreur(fr.depot.erreurs.fichierManquant)
    if (!matiere) return setErreur(fr.depot.erreurs.matiereManquante)
    if (titre.trim().length < 2) return setErreur(fr.depot.erreurs.titreManquant)

    demarrer(async () => {
      setErreur(null)

      let courseId: string | null = null
      try {
        const empreinte = await sha256(fichier)

        const preparation = await preparerDepot({
          fileHash: empreinte,
          subjectId: matiere,
          title: titre.trim(),
          examDate: examen === '' ? null : examen,
          mime: fichier.type as never,
          taille: fichier.size,
        })

        if (!preparation.ok) {
          // Document déjà déposé : ce n'est pas une erreur, c'est un
          // raccourci vers le cours qui existe.
          if (preparation.error === 'deja-depose' && preparation.courseId) {
            router.push(`/cours/${preparation.courseId}`)
            return
          }
          setErreur(messageRefus(preparation.error, preparation.plafond))
          return
        }

        courseId = preparation.courseId

        const reponse = await fetch(preparation.uploadUrl, {
          method: 'PUT',
          headers: { 'content-type': fichier.type },
          body: fichier,
        })

        if (!reponse.ok) {
          // La ligne créée doit disparaître, sinon l'empreinte reste prise
          // et l'étudiant ne pourra plus redéposer le même document.
          await annulerDepot(courseId)
          setErreur(fr.depot.erreurs.envoiImpossible)
          return
        }

        await confirmerDepot(courseId)
        router.push(`/cours/${courseId}`)
      } catch {
        if (courseId) await annulerDepot(courseId)
        setErreur(fr.depot.erreurs.inconnue)
      }
    })
  }

  return (
    <div className="flex flex-col gap-space-16">
      <FileDropzone
        accept={ACCEPT}
        tailleMax={TAILLE_MAX}
        onChange={choisir}
        disabled={enCours}
        label={fr.depot.labelFichier}
        hint={fr.depot.aideFichier}
      />

      {fichier ? (
        <Card size="sm">
          <span className="flex items-center gap-space-8">
            <Icon name="description" size={20} className="text-primary" />
            <span className="flex min-w-0 flex-1 flex-col">
              <span className="truncate text-label-md text-reviz-ink">
                {fichier.name}
              </span>
              <span className="text-label-sm text-reviz-muted">
                {poids(fichier.size)}
              </span>
            </span>
          </span>
        </Card>
      ) : null}

      <TextField
        label={fr.depot.labelTitre}
        hint={fr.depot.aideTitre}
        value={titre}
        onChange={(e) => setTitre(e.target.value)}
        disabled={enCours}
        maxLength={200}
      />

      <label className="flex flex-col gap-space-4">
        <span className="text-label-md text-reviz-ink">{fr.depot.labelMatiere}</span>
        <select
          value={matiere}
          onChange={(e) => setMatiere(e.target.value)}
          disabled={enCours}
          className="h-cta rounded-xl bg-reviz-card px-space-16 text-body-lg text-reviz-ink shadow-card-sm"
        >
          {matieres.map((m) => (
            <option key={m.id} value={m.id}>
              {m.nom}
            </option>
          ))}
        </select>
      </label>

      <label className="flex flex-col gap-space-4">
        <span className="text-label-md text-reviz-ink">{fr.depot.labelExamen}</span>
        <input
          type="date"
          value={examen}
          onChange={(e) => setExamen(e.target.value)}
          disabled={enCours}
          className="h-cta rounded-xl bg-reviz-card px-space-16 text-body-lg text-reviz-ink shadow-card-sm"
        />
        <span className="text-label-sm text-reviz-muted">{fr.depot.aideExamen}</span>
      </label>

      <Button icon="cloud_upload" onClick={envoyer} disabled={enCours || !fichier}>
        {enCours ? fr.depot.envoi : fr.depot.envoyer}
      </Button>

      {erreur ? (
        <p className="text-center text-label-sm text-reviz-danger">{erreur}</p>
      ) : null}
    </div>
  )
}

function messageRefus(error: string, plafond?: number): string {
  if (error === 'aucun-acces') return fr.depot.aucunAccesDetail
  if (error === 'acces-expire') return fr.depot.accesExpireDetail
  if (error === 'plafond-matieres') {
    return plafond === undefined
      ? fr.depot.plafondMatieresDetail
      : `${fr.depot.plafondMatieres(plafond)}. ${fr.depot.plafondMatieresDetail}`
  }
  if (error === 'session') return fr.connexion.erreurs.codeExpire
  return fr.depot.erreurs.inconnue
}

/**
 * Empreinte SHA-256 du fichier, calculée par le navigateur.
 *
 * Côté client et non côté serveur : le fichier ne passe jamais par nos
 * fonctions, et c'est précisément l'empreinte qui permet de savoir, avant de
 * l'envoyer, s'il a déjà été traité (règle métier 4).
 */
async function sha256(fichier: File): Promise<string> {
  const octets = await crypto.subtle.digest('SHA-256', await fichier.arrayBuffer())
  return [...new Uint8Array(octets)]
    .map((o) => o.toString(16).padStart(2, '0'))
    .join('')
}

function poids(octets: number): string {
  const mo = octets / 1_048_576
  return mo >= 1
    ? `${mo.toFixed(1).replace('.', ',')} Mo`
    : `${Math.max(1, Math.round(octets / 1024))} ko`
}
