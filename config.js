// Configuración de conexión con Supabase.
// Pega aquí los dos datos de Supabase → Project Settings → API.
// La clave "anon" (o "publishable") es pública por diseño: lo que protege los datos
// son las reglas del servidor. NUNCA pongas aquí la clave "service_role" ni la "secret".
window.PORFIN_CONFIG = {
  url: 'https://rmpuoxflxgrjxyfhxzua.supabase.co',   // ej.: 'https://abcdefghijkl.supabase.co'
  key: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJtcHVveGZseGdyanh5Zmh4enVhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIxNDU4NTgsImV4cCI6MjEwNzcyMTg1OH0.cdyJ4Ul7CEOgQSrj7NU8RKSUtfyuUCMODLoInV9wPw8'    // ej.: 'eyJhbGciOi...' o 'sb_publishable_...'
};
