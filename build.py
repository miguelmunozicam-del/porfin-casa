#!/usr/bin/env python3
"""Genera app.html (vista previa / demo) e index.html (producción, GitHub Pages) a partir de src/."""
import re, pathlib
R = pathlib.Path(__file__).parent
css = (R/'src/estilos.css').read_text()
js = (R/'src/app.js').read_text()
SB = '<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.112.4/dist/umd/supabase.js"></script>'
cuerpo = f'''<style>
{css}</style>

<div class="franja" aria-hidden="true"></div>
<main id="app" aria-live="polite"></main>
<div class="dock" id="dock" hidden></div>
<div id="toast" role="status" aria-live="polite"></div>
'''
cab = '<title>¡Por Fin!</title>\n<meta name="claude:viewport-fit-sides" content="cover">\n<meta name="theme-color" content="#1C2C5B">\n'
(R/'app.html').write_text(cab + cuerpo + f'<script>\n{js}</script>\n')
head = '''<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>¡Por Fin!</title>
<meta name="description" content="Orden en casa, por puntos.">
<meta name="theme-color" content="#1C2C5B">
<link rel="manifest" href="manifest.webmanifest">
<link rel="icon" type="image/png" sizes="192x192" href="icon-192.png">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="¡Por Fin!">
<meta name="apple-mobile-web-app-status-bar-style" content="default">
<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}[hidden]{display:none!important}</style>
</head>
<body>
'''
(R/'index.html').write_text(head + cuerpo + '<script src="config.js"></script>\n' + SB + f'\n<script>\n{js}</script>\n</body>\n</html>\n')
print('app.html e index.html generados')
