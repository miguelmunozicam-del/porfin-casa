// Configuración de conexión con Supabase.
// Pega aquí los dos datos de Supabase → Project Settings → API.
// La clave "anon" (o "publishable") es pública por diseño: lo que protege los datos
// son las reglas del servidor. NUNCA pongas aquí la clave "service_role" ni la "secret".
window.PORFIN_CONFIG = {
  url: '',   // ej.: 'https://abcdefghijkl.supabase.co'
  key: ''    // ej.: 'eyJhbGciOi...' o 'sb_publishable_...'
};
