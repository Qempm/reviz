import 'server-only'
import type { ClientReviz } from '@/lib/supabase/jeton'
import { createAdminClient } from '@/lib/supabase/admin'
import { peutCorriger } from '@/lib/payments/subscriptions'

export type ResultatDepot =
  | { ok: true; correctionId: string }
  | { ok: false; error: 'session' | 'pack' | 'storage' | 'serveur' }

/**
 * Déposer une copie pour correction.
 *
 * Client Supabase injecté : la Server Action de l'écran web et la route
 * `/api/corrections` partagent cette implémentation.
 *
 * ATTENTION — les fichiers traversent ici une fonction serverless, dont la
 * charge utile est plafonnée à 4,5 Mo sur Vercel. Deux photos de copie de
 * 10 Mo (la limite du bucket) ne passeront pas. Le dépôt de cours a résolu
 * cela par une URL signée et un PUT direct ; la correction devra suivre le
 * même chemin. C'est repéré, pas corrigé ici.
 *
 * 1. Vérifier l'accès (pack actif + corrections restantes)
 * 2. Uploader les images vers Supabase Storage
 * 3. Créer l'enregistrement corrections (status='pending')
 * 4. Créer le job correct_copy
 */
export async function deposerCorrection(
  supabase: ClientReviz,
  userId: string,
  copie: File,
  sujet?: File,
): Promise<ResultatDepot> {
  // 2. Vérifie l'accès
  const { data: lignes } = await supabase
    .from('subscriptions')
    .select('pack_code, starts_at, ends_at, corrections_left')
    .order('ends_at', { ascending: false })

  const subscriptions = (lignes ?? []).map((l) => ({
    packCode: l.pack_code as 'decouverte' | 'controle' | 'partiel' | 'semestre' | 'rattrapage',
    startsAt: new Date(l.starts_at),
    endsAt: new Date(l.ends_at),
    correctionsLeft: l.corrections_left,
    subjectsLimit: null, // pas utilisé ici
  }))

  // Récupère l'état d'accès
  const now = new Date()
  const { data: activeSubs } = await supabase
    .from('subscriptions')
    .select('*')
    .eq('user_id', userId)
    .lte('starts_at', now.toISOString())
    .gt('ends_at', now.toISOString())
    .limit(1)

  if (!activeSubs || activeSubs.length === 0) return { ok: false, error: 'pack' }

  // Compte les corrections du jour
  const { count: correctionsDuJour } = await supabase
    .from('corrections')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .gte('created_at', new Date(now.toDateString()).toISOString())

  const droit = peutCorriger({
    acces: {
      state: 'active',
      endsAt: new Date(activeSubs[0].ends_at),
      daysLeft: 999,
      correctionsLeft: activeSubs[0].corrections_left,
      subjectsLimit: null,
      packCodes: [activeSubs[0].pack_code as any],
    },
    correctionsAujourdhui: correctionsDuJour ?? 0,
  })

  if (!droit.autorise) return { ok: false, error: 'pack' }

  // 3. Upload les images
  const admin = createAdminClient()
  const correctionId = crypto.randomUUID()
  const paths: string[] = []

  try {
    // Upload copie
    const copiePath = `${userId}/${correctionId}/copie-${Date.now()}`
    const buffer = await copie.arrayBuffer()
    const { error: uploadError } = await admin.storage
      // `copies` et non `corrections` : ce dernier n'existe pas. Les buckets
      // créés par 20260909180000 sont cours, copies, cartes et avatars.
      .from('copies')
      .upload(copiePath, buffer, {
        contentType: copie.type,
      })

    if (uploadError) {
      console.error('Upload copie error:', uploadError)
      return { ok: false, error: 'storage' }
    }
    paths.push(copiePath)

    // Upload sujet optionnel
    if (sujet) {
      const sujetPath = `${userId}/${correctionId}/sujet-${Date.now()}`
      const sujetBuffer = await sujet.arrayBuffer()
      const { error: sujetUploadError } = await admin.storage
        .from('copies')
        .upload(sujetPath, sujetBuffer, {
          contentType: sujet.type,
        })

      if (!sujetUploadError) {
        paths.push(sujetPath)
      }
    }
  } catch (e) {
    console.error('Upload error:', e)
    return { ok: false, error: 'storage' }
  }

  // 4. Créer l'enregistrement corrections
  const { data: correction, error: correctionError } = await admin
    .from('corrections')
    .insert({
      id: correctionId,
      user_id: userId,
      course_id: null, // Pas de cours associé
      storage_paths: paths,
      status: 'pending',
      grade: null,
      max_grade: 20, // Notation standard /20
      rubric: null,
      feedback: null,
      model_used: null,
      created_at: new Date().toISOString(),
    })
    .select('id')
    .single()

  if (correctionError || !correction) {
    console.error('Failed to create correction record:', correctionError)
    return { ok: false, error: 'serveur' }
  }

  // 5. Créer le job correct_copy
  const { error: jobError } = await admin
    .from('jobs')
    .insert({
      type: 'correct_copy',
      payload: {
        correction_id: correctionId,
        user_id: userId,
        storage_paths: paths,
      },
      status: 'queued',
      attempts: 0,
      last_error: null,
      run_after: new Date().toISOString(),
      created_at: new Date().toISOString(),
    })

  if (jobError) {
    console.error('Failed to create job:', jobError)
    return { ok: false, error: 'serveur' }
  }

  return { ok: true, correctionId }
}
