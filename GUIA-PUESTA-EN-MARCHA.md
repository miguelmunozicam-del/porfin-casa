# ¡Por Fin! · Guía de puesta en marcha (v1.0)

Tiempo total: unos 30 minutos. Coste: 0 €.

---

## Paso 1 · Crear el proyecto en Supabase (5 min)

1. Entra en <https://supabase.com> → **Start your project** → inicia sesión con GitHub.
2. **New project**:
   - Name: `porfin`
   - Database Password: genera una y guárdala en tu gestor de contraseñas (no la necesitará la app).
   - Region: **Central EU (Frankfurt)**
   - Plan: **Free**
3. Espera 1-2 minutos a que el proyecto esté listo.

## Paso 2 · Crear la base de datos (2 min)

1. Menú izquierdo → **SQL Editor** → **New query**.
2. Abre `supabase/esquema.sql`, copia todo, pégalo y pulsa **Run**.
3. Debe aparecer *Success. No rows returned*. Si sale un aviso de seguridad sobre funciones `security definer`, es esperado (así se protegen los datos): confirma.

## Paso 3 · Conectar tu Gmail para enviar los códigos (10 min)

Supabase, sin configurar, **solo envía correos a los miembros de tu equipo en Supabase y como máximo 2 por hora**. Tu familia no recibiría el código. Lo resolvemos enviando desde tu Gmail.

**3a · Crea una contraseña de aplicación en Google**
1. Tu cuenta de Google debe tener activada la **verificación en dos pasos** (<https://myaccount.google.com/security>).
2. Ve a <https://myaccount.google.com/apppasswords>, escribe el nombre `Por Fin Supabase` y pulsa **Crear**.
3. Copia la contraseña de 16 letras (sin espacios). Solo se muestra una vez.

**3b · Configúrala en Supabase**
Supabase → **Authentication** → **Emails** → pestaña **SMTP Settings** → activa **Enable Custom SMTP**:

| Campo | Valor |
|---|---|
| Sender email | tu Gmail (ej. `miguelmunoz.icam@gmail.com`) |
| Sender name | `¡Por Fin!` |
| Host | `smtp.gmail.com` |
| Port number | `465` |
| Minimum interval | `60` |
| Username | tu Gmail completo |
| Password | la contraseña de aplicación de 16 letras |

Guarda (**Save changes**).

## Paso 4 · Que el correo lleve un código y no un enlace (3 min)

1. **Authentication → Emails → Templates**.
2. Plantilla **Magic Link**:
   - Subject: `Tu código para ¡Por Fin!: {{ .Token }}`
   - Body: pega el contenido de `supabase/plantilla-email.html`.
   - Guarda.
3. Repite lo mismo en la plantilla **Confirm signup** (es la que reciben quienes entran por primera vez).
4. **Authentication → Providers → Email** (o *Sign In / Providers*): comprueba que **Email** está activado y que **Email OTP Length** es `6`.
5. **Authentication → URL Configuration → Site URL**: `https://miguelmunozicam-del.github.io/porfin-casa/`

## Paso 5 · Conectar la app con Supabase (2 min)

1. Supabase → **Project Settings** → **API** (o **API Keys**).
2. Copia:
   - **Project URL** (`https://xxxx.supabase.co`)
   - La clave **anon public** (pestaña *Legacy API keys*) o la **publishable** (`sb_publishable_...`).
   - ⚠️ **Nunca** copies la `service_role` ni la `secret`.
3. Abre `config.js` con TextEdit y pega ambos valores entre las comillas. Guarda.

## Paso 6 · Publicar en GitHub Pages (5 min)

En el Terminal del Mac (copiar y pegar línea a línea):

```bash
cd ~/Downloads && unzip -o porfin-casa-v1.0.zip -d ~/Proyectos/
cd ~/Proyectos/porfin-casa
open -e config.js          # pega la URL y la clave, guarda y cierra
git init
git add .
git commit -m "v1.0 · sincronización con Supabase"
git branch -M main
gh repo create porfin-casa --public --source=. --push
gh api -X POST repos/miguelmunozicam-del/porfin-casa/pages -f "source[branch]=main" -f "source[path]=/"
```

> Si el repositorio `porfin-casa` ya existe de la v0.1, sustituye las dos últimas líneas por:
> `git remote add origin https://github.com/miguelmunozicam-del/porfin-casa.git && git push -f origin main`
> y activa Pages en GitHub → Settings → Pages → *Deploy from a branch* → `main` / `root`.

En 1-2 minutos la app estará en: **https://miguelmunozicam-del.github.io/porfin-casa/**

## Paso 7 · Primer acceso (tú, como administrador)

1. Abre el enlace en el iPhone con **Safari** → botón **Compartir** → **Añadir a pantalla de inicio**.
2. Abre la app **desde el icono** (no desde Safari) → **Entrar con mi email** → escribe tu Gmail → introduce el código.
3. **Crear una casa nueva** → nombre de la casa, tu nombre y el premio.
4. **Ajustes → Miembros** → añade a cada persona con **nombre y email**.
5. **Ajustes → Catálogo → Importar desde Excel** si has cambiado puntuaciones en el Excel.
6. **Ajustes → Miembros → Copiar enlace** y envíalo por WhatsApp.

## Paso 8 · Alta de cada miembro (2 min por persona)

- **iPhone**: abrir el enlace en **Safari** → Compartir → **Añadir a pantalla de inicio** → abrir desde el icono → email → código.
- **Android**: abrir el enlace en **Chrome** → menú ⋮ → **Añadir a pantalla de inicio** / **Instalar app** → abrir desde el icono → email → código.
- **Ordenador**: abrir el enlace en el navegador y entrar con el mismo email.

El código **solo se pide una vez por dispositivo**. Después la app se abre directamente.

---

## Si algo falla

| Síntoma | Causa probable | Solución |
|---|---|---|
| No llega el código | SMTP mal configurado | Revisa el paso 3; mira *Authentication → Logs* en Supabase |
| «Email address not authorized» | No se activó el SMTP propio | Paso 3b |
| «No perteneces a esta casa» | El email no coincide con el que puso el administrador | Corrige el email en Ajustes → Miembros |
| «Tiene que quedar al menos una persona…» | Aún no ha entrado nadie más | Que entre al menos otro miembro |
| La app no carga datos tras días sin uso | Supabase pausa proyectos gratuitos tras 7 días sin actividad | Supabase → proyecto → **Restore** |
| En iPhone pide el código otra vez | Se abrió en Safari en vez de desde el icono | Abrir siempre desde el icono |
