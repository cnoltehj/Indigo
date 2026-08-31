# SOLUTION - Indigo Claims Intake Architecture and Governance Blueprint

## 1. Decision summary

The baseline deliberately optimises for the three must-have capabilities: 

**Azure architecture under governance,**
**cloud baseline as code,**  
**and CI/CD with controlled promotion**. 

The production target is one .NET Claims Intake API on Azure App Service, Azure SQL for relational persistence, Azure Key Vault for secrets, and Application Insights/Log Analytics for observability.

The optional .NET implementation in this repository is only an in-memory stub used to demonstrate `externalReference` idempotency and a working deployment artifact. Detailed application logic, database schema/migrations and external integrations remain out of scope.

> **Governance principle: vendors implement within the baseline; Indigo retains ownership of the guardrails and production release authority.**

## 2. Target Azure shape

```text
Customer / Agent
      |
      | HTTPS + OAuth2/OIDC
      v
Microsoft Entra ID
      |
      v
+----------------------------------+
| Azure App Service                |
| .NET Claims Intake API           |
| Managed Identity                 |
+----------------+-----------------+
                 |
        +--------+---------+
        |        |         |
        v        v         v
   Azure SQL   Key Vault   Application Insights
   Database                 + Log Analytics
```

### Component responsibilities

- **App Service** hosts the HTTP API, provides managed hosting, TLS, scale-out and platform-managed traffic distribution across instances.
- **Azure SQL** is the production relational system of record. The eventual schema should enforce uniqueness on `externalReference` so concurrent duplicate submissions cannot create multiple claims.
- **Key Vault** is the secret boundary. The App Service Managed Identity receives least-privilege read access and the runtime receives a Key Vault reference rather than a credential embedded in source code.
- **Application Insights + Log Analytics** provide request telemetry, errors, dependencies, traces and diagnostics.
- **Microsoft Entra ID** is the target identity platform. Submit/read operations should use separate scopes or roles and object-level authorisation.

### Load balancing and scale

A separate Azure Load Balancer is **not** required for this small single-region baseline. When App Service scales to multiple instances, the platform distributes incoming requests across those instances. This keeps the architecture small and avoids an unnecessary networking component. If Indigo later requires multi-region failover, WAF/edge policy, global routing or partner-facing API controls, Azure Front Door, Traffic Manager and/or API Management can be evaluated.

## 3. Claims-specific security and data controls

### Duplicate submissions

`externalReference` is the idempotency key:

```text
POST claim
    |
    v
externalReference already known?
    | yes                 | no
    v                     v
return existing       create claim
                          |
                          v
                 production SQL UNIQUE
                 constraint is final guard
```

The in-memory stub demonstrates the behaviour; production persistence must enforce the uniqueness rule at database level as well as application level.

### Sensitive claims data

- Anonymous claim modification is prohibited.
- Production uses Entra/OAuth2; the API-key check in the local stub is only a runnable demonstration control.
- Secrets are stored in Key Vault and resolved at runtime using Managed Identity/RBAC.
- HTTPS/TLS is mandatory.
- Application logs must not contain claim descriptions, full policy details, contact details or complete request payloads.
- Responses should expose only the data needed for the operation; the stub masks the policy number as an example.
- Production-derived data should not be copied unchanged into development environments.

### Network exposure

The assignment baseline keeps networking intentionally simple so it remains deployable in the allowed time. Production hardening can add SQL/Key Vault private endpoints, VNet integration, WAF/API Management and tighter ingress controls if Indigo's enterprise network standard requires them.

## 4. Operations and resilience

Minimum operational controls:

- `/health` endpoint for smoke checks;
- Application Insights and Log Analytics;
- structured logs with correlation/claim identifiers;
- monitoring for request rate, failures, latency and Azure SQL dependency health;
- bounded retry only for transient dependencies;
- App Service scale-out where capacity warrants it;
- production alert ownership and a documented incident/escalation path.

App Service provides the required small-workload resilience without introducing Kubernetes cluster operations. If future demand requires multiple regions, specialised container orchestration or platform-standard Kubernetes controls, the hosting decision can be revisited.

## 5. Indigo/vendor responsibilities

| Area | Indigo | Vendor |
|---|---|---|
| Architecture standards | Own reference shape and guardrails | Implement within them |
| Azure subscription/RBAC | Own and grant least privilege | Request only required access |
| Bicep baseline | Own/review | Extend through PR |
| Application implementation | Define minimum expectations/review | Implement and maintain |
| Tests/quality evidence | Define required gates | Produce and fix failures |
| Key Vault/access policy | Own | Consume approved runtime configuration |
| Monitoring standard | Define required signals | Instrument service/runbook |
| Production approval | Own | Cannot self-approve |
| Security findings | Define severity/acceptance policy | Remediate |

## 6. Environment and release governance

The assignment implements **one non-production DEV baseline** and shows how the same definition promotes to Production.

```text
feature/*
    |
    v
Pull Request
    |
    +-- review
    +-- build
    +-- quality/security checks
    +-- Bicep validation
    v
main
    |
    v
Build/package once
    |
    v
DEV
    |
    +-- smoke/verification
    v
claims-prod Environment approval/checks
    |
    v
PRODUCTION
```

### Branching

Use a simple trunk-based model: `feature/*` or `bugfix/*` -> pull request -> protected `main`. No direct commits to `main`. Changes to Bicep, pipeline or security controls require Indigo review.

### Promotion control

Production is a separate Azure DevOps deployment stage using the `claims-prod` Environment. Approval/checks belong to the Azure DevOps Environment rather than solely to YAML. This prevents a vendor from removing Indigo's production approval merely by editing a pipeline file.

### Environment configuration

One `main.bicep` is reused. Environment differences are parameters rather than copied templates. DEV uses low-cost capacity; the production example uses stronger capacity/retention/purge protection. Secrets remain environment-specific and are not source controlled.

### Naming and tags

Naming pattern:

```text
indigo-claims-<resource>-<environment>-<region>
```

Minimum tags:

```text
environment = dev | prod
application = claims-intake
owner       = claims-platform
managedBy   = bicep
dataClass   = confidential
```

## 7. Key trade-offs

**App Service instead of AKS.** One small API does not justify Kubernetes cluster, ingress, node, upgrade and policy overhead. App Service meets the brief with lower operational complexity and built-in scale-out. AKS can be reconsidered if a future enterprise Kubernetes standard or workload requirement makes it necessary.

**Azure SQL instead of NoSQL.** Claims are structured and transactional, and the duplicate requirement benefits from a hard uniqueness constraint.

**No Service Bus/Kafka.** The stated use case is synchronous Claims Intake. Messaging should be introduced only when real asynchronous integrations appear.

**No API Management initially.** APIM may become useful for partner onboarding, throttling, central API policy and lifecycle governance, but it is not required for this minimal baseline.

**Minimal app stub.** The API is deliberately in-memory because the brief explicitly excludes full application implementation and detailed database work. It exists only so the project can be run and demonstrated.

## 8. Outcome

The result is a small reference implementation that a vendor can understand quickly, deploy repeatably and extend through reviewed changes. Security, observability, environment separation and production promotion are part of the delivery path, while Indigo retains control over the controls that determine production risk.
