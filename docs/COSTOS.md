# Estimación de costos — ambiente de demo Azure SRE Agent + Arc

Esta tabla es una **estimación orientativa** (región East US 2, precios de lista estándar sin descuentos de Enterprise Agreement/CSP) para que el presentador pueda responder con confianza si el cliente pregunta "¿cuánto cuesta tener esto corriendo?". Los precios reales varían según acuerdo comercial, región y el consumo real del cliente.

## Costos de cómputo (las 2 VMs "on-premises" simuladas)

| Recurso | SKU | Costo aprox. (USD/mes, 730h encendida) |
|---|---|---|
| `vm-onprem-sql` (Linux) | Standard_D2ads_v6 (2 vCPU, 8 GB RAM) | ~$70–90 |
| `vm-onprem-iis` (Windows) | Standard_D2as_v6 (2 vCPU, 8 GB RAM) + licencia Windows Server | ~$140–160 |
| 2× disco OS (StandardSSD_LRS, 128GB c/u) | — | ~$20 |
| 2× IP pública estática | — | ~$7 |

> **Importante para el cliente real**: en un escenario de producción, estas VMs representarían servidores *que el cliente ya posee* (on-premises o en otra nube) — el costo de cómputo no sería un costo adicional de Azure, sino el costo de administrar esos servidores existentes. Este costo de cómputo en la demo es solo para *simular* esos servidores dentro de la suscripción de Azure.

## Costos específicos de la integración Arc + Monitor + Defender (estos sí aplican a un servidor on-premises real)

| Componente | Modelo de precio | Estimación para 2 servidores |
|---|---|---|
| **Azure Arc (Hybrid Compute)** | Gratis — no hay cargo por la conexión/agente en sí | $0 |
| **Log Analytics — ingesta de datos** | ~$2.30–2.76 por GB ingerido (Pay-as-you-go, primeros 5GB/día gratis por workspace) | Depende del volumen; un servidor con telemetría básica (perf, eventos, syslog) suele ingerir 1-3 GB/mes → ~$3-8/mes para 2 servidores |
| **Log Analytics — retención** | Primeros 31 días gratis, luego ~$0.12/GB/mes | Marginal para este volumen |
| **Microsoft Defender for Servers (Plan 2)** | ~$15 por servidor/mes | ~$30/mes (2 servidores) |
| **Microsoft Defender for SQL** | ~$15 por instancia de SQL Server/mes | ~$15/mes (1 instancia) |
| **Azure Monitor — Alertas (scheduled query rules)** | ~$0.10 por regla/mes + costo de evaluación de queries | Marginal (pocos dólares) |

## Costo del Azure SRE Agent

| Concepto | Modelo de precio |
|---|---|
| **Always-on flow** | Cargo fijo mensual por agente (consulta "Learn more about trial limits, eligibility, and billing" en el portal del agente para el valor vigente — frecuentemente con período de prueba gratuito) |
| **Active-usage (AAU — Azure Agent Units)** | Variable, según consumo real: chats, incidentes investigados, tareas programadas, triggers. En esta demo, limitar la frecuencia de tareas programadas (ver lección aprendida en `prompts/REDEPLOY.md`) reduce significativamente este costo. |

> Dato de referencia real observado en este mismo tenant: una tarea programada corriendo cada 30 minutos generó ~1,864 AAU en un mes con una proyección de cierre de ~$923 USD solo de ese agente — de ahí la importancia de ajustar la frecuencia a lo mínimo necesario para la demo (ej. cada 4 horas, o solo bajo demanda).

## Resumen para la slide de la presentación

```
Costo mensual estimado (ambiente de 2 servidores "on-prem" simulados):

  Cómputo de las VMs (solo para esta demo)......... ~$230-280/mes
  Log Analytics (ingesta + retención)............... ~$5-10/mes
  Defender for Servers (2 servidores)................ ~$30/mes
  Defender for SQL (1 instancia)...................... ~$15/mes
  Azure Monitor (alertas)............................. ~$2-5/mes
  Azure SRE Agent (always-on + uso activo moderado)... variable, ver portal

  ──────────────────────────────────────────────────────────────
  Total solo de "habilitar la inteligencia" (sin VMs).. ~$55-65/mes
  (para 2 servidores on-premises reales del cliente)
```

La conclusión clave para el cliente: **el costo incremental de darle a su infraestructura existente (on-premises o multi-cloud) esta capacidad de observabilidad + remediación autónoma es bajo** (decenas de dólares por servidor al mes), comparado con el costo de horas de ingeniería de guardia o el costo de un incidente no resuelto a tiempo.
