# Regenerar la presentación

Este script genera `docs/Presentacion-Intro-Demo.pptx` con `pptxgenjs`, usando
la paleta "Microsoft Executive" (navy/blue/cyan sobre blanco, fuente Arial).

```bash
cd docs/pptx-build
npm install pptxgenjs
node build.js
```

El archivo se escribe en `docs/Presentacion-Intro-Demo.pptx`. Para validar y
revisar visualmente después de cualquier cambio, ver la sección QA de la
skill de PowerPoint del asistente (valida con python3.11 por el uso de
`match` statements, y usa LibreOffice + `pdftoppm` para convertir a imágenes).
