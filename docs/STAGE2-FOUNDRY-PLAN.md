# Fase 2 (futuro) — Agente de Microsoft Foundry con visibilidad sobre inventario de Azure Arc

> Este documento es un **diseño de alcance**, no una implementación. Describe cómo extender esta misma base de demo (servidores on-premises simulados vía Arc) hacia un escenario más avanzado para clientes que necesiten un agente **más personalizable** que el producto estándar Azure SRE Agent — con su propio modelo, su propia lógica de negocio, y un frontend de chat a medida con la marca del cliente.

## Por qué esta Fase 2 es relevante

Azure SRE Agent es un producto gestionado con un conjunto de capacidades ya definidas por Microsoft. Hay clientes que van a querer:
- Un **modelo propio** (fine-tuned, o un modelo específico de Microsoft Foundry Models catalog) en vez del modelo del SRE Agent.
- **Lógica de negocio custom** sobre cómo decide actuar (reglas propias de aprobación, integraciones con su propio ITSM, su propio formato de ticket).
- Un **frontend de chat con su propia marca**, embebido en su portal interno, en vez de la UI de sre.azure.com.

Para esos casos, la propuesta es: **mismo Arc, mismo inventario de servidores on-premises, pero el "cerebro" que razona y actúa es un agente construido sobre Microsoft Foundry**, no el producto SRE Agent.

## Arquitectura propuesta

```
┌─────────────────────────────────────────────────────────────┐
│  Frontend de chat (basado en azure-finops-agent-demo)        │
│  Vue 3 SPA + .NET API, corriendo en App Service               │
│  - Login OAuth delegado (Entra ID) — el agente actúa con los  │
│    permisos del usuario, no con una identidad propia          │
└───────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Microsoft Foundry — Proyecto + Modelo (Responses API)         │
│  El agente custom: su propio system prompt, sus propias        │
│  herramientas (tools) definidas, posible modelo fine-tuned      │
└───────────────────────┬─────────────────────────────────────┘
                         │ (tool calls)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Capa de herramientas (tools) del agente:                       │
│  - list_arc_machines()  → az connectedmachine list              │
│  - get_machine_inventory(machine)  → detalles, extensiones       │
│  - run_diagnostic(machine, command)  → az connectedmachine       │
│       run-command create (con aprobación / RBAC scoping)        │
│  - query_log_analytics(kql)  → consulta telemetría               │
│  - create_github_issue(...) / create_pull_request(...)          │
└───────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Azure Arc — mismo inventario de servidores on-premises         │
│  simulados (vm-onprem-sql, vm-onprem-iis, y cualquier otro       │
│  servidor real del cliente en el futuro)                        │
└─────────────────────────────────────────────────────────────┘
```

## Componentes a reutilizar de `azure-finops-agent-demo`

| Componente del repo de FinOps | Cómo se reutiliza aquí |
|---|---|
| App Service (Vue 3 SPA + .NET API) | Mismo esqueleto de frontend de chat — se reemplaza la lógica de negocio de "consultas de costos" por "consultas e interacción con inventario Arc" |
| Microsoft Foundry (cuenta + proyecto + modelo) | Mismo patrón de despliegue — se define un nuevo proyecto/modelo orientado a SRE/observabilidad en vez de FinOps |
| Managed Identity sin privilegios propios | Mismo principio de seguridad — el agente actúa con los permisos del usuario logueado (vía Entra ID OAuth delegado), nunca con una identidad propia sobre-privilegiada capaz de ejecutar comandos en cualquier servidor sin control |
| Log Analytics + App Insights | Mismo propósito — telemetría de la app del agente (no confundir con el Log Analytics de telemetría de los servidores Arc, que es un recurso distinto) |
| Patrón de script de deploy + `DEPLOY-RUNBOOK.md` | Mismo patrón de "prompt de redeploy" ya aplicado en este mismo repo (`prompts/REDEPLOY.md`) |

## Diferencias clave respecto al SRE Agent estándar

