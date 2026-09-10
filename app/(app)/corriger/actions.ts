'use server'

import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import { peutCorriger } from '@/lib/payments/subscriptions'

export type ResultatDepot =
  | { ok: true; correctionId: string }
  | { ok: false; error: 'session' | 'pack' | 'storage' | 'serveur' }

/**
 * Déposer une copie pour correction.
 *
 * 1. Vérifier l'accès (pack actif + corrections restantes)
 * 2. Uploader les images vers Supabase Storage
 * 3. Créer l'enregistrement corrections (status='pending')
 * 4. Créer le job correct_copy
 */
export async function deposerCorrection(
  copie: File,
  sujet?: File,
): Promise<ResultatDepot> {
  const supabase = await createClient()

  // 1. Récupère l'utilisateur
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return { ok: false, error: 'session' }

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
    .eq('user_id', user.id)
    .lte('starts_at', now.toISOString())
    .gt('ends_at', now.toISOString())
    .limit(1)

  if (!activeSubs || activeSubs.length === 0) return { ok: false, error: 'pack' }

  // Compte les corrections du jour
  const { count: correctionsDuJour } = await supabase
    .from('corrections')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', user.id)
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
    const copiePath = `${user.id}/${correctionId}/copie-${Date.now()}`
    const buffer = await copie.arrayBuffer()
    const { error: uploadError } = await admin.storage
      .from('corrections')
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
      const sujetPath = `${user.id}/${correctionId}/sujet-${Date.now()}`
      const sujetBuffer = await sujet.arrayBuffer()
      const { error: sujetUploadError } = await admin.storage
        .from('corrections')
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
      user_id: user.id,
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
        user_id: user.id,
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
