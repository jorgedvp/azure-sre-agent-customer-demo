# PROMPT DE REDEPLOY — Azure SRE Agent + Arc Customer Demo

> Este archivo está pensado para ser pegado directamente en una conversación con el asistente de IA (Scout/Copilot) cuando Jorge necesite volver a desplegar este ambiente de demo antes de una presentación a cliente. Contiene todo el contexto necesario para que el asistente ejecute el despliegue de principio a fin de forma autónoma, pidiendo solo las aprobaciones estrictamente necesarias.

---

## Prompt a usar

```
Necesito que despliegues el ambiente de demo del repositorio
jorgedvp/azure-sre-agent-customer-demo para una presentación a cliente.

Clona o revisa el repo, lee docs/ARCHITECTURE.md y este mismo archivo
(prompts/REDEPLOY.md) para entender el contexto completo, y luego ejecuta
TODO el despliegue de principio a fin, en este orden:

1. scripts/01-deploy-infra.sh — infraestructura base (VNet, 2 VMs, Log
   Analytics, DCR). Genera una contraseña fuerte nueva para ADMIN_PASSWORD
   y SA_PASSWORD si no te doy una explícita, y guárdalas de forma segura
   para los pasos siguientes.
2. scripts/02-onboard-arc-linux.sh — onboarding de Arc en vm-onprem-sql
   (simulación on-premises Linux).
3. scripts/03-onboard-arc-windows.sh — onboarding de Arc en vm-onprem-iis
   (simulación on-premises Windows).
4. scripts/04-install-sql.sh — instalación de SQL Server 2022 + DemoDB en
   vm-onprem-sql.
5. scripts/05-install-iis.sh — instalación de IIS en vm-onprem-iis.
6. scripts/06-create-sre-agent.sh — asignación de RBAC al SRE Agent (el
   agente en sí debe crearse primero vía portal https://sre.azure.com si
   no existe — avísame si necesitas que lo haga yo manualmente).
7. scripts/07-enable-defender-and-alerts.sh — Defender for Servers/SQL y
   alertas base de Azure Monitor.

Después de desplegar la infraestructura, conecta este mismo repositorio
GitHub al SRE Agent como fuente de "Code" (método PAT, el mismo patrón que
usamos en los labs anteriores: gh auth token | pbcopy, pegar en el portal,
nunca como texto plano).

Una vez todo esté desplegado y conectado, ejecuta los 4 escenarios de
demo (carpetas scenarios/scenario-1 a scenario-4) para dejar el ambiente
"pre-roto" y listo para que yo muestre las remediaciones en vivo frente
al cliente — exactamente como lo hicimos en el lab de investigación
previo (azure-sre-agent-arc-lab).

Tómate capturas de pantalla de cada paso relevante (igual que en los labs
anteriores) y guárdalas en una carpeta docs/redeploy-run-<fecha>/ para que
yo pueda revisar que todo quedó bien antes de la reunión con el cliente.

Al final, dame un resumen con:
- Las IPs/nombres de los recursos desplegados
- Confirmación de que los 4 escenarios quedaron en estado "roto" listo
  para remediar en vivo
- Cualquier costo estimado relevante (recuerda apagar o eliminar el
  ambiente después de la demo si no lo vamos a usar por un tiempo, para
  no seguir generando costo de cómputo).
```

## Contexto que el asistente debe tener presente (lecciones aprendidas)

Estas son fricciones ya resueltas en la construcción original de esta demo — tenerlas presentes ahorra tiempo en redeployments futuros:

1. **Nunca combinar "conectar a Arc" y "deshabilitar el agente nativo" en un solo script/run-command.** Deshabilitar el agente nativo de Azure es el mecanismo que reporta el resultado del comando — si se hace en el mismo script que lo dispara, el comando se queda colgado indefinidamente (confirmado empíricamente). Por eso el onboarding está dividido en Paso A (conectar) y Paso B (simular on-prem, disparado con `--no-wait`).

2. **SSH hacia las VMs recién creadas puede fallar de forma intermitente** ("kex_exchange_identification: Connection reset by peer") incluso con la NSG bien configurada. La automatización usa `az vm run-command` (antes de Arc) y `az connectedmachine run-command` (después de Arc) en vez de SSH directo, por ser más confiable.

3. **Una vez el servidor está "simulando on-premises"** (agente nativo deshabilitado, IMDS bloqueado), el canal nativo de Azure (`az vm run-command`, extensiones `Microsoft.Compute`) deja de responder por diseño. A partir de ese punto, **toda** automatización debe usar `az connectedmachine run-command` (namespace `Microsoft.HybridCompute`).

4. **Arc solo permite una operación de extensión/run-command a la vez por máquina.** Si se ejecutan comandos en paralelo contra la misma VM (ej. dos pestañas de chat del agente, o un script y el agente al mismo tiempo), se generan conflictos "Conflict: Run command extension execution is in progress". Evitar paralelismo contra la misma VM.

5. **Microsoft Defender for SQL (Vulnerability Assessment) no es instantáneo** — puede tardar 24-48h en reflejar un cambio nuevo. Para el escenario 4, sembrar la vulnerabilidad con 1-2 días de anticipación a la demo si se quiere mostrar el hallazgo real en Defender, o usar el disparo manual del escaneo si el portal lo permite.

6. **Costos**: dejar el ambiente completo (2 VMs + Defender + Log Analytics) corriendo fuera de las ventanas de demo genera costo continuo innecesario. Ver `docs/COSTOS.md`. Preguntar a Jorge si debe desasignarse (`az vm deallocate`) o eliminarse (`az group delete`) el resource group `rg-sre-customer-demo` al finalizar cada demo.

## Variables de entorno esperadas por los scripts

```bash
export RG="rg-sre-customer-demo"
export LOCATION="eastus2"
export SUBSCRIPTION="<subscription-id>"
export ADMIN_USERNAME="azureadmin"
export ADMIN_PASSWORD="<contraseña fuerte, generar nueva en cada redeploy>"
export SA_PASSWORD="<contraseña fuerte para sa de SQL Server, generar nueva>"
```

## Separación de responsabilidades: qué hace el asistente vs. qué debe hacer Jorge manualmente

| Paso | Quién lo ejecuta |
|---|---|
| Despliegue de infraestructura (Bicep, scripts 01-07) | Asistente (CLI, autónomo) |
| Creación del recurso SRE Agent en el portal (si no existe) | Requiere portal — el asistente puede hacerlo vía Playwright si tiene acceso, o Jorge lo crea manualmente y le pasa el nombre al asistente |
| Conexión del repo GitHub al agente (Code source) | Asistente, vía Playwright + PAT (mismo patrón ya usado) |
| Conexión del workspace de Log Analytics al agente | Asistente, vía Playwright (portal) |
| Disparo de los 4 escenarios (pre-romper el ambiente) | Asistente (CLI) |
| Aprobación de las remediaciones **durante la demo en vivo frente al cliente** | **Jorge** — este es el punto central de la presentación, nunca automatizado |
