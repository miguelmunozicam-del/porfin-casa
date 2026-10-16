# ¡Por Fin!

Orden en casa, por puntos. Cada tarea doméstica suma puntos según su complejidad, tiempo y molestia; el resto de la familia la valida en 24 horas y, al final del periodo, quien más puntos tenga gana el premio.

**App:** https://miguelmunozicam-del.github.io/porfin-casa/

## Qué hace
- Anotar una tarea en dos toques desde el móvil.
- Validar o rechazar (con motivo) las tareas de los demás. Hacen falta 2/3 del resto de miembros.
- Silencio positivo: si a las 24 h no hay rechazos suficientes, la tarea se aprueba.
- +1 punto por responder a tiempo y −3 por no responder (se admite saldo negativo).
- Tareas compartidas: quien anota elige con quién la hizo; los puntos se reparten a partes iguales y la validan los que no participaron.
- Panel con clasificación, desglose por miembro, rechazos con sus causas y tareas sin responder.
- Periodo y premio configurables por el administrador. Catálogo de tareas editable e importable desde Excel.

## Cómo se usa
1. Abre la app y elige «Probar con una familia de ejemplo» o «Configurar mi casa».
2. Pulsa «Anotar tarea» y toca lo que has hecho.
3. Valida o rechaza lo que te aparezca en «Te toca validar» antes de que venza el plazo.
4. Consulta en «Panel» quién va ganando y por qué.

En modo demo puedes cambiar de persona y adelantar el reloj desde Ajustes para ver vencer los plazos.

## Instalación
La guía completa, paso a paso, está en **[GUIA-PUESTA-EN-MARCHA.md](GUIA-PUESTA-EN-MARCHA.md)**. En resumen:
1. Crear un proyecto gratuito en Supabase (región UE) y ejecutar `supabase/esquema.sql`.
2. Conectar un correo propio (Gmail) para enviar los códigos y ajustar la plantilla de email.
3. Pegar la URL y la clave pública en `config.js`.
4. Publicar en GitHub Pages.

Cada persona instala la app desde el navegador («Añadir a pantalla de inicio»), entra con su email y un código de 6 cifras **una sola vez por dispositivo**.

Sin `config.js` rellenado, la app funciona en modo demo o con una casa guardada solo en el dispositivo.

## Estructura del proyecto
| Archivo | Para qué sirve |
|---|---|
| `index.html` | La app (generada con `python3 build.py` a partir de `src/`) |
| `config.js` | URL y clave pública de Supabase |
| `src/app.js`, `src/estilos.css` | Código fuente |
| `supabase/esquema.sql` | Tablas, reglas de seguridad y funciones del servidor |
| `supabase/plantilla-email.html` | Correo con el código de acceso |
| `manifest.webmanifest`, `icon-*.png` | Instalación en la pantalla de inicio |

## Cómo se calculan los puntos
`Puntos = (Complejidad × peso + Tiempo × peso + Molestia × peso) × multiplicador`, con escalas de 1 a 3 y pesos 1/1/1 × 2 por defecto. Un ajuste manual sustituye al cálculo. Cada anotación guarda sus puntos y su plazo, así que cambiar las reglas no altera lo ya anotado. Los estados y sanciones se calculan a partir de fechas y votos.

## Tareas compartidas
- Al anotar, despliega «¿La has hecho con alguien?» y marca a quien te ayudó. También puedes hacerlo después desde «Tus tareas esperando», mientras nadie haya votado.
- Los puntos se reparten a partes iguales (con un decimal): Cocinar (14) entre tres son 4,7 para cada uno.
- Validan solo quienes no participaron, con el mismo quórum de 2/3. Siempre tiene que quedar al menos una persona para validar.
- Si se rechaza, nadie suma. Los rechazos y sus causas cuentan para todos los participantes.

## Privacidad
- **Dónde están los datos.** En la versión con sincronización, los datos de la casa (nombres o alias, emails, tareas, votos y puntos) se guardan en Supabase, en un servidor de la Unión Europea (Frankfurt). Supabase actúa como encargado del tratamiento conforme a su DPA.
- **Quién los ve.** Solo los miembros de cada casa. Los emails solo los ve el administrador. El acceso directo a las tablas está bloqueado: todo pasa por funciones del servidor que comprueban quién eres.
- **Qué se envía a terceros.** Nada más: sin analítica, publicidad ni cookies de seguimiento. Los códigos de acceso se envían por correo desde la cuenta configurada por el administrador.
- **En el dispositivo.** Se guarda la sesión (para no pedir el código cada vez) y las preferencias de tema. El modo demo y la casa local se guardan solo en el navegador.
- **Baja.** El administrador puede quitar a un miembro (deja de tener acceso). Para borrar la casa entera, el administrador puede hacerlo desde el panel de Supabase.
- **Uso doméstico.** Pensada para uso familiar; usa alias si lo prefieres. Si se abre a otras familias, revisa la información a los usuarios (art. 13 RGPD).

## Hoja de ruta
- [x] v1.0 · Sincronización entre móviles con Supabase (acceso con código por email, tiempo real, región UE).
- [ ] Notificaciones push de validaciones pendientes.
- [ ] Recordatorio por WhatsApp (Make/Twilio).
- [ ] Foto opcional como prueba de la tarea.
- [ ] Rachas, logros e historial de premios.

## Licencia
MIT. Consulta el archivo `LICENSE`.

## Autor
Miguel Muñoz
