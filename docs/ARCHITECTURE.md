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

## Seguridad y permisos: qué puede hacer el agente y por qué

> **Mensaje para el cliente, antes de entrar en los casos 1 y 2 (sistema operativo / IIS):**
>
> Azure Arc no otorga al agente "superpoderes" especiales distintos a los de un administrador humano. El mecanismo es el mismo que usaría cualquier administrador de sistemas via Arc Run Command:
>
> - **En Linux**, los comandos se ejecutan con privilegios de **root**.
> - **En Windows**, los comandos se ejecutan con privilegios de **SYSTEM / Administrador local**.
>
> El rol RBAC **"Azure Connected Machine Resource Administrator"** que se le asigna al SRE Agent controla **si** el agente puede ejecutar un Run Command contra una máquina Arc específica (control de acceso a nivel de recurso de Azure) — **no limita qué puede hacer ese comando una vez que se ejecuta dentro del servidor**. Es decir: una vez autorizado a ejecutar comandos en una VM, el agente tiene el mismo alcance que un administrador local de esa máquina — exactamente igual que cualquier herramienta de automatización IT (Ansible, SSM, DSC) que use una cuenta con privilegios elevados.
>
> **Esto es por diseño** — remediar un servicio del sistema operativo o reiniciar un Application Pool de IIS requiere privilegios administrativos por naturaleza. El control real de seguridad no está en "limitar lo que el comando puede hacer", sino en:
> 1. **Quién puede autorizar al agente a actuar** (ver sección de roles de usuario más abajo).
> 2. **El modo de ejecución** — Revisión (requiere aprobación humana explícita antes de cada acción, como se muestra en esta demo) vs. Autónomo (solo para tareas acotadas y de bajo riesgo, pre-aprobadas).
> 3. **El alcance de RBAC** — el agente solo tiene permisos sobre los recursos del grupo de recursos que se le autorizó explícitamente (`rg-sre-customer-demo`), no sobre toda la suscripción.

### El caso especial de la base de datos (SQL Server)

Para el caso de uso 3, **no** replicamos el patrón de "contraseña en un archivo local" que a veces se ve en labs de referencia — ese patrón es válido para un laboratorio técnico, pero **no es aceptable mostrarlo como recomendación a un cliente**, ya que ningún entorno productivo real debería tener la contraseña `sa` en texto plano en disco.

En este ambiente implementamos el patrón **recomendado por Microsoft para producción**:

| Componente | Rol |
|---|---|
| **Microsoft Entra ID** | SQL Server enabled by Azure Arc (SQL Server 2022+) soporta autenticación nativa contra Microsoft Entra ID — se elimina la necesidad de usuarios/contraseñas SQL tradicionales (`sa`) para la automatización. |
| **Azure Key Vault** (`kv-sredemo-6fed41`) | Almacena el **certificado de autenticación Entra ID** que usa el SQL Server Arc-enabled para validar tokens — nunca se guarda en disco local de la VM. |
| **Private Endpoint** (`pe-kv-sredemo`) | El Key Vault no tiene acceso público — solo es alcanzable desde dentro de la VNet de la demo, a través de una interfaz de red privada. Esto es tanto una política del tenant como la práctica recomendada de Microsoft. |
| **Private DNS Zone** (`privatelink.vaultcore.azure.net`) | Resuelve el nombre del Key Vault a su IP privada dentro de la VNet, de forma transparente para la VM/agente. |
| **Managed Identity** | El agente (o cualquier proceso de automatización) se autentica contra SQL Server usando su identidad administrada — sin contraseñas, sin secretos distribuidos manualmente. |

> **Mensaje para el cliente, antes del caso 3 (SQL):** "Lo que van a ver no usa la contraseña `sa` del motor de base de datos. La conexión del agente hacia SQL Server pasa por autenticación Entra ID, con el certificado de confianza resguardado en Key Vault y accesible únicamente a través de una red privada — el mismo patrón que recomendamos para cualquier despliegue productivo de SQL Server on-premises conectado a Arc."

