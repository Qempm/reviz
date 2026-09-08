/**
 * Page technique temporaire : elle atteste que le socle compile et que les
 * tokens du design system sont bien appliqués.
 *
 * Elle sera remplacée par le vrai tableau de bord à l'étape 3, après
 * validation du kitchen-sink. Ne pas y ajouter de logique métier.
 */
export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-space-16 px-screen-margin-mobile">
      <h1 className="text-headline-xl text-on-surface">Socle Reviz prêt</h1>
      <p className="text-body-md text-on-surface-variant text-center">
        Next.js, Tailwind et Supabase sont câblés.
        <br />
        Prochaine étape : les migrations SQL, puis le design system.
      </p>
      <div className="flex items-center gap-space-8">
        <span className="h-10 w-10 rounded-xl bg-reviz-yellow shadow-tactile" />
        <span className="h-10 w-10 rounded-xl bg-reviz-orange" />
        <span className="h-10 w-10 rounded-xl bg-reviz-blue" />
        <span className="h-10 w-10 rounded-xl bg-reviz-card border border-reviz-border" />
      </div>
    </main>
  )
}
