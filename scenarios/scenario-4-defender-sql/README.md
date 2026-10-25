# Escenario 4 — Vulnerabilidad detectada por Microsoft Defender for SQL

## Qué se simula

A diferencia de los escenarios 1-3 (donde el "error" es un incidente operativo), este escenario demuestra el valor de **Microsoft Defender for Cloud** integrado con el SRE Agent: una configuración insegura real en SQL Server que Defender for SQL detecta como vulnerabilidad, y el agente la convierte en un ticket accionable con diagnóstico y propuesta de remediación — sin que haya "caída" de servicio de por medio.

## Vulnerabilidad simulada

Se introduce una de las vulnerabilidades más comunes y fáciles de simular de forma real (no artificial) que el Vulnerability Assessment de Defender for SQL detecta out-of-the-box:

- **VA2065 / regla equivalente**: Auditoría de nivel de servidor deshabilitada, o
- **Cuenta `sa` con política de expiración de contraseña deshabilitada**, o
- **Permisos excesivos otorgados a `public`** sobre una base de datos

Se recomienda usar la de permisos excesivos por ser la más rápida de disparar y más fácil de explicar al cliente:

```sql
-- Otorga permisos de lectura amplios al rol public sobre DemoDB (hallazgo típico de VA)
USE DemoDB;
GRANT SELECT ON SCHEMA::dbo TO public;
```

## Cómo se dispara

```bash
az connectedmachine run-command create \
  --resource-group rg-sre-customer-demo \
  --machine-name vm-onprem-sql \
  --name trigger-scenario-4-vuln \
  --location eastus2 \
  --source @scenarios/scenario-4-defender-sql/trigger.json \
  --timeout-in-seconds 30
```

## Importante: tiempos de Defender

El Vulnerability Assessment de Defender for SQL **no es instantáneo** — el escaneo corre en un ciclo periódico (normalmente diario) y puede tardar 24-48 horas en reflejar un cambio nuevo la primera vez. Para la demo en vivo frente al cliente, hay dos opciones:

1. **Disparar un escaneo bajo demanda** desde Microsoft Defender for Cloud > Recommendations > "Vulnerability assessment findings on your SQL servers should be remediated" > Trigger scan (si la UI lo permite para el recurso Arc-enabled SQL Server).
2. **Pre-sembrar el hallazgo con anticipación** (recomendado): ejecutar `trigger.json` 1-2 días antes de la demo con el cliente, de forma que el hallazgo ya esté disponible en Log Analytics (tabla `SqlVulnerabilityAssessmentResult`) y el agente pueda reaccionar en tiempo real durante la presentación.

## Lo que el cliente debería ver

1. El hallazgo de Defender aparece en Log Analytics (`SqlVulnerabilityAssessmentResult`) y/o como recomendación en Microsoft Defender for Cloud.
2. El **SRE Agent detecta el hallazgo** (vía consulta programada a Log Analytics o alerta de Azure Monitor configurada sobre esa tabla).
3. El agente **investiga el contexto** vía Arc Run Command (confirma el permiso otorgado, identifica qué lo originó si hay logs de auditoría disponibles).
4. El agente **crea un GitHub Issue** documentando el hallazgo de seguridad con la evidencia de Defender.
5. El agente **abre un Pull Request** proponiendo la remediación (script SQL para revocar el permiso: `REVOKE SELECT ON SCHEMA::dbo FROM public;`) contra el repo de este proyecto.
6. Jorge puede mostrar el PR generado y, si se desea, aprobar y aplicar la remediación en vivo (opcional — el foco de este caso es la detección + ticket + PR autónomos, no necesariamente la ejecución).

## Guion sugerido para el presentador

> "Este último caso muestra algo distinto a los anteriores: no hubo una caída de servicio, sino una vulnerabilidad de seguridad real detectada por Microsoft Defender — en este caso, un permiso demasiado amplio otorgado sobre la base de datos. Lo interesante es que el agente no se queda solo en el diagnóstico: genera un ticket formal en GitHub documentando el hallazgo, y abre un Pull Request con el script de corrección listo para revisar y aprobar — el mismo flujo de trabajo que ya usa su equipo de desarrollo."

## trigger.json

Ver archivo en esta misma carpeta.
