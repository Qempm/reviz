import { describe, expect, it, vi } from 'vitest'
import { runAiTask, ROUTES } from './routing'
import { estimateCost, MODELS } from './providers'
import { AiError, type ChatMessage } from './types'

const ENV = {
  DEEPSEEK_API_KEY: 'ds',
  DASHSCOPE_API_KEY: 'qw',
  ZAI_API_KEY: 'gl',
} as unknown as NodeJS.ProcessEnv

const QUESTIONS_VALIDES = {
  questions: [
    {
      type: 'mcq',
      statement: 'Quel organe contrôle la constitutionnalité des lois ?',
      options: ['La Cour suprême', 'La Cour constitutionnelle'],
      answer: 'La Cour constitutionnelle',
      probability: 'high',
    },
  ],
}

/** Réponse au format OpenAI Chat Completions. */
function reponse(content: unknown, usage?: Record<string, number>) {
  return new Response(
    JSON.stringify({
      choices: [
        {
          message: {
            content: typeof content === 'string' ? content : JSON.stringify(content),
          },
        },
      ],
      usage: usage ?? {
        prompt_tokens: 1000,
        completion_tokens: 500,
        prompt_cache_hit_tokens: 200,
      },
    }),
    { status: 200, headers: { 'content-type': 'application/json' } },
  )
}

function erreurHttp(status: number) {
  return new Response('boom', { status })
}

/** Construit un fetch qui répond dans l'ordre donné, puis échoue. */
function fetchSequence(...reponses: Response[]) {
  let i = 0
  const appels: string[] = []
  const impl = vi.fn(async (url: unknown, init?: unknown) => {
    appels.push(
      JSON.parse((init as { body: string }).body).model as string,
    )
    const r = reponses[i++]
    if (!r) throw new Error('Appel inattendu')
    return r
  })
  return { impl: impl as unknown as typeof fetch, appels }
}

const MESSAGES: ChatMessage[] = [{ role: 'user', content: 'Génère des QCM.' }]

