# Escenario 3 — Error de base de datos SQL Server

## Qué se simula

En el mismo servidor Linux Arc-conectado (`vm-onprem-sql`), SQL Server 2022 hospeda la base `DemoDB`. Se simula un **servicio SQL Server detenido**: el servicio systemd `mssql-server` se detiene directamente, dejando la base completamente inaccesible — causa típica de "la aplicación no puede conectarse / las conexiones fallan" reportada por usuarios finales. Es un error estable y determinista (no depende de ningún temporizador ni se autocura solo), a diferencia del diseño anterior basado en blocking session con `WAITFOR DELAY`, que expiraba antes de poder mostrarse en vivo.

## Cómo se dispara (script de simulación)

```bash
az connectedmachine run-command create \
  --resource-group rg-sre-customer-demo \
  --machine-name vm-onprem-sql \
  --name trigger-scenario-3-sqlservice-down \
  --location eastus2 \
  --source @scenarios/scenario-3-sql/trigger.json \
  --timeout-in-seconds 30
```

El script ejecuta `systemctl stop mssql-server` y confirma con `systemctl is-active mssql-server` que el servicio quedó `inactive`. Se mantiene así indefinidamente hasta que el agente lo reinicie.

## Lo que el cliente debería ver

1. La aplicación no logra conectarse a SQL Server — las conexiones fallan o hacen timeout.
2. El **SRE Agent investiga** vía Arc Run Command:
   - Verifica el estado del servicio (`systemctl status mssql-server`)
   - Confirma que está `inactive`/detenido y revisa el log (`journalctl -u mssql-server`) para la causa
3. El agente **captura evidencia** (estado del servicio, logs recientes) antes de actuar.
4. El agente propone la remediación: `systemctl start mssql-server`.
5. **Jorge aprueba la remediación en vivo**.
6. El agente ejecuta el reinicio real vía Arc Run Command.
7. Verificación: el servicio queda `active (running)` y las conexiones vuelven a completarse.

## Guion sugerido para el presentador

> "Este caso muestra al agente operando directamente sobre la infraestructura: detecta que el servicio de base de datos está caído, confirma la causa con los logs del sistema, y si yo lo autorizo, lo reinicia para restaurar el servicio. Todo esto corre en un servidor fuera de Azure, por el puente de Arc."

## Nota de diseño

La versión original de este escenario simulaba un **blocking session** (transacción abierta sosteniendo un lock exclusivo). Se descartó porque el disparador usaba un `WAITFOR DELAY` con límite fijo que expiraba solo (se autocuraba) antes de poder mostrarse en una demo en vivo, dejando al agente sin nada que detectar. El nuevo diseño (servicio detenido) no tiene temporizador: permanece caído indefinidamente hasta la remediación real del agente.
