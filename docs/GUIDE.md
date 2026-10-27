# Guía de la demo — Azure SRE Agent + Azure Arc (Customer Demo)

> Esta guía está pensada para que Jorge **navegue y muestre** la demo en vivo frente al cliente, con el mínimo de pasos manuales. Toda la preparación técnica (encender VMs, sembrar los errores, verificar que todo esté listo) la hace el asistente de IA antes de la sesión — ver `prompts/LAUNCH-DEMO.md`.
>
> Durante la demo, lo único que Jorge hace es: (1) pegar el texto de inicio de cada escenario en el chat correspondiente del SRE Agent, y (2) hacer clic en **Approve action** cuando el agente lo solicita.

---

## Antes de empezar: el mensaje para el cliente

> "Lo que les voy a mostrar hoy es Azure SRE Agent operando sobre servidores que **no viven en Azure** — están conectados mediante Azure Arc, simulando exactamente lo que tendrían en su propio datacenter o en otra nube. Van a ver al agente diagnosticar problemas reales — no simulados — a nivel de sistema operativo, de una aplicación web, y de una base de datos SQL Server, y en cada caso **yo soy quien autoriza la acción de remediación en tiempo real**. Al final les muestro un cuarto caso, distinto: una vulnerabilidad de seguridad detectada automáticamente, donde el agente genera un ticket y una propuesta de corrección sin que nadie se lo pida."

Ver `docs/ARCHITECTURE.md` para la explicación completa de arquitectura, los recuadros de seguridad/permisos (Arc + Entra ID/Key Vault para SQL), y el modelo de roles del agente — recomendado leerlos/mostrarlos **antes** de entrar a los casos de uso 1/2 y al caso 3 respectivamente.

---

## Componentes principales de la demo (contexto rápido para el cliente o tu jefe)

Antes de entrar a los casos de uso, conviene ubicar en 1-2 minutos qué es cada pieza. No hace falta un diagrama — basta con esta tabla y el mensaje de abajo.

| Componente | Qué es | Por qué importa |
|---|---|---|
| **`vm-onprem-sql`** (Linux, Ubuntu 22.04) | Servidor simulando on-premises, con SQL Server 2022 | Hospeda los casos 1 (SO), 3 (BD) y 4 (seguridad) |
| **`vm-onprem-iis`** (Windows Server 2022) | Servidor simulando on-premises, con IIS | Hospeda el caso 2 (aplicación web) |
| **Azure Arc** | El "puente" de conectividad — hace que Azure pueda ver y gestionar estos servidores como si fueran recursos propios, sin que vivan en la nube | Es la pieza central del mensaje: el mismo mecanismo funciona con un servidor físico real del cliente |
| **Azure SRE Agent** | El agente de IA que diagnostica (vía comandos reales a través de Arc) y propone/ejecuta remediación | El protagonista de la demo |
| **Log Analytics + Azure Monitor** | Reciben telemetría de los servidores y disparan alertas | De aquí nace el "síntoma" que investiga el agente en un escenario real (en la demo, el operador también puede reportarlo directo para controlar el timing) |
| **Microsoft Defender for Cloud** (Servers + SQL) | Evalúa seguridad/vulnerabilidades sobre el SQL Arc-conectado | Motor del caso 4 |
| **Entra ID + Key Vault** | Autenticación sin contraseñas hacia SQL Server (nada de `sa` en texto plano) | Tranquiliza sobre el manejo de credenciales en un entorno productivo real |
| **Repo de GitHub conectado** | Donde el agente documenta hallazgos (Issues) y propone correcciones (Pull Requests) | Cierra el ciclo: diagnóstico → ticket → propuesta de fix → aprobación humana |

**Mensaje para dar contexto (30 segundos, antes del Paso 0):**

> "Lo que ven acá son dos servidores que se comportan exactamente como los suyos en su datacenter — no viven en Azure, están conectados vía Azure Arc. El agente de IA (Azure SRE Agent) les habla directamente a través de ese puente: puede diagnosticar y, con mi aprobación, corregir problemas reales a nivel de sistema operativo, aplicación web, y base de datos. Todo lo que muestro de acá en adelante es real, no una simulación de pantallas."