describe('table de routage', () => {
  it('suit l’ordre DeepSeek → Qwen → GLM sur le texte', () => {
    expect(ROUTES.questions).toEqual(['deepseekFlash', 'qwenFlash', 'glmFlash'])
  })

  it('route la correction vers les deux modèles de raisonnement', () => {
    // docs/STACK-IA.md § 0 : deepseek-v4-pro puis glm-5.3, pas les modèles
    // Flash qui n'apportent rien sur une copie notée.
    expect(ROUTES.correction).toEqual(['deepseekPro', 'glmPro'])
    expect(MODELS.deepseekPro.thinking).toBe(true)
    expect(MODELS.deepseekPro.reasoningEffort).toBe('high')
  })

  it('route la vision vers GLM avant Qwen', () => {
    // glm-5.3-flash a la vision native ; côté Qwen c'est qwen3-vl-flash et
    // non qwen3.8-flash (docs/STACK-IA.md § 2.1 et 3.1).
    expect(ROUTES.student_card).toEqual([
      'deepseekVision',
      'glmFlash',
      'qwenVlFlash',
    ])
    expect(MODELS.glmFlash.capabilities).toContain('vision')
    expect(MODELS.qwenFlash.capabilities).not.toContain('vision')
    expect(MODELS.qwenVlFlash.capabilities).toContain('vision')
  })

  it('réussit sur le premier fournisseur sans appeler les suivants', async () => {
    const { impl, appels } = fetchSequence(reponse(QUESTIONS_VALIDES))
    const usages: unknown[] = []

    const res = await runAiTask({
      task: 'questions',
      messages: MESSAGES,
      env: ENV,
      fetchImpl: impl,
      retryDelayMs: 0,
      recordUsage: (u) => void usages.push(u),
    })

    expect(res.provider).toBe('deepseek')
    expect(appels).toEqual(['deepseek-v4-flash'])
    expect(res.attempts).toHaveLength(1)
    expect(res.attempts[0].outcome).toBe('success')
    expect(usages).toHaveLength(1)
  })

  it('bascule sur erreur HTTP', async () => {
    const { impl, appels } = fetchSequence(
      erreurHttp(500),
      reponse(QUESTIONS_VALIDES),
    )

    const res = await runAiTask({
      task: 'questions',
      messages: MESSAGES,
      env: ENV,
      fetchImpl: impl,
      retryDelayMs: 0,
    })

    expect(appels).toEqual(['deepseek-v4-flash', 'qwen3.8-flash'])
    expect(res.provider).toBe('qwen')
    expect(res.attempts[0].outcome).toBe('http_error')
  })

  it('bascule sur JSON illisible et consigne les jetons déjà consommés', async () => {
    const { impl, appels } = fetchSequence(
      reponse('désolé, je ne peux pas répondre'),
      reponse(QUESTIONS_VALIDES),
    )
    const usages: Array<{ provider: string; costUsdEstimate: number }> = []

    const res = await runAiTask({
      task: 'questions',
      messages: MESSAGES,
      env: ENV,
      fetchImpl: impl,
      retryDelayMs: 0,
      recordUsage: (u) => void usages.push(u),
    })

    expect(appels).toHaveLength(2)
    expect(res.attempts[0].outcome).toBe('invalid_json')
    // L'appel raté a bien consommé des jetons : il doit apparaître dans
    // ai_usage, sinon le suivi de coût est faux.
    expect(usages).toHaveLength(2)
    expect(usages[0].provider).toBe('deepseek')
    expect(usages[0].costUsdEstimate).toBeGreaterThan(0)
  })

  it('bascule quand le JSON ne respecte pas le schéma', async () => {
    // Un QCM avec une seule proposition : refusé par questionSchema.
    const invalide = {
      questions: [
        {
          type: 'mcq',
          statement: 'Question tronquée',
          options: ['seule proposition'],
          answer: 'seule proposition',
        },
      ],
    }
    const { impl } = fetchSequence(reponse(invalide), reponse(QUESTIONS_VALIDES))

    const res = await runAiTask({
      task: 'questions',
      messages: MESSAGES,
      env: ENV,
      fetchImpl: impl,
      retryDelayMs: 0,
    })

    expect(res.attempts[0].outcome).toBe('schema_error')
    expect(res.provider).toBe('qwen')
  })

  it('saute les modèles sans vision quand la demande porte une image', async () => {
    const avecImage: ChatMessage[] = [
      {
        role: 'user',
        content: [
          { type: 'text', text: 'Lis cette carte.' },
          { type: 'image_url', image_url: { url: 'https://exemple/carte.jpg' } },
        ],
      },
    ]

    const { impl, appels } = fetchSequence(
      reponse({ isReadable: false, confidence: 0.1 }),
    )

    const res = await runAiTask({
      task: 'student_card',
      messages: avecImage,
      env: ENV,
      fetchImpl: impl,
      retryDelayMs: 0,
    })

    // deepseekVision traite les images : il est appelé en premier et suffit.
    expect(appels).toEqual(['deepseek-v4-flash-vision-exp'])
    expect(res.provider).toBe('deepseek')
  })

  it('saute un fournisseur dont la clé est absente', async () => {
    const { impl, appels } = fetchSequence(reponse(QUESTIONS_VALIDES))

    const res = await runAiTask({
      task: 'questions',
      messages: MESSAGES,
      env: { DASHSCOPE_API_KEY: 'qw' } as unknown as NodeJS.ProcessEnv,
      fetchImpl: impl,
      retryDelayMs: 0,
    })

    expect(appels).toEqual(['qwen3.8-flash'])
    expect(res.attempts[0].outcome).toBe('skipped_capability')
    expect(res.attempts[0].error).toMatch(/Clé absente/)
    expect(res.provider).toBe('qwen')
  })

  it('lève AiError quand toute la chaîne échoue', async () => {
    const { impl } = fetchSequence(
      erreurHttp(500),
      erreurHttp(429),
      erreurHttp(503),
    )

    await expect(
      runAiTask({
        task: 'questions',
        messages: MESSAGES,
        env: ENV,
        fetchImpl: impl,
        retryDelayMs: 0,
      }),
    ).rejects.toBeInstanceOf(AiError)
  })

  it('accepte un JSON encadré de balises markdown', async () => {
    const { impl } = fetchSequence(
      reponse('```json\n' + JSON.stringify(QUESTIONS_VALIDES) + '\n```'),
    )

    const res = await runAiTask({
      task: 'questions',
      messages: MESSAGES,
      env: ENV,
      fetchImpl: impl,
      retryDelayMs: 0,
    })

    expect(res.attempts[0].outcome).toBe('success')
  })
})

describe('estimation du coût', () => {
  it('facture le cache à part sans compter deux fois les jetons d’entrée', () => {
    const spec = MODELS.deepseekFlash
    const cout = estimateCost(spec, {
      promptTokens: 1_000_000,
      completionTokens: 0,
      cacheHitTokens: 1_000_000,
    })
    // Tous les jetons d'entrée viennent du cache : on paie le tarif cache.
    expect(cout).toBeCloseTo(spec.pricing.cacheHit, 6)
  })

  it('somme entrée, sortie et cache', () => {
    const spec = MODELS.deepseekFlash
    const cout = estimateCost(spec, {
      promptTokens: 1_000_000,
      completionTokens: 1_000_000,
      cacheHitTokens: 0,
    })
    expect(cout).toBeCloseTo(spec.pricing.input + spec.pricing.output, 6)
  })
})

