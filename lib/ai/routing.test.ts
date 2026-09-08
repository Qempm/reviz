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
  it('suit l’ordre DeepSeek → Qwen → GLM', () => {
    expect(ROUTES.questions).toEqual(['deepseekFlash', 'qwenFlash', 'glmFlash'])
    expect(ROUTES.correction[0]).toBe('deepseekPro')
    expect(MODELS.deepseekPro.thinking).toBe(true)
  })

  it('réussit sur le premier fournisseur sans appeler les suivants', async () => {
    const { impl, appels } = fetchSequence(reponse(QUESTIONS_VALIDES))
    const usages: unknown[] = []

    const res = await runAiTask({
      task: 'questions',
      messages: MESSAGES,
      env: ENV,
      fetchImpl: impl,
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
