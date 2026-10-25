# Azure SRE Agent + Azure Arc — Customer Demo

Ambiente de demostración **repetible** para mostrarle a clientes cómo **Azure SRE Agent** puede observar y remediar incidentes en servidores que viven **fuera de Azure** (on-premises, otra nube, datacenter propio), usando **Azure Arc** como puente de conectividad.

## Qué incluye este repositorio

- `infra/` — Plantilla Bicep con toda la infraestructura base (red, VMs, Log Analytics, Data Collection Rules).
- `scripts/` — Scripts de automatización numerados (01 a 07) para desplegar todo el ambiente de punta a punta, incluyendo onboarding de Arc, instalación de SQL Server/IIS, RBAC del agente, y Defender/alertas.
- `scenarios/` — Los 4 casos de uso de la demo, cada uno con su `README.md` (guion para el presentador) y su script de disparo (`trigger.json`).
- `docs/` — Arquitectura explicada para el cliente (`ARCHITECTURE.md`), guía con capturas de ejecución real (`GUIDE.md`), estimación de costos (`COSTOS.md`), el plan de la Fase 2 (`STAGE2-FOUNDRY-PLAN.md`), y la presentación introductoria para abrir la demo (`Presentacion-Intro-Demo.pptx`).
- `prompts/LAUNCH-DEMO.md` — Prompt rápido para dejar la demo lista para mostrar HOY (infra ya existente): enciende VMs, siembra los 4 errores, verifica todo, y entrega el guion exacto para pegar en cada chat. **Este es el que se usa normalmente antes de cada demo.**
- `prompts/REDEPLOY.md` — Prompt para reconstruir TODA la infraestructura desde cero (solo si algo se eliminó o rompió gravemente).

## Los 4 casos de uso

1. **Error de sistema operativo** — disco lleno en un servidor Linux on-prem simulado.
2. **Error de aplicación web (IIS)** — Application Pool caído en un servidor Windows on-prem simulado.
3. **Error de base de datos (SQL Server)** — sesión de bloqueo (blocking session) real.
4. **Vulnerabilidad de seguridad (Microsoft Defender for SQL)** — detección autónoma + Issue + Pull Request de remediación.

En los 3 primeros, el presentador aprueba la remediación en vivo frente al cliente. En el cuarto, el foco es la detección y generación automática de ticket/PR.

## Quick start

```bash
export SUBSCRIPTION="<tu-subscription-id>"
export ADMIN_PASSWORD="<contraseña fuerte>"
export SA_PASSWORD="<contraseña fuerte para SQL sa>"

bash scripts/01-deploy-infra.sh
bash scripts/02-onboard-arc-linux.sh
bash scripts/03-onboard-arc-windows.sh
bash scripts/04-install-sql.sh
bash scripts/05-install-iis.sh
bash scripts/06-create-sre-agent.sh   # requiere crear el agente vía portal primero
bash scripts/07-enable-defender-and-alerts.sh
```

Ver `prompts/REDEPLOY.md` para el flujo completo recomendado (incluye pasos manuales de portal y lecciones aprendidas).

## Relación con el laboratorio de investigación previo

Este repositorio es la "versión demo-ready" de los hallazgos validados en [`jorgedvp/azure-sre-agent-arc-lab`](https://github.com/jorgedvp/azure-sre-agent-arc-lab), donde se confirmó empíricamente (con verificación independiente) que el SRE Agent puede diagnosticar y remediar directamente sobre sistema operativo y base de datos a través de Arc, sin depender del plano de control nativo de Azure.

## Fase 2 (futuro)

Ver `docs/STAGE2-FOUNDRY-PLAN.md` para el diseño de una integración más avanzada: un agente de Azure AI Foundry con visibilidad sobre el inventario de Arc, expuesto a través de un frontend de chat personalizado (reutilizando la base del demo de FinOps de Jorge), para clientes que requieran mayor nivel de customización que el producto SRE Agent estándar.