---

## Paso 0 — Prueba de alcance (antes de los 4 escenarios)

**Para qué sirve:** antes de entrar de lleno a los 4 casos de incidente, esto demuestra en ~1-2 minutos que el agente **efectivamente llega** a las 3 capas (sistema operativo, aplicación web, base de datos) a través de Arc — con una sola acción de escritura mínima y aprobada en vivo, para dejar clara la mecánica de aprobación antes de los escenarios más largos. Útil tanto para abrir la demo con el cliente como para una muestra rápida a tu jefe.

**Contexto para el cliente:** "Antes de ver los casos de incidente, les muestro algo rápido: el mismo agente llegando en vivo a las tres capas de este servidor on-premises simulado."

### Guion exacto para pegar en el chat (nuevo hilo del SRE Agent)

```
Before we start the incident scenarios, I want a quick live proof that you can
reach each layer of our on-premises servers directly via Azure Arc. Please do
the following and show me the real output for each:

1. On vm-onprem-sql (Linux) - OS layer: run `hostname && uptime && whoami` to
   prove direct OS-level reach. Then write a small harmless marker file:
   `echo "Azure SRE Agent reached this OS via Arc - $(date)" >
   /tmp/sre-agent-proof.txt && cat /tmp/sre-agent-proof.txt`.
2. On the same machine - database layer: connect to the DemoDB database and
   run `SELECT @@VERSION, DB_NAME()` to prove direct database reach.
3. On vm-onprem-iis (Windows) - web application layer: run
   `Get-WebAppPoolState -Name DefaultAppPool` and `Get-Website` to prove
   direct IIS reach.

Do not change any application or service configuration - the only write
action in this check is the harmless marker file in step 1.
```

### Lo que vas a ver

1. El agente ejecuta los 3 chequeos de solo lectura (hostname/uptime, versión SQL, estado de IIS) sin pedir aprobación — son de solo lectura.
2. Al llegar al paso de escritura del archivo marcador, el agente **pide tu aprobación** — es el único "cambio" real de este paso, y es inofensivo (un archivo de texto en `/tmp`).
3. Apruebas → el agente confirma con el contenido real del archivo creado.

### Lo que tú haces
1. Pegar el texto de arriba en un chat nuevo.
2. Esperar los 3 resultados (debería tomar menos de 1 minuto, todo de solo lectura).
3. Aprobar la única acción de escritura (el archivo marcador).
4. Cerrar con: *"Con esto confirmado, pasamos a los casos reales — cada uno sigue exactamente esta misma mecánica de diagnóstico y aprobación, pero con una remediación de verdad."*

---

## Escenario 1 — Error de sistema operativo

**Contexto para el cliente:** "Un servicio crítico del sistema operativo está caído en nuestro servidor Linux on-premises."

### Guion exacto para pegar en el chat (nuevo hilo del SRE Agent)

```
Our internal operations team reports that a critical service appears to be down
on vm-onprem-sql. Please investigate via Azure Arc and find the root cause. Do
not apply any fix yet - just diagnose first.
```

### Lo que vas a ver

| Paso | Captura |
|---|---|
| 1. Síntoma reportado, el agente empieza a investigar | ![Síntoma](screenshots/scenario-1-os/01-symptom-reported.png) |
| 2. Diagnóstico completo con causa raíz | ![Diagnóstico](screenshots/scenario-1-os/02-diagnosis.png) |
| 3. Remediación propuesta, pendiente de tu aprobación | ![Remediación propuesta](screenshots/scenario-1-os/03-remediation-proposed.png) |
| 4. Apruebas → el agente ejecuta | ![Aprobado](screenshots/scenario-1-os/04-remediation-approved.png) |
| 5. Confirmación final — servicio restaurado | ![Confirmado](screenshots/scenario-1-os/05-final-confirmed.png) |

