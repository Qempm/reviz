import { describe, expect, it, vi } from 'vitest'
import { runJobs, type JobStore } from './runner'
import { MAX_ATTEMPTS } from './policy'
import { PermanentJobError, type Job, type JobType } from './types'

const T0 = new Date('2026-09-09T12:00:00Z')

function job(over: Partial<Job> = {}): Job {
  return {
    id: 'j1',
    type: 'notify',
    payload: {},
    status: 'running',
    attempts: 1,
    lastError: null,
    runAfter: T0,
    createdAt: T0,
    startedAt: T0,
    finishedAt: null,
    ...over,
  }
}

/** Magasin en mémoire, qui enregistre les appels reçus. */
function magasin(lot: Job[]) {
  const done: string[] = []
  const failed: Array<{ id: string; error: string }> = []
  const requeued: Array<{ id: string; runAfter: Date; error: string }> = []

  const store: JobStore = {
    claim: vi.fn(async () => lot),
    markDone: vi.fn(async (id) => void done.push(id)),
    markFailed: vi.fn(async (id, e) => void failed.push({ id, error: e })),
    requeue: vi.fn(async (id, runAfter, e) =>
      void requeued.push({ id, runAfter, error: e }),
    ),
  }

  return { store, done, failed, requeued }
}

describe('exécution d’un lot', () => {
  it('clôture un job traité sans erreur', async () => {
    const { store, done } = magasin([job()])

    const r = await runJobs({
      store,
      handlers: { notify: async () => {} },
      now: () => T0,
    })

    expect(r).toMatchObject({ claimed: 1, done: 1, requeued: 0, failed: 0 })
    expect(done).toEqual(['j1'])
    expect(r.jobs[0].outcome).toBe('done')
  })

  it('traite les jobs les uns après les autres', async () => {
    const ordre: string[] = []
    const { store } = magasin([
      job({ id: 'a' }),
      job({ id: 'b' }),
      job({ id: 'c' }),
    ])

    await runJobs({
      store,
      handlers: {
        notify: async (j) => {
          ordre.push(`debut-${j.id}`)
          await new Promise((r) => setTimeout(r, 1))
          ordre.push(`fin-${j.id}`)
        },
      },
      now: () => T0,
    })

    // Séquentiel : aucun début ne s'intercale avant la fin du précédent.
    expect(ordre).toEqual([
      'debut-a', 'fin-a',
      'debut-b', 'fin-b',
      'debut-c', 'fin-c',
    ])
  })

  it('remet en file avec un délai croissant après un échec', async () => {
    const { store, requeued } = magasin([job({ attempts: 1 })])

    const r = await runJobs({
      store,
      handlers: {
        notify: async () => {
          throw new Error('n8n injoignable')
        },
      },
      now: () => T0,
    })

    expect(r.requeued).toBe(1)
    expect(requeued[0].error).toContain('n8n injoignable')
    // Première tentative échouée : nouvel essai dans une minute.
    expect(requeued[0].runAfter.toISOString()).toBe('2026-09-09T12:01:00.000Z')
  })

  it('abandonne au bout de MAX_ATTEMPTS', async () => {
    const { store, failed, requeued } = magasin([job({ attempts: MAX_ATTEMPTS })])

    const r = await runJobs({
      store,
      handlers: {
        notify: async () => {
          throw new Error('toujours en panne')
        },
      },
      now: () => T0,
    })

    expect(r.failed).toBe(1)
    expect(requeued).toHaveLength(0)
    expect(failed[0].id).toBe('j1')
  })

  it('abandonne tout de suite sur une erreur permanente', async () => {
    const { store, failed } = magasin([job({ attempts: 1 })])

    const r = await runJobs({
      store,
      handlers: {
        notify: async () => {
          throw new PermanentJobError('charge utile invalide')
        },
      },
      now: () => T0,
    })

    // Une seule tentative consommée sur cinq, et pourtant abandon : un
    // réessai ne réparerait rien.
    expect(r.failed).toBe(1)
    expect(failed[0].error).toContain('charge utile invalide')
  })

  it('abandonne un type sans traitement enregistré', async () => {
    const { store, failed, requeued } = magasin([
      job({ type: 'ingest_course' as JobType, attempts: 1 }),
    ])

    const r = await runJobs({ store, handlers: {}, now: () => T0 })

    expect(r.failed).toBe(1)
    expect(requeued).toHaveLength(0)
    expect(failed[0].error).toMatch(/Aucun traitement enregistré/)
  })

  it('isole les échecs : un job raté n’arrête pas le lot', async () => {
    const { store, done, requeued } = magasin([
      job({ id: 'a' }),
      job({ id: 'b' }),
      job({ id: 'c' }),
    ])

    const r = await runJobs({
      store,
      handlers: {
        notify: async (j) => {
          if (j.id === 'b') throw new Error('panne isolée')
        },
      },
      now: () => T0,
    })

    expect(r).toMatchObject({ claimed: 3, done: 2, requeued: 1, failed: 0 })
    expect(done).toEqual(['a', 'c'])
    expect(requeued[0].id).toBe('b')
  })

  it('s’arrête à l’échéance sans démarrer de job qu’il ne finirait pas', async () => {
    const { store, done } = magasin([job({ id: 'a' }), job({ id: 'b' })])

    let appels = 0
    const horloge = () => {
      // Premier contrôle : dans les temps. Suivant : échéance dépassée.
      appels++
      return appels <= 1 ? T0 : new Date(T0.getTime() + 60_000)
    }

    const r = await runJobs({
      store,
      handlers: { notify: async () => {} },
      now: horloge,
      deadline: new Date(T0.getTime() + 30_000),
    })

    // Le second job reste en `running` : il sera repris comme abandonné.
    expect(r.claimed).toBe(2)
    expect(done).toEqual(['a'])
    expect(r.jobs).toHaveLength(1)
  })

  it('transmet la taille de lot et le seuil d’abandon au magasin', async () => {
    const { store } = magasin([])

    await runJobs({
      store,
      handlers: {},
      batchSize: 3,
      staleAfterMinutes: 7,
      now: () => T0,
    })

    expect(store.claim).toHaveBeenCalledWith(3, 7)
  })

  it('ne fait rien quand la file est vide', async () => {
    const { store } = magasin([])
    const r = await runJobs({ store, handlers: {}, now: () => T0 })
    expect(r).toMatchObject({ claimed: 0, done: 0, requeued: 0, failed: 0 })
  })
})
