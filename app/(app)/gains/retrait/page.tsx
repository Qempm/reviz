'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { Button, Card, Icon, Input, Select, Toast } from '@/components/ui'
import { SEUIL_RETRAIT_FCFA } from '@/lib/payments/commission'

/**
 * Ecran 50 — Demande de retrait.
 *
 * Formulaire: montant, operateur Mobile Money, numero telephone.
 * Appelle /api/wallet/withdrawal en Server Action.
 */
export default function DemandeRetrait() {
  const router = useRouter()
  const [montant, setMontant] = useState('')
  const [operateur, setOperateur] = useState<'mtn' | 'moov' | 'wave'>('mtn')
  const [telephone, setTelephone] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [toast, setToast] = useState('')

  const montantNum = parseInt(montant) || 0
  const montantOk = montantNum >= SEUIL_RETRAIT_FCFA && montantNum > 0
  const telOk = /^\+?[0-9]{8,15}$/.test(telephone)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!montantOk || !telOk) return

    setLoading(true)
    setError('')

    try {
      const res = await fetch('/api/wallet/withdrawal', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          amount_fcfa: montantNum,
          operator: operateur,
          phone: telephone,
        }),
      })

      const data = await res.json()

      if (!data.ok) {
        setError(data.error || 'Erreur lors de la demande')
        setToast('')
        return
      }

      setToast('Demande envoyee ! Vous serez notifie par SMS.')
      setTimeout(() => {
        router.push('/gains')
      }, 2000)
    } catch (e) {
      setError(String(e))
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="flex flex-col gap-space-20">
      <header className="flex flex-col gap-space-4">
        <Link href="/gains" className="mb-space-8">
          <Icon name="arrow_back" size={24} className="text-reviz-ink" />
        </Link>
        <h1 className="text-headline-xl text-reviz-ink">Demander un retrait</h1>
        <p className="text-body-md text-reviz-muted">Transfere tes gains en Mobile Money.</p>
      </header>

      <Card>
        <form onSubmit={handleSubmit} className="flex flex-col gap-space-16">
          {/* Montant */}
          <div className="flex flex-col gap-space-4">
            <label className="text-label-md text-reviz-ink">Montant</label>
            <Input
              type="number"
              placeholder="Ex: 5000"
              value={montant}
              onChange={(e) => setMontant(e.target.value)}
              disabled={loading}
            />
            <span className="text-label-sm text-reviz-muted">
              Minimum {SEUIL_RETRAIT_FCFA.toLocaleString('fr-FR')} FCFA
            </span>
            {montantNum > 0 && montantNum < SEUIL_RETRAIT_FCFA && (
              <span className="text-label-sm text-reviz-danger">
                Encore {(SEUIL_RETRAIT_FCFA - montantNum).toLocaleString('fr-FR')} FCFA a accumuler
              </span>
            )}
          </div>

          {/* Operateur */}
          <div className="flex flex-col gap-space-4">
            <label className="text-label-md text-reviz-ink">Operateur Mobile Money</label>
            <Select
              value={operateur}
              onChange={(e) => setOperateur(e.target.value as any)}
              disabled={loading}
              options={[
                { value: 'mtn', label: 'MTN Mobile Money' },
                { value: 'moov', label: 'Moov Money' },
                { value: 'wave', label: 'Wave' },
              ]}
            />
          </div>

          {/* Telephone */}
          <div className="flex flex-col gap-space-4">
            <label className="text-label-md text-reviz-ink">Numero de telephone</label>
            <Input
              type="tel"
              placeholder="+229 xx xx xx xx"
              value={telephone}
              onChange={(e) => setTelephone(e.target.value)}
              disabled={loading}
            />
            <span className="text-label-sm text-reviz-muted">Au format international : +229 xx xx xx xx</span>
          </div>

          {/* Erreur */}
          {error && (
            <div className="flex items-start gap-space-8 rounded-lg bg-reviz-danger-light px-space-12 py-space-8">
              <Icon name="error" size={20} className="text-reviz-danger" filled />
              <p className="text-body-sm text-reviz-danger">{error}</p>
            </div>
          )}

          {/* CTA */}
          <Button
            type="submit"
            disabled={!montantOk || !telOk || loading}
            className="mt-space-12"
          >
            {loading ? 'Traitement...' : 'Demander le retrait'}
          </Button>
        </form>
      </Card>

      {/* Info */}
      <Card size="sm">
        <div className="flex flex-col gap-space-8">
          <div className="flex items-start gap-space-8">
            <Icon name="info" size={18} className="text-reviz-muted flex-shrink-0 mt-space-2" />
            <span className="text-label-sm text-reviz-muted">Tu recevras une notification WhatsApp quand ton retrait sera approuve. Les paiements prennent 1-2 jours.</span>
          </div>
        </div>
      </Card>

      {toast && <Toast message={toast} />}
    </div>
  )
}