### Lo que tú haces
1. Pegar el texto de arriba.
2. Esperar el diagnóstico (puede tomar 1-3 min, el agente ejecuta comandos reales vía Arc).
3. Cuando proponga la remediación, hacer clic en **Approve action**.
4. Mostrar la confirmación final.

---

## Escenario 2 — Error de aplicación web (IIS)

**Contexto para el cliente:** "El equipo de aplicaciones reporta que el sitio web no responde."

### Guion exacto para pegar en el chat (nuevo hilo del SRE Agent)

```
Our internal app team reports that errors are occurring on the web application
running on vm-onprem-iis. Please investigate via Azure Arc and find the root
cause. Do not apply any fix yet - just diagnose first.
```

### Lo que vas a ver

| Paso | Captura |
|---|---|
| 1. Síntoma reportado | ![Síntoma](screenshots/scenario-2-iis/01-symptom-reported.png) |
| 2. Diagnóstico completo (DefaultAppPool detenido) | ![Diagnóstico](screenshots/scenario-2-iis/02-diagnosis.png) |
| 3. Remediación propuesta | ![Remediación propuesta](screenshots/scenario-2-iis/03-remediation-proposed.png) |
| 4. Apruebas → el agente ejecuta | ![Aprobado](screenshots/scenario-2-iis/04-remediation-approval.png) |
| 5. Confirmación final — sitio respondiendo | ![Confirmado](screenshots/scenario-2-iis/05-final-confirmed.png) |

### Lo que tú haces
1. Pegar el texto de arriba.
2. Esperar el diagnóstico.
3. Aprobar la remediación cuando se proponga.
4. Mostrar la confirmación final.

> Nota interna (no mencionar al cliente): si el agente intenta primero `az vm run-command` (canal nativo) en vez de Arc, es un artefacto de cómo simulamos el ambiente (ver nota en `prompts/REDEPLOY.md`, punto 9). Si ocurre, simplemente escribe: *"este servidor es on-premises, usa el canal Arc (connectedmachine run-command)"* y el agente pivota solo.

---

## Escenario 3 — Error de base de datos SQL Server (blocking session)

**Antes de este escenario**, mostrar al cliente el recuadro de seguridad de `docs/ARCHITECTURE.md` sobre Entra ID + Key Vault para la conexión a SQL — tranquiliza al cliente sobre cómo se maneja la autenticación en un entorno productivo real.

**Contexto para el cliente:** "Las actualizaciones a una tabla de pedidos están quedando colgadas — es un clásico blocking session."

### Guion exacto para pegar en el chat (nuevo hilo del SRE Agent)

```
Our internal app team reports that updates to the Orders table in DemoDB on
vm-onprem-sql are hanging / timing out. Please investigate the SQL Server
instance on vm-onprem-sql via Azure Arc and find the root cause. Do not apply
any fix yet - just diagnose first.
```

> Si el agente no logra autenticarse por no tener la contraseña `sa` (no vive en ningún archivo, por diseño), simplemente indícale: *"As the operator, I'm providing it to you directly: sa password is `<ver prompts/LAUNCH-DEMO.md o pedir al asistente>`"*. En un entorno productivo real este paso no existiría — se usaría autenticación Entra ID + Key Vault sin contraseñas (ver `docs/ARCHITECTURE.md`).

### Lo que vas a ver

| Paso | Captura |
|---|---|
| 5. Confirmación final — sesión bloqueadora eliminada, tabla responde | ![Confirmado](screenshots/scenario-3-sql/05-final-confirmed.png) |

*(Capturas de los pasos intermedios 1-4 pendientes de incorporar en una próxima ejecución — el flujo fue validado completo end-to-end: diagnóstico con `sys.dm_exec_requests`/`sys.dm_exec_sessions`, identificación exacta de la sesión y el SQL bloqueador, propuesta de `KILL <session_id>`, aprobación, ejecución, y verificación de que el UPDATE vuelve a completar instantáneamente.)*

