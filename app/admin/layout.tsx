import type { Metadata } from 'next'

/** L'espace administrateur : jamais indexé, jamais mis en cache. */
export const metadata: Metadata = {
  title: 'Administration · Reviz',
  robots: { index: false, follow: false },
}

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return <div className="min-h-screen bg-reviz-cream text-reviz-ink">{children}</div>
}
