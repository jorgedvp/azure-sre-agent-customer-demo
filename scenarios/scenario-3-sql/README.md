# Escenario 3 — Error de base de datos SQL Server

## Qué se simula

En el mismo servidor Linux Arc-conectado (`vm-onprem-sql`), SQL Server 2022 hospeda la base `DemoDB`. Se simula la base de datos **`DemoDB` puesta en estado `OFFLINE`** (`ALTER DATABASE DemoDB SET OFFLINE WITH ROLLBACK IMMEDIATE`) — causa típica de "la aplicación no puede acceder a sus datos / las consultas fallan" reportada por usuarios finales.

Este diseño es deliberadamente simple y **persistente de verdad**: el estado `OFFLINE` queda grabado en el catálogo del sistema (`sys.databases`), no depende de ningún proceso en memoria ni de un temporizador. Sobrevive sin cambios aunque la VM se apague/encienda (deallocate/start) o el servicio `mssql-server` se reinicie — a diferencia de los dos diseños anteriores descartados (ver "Nota de diseño" abajo).

## Cómo se dispara (script de simulación)

```bash
az connectedmachine run-command create \
  --resource-group rg-sre-customer-demo \
  --machine-name vm-onprem-sql \
  --name trigger-scenario-3-db-offline \
  --location eastus2 \
  --source @scenarios/scenario-3-sql/trigger.json \
  --timeout-in-seconds 90
```

El script espera a que `mssql-server` acepte conexiones (reintenta `SELECT 1` hasta 6 veces, útil justo después de encender la VM), ejecuta `ALTER DATABASE DemoDB SET OFFLINE WITH ROLLBACK IMMEDIATE` y confirma con `SELECT name, state_desc FROM sys.databases WHERE name='DemoDB'` que quedó en `OFFLINE`.

## Lo que el cliente debería ver

1. La aplicación no logra leer/escribir en `DemoDB` — las consultas fallan.
2. El **SRE Agent investiga** vía Arc Run Command:
   - Consulta `sys.databases` y encuentra que `DemoDB` está en estado `OFFLINE`
   - Revisa el log de errores de SQL Server para confirmar cuándo y por qué cambió el estado
3. El agente **captura evidencia** (estado de la base, log de errores) antes de actuar.
4. El agente propone la remediación: `ALTER DATABASE DemoDB SET ONLINE`.
5. **Jorge aprueba la remediación en vivo**.
6. El agente ejecuta el `ALTER DATABASE ... SET ONLINE` real vía Arc Run Command.
7. Verificación: `sys.databases` muestra `ONLINE` y las consultas de prueba vuelven a completarse.

## Guion sugerido para el presentador

> "Este caso muestra al agente operando directamente dentro del motor de base de datos: detecta que la base quedó offline, confirma la causa en los logs, y si yo lo autorizo, la vuelve a poner online para restaurar el servicio. Todo esto corre en un servidor fuera de Azure, por el puente de Arc."

## Nota de diseño

Este escenario pasó por dos iteraciones previas, ambas descartadas por no ser verdaderamente persistentes:

1. **Blocking session** (transacción abierta con `WAITFOR DELAY` sosteniendo un lock exclusivo). Se descartó porque el temporizador fijo expiraba solo (se autocuraba) antes de poder mostrarse en una demo en vivo.
2. **Servicio `mssql-server` detenido** (`systemctl stop mssql-server`). Se descartó porque **no sobrevive un reinicio de la VM**: al encender la VM de nuevo, systemd vuelve a arrancar el servicio automáticamente (está `enabled`), dejando el escenario "curado" sin que el agente haga nada.

El diseño actual (`DemoDB OFFLINE`) no tiene ninguno de los dos problemas: no hay temporizador y el estado persiste en disco independientemente de si la VM o el servicio se reinician.
