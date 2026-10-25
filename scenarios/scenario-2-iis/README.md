# Escenario 2 — Error de IIS (aplicación web)

## Qué se simula

El servidor on-premises `vm-onprem-iis` (Windows Server Arc-conectado) hospeda una aplicación web crítica en IIS. Se simula uno de los incidentes más comunes en soporte de aplicaciones: **el Application Pool se detiene inesperadamente** (ej. por una excepción no controlada o un crash del worker process), dejando el sitio devolviendo error HTTP 503 (Service Unavailable) a todos los usuarios.

## Cómo se dispara (script de simulación)

```bash
az connectedmachine run-command create \
  --resource-group rg-sre-customer-demo \
  --machine-name vm-onprem-iis \
  --name trigger-scenario-2-apppool-down \
  --location eastus2 \
  --source @scenarios/scenario-2-iis/trigger.json \
  --timeout-in-seconds 60
```

El script detiene el `DefaultAppPool` vía PowerShell (`Stop-WebAppPool`), simulando el crash.

## Lo que el cliente debería ver

1. El sitio deja de responder (503). Se puede mostrar en vivo con un `curl` o abriendo el navegador contra la IP pública del servidor.
2. El evento queda registrado en el Windows Event Log (System/Application), que fluye a Log Analytics vía la Data Collection Rule.
3. El **SRE Agent investiga** vía Arc Run Command:
   - `Get-WebAppPoolState` — confirma que el pool está detenido
   - Revisa el Event Log reciente para la causa (crash, timeout, etc.)
4. El agente **propone la remediación**: reiniciar el Application Pool (`Start-WebAppPool`).
5. **Jorge aprueba la remediación en vivo**.
6. El agente ejecuta el restart real vía Arc Run Command.
7. Verificación: el sitio vuelve a responder 200 OK.

## Guion sugerido para el presentador

> "Este segundo caso es el típico 'la página se cayó' que cualquier equipo de aplicaciones conoce bien. El Application Pool de IIS se detuvo — podríamos estar frente a un servidor en nuestro propio datacenter corriendo una aplicación interna. Van a ver que el agente no solo mira métricas de Azure: entra al servidor, revisa el estado real de IIS, encuentra la causa en el visor de eventos de Windows, y propone reiniciar el servicio. Yo apruebo la acción y verificamos juntos que el sitio vuelve a funcionar."

## Nota técnica

A diferencia del escenario 1 y 3 (Linux, vía SSH-equivalente con `sqlcmd`/shell), este escenario corre enteramente sobre PowerShell vía Arc Run Command en Windows — útil para mostrarle al cliente que la capacidad no es exclusiva de Linux.
