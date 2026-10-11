'use client'

import { useEffect, useRef, useState } from 'react'
import type { PaiementAdmin, Tableau } from '@/lib/admin/serveur'

/**
 * Les chiffres et les paiements, relus toutes les 15 s par
 * `/api/admin/flux`. Un paiement arrivé depuis la dernière lecture est
 * surligné quelques secondes.
 */

const INTERVALLE_MS = 15_000

const nombre = new Intl.NumberFormat('fr-FR')
const fcfa = (n: number) => `${nombre.format(n)} F`
const dollars = new Intl.NumberFormat('fr-FR', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 2,
})
const heure = new Intl.DateTimeFormat('fr-FR', {
  day: '2-digit',
  month: 'short',
  hour: '2-digit',
  minute: '2-digit',
  timeZone: 'Africa/Porto-Novo',
})
const horloge = new Intl.DateTimeFormat('fr-FR', {
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  timeZone: 'Africa/Porto-Novo',
})

const PACKS: Record<string, string> = {
  decouverte: 'Découverte',
  controle: 'Contrôle',
  partiel: 'Partiel',
  rattrapage: 'Rattrapage',
  semestre: 'Semestre',
}

const STATUTS: Record<string, { libelle: string; classe: string }> = {
  success: { libelle: 'Réussi', classe: 'bg-reviz-yellow text-reviz-ink' },
  pending: { libelle: 'En attente', classe: 'bg-reviz-orange-soft text-reviz-orange-deep' },
  failed: { libelle: 'Échoué', classe: 'bg-reviz-danger-soft text-reviz-danger' },
}

function Chiffre({ titre, valeur, detail }: { titre: string; valeur: string; detail?: string }) {
  return (
    <div className="flex min-w-0 flex-col gap-1 rounded-card bg-reviz-card p-5 shadow-card">
      <p className="text-xs font-semibold uppercase tracking-[0.1em] text-reviz-muted">{titre}</p>
      <p className="font-titre text-3xl tabular-nums">{valeur}</p>
      {detail && <p className="text-sm text-reviz-muted">{detail}</p>}
    </div>
  )
}

