# Arquitectura de la demo — Azure SRE Agent + Azure Arc

Este documento describe la infraestructura desplegada y el guion de narrativa que se puede usar frente al cliente para explicar qué se está mostrando y por qué es relevante.

## El mensaje central para el cliente

> "Azure SRE Agent no solo sirve para recursos 100% nativos de Azure. A través de **Azure Arc**, el mismo agente de SRE puede **observar y actuar sobre servidores que viven fuera de Azure** — on-premises, en otra nube, en un datacenter propio — con el mismo nivel de autonomía: lectura de telemetría, diagnóstico, y **remediación real** sobre el sistema operativo, aplicaciones (IIS) y bases de datos (SQL Server), cerrando el ciclo con generación automática de tickets (GitHub Issues) y Pull Requests con la corrección propuesta."

## Cómo se simula "on-premises" en esta demo

Azure Arc no se puede instalar sobre una VM nativa de Azure sin pasos adicionales (Azure bloquea la instalación del agente dentro de su propia nube para evitar un circuito duplicado). Para simular un servidor on-premises real dentro de esta demo, seguimos el procedimiento **oficial de Microsoft** para "evaluar Arc en una VM de Azure":

1. Se deshabilita el agente nativo de Azure (`walinuxagent` en Linux / WindowsAzureGuestAgent en Windows).
2. Se bloquea el acceso al endpoint de metadatos de instancia (IMDS, `169.254.169.254`) vía firewall.
3. Se configura una variable de entorno (`MSFT_ARC_TEST=true`) que le indica al agente de Arc que debe comportarse como si estuviera fuera de Azure.

**Resultado verificado:** una vez aplicado esto, el VM Agent nativo de Azure queda "Unresponsive" y el canal nativo (`az vm run-command`, extensiones `Microsoft.Compute`) deja de funcionar — **confirmado empíricamente** en la investigación previa a esta demo (historial de ejecución vacío sobre el recurso nativo). Todas las acciones del agente pasan, en consecuencia, exclusivamente por el canal de Arc (`Microsoft.HybridCompute`), exactamente como ocurriría con un servidor físico real en las oficinas del cliente.

> Para el cliente, esto significa: lo que ve en la demo es indistinguible, en términos de mecanismo técnico, de lo que ocurriría con su propio servidor físico on-premises con el agente de Arc instalado.

## Componentes desplegados

| Componente | Propósito |
|---|---|
| **VM Linux (Ubuntu 22.04)** — `vm-onprem-sql` | Simula un servidor on-premises con SQL Server 2022. Hospeda los casos de uso 1 (sistema operativo) y 3 (base de datos). |
| **VM Windows Server 2022** — `vm-onprem-iis` | Simula un servidor on-premises con IIS. Hospeda el caso de uso 2 (aplicación web). |
| **Azure Arc (Hybrid Compute)** | Puente de conectividad y gestión para ambos servidores "on-premises". Habilita Run Command remoto, inventario, y recolección de telemetría. |
| **Log Analytics Workspace** | Repositorio central de logs: heartbeat, performance (CPU/memoria/disco), eventos de Windows (System/Application — incluye errores de IIS), syslog (Linux), y hallazgos de Microsoft Defender. |
| **Data Collection Rules (DCR)** | Definen qué telemetría se recolecta de cada servidor y hacia qué tabla de Log Analytics se envía. |
| **Azure Monitor — Alertas** | Reglas de alerta sobre las métricas/logs ingeridos (ej. servicio caído, error HTTP 500 recurrente, sesión SQL bloqueada, hallazgo de vulnerabilidad). |
| **Microsoft Defender for Cloud** (Plan Servers + Plan SQL) | Evaluación continua de seguridad y vulnerabilidades sobre el servidor SQL Arc-conectado — motor del caso de uso 4. |
| **Azure SRE Agent** | El agente de IA que consume las alertas/telemetría, diagnostica usando Run Command vía Arc, y decide o propone una remediación. |
| **Repositorio GitHub conectado** (este mismo repo) | Fuente de "código" del agente — aquí vive el script de salud SQL, la configuración de referencia de IIS, y los scripts de hardening de OS que el agente lee y modifica al proponer una corrección vía Pull Request. |

## Flujo end-to-end (lo que se muestra en cada caso de uso)

```
Error simulado en el servidor on-prem (vía Arc Run Command)
        │
        ▼
Telemetría/log fluye a Log Analytics (Heartbeat, Perf, Event, Syslog, Defender)
        │
        ▼
Azure Monitor dispara una alerta (o el operador reporta el incidente al agente)
        │
        ▼
Azure SRE Agent investiga:
  - Lee la alerta / contexto del incidente
  - Ejecuta diagnóstico real vía Arc Run Command (no simulado — comandos reales
    contra el sistema operativo, IIS o SQL Server)
  - Identifica la causa raíz
        │
        ▼
Azure SRE Agent actúa (con aprobación humana en la demo):
  - Crea un GitHub Issue documentando el incidente con la evidencia real
  - Abre un Pull Request proponiendo la corrección (script, configuración)
  - Si se autoriza, ejecuta la remediación real sobre el servidor vía Arc
        │
        ▼
Verificación: el servicio/consulta/aplicación vuelve a funcionar correctamente
```

## Los 4 casos de uso

| # | Capa | Error simulado | Dónde |
|---|---|---|---|
| 1 | Sistema operativo | Servicio crítico detenido / disco con uso crítico | `vm-onprem-sql` (Linux) |
| 2 | Aplicación web (IIS) | Application Pool detenido / error HTTP 500 recurrente | `vm-onprem-iis` (Windows) |
| 3 | Base de datos (SQL Server) | Sesión bloqueada (blocking session) por transacción no confirmada | `vm-onprem-sql` (Linux) |
| 4 | Seguridad (Defender) | Vulnerabilidad detectada por Microsoft Defender for SQL | `vm-onprem-sql` (Linux) |

En los casos 1–3, el agente diagnostica y **el presentador (Jorge) ejecuta la aprobación de la remediación en vivo** frente al cliente. En el caso 4, el foco es la detección autónoma + generación de Issue/PR (la remediación de una vulnerabilidad real normalmente requiere más contexto/aprobación de seguridad, por lo que el PR propuesto es el entregable central de este caso).

## Nota sobre costos

Ver `docs/COSTOS.md` y la presentación `docs/Presentacion-Intro-Demo.pptx` para el detalle de costos estimados de este ambiente (cómputo, Defender, ingesta de Log Analytics, y consumo de tokens del SRE Agent).
