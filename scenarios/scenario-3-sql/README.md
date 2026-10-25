# Escenario 3 — Error de base de datos SQL Server

## Qué se simula

En el mismo servidor Linux Arc-conectado (`vm-onprem-sql`), SQL Server 2022 hospeda la base `DemoDB`. Se simula un **blocking session** real: una transacción queda abierta sosteniendo un lock exclusivo sobre una fila, bloqueando indefinidamente a otras consultas legítimas que intentan actualizar el mismo registro — causa típica de "la aplicación se congela" reportada por usuarios finales.

Este escenario ya fue validado end-to-end en el laboratorio de investigación previo (`azure-sre-agent-arc-lab`); aquí se reutiliza el mismo patrón, adaptado a esta infraestructura.

## Cómo se dispara (script de simulación)

```bash
az connectedmachine run-command create \
  --resource-group rg-sre-customer-demo \
  --machine-name vm-onprem-sql \
  --name trigger-scenario-3-blocking \
  --location eastus2 \
  --source @scenarios/scenario-3-sql/trigger.json \
  --timeout-in-seconds 30
```

El script lanza dos transacciones concurrentes sobre `Orders.OrderId=1`: una sostiene el lock por 10-12 minutos (`WAITFOR DELAY`), la otra queda bloqueada esperando.

## Lo que el cliente debería ver

1. Una consulta de la aplicación (`UPDATE Orders ...`) empieza a hacer timeout.
2. El **SRE Agent investiga** vía Arc Run Command:
   - Consulta `sys.dm_exec_requests` / `sys.dm_exec_sessions` para encontrar la sesión bloqueadora
   - Identifica el SQL exacto que sostiene el lock y hace cuánto tiempo
3. El agente **captura evidencia completa** (locks, SQL text, impacto simulado) antes de actuar.
4. El agente propone la remediación: `KILL <session_id>`.
5. **Jorge aprueba la remediación en vivo**.
6. El agente ejecuta el `KILL` real vía Arc Run Command.
7. Verificación: la consulta de prueba ahora se completa exitosamente.

## Guion sugerido para el presentador

> "Este es el caso que más nos gusta mostrar, porque es el más delicado: una acción directa dentro del motor de base de datos. El agente no solo lee logs — ejecuta la misma consulta de diagnóstico que haría un DBA senior, identifica la sesión culpable, y si yo lo autorizo, mata esa sesión para restaurar el servicio. Todo esto corre en un servidor fuera de Azure, por el puente de Arc."

## Referencia técnica

Ver `docs/RESULTADOS-REMEDIATION-TEST.md` del repo de investigación (`azure-sre-agent-arc-lab`) para la evidencia de verificación independiente de este exacto flujo, incluyendo la confirmación de que la acción pasa 100% por Arc y nunca por el canal nativo de Azure.