### Lo que tú haces
1. Pegar el texto de arriba.
2. Si pide la contraseña SA, pedírsela al asistente (fuera de cámara) y pasarla al chat.
3. Aprobar el `KILL <session_id>` cuando se proponga.
4. Mostrar la confirmación final (la consulta ahora completa instantáneamente).

---

## Escenario 4 — Vulnerabilidad de seguridad (Microsoft Defender for SQL)

**Contexto para el cliente:** "Este último caso es distinto — no hay una caída de servicio, sino un hallazgo de seguridad real detectado por Microsoft Defender."

> **Nota operativa importante:** el escaneo real de Vulnerability Assessment de Defender tarda 24-48h en reflejar cambios nuevos. Por eso, en el guion le indicamos al agente que Defender "ya" marcó el hallazgo — esto es 100% honesto de explicar al cliente ("el hallazgo que ven fue sembrado minutos antes para la demo, pero el mecanismo de detección e intervención del agente es exactamente el mismo que operaría con un hallazgo real de Defender").

### Guion exacto para pegar en el chat (nuevo hilo del SRE Agent)

```
Microsoft Defender for SQL has flagged a Vulnerability Assessment finding on
the SQL Server instance running on vm-onprem-sql (Azure Arc-enabled server):
"Excessive permissions granted to the public role on database DemoDB" (finding
similar to VA rule category: Authentication & Authorization). Please investigate
via Azure Arc run-command to confirm the exact permissions granted to the
public role in DemoDB, document the finding, and then: (1) create a GitHub
Issue in the connected repository describing the vulnerability with the
evidence you gathered, and (2) open a Pull Request proposing the SQL
remediation script (REVOKE the excessive permissions). Do not apply the fix
directly to the live database - only create the Issue and PR for review.
```

### Lo que vas a ver

| Paso | Captura |
|---|---|
| 3. Issue y PR creados — resumen final del agente con links | ![Issue y PR](screenshots/scenario-4-defender-sql/03-issue-pr-created.png) |

*(Capturas de la investigación intermedia pendientes — el flujo fue validado completo: el agente consultó `sys.database_permissions` para confirmar el `GRANT SELECT ON SCHEMA::dbo TO public` y las 226 concesiones en cascada, creó el [Issue #1](https://github.com/jorgedvp/azure-sre-agent-customer-demo/issues/1) con la evidencia completa, y abrió el [PR #2](https://github.com/jorgedvp/azure-sre-agent-customer-demo/pull/2) con el script de remediación `REVOKE`, verificación antes/después y checklist de pre-merge — todo sin pedir aprobación intermedia, ya que el foco de este caso es la detección + ticket + PR autónomos.)*

### Lo que tú haces
1. Pegar el texto de arriba.
2. Esperar (este flujo es más largo, ~3-5 min porque incluye varias queries de diagnóstico).
3. Mostrar el Issue y el PR generados en GitHub (abrir el repo en otra pestaña).
4. Cerrar con el mensaje: *"El agente nunca tocó la base de datos en vivo — generó el ticket y la propuesta de corrección para que el equipo la revise y apruebe, el mismo flujo de trabajo que ya usa su equipo de desarrollo."*

---

## Cierre de la demo

Ver `docs/COSTOS.md` para el detalle de costos a mostrar (cómputo, Defender, Log Analytics, tokens del agente).

Mensaje de cierre sugerido:

> "En los cuatro casos, noten que el agente **nunca actuó sin autorización humana explícita** — ya sea mi aprobación en vivo, o el diseño deliberado del cuarto caso para solo proponer, nunca ejecutar, sobre una vulnerabilidad de seguridad. Este control de quién puede aprobar qué, y sobre qué recursos, es completamente configurable por ustedes — lo vimos en el recuadro de roles de usuario del agente."

## Preparación / relanzamiento de la demo

Ver `prompts/LAUNCH-DEMO.md` (preparación rápida, infraestructura ya existente) y `prompts/REDEPLOY.md` (reconstrucción completa desde cero, solo si es necesario).