*(Capturas de portal pendientes de incorporar: Private Endpoint "Approved" sobre `kv-sredemo-6fed41`, certificado `sql-entra-auth-cert` en el Key Vault, configuración de "Microsoft Entra ID and Microsoft Purview" admin sobre el recurso SQL Server - Azure Arc.)*

### Quién puede usar (y autorizar) al agente — modelo de roles

El acceso al SRE Agent se controla en **tres capas independientes**, todas configurables por el cliente:

1. **Roles de Azure IAM sobre el recurso del agente** (quién puede entrar al chat y qué puede hacer ahí):

   | Rol | Puede chatear | Puede ver acciones propuestas | Puede **aprobar** acciones | Puede configurar el agente |
   |---|---|---|---|---|
   | **Reader** | ✅ | ✅ | ❌ | ❌ |
   | **Standard User** | ✅ | ✅ | ❌ | ❌ |
   | **Author** | ✅ | ✅ | ❌ | ✅ (tareas, prompts) |
   | **Administrator** | ✅ | ✅ | ✅ | ✅ |

   Solo el rol **Administrator** puede aprobar una acción (como las que Jorge aprueba en vivo durante esta demo) o autorizar una solicitud "on-behalf-of" cuando el agente necesita permisos adicionales. El creador del agente recibe este rol automáticamente.

2. **Modo de ejecución por tarea/plan de respuesta**: cada tarea programada o respuesta automática se configura en modo **Revisión** (requiere aprobación humana antes de cada acción — lo que se muestra en los casos 1–3 de esta demo) o **Autónomo** (ejecuta sin aprobación, reservado para acciones de bajo riesgo ya validadas).

3. **RBAC del agente sobre los recursos objetivo**: el agente solo puede actuar sobre lo que se le autorizó explícitamente vía Azure RBAC (en esta demo, únicamente sobre `rg-sre-customer-demo`) — no tiene alcance sobre el resto de la suscripción del cliente.

> **Conclusión para cerrar la demo:** el agente nunca ejecuta una acción de remediación sin que exista una autorización humana explícita en algún punto del proceso — ya sea la aprobación en vivo que se mostró en cada caso de uso, o la configuración previa y deliberada de una tarea específica en modo autónomo por un Administrador del agente. El cliente mantiene control total sobre quién puede operar el agente y sobre qué recursos.

## Los 4 casos de uso

| # | Capa | Error simulado | Dónde |
|---|---|---|---|
| 1 | Sistema operativo | Servicio crítico detenido / disco con uso crítico | `vm-onprem-sql` (Linux) |
| 2 | Aplicación web (IIS) | Application Pool detenido / error HTTP 500 recurrente | `vm-onprem-iis` (Windows) |
| 3 | Base de datos (SQL Server) | Base de datos `DemoDB` en estado OFFLINE | `vm-onprem-sql` (Linux) |
| 4 | Seguridad (Defender) | Vulnerabilidad detectada por Microsoft Defender for SQL | `vm-onprem-sql` (Linux) |

En los casos 1–3, el agente diagnostica y **el presentador (Jorge) ejecuta la aprobación de la remediación en vivo** frente al cliente. En el caso 4, el foco es la detección autónoma + generación de Issue/PR (la remediación de una vulnerabilidad real normalmente requiere más contexto/aprobación de seguridad, por lo que el PR propuesto es el entregable central de este caso).

## Nota final: control de autorización

En ningún caso de uso de esta demo el agente ejecuta una remediación por sí solo sin una autorización humana de por medio — ya sea la aprobación en vivo de cada acción (casos 1–3) o la activación deliberada y acotada de una tarea en modo autónomo por un Administrador del agente. Este es un control de diseño, no una limitación técnica: el cliente define exactamente qué puede automatizarse sin supervisión y qué siempre requiere aprobación.

## Nota sobre costos

Ver `docs/COSTOS.md` y la presentación `docs/Presentacion-Intro-Demo.pptx` para el detalle de costos estimados de este ambiente (cómputo, Defender, ingesta de Log Analytics, y consumo de tokens del SRE Agent).