export function TableauDirect({
  tableauInitial,
  paiementsInitiaux,
  github,
}: {
  tableauInitial: Tableau | null
  paiementsInitiaux: PaiementAdmin[]
  github: { total: number; derniere: number; version: string | null }
}) {
  const [tableau, setTableau] = useState(tableauInitial)
  const [paiements, setPaiements] = useState(paiementsInitiaux)
  const [nouveaux, setNouveaux] = useState<Set<string>>(new Set())
  // Posée après le montage : le serveur et le navigateur ne lisent pas
  // l'heure à la même seconde, et un écart fait échouer l'hydratation.
  const [lu, setLu] = useState<Date | null>(null)
  const [horsLigne, setHorsLigne] = useState(false)
  const connus = useRef(new Set(paiementsInitiaux.map((p) => p.id)))

  useEffect(() => {
    setLu(new Date())
    let arret = false
    async function relire() {
      try {
        const res = await fetch('/api/admin/flux', { cache: 'no-store' })
        if (res.status === 401) {
          window.location.assign('/admin/connexion')
          return
        }
        const corps = await res.json()
        if (arret || !corps.ok) return
        const frais: PaiementAdmin[] = corps.data.paiements
        const arrives = frais.filter((p) => !connus.current.has(p.id)).map((p) => p.id)
        arrives.forEach((id) => connus.current.add(id))
        setTableau(corps.data.tableau)
        setPaiements(frais)
        setLu(new Date())
        setHorsLigne(false)
        if (arrives.length > 0) {
          setNouveaux(new Set(arrives))
          setTimeout(() => {
            if (!arret) setNouveaux(new Set())
          }, 8000)
        }
      } catch {
        if (!arret) setHorsLigne(true)
      }
    }
    const minuteur = setInterval(relire, INTERVALLE_MS)
    return () => {
      arret = true
      clearInterval(minuteur)
    }
  }, [])

  const t = tableau
  const packsActifs = t ? Object.values(t.packsActifs).reduce((s, n) => s + n, 0) : 0

  return (
    <>
      {!t && (
        <p className="rounded-card bg-reviz-danger-soft p-4 font-semibold text-reviz-danger">
          Les chiffres sont illisibles pour l’instant (base injoignable ou clé de service absente).
        </p>
      )}

      <section aria-label="Chiffres" className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Chiffre
          titre="Téléchargements"
          valeur={nombre.format(github.total)}
          detail={`GitHub, dont ${nombre.format(github.derniere)} pour ${github.version ?? 'la dernière'} · ${nombre.format(t?.telechargementsSite.total ?? 0)} clics sur le site`}
        />
        <Chiffre
          titre="Comptes"
          valeur={nombre.format(t?.comptes ?? 0)}
          detail={`+${nombre.format(t?.nouveaux.semaine ?? 0)} cette semaine · ${nombre.format(t?.verifies ?? 0)} vérifiés`}
        />
        <Chiffre
          titre="Actifs aujourd’hui"
          valeur={nombre.format(t?.actifs.jour ?? 0)}
          detail={`${nombre.format(t?.actifs.semaine ?? 0)} sur 7 jours · ${nombre.format(t?.actifs.mois ?? 0)} sur 30 jours`}
        />
        <Chiffre
          titre="Packs actifs"
          valeur={nombre.format(packsActifs)}
          detail={
            t && packsActifs > 0
              ? Object.entries(t.packsActifs)
                  .map(([code, n]) => `${PACKS[code] ?? code} ${n}`)
                  .join(' · ')
              : 'Aucun pack en cours'
          }
        />
        <Chiffre
          titre="Encaissé aujourd’hui"
          valeur={fcfa(t?.encaisse.jour ?? 0)}
          detail={`${fcfa(t?.encaisse.semaine ?? 0)} sur 7 jours · ${fcfa(t?.encaisse.mois ?? 0)} sur 30 jours`}
        />
        <Chiffre
          titre="Encaissé au total"
          valeur={fcfa(t?.encaisse.total ?? 0)}
          detail={`${nombre.format(t?.paiements.reussis ?? 0)} paiements réussis`}
        />
        <Chiffre
          titre="Coût de l’IA, 30 jours"
          valeur={dollars.format(t?.coutIa30j ?? 0)}
          detail="Claude, DeepSeek, Qwen et GLM"
        />
        <Chiffre
          titre="Révisions"
          valeur={nombre.format(t?.coursPrets ?? 0)}
          detail={`cours prêts · ${nombre.format(t?.corrections ?? 0)} copies · ${nombre.format(t?.tuteur ?? 0)} vérifications`}
        />
      </section>

      <section aria-label="Paiements" className="rounded-card bg-reviz-card p-5 shadow-card">
        <div className="flex flex-wrap items-baseline justify-between gap-2">
          <h2 className="font-titre text-2xl">Paiements en direct</h2>
          <p className="text-sm text-reviz-muted">
            {horsLigne
              ? 'Connexion perdue, nouvel essai dans 15 s'
              : lu
                ? `Relu à ${horloge.format(lu)} · toutes les 15 s`
                : 'Relu toutes les 15 s'}
            {t && ` · ${t.paiements.enAttente} en attente, ${t.paiements.echoues} échoués`}
          </p>
        </div>

        {paiements.length === 0 ? (
          <p className="mt-4 text-reviz-muted">Aucun paiement pour l’instant.</p>
        ) : (
          <div className="mt-4 overflow-x-auto">
            <table className="w-full min-w-[640px] border-collapse text-left text-sm">
              <thead>
                <tr className="text-xs uppercase tracking-[0.08em] text-reviz-muted">
                  <th className="py-2 pr-3 font-semibold">Quand</th>
                  <th className="py-2 pr-3 font-semibold">Étudiant</th>
                  <th className="py-2 pr-3 font-semibold">Pack</th>
                  <th className="py-2 pr-3 text-right font-semibold">Montant</th>
                  <th className="py-2 pr-3 font-semibold">Opérateur</th>
                  <th className="py-2 pr-3 font-semibold">Numéro</th>
                  <th className="py-2 font-semibold">Statut</th>
                </tr>
              </thead>
              <tbody>
                {paiements.map((p) => {
                  const s = STATUTS[p.statut] ?? {
                    libelle: p.statut,
                    classe: 'bg-reviz-surface-low text-reviz-ink',
                  }
                  return (
                    <tr
                      key={p.id}
                      className={`border-t border-[#EBDDB8] transition-colors ${nouveaux.has(p.id) ? 'bg-reviz-yellow-soft' : ''}`}
                    >
                      <td className="py-3 pr-3 tabular-nums">{heure.format(new Date(p.le))}</td>
                      <td className="py-3 pr-3">{p.prenom ?? '—'}</td>
                      <td className="py-3 pr-3">{p.pack ? (PACKS[p.pack] ?? p.pack) : '—'}</td>
                      <td className="py-3 pr-3 text-right font-semibold tabular-nums">{fcfa(p.montant)}</td>
                      <td className="py-3 pr-3">{p.operateur ?? '—'}</td>
                      <td className="py-3 pr-3 tabular-nums text-reviz-muted">{p.telephone}</td>
                      <td className="py-3">
                        <span className={`rounded-full px-3 py-1 text-xs font-semibold ${s.classe}`}>{s.libelle}</span>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </>
  )
}
