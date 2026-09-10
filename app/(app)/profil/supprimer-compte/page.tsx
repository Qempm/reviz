'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { Button, Card, Icon } from '@/components/ui'

/**
 * Ecran - Suppression de compte.
 *
 * Confirmation irreversible pour supprimer le compte et toutes ses donnees.
 */
export default function SupprimerCompte() {
  const router = useRouter()
  const [confirmed, setConfirmed] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleDelete = async () => {
    if (!confirmed) return

    setLoading(true)
    setError('')

    try {
      const res = await fetch('/api/profile/delete', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      })

      const data = await res.json()

      if (!data.ok) {
        setError(data.error || 'Erreur lors de la suppression')
        return
      }

      // Redirection vers accueil (connexion sera necessaire)
      setTimeout(() => {
        router.push('/connexion')
      }, 1000)
    } catch (e) {
      setError(String(e))
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="flex flex-col gap-space-20">
      <header className="flex flex-col gap-space-4">
        <Link href="/profil" className="mb-space-8">
          <Icon name="arrow_back" size={24} className="text-reviz-ink" />
        </Link>
        <h1 className="text-headline-xl text-reviz-ink">Supprimer mon compte</h1>
        <p className="text-body-md text-reviz-muted">Cette action est irreversible.</p>
      </header>

      {/* Avertissement */}
      <div className="flex flex-col bg-reviz-card rounded-card p-space-20 gap-space-16 shadow-card border-reviz-danger border-2">
        <div className="flex gap-space-12">
          <Icon name="warning" size={24} className="text-reviz-danger flex-shrink-0" filled />
          <div className="flex flex-col gap-space-8">
            <span className="text-label-lg text-reviz-danger font-600">Attention</span>
            <ul className="text-body-md text-reviz-muted space-y-space-8 list-disc list-inside">
              <li>Tous tes cours seront supprimes definitivement.</li>
              <li>Tes resultats et ton classement seront effaces.</li>
              <li>Tes gains en attente ne seront pas reverses.</li>
              <li>Tes filleuls perdront la commission associee.</li>
              <li>Cette action ne peut pas etre annulee.</li>
            </ul>
          </div>
        </div>
      </div>

      {/* Confirmation */}
      <Card>
        <label className="flex items-start gap-space-12 cursor-pointer">
          <input
            type="checkbox"
            checked={confirmed}
            onChange={(e) => setConfirmed(e.target.checked)}
            className="mt-space-4"
          />
          <span className="text-body-md text-reviz-ink">
            J\'accepte de supprimer definitivement mon compte et toutes mes donnees.
          </span>
        </label>
      </Card>

      {/* Erreur */}
      {error && (
        <div className="flex items-start gap-space-8 rounded-lg bg-reviz-danger-light px-space-12 py-space-8">
          <Icon name="error" size={20} className="text-reviz-danger flex-shrink-0" filled />
          <p className="text-body-sm text-reviz-danger">{error}</p>
        </div>
      )}

      {/* CTA */}
      <Button
        onClick={handleDelete}
        disabled={!confirmed || loading}
        variant="danger"
      >
        {loading ? 'Suppression...' : 'Supprimer mon compte'}
      </Button>

      <Link href="/profil" className="w-full">
        <Button variant="secondary">Annuler</Button>
      </Link>
    </div>
  )
}