describe('réessai avant bascule', () => {
  it('réessaie trois fois sur 429 puis bascule', async () => {
    const { impl, appels } = fetchSequence(
      erreurHttp(429),
      erreurHttp(429),
      erreurHttp(429),
      reponse(QUESTIONS_VALIDES),
    )

    const res = await runAiTask({
      task: 'questions',
      messages: MESSAGES,
      env: ENV,
      fetchImpl: impl,
      retryDelayMs: 0,
    })

    // Trois tentatives chez DeepSeek, puis Qwen (docs/STACK-IA.md § 1.7).
    expect(appels).toEqual([
      'deepseek-v4-flash',
      'deepseek-v4-flash',
      'deepseek-v4-flash',
      'qwen3.8-flash',
    ])
    expect(res.provider).toBe('qwen')
    expect(res.attempts.filter((a) => a.outcome === 'http_error')).toHaveLength(3)
  })

  it('ne réessaie pas un 500 : il bascule tout de suite', async () => {
    const { impl, appels } = fetchSequence(
      erreurHttp(500),
      reponse(QUESTIONS_VALIDES),
    )

    await runAiTask({
      task: 'questions',
      messages: MESSAGES,
      env: ENV,
      fetchImpl: impl,
      retryDelayMs: 0,
    })

    expect(appels).toEqual(['deepseek-v4-flash', 'qwen3.8-flash'])
  })

  it('réessaie un contenu vide renvoyé en mode JSON', async () => {
    const { impl, appels } = fetchSequence(
      reponse(''),
      reponse(QUESTIONS_VALIDES),
    )

    const res = await runAiTask({
      task: 'questions',
      messages: MESSAGES,
      env: ENV,
      fetchImpl: impl,
      retryDelayMs: 0,
    })

    expect(res.attempts[0].outcome).toBe('empty_content')
    // Même fournisseur : le contenu vide est un aléa, pas une panne.
    expect(appels).toEqual(['deepseek-v4-flash', 'deepseek-v4-flash'])
    expect(res.provider).toBe('deepseek')
  })
})

describe('paramètres envoyés au fournisseur', () => {
  /** Capture le corps du PREMIER appel — celui adressé à DeepSeek. */
  async function corpsEnvoye(
    task: 'questions' | 'correction',
    reponses: Response[],
  ): Promise<Record<string, unknown>> {
    let corps: Record<string, unknown> | null = null
    const impl = (async (_url: unknown, init?: unknown) => {
      if (corps === null) corps = JSON.parse((init as { body: string }).body)
      return reponses.shift() ?? erreurHttp(503)
    }) as unknown as typeof fetch

    await runAiTask({
      task,
      messages: MESSAGES,
      env: ENV,
      fetchImpl: impl,
      retryDelayMs: 0,
      userId: 'etudiant_123',
    }).catch(() => undefined)

    return corps ?? {}
  }

  it('donne de la latitude aux QCM et de la rigueur aux corrections', async () => {
    const qcm = await corpsEnvoye('questions', [reponse(QUESTIONS_VALIDES)])
    expect(qcm.temperature).toBe(0.7)
    expect(qcm.max_tokens).toBe(8000)
    expect(qcm.response_format).toEqual({ type: 'json_object' })

    const corr = await corpsEnvoye('correction', [erreurHttp(500)])
    expect(corr.temperature).toBe(0.2)
    expect(corr.max_tokens).toBe(4000)
  })

  it('n’envoie user_id et thinking qu’à DeepSeek', async () => {
    const chezDeepSeek = await corpsEnvoye('correction', [erreurHttp(500)])
    expect(chezDeepSeek.user_id).toBe('etudiant_123')
    expect(chezDeepSeek.thinking).toEqual({ type: 'enabled' })
    expect(chezDeepSeek.reasoning_effort).toBe('high')

    // Deuxième maillon de la route correction : GLM. Ni user_id ni thinking.
    let corpsGlm: Record<string, unknown> = {}
    let appel = 0
    const impl = (async (_url: unknown, init?: unknown) => {
      appel++
      if (appel === 1) return erreurHttp(500)
      corpsGlm = JSON.parse((init as { body: string }).body)
      return erreurHttp(500)
    }) as unknown as typeof fetch

    await runAiTask({
      task: 'correction',
      messages: MESSAGES,
      env: ENV,
      fetchImpl: impl,
      retryDelayMs: 0,
      userId: 'etudiant_123',
    }).catch(() => undefined)

    expect(corpsGlm.model).toBe('glm-5.3')
    expect(corpsGlm.user_id).toBeUndefined()
    expect(corpsGlm.thinking).toBeUndefined()
    expect(corpsGlm.reasoning_effort).toBe('high')
  })
})

describe('tarif heures pleines', () => {
  const usage = { promptTokens: 1_000_000, completionTokens: 0, cacheHitTokens: 0 }
  const creuses = new Date(Date.UTC(2026, 8, 9, 12, 0, 0)) // mercredi 12:00
  const pleines = new Date(Date.UTC(2026, 8, 9, 7, 0, 0)) // mercredi 07:00

  it('double le tarif DeepSeek en heures pleines', () => {
    const bas = estimateCost(MODELS.deepseekFlash, usage, creuses)
    const haut = estimateCost(MODELS.deepseekFlash, usage, pleines)
    expect(bas).toBeCloseTo(0.22, 6)
    expect(haut).toBeCloseTo(0.44, 6)
  })

  it('laisse Qwen et GLM insensibles à l’heure', () => {
    for (const spec of [MODELS.qwenFlash, MODELS.glmFlash]) {
      expect(estimateCost(spec, usage, creuses)).toBeCloseTo(
        estimateCost(spec, usage, pleines),
        6,
      )
    }
  })
})
