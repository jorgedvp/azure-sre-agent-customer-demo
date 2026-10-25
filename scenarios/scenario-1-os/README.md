# Escenario 1 — Error de sistema operativo

## Qué se simula

El servidor on-premises (`vm-onprem-sql`, Linux Arc-conectado) sufre un problema clásico a nivel de sistema operativo: **el disco se llena por completo** debido a un archivo de log mal rotado, lo que impide que servicios críticos (incluido SQL Server) escriban datos, generando fallas en cascada.

## Cómo se dispara (script de simulación)

```bash
# Ejecutar vía Arc Run Command contra vm-onprem-sql
az connectedmachine run-command create \
  --resource-group rg-sre-customer-demo \
  --machine-name vm-onprem-sql \
  --name trigger-scenario-1-disk-full \
  --location eastus2 \
  --source @scenarios/scenario-1-os/trigger.json \
  --timeout-in-seconds 120
```

El script (`trigger.json`) genera un archivo de ~95% del espacio libre del disco en `/var/log/demo-fill.log`, simulando un log descontrolado. Esto:
- Dispara la métrica `% Free Space` / `Free Megabytes` por debajo del umbral de la alerta configurada en Azure Monitor (`alert-os-disk-critical`).
- Puede causar que SQL Server reporte errores de escritura si el umbral es suficientemente agresivo.

## Lo que el cliente debería ver

1. **Alerta en Azure Monitor** disparándose (o el operador reporta el síntoma al agente directamente, para controlar el timing de la demo).
2. El **SRE Agent investiga** vía Arc Run Command:
   - `df -h` — confirma el disco crítico
   - Identifica el archivo culpable (`du -sh /var/log/* | sort -rh`)
3. El agente **propone la remediación**: eliminar/truncar el archivo de log, y configurar logrotate como prevención futura.
4. **Jorge aprueba la remediación en vivo** frente al cliente.
5. El agente ejecuta la remediación real vía Arc Run Command (`truncate -s 0` o `rm` del archivo, reinicio de logrotate si aplica).
6. Verificación: `df -h` vuelve a mostrar espacio libre saludable.

## Guion sugerido para el presentador

> "Vamos a simular algo muy común en cualquier datacenter: un log que se descontroló y llenó el disco. Fíjense que el servidor que estamos viendo no es un recurso de Azure — es una máquina que se comporta exactamente como uno de sus servidores físicos, conectada vía Azure Arc. Ahora vamos a dejar que el agente detecte esto, los invito a ver cómo diagnostica el problema real usando comandos de sistema operativo, y cuando proponga la corrección, yo la voy a aprobar en vivo."

## Script de remediación propuesto (referencia para el agente)

Ver `scripts/remediation-os-disk-cleanup.sh` en el repo — este es el script de referencia que vive en el repo conectado al agente como "Code", y que el agente puede proponer actualizar vía PR si detecta que necesita mejoras (ej. agregar rotación automática).
