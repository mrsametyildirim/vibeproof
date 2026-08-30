const HERO = supabase.storage.from("marketing").getPublicUrl("hero-2026.webp");

export function Hero() {
  return <img src={HERO.data.publicUrl} alt="" />;
}