| Aspecto | Azure SRE Agent (Fase 1, este repo) | Agente Foundry custom (Fase 2) |
|---|---|---|
| Quién lo opera | Producto gestionado por Microsoft | El cliente (o Microsoft en su nombre) lo construye y mantiene |
| Modelo | Definido por el producto | Elegible por el cliente (catálogo de Foundry Models, incluyendo modelos propios) |
| UI | sre.azure.com | Frontend custom, embebible en el portal del cliente |
| Herramientas disponibles | Catálogo fijo del producto (Run Command, consultas KQL, GitHub, etc.) | Definidas a medida — se pueden agregar integraciones propias (ITSM del cliente, Teams, Slack, etc.) |
| Nivel de esfuerzo de implementación | Bajo — habilitar y configurar | Medio-alto — requiere desarrollo de la capa de herramientas y mantenimiento del código del agente |

## Qué NO cambia respecto a la Fase 1

- La base de Azure Arc, el onboarding de los servidores "on-premises", y los 4 escenarios de demo **siguen siendo exactamente los mismos**. Lo único que cambia es "quién" consume ese inventario y telemetría para razonar y actuar.
- Los mismos aprendizajes técnicos documentados en `prompts/REDEPLOY.md` (separación de pasos de onboarding, uso de `az connectedmachine run-command`, limitación de un comando concurrente por máquina, etc.) aplican igual.

## Próximos pasos cuando se decida avanzar con esta fase

1. Hacer un fork/adaptación de `azure-finops-agent-demo` como punto de partida del frontend.
2. Definir el conjunto mínimo de "tools" que el agente Foundry necesita (ver diagrama arriba) y implementarlas como funciones callable desde el modelo (Foundry Agents / function calling).
3. Decidir el modelo de permisos: ¿el agente actúa con la identidad del usuario logueado (más seguro, requiere que cada usuario tenga RBAC sobre los recursos Arc) o con una identidad administrada de la app (más simple, requiere definir cuidadosamente el alcance de esa identidad)?
4. Reutilizar los mismos 4 escenarios de esta demo (o escenarios del propio ambiente del cliente) para validar que el agente custom logra el mismo nivel de diagnóstico/remediación que el SRE Agent estándar.
5. Evaluar con el cliente si prefiere este modelo (más control, más esfuerzo de mantenimiento) frente al producto gestionado (menos esfuerzo, menos control granular).

Esta fase se marca explícitamente como **no ejecutada aún** — es el documento de alcance para cuando Jorge decida avanzar con un cliente específico interesado en esta ruta.

---

## ✅ Actualización — Construido y validado (26-oct-2026)

Esta fase ya tiene una **prueba de concepto funcionando en vivo**, en un repo separado y complementario: **[`jorgedvp/azure-sre-agent-foundry-arc`](https://github.com/jorgedvp/azure-sre-agent-foundry-arc)**.

**Lo que se construyó** (resumen — ver el `README.md` y `docs/DEPLOY.md` de ese repo para el detalle completo):
- Agente custom sobre Microsoft Foundry (modelo `gpt-4o`, function calling), con un frontend de chat propio desplegado en Azure Container Apps.
- Herramientas reales conectadas al **mismo inventario Arc** de este demo: listar servidores, ver inventario detallado, ejecutar diagnósticos de solo lectura vía Arc Run Command, y documentar hallazgos como GitHub Issues (etiquetados `foundry-poc`, nunca mezclados con los del SRE Agent real).
- **Nada de este demo (`azure-sre-agent-customer-demo`) fue modificado.** El único cambio fue aditivo: 3 asignaciones de rol nuevas (Reader, Azure Connected Machine Resource Administrator, Log Analytics Reader) sobre una identidad administrada dedicada a la Etapa 2, sin tocar el RBAC del SRE Agent ni de las VMs.

**Validado en vivo end-to-end**:
- El agente Foundry listó los servidores Arc reales y su estado de conexión.
- Ejecutó un diagnóstico real (`df -h`) sobre `vm-onprem-sql` vía Arc Run Command, con resultado real.
- Rechazó correctamente un intento de comando destructivo (`systemctl stop mssql-server`) — tanto por juicio propio del modelo como por el guardrail de código (deny-list de patrones de escritura, documentado como límite de seguridad explícito de esta prueba de concepto).
- Creó un GitHub Issue real documentando el hallazgo.

Esto confirma la respuesta a la pregunta original de Jorge: **sí, el mismo puente de Azure Arc puede alimentar un "cerebro" distinto al producto SRE Agent** — abriendo la puerta a clientes que necesiten un agente más personalizable (modelo propio, lógica propia, frontend con su marca) sin perder nada de la infraestructura ya validada en este demo.

