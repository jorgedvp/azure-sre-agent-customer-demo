# PROMPT DE LANZAMIENTO — Preparar la demo para mostrar al cliente HOY

> Este prompt es distinto a `REDEPLOY.md`. `REDEPLOY.md` reconstruye toda la infraestructura desde cero (solo si algo se rompió gravemente o la infra fue eliminada). **Este prompt asume que la infraestructura ya existe** (VMs, Arc, SQL, IIS, SRE Agent) y solo la deja *lista para mostrar* en los próximos minutos: encendida, con los 4 errores sembrados, y verificada.
>
> Úsalo así: el día de la demo, con un par de horas de anticipación, pega este prompt en una conversación con el asistente. Él hace todo el trabajo técnico. Tú no necesitas ejecutar nada manualmente salvo lo que se indica explícitamente al final.

---

## Prompt a usar

```
Necesito dejar lista la demo del repositorio jorgedvp/azure-sre-agent-customer-demo
para mostrarla a un cliente hoy. La infraestructura ya existe (no la redespliegues).
Haz esto de principio a fin sin pedirme pasos intermedios, y al final dame un
resumen en una tabla de qué quedó listo y qué debo hacer yo manualmente (si algo):

1. Verifica que ambas VMs (vm-onprem-sql, vm-onprem-iis) estén encendidas.
   Si alguna está apagada (az vm get-instance-view), enciéndela y espera a que
   Azure Arc reporte "Connected" antes de continuar.

2. Verifica que la cola de Arc Run Command esté libre en ambas VMs (sin
   comandos huérfanos en estado "Creating"/"Deleting"). Si hay alguno,
   límpialo (az rest --method DELETE) y si no se limpia, reinicia la VM
   afectada y espera a que Arc reconecte.

3. Siembra los 4 escenarios de error, en este orden, verificando cada uno
   antes de pasar al siguiente:
   a. Escenario 1 (OS) — ver scenarios/scenario-1-os/README.md
   b. Escenario 2 (IIS) — detener DefaultAppPool vía Arc Run Command
   c. Escenario 3 (SQL) — poner `DemoDB` en estado OFFLINE vía Arc Run
      Command (`ALTER DATABASE DemoDB SET OFFLINE WITH ROLLBACK IMMEDIATE`).
      Persiste aunque la VM se reinicie o se apague/encienda — no requiere
      timers ni reintentos de siembra antes de la demo.
   d. Escenario 4 (Defender) — otorgar el permiso excesivo
      (GRANT SELECT ON SCHEMA::dbo TO public) sobre DemoDB.

4. Verifica independientemente (sin depender del chat del agente) que cada
   error está activo:
   - Escenario 1: el síntoma esperado está presente
   - Escenario 2: el sitio IIS no responde (curl/Invoke-WebRequest falla)
   - Escenario 3: SELECT state_desc FROM sys.databases WHERE name='DemoDB' devuelve "OFFLINE"
   - Escenario 4: sys.database_permissions muestra el GRANT a public

5. Abre 4 conversaciones NUEVAS en el SRE Agent (sre.azure.com), una por
   escenario, para que durante la demo cada una empiece limpia. Déjalas
   abiertas en pestañas del navegador si es posible, en este orden:
   Escenario 1 → Escenario 2 → Escenario 3 → Escenario 4.

6. Dame el resumen final: tabla con cada escenario, su estado (listo/no
   listo), y el texto EXACTO que debo pegar en cada chat para arrancar
   la investigación en vivo frente al cliente (están en docs/GUIDE.md,
   sección "Guion exacto por escenario" — cópialos de ahí tal cual).
```

---

## Qué hace el asistente de forma 100% autónoma

- Encender VMs, verificar Arc, limpiar colas atascadas.
- Sembrar los 4 errores reales (no simulados a medias) vía Arc Run Command.
- Verificar cada error de forma independiente a la base de datos / servicio, antes de confiar en el chat del agente.
- Abrir los 4 hilos de chat nuevos, uno por escenario.

## Lo único que Jorge hace manualmente durante la demo en vivo

1. **Pegar el texto de inicio** de cada escenario en su chat correspondiente (texto ya preparado — ver `docs/GUIDE.md`, no hay que redactarlo en vivo).
2. **Hacer clic en "Approve action"** cuando el agente lo pida — este es justamente el punto central de la demo (mostrar que el cliente controla cada acción).
3. **Para el Escenario 4 (Defender)**, aclarar al agente en el primer mensaje que Defender "detectó" el hallazgo — en producción esto llega solo, pero el escaneo real de Defender tarda 24-48h en reflejar cambios nuevos, así que en la demo se lo indicamos directamente en el prompt (ver guion exacto en `docs/GUIDE.md`).
4. Si algún comando del agente falla por un detalle técnico menor (quirk de CLI, extensión no instalada) — **no hay que hacer nada**: el agente se auto-corrige solo en 1-2 intentos, como ya fue validado repetidas veces. Solo hay que seguir aprobando cuando pida aprobación.

## Checklist de tiempo

| Momento | Acción |
|---|---|
| 2-3 horas antes | Jorge pega el prompt de arriba en una conversación con el asistente. |
| 15 min antes | Jorge revisa el resumen final, abre las 4 pestañas del SRE Agent. |
| En vivo | Jorge pega el texto de inicio de cada escenario y aprueba las acciones. |
| Al finalizar | (Opcional) pedir al asistente que desasigne las VMs (`az vm deallocate`) para cortar el costo si no habrá otra demo pronto. |
