# Enterprise-Scale Event-Driven Major Incident Management (MIM) Engine

An enterprise-grade, low-latency infrastructure response engine built entirely within the AWS Free Tier boundaries. This system leverages declarative configurations to isolate monitoring telemetry from downstream automation routines—reducing Mean Time to Resolution (MTTR) programmatically.

## 🏗️ AWS Infrastructure Topology

```mermaid
graph LR
    classDef customNamespace fill:#232F3E,stroke:#232F3E,stroke-width:2px,color:#ffffff;
    classDef awsCompute fill:#FF9900,stroke:#FF9900,stroke-width:2px,color:#000000;
    classDef awsManagement fill:#EC2127,stroke:#EC2127,stroke-width:2px,color:#ffffff;
    classDef awsIntegration fill:#4B27A2,stroke:#4B27A2,stroke-width:2px,color:#ffffff;
    classDef externalNode fill:#1E293B,stroke:#334155,stroke-width:1px,color:#f8fafc;

    subgraph Telemetry_Boundary [" Observability & Telemetry "]
        A[/"Custom App Metric Space<br/>(CustomApplication/MIM)"/]:::customNamespace
        B("CloudWatch Alarm<br/>(prod-major-incident-alarm)"):::awsManagement
    end

    subgraph Event_Routing [" Event Ingestion Layer "]
        C{"Amazon EventBridge<br/>(mim-routing-rule)"}:::awsIntegration
    end

    subgraph FanOut_Targets [" Decoupled Downstream Fan-Out (Concurrent) "]
        D("Amazon SNS Topic<br/>(prod-major-incident-topic)"):::awsIntegration
        E["AWS Lambda Function<br/>(email-diagnostic-router)"]:::awsCompute
        F["AWS Lambda Function<br/>(auto-remediation)"]:::awsCompute
    end

    subgraph Responders [" On-Call Action Triage "]
        G[["On-Call Team Inbox<br/>(SRE Triage Roster)"]]:::externalNode
        H[/"Volatile System Cache<br/>(Target Component Purged)"/]:::customNamespace
    end

    A -->|1. SLA Metric Breached| B
    B -->|2. State Intercept| C
    C -->|3a. Direct Topic Route| D
    C -->|3b. Invoke SDK Parser| E
    C -->|3c. Trigger Playbook| F
    E -->|4. Push Parsed Template| D
    D -.->|5. High-Priority Alert Email| G
    F -->|6. Runbook SRE-041 Executed| H

    style Telemetry_Boundary fill:rgba(236,33,39,0.03),stroke:#EC2127,stroke-dasharray: 5 5;
    style Event_Routing fill:rgba(75,39,162,0.03),stroke:#4B27A2,stroke-dasharray: 5 5;
    style FanOut_Targets fill:rgba(255,153,0,0.03),stroke:#FF9900,stroke-dasharray: 5 5;
    style Responders fill:rgba(30,41,59,0.05),stroke:#334155;
```

---

## 🛠️ Core Engineering Principles Implemented
* **Blast Radius Isolation**: Observability metrics injection points remain entirely separate from computing resources. If a remediation lambda times out, metric monitoring continues uninterrupted.
* **Declarative Multi-Module Layout**: Infrastructure is broken out into standalone, reusable submodules to prevent monolithic state files and allow rapid deployment configurations.
* **Zero-Polling Architecture**: Replaces periodic cron checks with sub-second EventBridge rule matching, driving notification overhead down to seconds.
* **Continuous Integration Rigor**: Protected by an automated GitHub Actions pipeline executing `terraform fmt` checking and `terraform validate` logic on every push event.

---

## 📊 End-to-End System Validation & Proofs

### Phase 1: Notification Authorization Layer
To secure our communication lines, an out-of-band Amazon SNS confirmation loop was initialized via Terraform and verified via the AWS CLI.

<p align="center">
  <img src="docs/assets/01-sns-confirmation-email.png" width="48%" title="SNS Opt-In Email" />
  <img src="docs/assets/02-aws-subscription-success.png" width="48%" title="AWS Registration Success" />
</p>

Verifying the topic state via the AWS CLI confirms that our targeted communication parameters have moved safely out of the `PendingConfirmation` stage and into an active ARN block:

```text
aws sns list-subscriptions-by-topic --topic-arn "arn:aws:sns:us-east-1:542129211547:prod-major-incident-topic"
```
<p align="center">
  <img src="docs/assets/03-cli-active-subscription.png" width="90%" title="CLI Active Table Output" />
</p>

### Phase 2: Anomaly Data Injection & Alarm Triggering
To simulate a production failure pattern, a sample anomaly data packet was injected using the AWS CLI toolset. CloudWatch intercepted the metric count spike, driving the telemetry state into **ALARM**:

```text
aws cloudwatch describe-alarms --alarm-names "prod-major-incident-alarm"
```
<p align="center">
  <img src="docs/assets/04-cloudwatch-alarm-tripped.png" width="90%" title="CloudWatch Alarm Fired" />
</p>

### Phase 3: Decoupled Concurrent Fan-Out Execution
Upon state alteration, the Amazon EventBridge bus immediately intercepted the alarm payload and distributed execution tasks concurrently to all decoupled downstream systems:

#### Target A: Direct SNS Raw Event Payload
The raw metrics string payload was passed directly to the standby on-call alerting engineers:
<p align="center">
  <img src="docs/assets/05-sns-raw-json-payload.png" width="90%" title="SNS Raw JSON Notification" />
</p>

#### Target B: Python Diagnostic Parsing Engine
Concurrently, the `email-diagnostic-router` Lambda parsed the raw payload variables into a clean, human-readable triage report template:
<p align="center">
  <img src="docs/assets/06-lambda-parsed-triage.png" width="90%" title="Python Parsed Triage Alert" />
</p>

#### Target C: Self-Healing Runbook Mitigation (MTTR: 1.39ms)
Concurrently, the `auto-remediation` Lambda initialized and executed corrective runbook tasks (`[SRE-RUNBOOK-041]`) to flush corrupt cache variables, mitigating system degradation automatically:
<p align="center">
  <img src="docs/assets/07-lambda-remediation-logs.png" width="90%" title="Lambda Self Healing Output Logs" />
</p>

---

## 🚀 How to Run Locally

1. Initialize directories: `cd environments/prod && terraform init`
2. Validate syntax hooks: `terraform validate`
3. Launch infrastructure map: `terraform apply -auto-approve`
4. Tear down infrastructure boundaries: `terraform destroy -auto-approve`
