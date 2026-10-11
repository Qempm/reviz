'use client'

import { useRouter } from 'next/navigation'
import { createClientNavigateur } from '@/lib/supabase/navigateur'

export function Deconnexion() {
  const router = useRouter()
  return (
    <button
      type="button"
      onClick={async () => {
        await createClientNavigateur().auth.signOut()
        router.replace('/admin/connexion')
        router.refresh()
      }}
      className="shrink-0 rounded-full border border-[#E5D3A6] bg-reviz-card px-4 py-2 text-sm font-semibold text-reviz-ink hover:bg-reviz-surface-low focus-visible:outline focus-visible:outline-2 focus-visible:outline-reviz-ink"
    >
      Se déconnecter
    </button>
  )
}
