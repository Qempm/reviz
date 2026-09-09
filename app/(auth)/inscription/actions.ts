'use server'

import { z } from 'zod'
import { createAdminClient } from '@/lib/supabase/admin'
import { createClient } from '@/lib/supabase/server'
import { normaliserTelephone, paysParCode, PAYS_PAR_DEFAUT } from '@/lib/auth/phone'
import { TAUX_AMBASSADEUR, TAUX_STANDARD } from '@/lib/payments/commission'
import type { Reponse } from '../actions'

/**
 * B2 — Création du profil après la première connexion.
 *
 * Le numéro est facultatif depuis le passage à Google/email : il ne sert
 * qu'aux notifications WhatsApp, il n'est ni obligatoire ni vérifié
 * (CLAUDE.md, règle métier 3).
 */

const schema = z.object({
  prenom: z.string().trim().min(2).max(60),
  universiteId: z.string().uuid(),
  faculteId: z.string().uuid(),
  annee: z.coerce.number().int().min(1).max(7),
  telephone: z.string().trim().max(30).optional(),
  pays: z.string().length(2).default('BJ'),
  codeParrain: z.string().trim().max(12).optional(),
})

export type EntreeProfil = z.input<typeof schema>

export async function creerProfil(
  entree: EntreeProfil,
): Promise<Reponse<{ id: string }>> {
  const parsed = schema.safeParse(entree)
  if (!parsed.success) {
    const premier = parsed.error.issues[0]
    const champs: Record<string, string> = {
      prenom: 'Entre ton prénom.',
      universiteId: 'Choisis ton université.',
      faculteId: 'Choisis ta filière.',
      annee: 'Choisis ton année.',
    }
    const champ = String(premier?.path[0] ?? '')
    return {
      ok: false,
      error: champs[champ] ?? 'Vérifie les informations saisies.',
      champ,
    }
  }

  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) {
    return { ok: false, error: 'Ta session a expiré. Reconnecte-toi.' }
  }

  const d = parsed.data

  // Téléphone : facultatif, normalisé s'il est fourni.
  let telephone: string | null = null
  if (d.telephone && d.telephone.length > 0) {
    const pays = paysParCode(d.pays) ?? PAYS_PAR_DEFAUT
    const numero = normaliserTelephone(d.telephone, pays)
    if (!numero.ok) {
      return {
        ok: false,
        error: `Ce numéro ne ressemble pas à un numéro ${pays.nom}.`,
        champ: 'telephone',
      }
    }
    telephone = numero.e164
  }

  // Le code parrain désigne un profil dont on ne peut rien lire sous RLS :
  // la recherche passe par le rôle de service.
  let parrain: { id: string; is_ambassador: boolean } | null = null
  if (d.codeParrain && d.codeParrain.length > 0) {
    let data: { id: string; is_ambassador: boolean } | null = null

    try {
      const admin = createAdminClient()
      const resultat = await admin
        .from('profiles')
        .select('id, is_ambassador')
        .eq('referral_code', d.codeParrain.toUpperCase())
        .maybeSingle()
      data = resultat.data
    } catch (e) {
      // Clé de service absente : on le dit franchement au lieu de laisser
      // l'action planter sur un message technique.
      console.error('[inscription] recherche du parrain impossible', e)
      return {
        ok: false,
        error:
          'La vérification du code parrain est indisponible. Réessaie sans le code, tu pourras l’ajouter plus tard.',
        champ: 'codeParrain',
      }
    }

    if (!data) {
      return { ok: false, error: 'Ce code parrain n’existe pas.', champ: 'codeParrain' }
    }
    if (data.id === user.id) {
      return {
        ok: false,
        error: 'Tu ne peux pas être ton propre parrain.',
        champ: 'codeParrain',
      }
    }
    parrain = data
  }

  const { data: profil, error } = await supabase
    .from('profiles')
    .insert({
      id: user.id,
      phone: telephone,
      first_name: d.prenom,
      university_id: d.universiteId,
      faculty_id: d.faculteId,
      study_year: d.annee,
      referred_by: parrain?.id ?? null,
    })
    .select('id')
    .single()

  if (error) {
    // 23505 : violation d'unicité. Le seul champ unique saisissable ici est
    // le téléphone.
    if (error.code === '23505') {
      return {
        ok: false,
        error: 'Ce numéro est déjà lié à un autre compte.',
        champ: 'telephone',
      }
    }
    return { ok: false, error: 'On n’a pas pu créer ton profil. Réessaie.' }
  }

  // Le parrainage vit dans une table fermée au client : rôle de service.
  // Un échec ici ne doit pas annuler l'inscription — le profil est créé, le
  // lien de parrainage se rattrape, l'étudiant ne doit pas rester bloqué.
  if (parrain) {
    try {
      const admin = createAdminClient()
      const { error: erreurParrainage } = await admin.from('referrals').insert({
        referrer_id: parrain.id,
        referred_id: user.id,
        // Le taux définitif est recalculé au paiement ; on enregistre celui
        // qui s'applique aujourd'hui.
        commission_rate: parrain.is_ambassador ? TAUX_AMBASSADEUR : TAUX_STANDARD,
      })

      if (erreurParrainage) {
        console.error('[inscription] parrainage non enregistré', erreurParrainage.message)
      }
    } catch (e) {
      console.error('[inscription] parrainage non enregistré', e)
    }
  }

  return { ok: true, data: { id: profil.id } }
}
