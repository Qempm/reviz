'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { Button, Card, Icon } from '@/components/ui'

/**
 * Ecran - Selection d'avatar.
 *
 * Affiche 24 avatars disponibles et permet de changer le sien.
 */

const AVATARS = [
  'avatar-1-garcon-sourire',
  'avatar-2-fille-lunettes',
  'avatar-3-garcon-cheveux-rouges',
  'avatar-4-fille-cheveux-longs',
  'avatar-5-garcon-cap',
  'avatar-6-fille-boucles',
  'avatar-7-garcon-noir',
  'avatar-8-fille-noir',
  'avatar-9-garcon-taches',
  'avatar-10-fille-taches',
  'avatar-11-garcon-cheveux-courts',
  'avatar-12-fille-cheveux-courts',
  'avatar-13-garcon-costume',
  'avatar-14-fille-robe',
  'avatar-15-garcon-casual',
  'avatar-16-fille-casual',
  'avatar-17-garcon-sportif',
  'avatar-18-fille-sportive',
  'avatar-19-garcon-barbe',
  'avatar-20-fille-maquillage',
  'avatar-21-garcon-hipster',
  'avatar-22-fille-hipster',
  'avatar-23-garcon-star',
  'avatar-24-fille-star',
]

export default function SelectionAvatar() {
  const router = useRouter()
  const [selected, setSelected] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  const handleSelect = async (avatar: string) => {
    setSelected(avatar)
    setLoading(true)

    try {
      const res = await fetch('/api/profile/avatar', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ avatar_key: avatar }),
      })

      const data = await res.json()
      if (data.ok) {
        setTimeout(() => {
          router.push('/profil')
        }, 500)
      }
    } catch (e) {
      console.error(e)
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
        <h1 className="text-headline-xl text-reviz-ink">Choisir un avatar</h1>
        <p className="text-body-md text-reviz-muted">Quelle tete feras-tu ?</p>
      </header>

      {/* Grille d'avatars */}
      <div className="grid grid-cols-3 gap-space-12">
        {AVATARS.map((avatar) => (
          <button
            key={avatar}
            onClick={() => handleSelect(avatar)}
            disabled={loading}
            className={`flex aspect-square flex-col items-center justify-center rounded-xl border-2 transition-all ${
              selected === avatar
                ? 'border-reviz-yellow bg-reviz-yellow-soft'
                : 'border-reviz-border bg-reviz-card hover:border-reviz-yellow'
            } ${loading ? 'opacity-50' : ''}`}
          >
            {/* Placeholder avatar avec initiales */}
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-reviz-yellow text-headline-md font-bold text-reviz-on-yellow">
              {avatar.substring(7, 9).toUpperCase()}
            </div>
            <span className="mt-space-8 text-center text-caption text-reviz-muted px-space-4 line-clamp-2">
              {avatar.substring(10).replace(/-/g, ' ')}
            </span>
          </button>
        ))}
      </div>
    </div>
  )
}
