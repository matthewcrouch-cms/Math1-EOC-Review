// ====== SETTINGS ======
// Paste your Supabase project URL and publishable (anon) key here.
// Supabase → Project Settings → API (or "Connect"). The publishable key is safe to put in a public site.
window.EOC_CONFIG = {
  SUPABASE_URL: "https://ttyuhuoxexhymmlonjpg.supabase.co",
  SUPABASE_KEY: "sb_publishable_Ebx7fD8CAe4n7UFuuwVjeg_eTa0KRd-",
  SITE_NAME: "BR: Math 1 EOC Review",
};
// Local testing only: when the site runs on localhost it talks to the local test server instead.
if (/^(localhost|127\.0\.0\.1)$/.test(location.hostname)) {
  window.EOC_CONFIG.SUPABASE_URL = location.origin;
  window.EOC_CONFIG.SUPABASE_KEY = "local";
}
