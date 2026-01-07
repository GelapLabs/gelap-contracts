# Compliance Ready - Activity Diagram

## Use Case: Privacy with Regulatory Compliance

Provide **privacy by default** with ability to:
- **Selectively disclose** to regulators/auditors
- **Prove compliance** without revealing all data
- Support **KYC/AML** requirements while maintaining privacy

---

## Activity Diagram

```mermaid
flowchart TD
    Start([User Onboarding]) --> A[Connect Wallet]
    A --> B{KYC Required?}
    
    B -->|No - Under Threshold| C[Generate Shielded Keypair]
    B -->|Yes - Regulated Jurisdiction| D[Complete KYC Process]
    
    D --> E[Submit Identity Documents]
    E --> F[KYC Provider Verifies]
    F --> G{KYC Approved?}
    G -->|No| H[Reject - Retry or Exit]
    G -->|Yes| I[Issue KYC Credential]
    
    I --> J[Create ZK KYC Proof]
    J --> K[Store Encrypted KYC Hash On-Chain]
    K --> C
    
    C --> L[User Can Now Transact Privately]
    
    L --> M{Transaction Type}
    
    M -->|Normal Private TX| N[Standard Gelap Flow]
    N --> O[No Disclosure Needed]
    O --> L
    
    M -->|Large Amount| P[Threshold Triggered]
    P --> Q[Attach KYC Proof to TX]
    Q --> R[Regulator Can Verify if Needed]
    R --> L
    
    M -->|Cross-Border| S[Jurisdiction Check]
    S --> T[Prove Allowed Jurisdiction]
    T --> U[TX Proceeds with Compliance Proof]
    U --> L
    
    L --> V{Regulatory Inquiry?}
    
    V -->|No| L
    V -->|Yes| W[Regulator Requests Audit]
    
    W --> X[User Receives Disclosure Request]
    X --> Y{User Responds}
    
    Y -->|Full Disclosure| Z[Reveal All Requested Data]
    Y -->|Selective Disclosure| AA[Generate ZK Proof of Compliance]
    
    AA --> AB[Prove Specific Facts Without Full Reveal]
    
    subgraph SELECTIVE_DISCLOSURE [Selective Disclosure Options]
        AB --> AB1[Prove: "I am not on sanctions list"]
        AB --> AB2[Prove: "Total holdings < $X"]
        AB --> AB3[Prove: "Funds source is legitimate"]
        AB --> AB4[Prove: "I am from allowed jurisdiction"]
    end
    
    Z --> AC[Regulator Receives Full Data]
    AB1 --> AD[Regulator Receives Proof Only]
    AB2 --> AD
    AB3 --> AD
    AB4 --> AD
    
    AC --> AE{Regulator Satisfied?}
    AD --> AE
    
    AE -->|Yes| AF[Compliance Confirmed ✅]
    AE -->|No| AG[Further Action Required]
    
    AF --> L
    AG --> End([Escalation Process])
```

---

## Compliance Flow Sequence

```mermaid
sequenceDiagram
    participant User
    participant Gelap
    participant KYC as KYC Provider
    participant Regulator
    participant Auditor
    
    Note over User,Auditor: ONBOARDING WITH KYC
    User->>Gelap: Request access
    Gelap->>User: KYC required for your jurisdiction
    User->>KYC: Submit identity documents
    KYC->>KYC: Verify identity
    KYC-->>User: KYC credential issued
    
    User->>Gelap: Submit ZK-KYC proof
    Note over Gelap: Stores: Hash(KYC) on-chain<br/>Cannot see actual KYC data
    Gelap-->>User: Access granted ✅
    
    Note over User,Auditor: NORMAL PRIVATE TRANSACTIONS
    loop Daily Usage
        User->>Gelap: Private transactions
        Gelap->>Gelap: No disclosure needed
        Note over Gelap: Privacy preserved
    end
    
    Note over User,Auditor: REGULATORY INQUIRY
    Regulator->>Gelap: Request user audit
    Gelap->>User: Disclosure request received
    
    alt Full Disclosure
        User->>Regulator: Reveal all transaction history
        Regulator-->>User: Compliance verified
    else Selective Disclosure
        User->>User: Generate ZK compliance proof
        User->>Regulator: "I prove X without revealing Y"
        Note over Regulator: Can verify claim<br/>Cannot see underlying data
        Regulator-->>User: Proof accepted
    end
    
    Note over User,Auditor: ANNUAL AUDIT
    Auditor->>User: Request holdings proof
    User->>User: Generate holdings summary proof
    User->>Auditor: Prove total value without itemizing
    Auditor-->>User: Audit complete
```

---

## ZK Compliance Proofs

### What Can Be Proven (Without Revealing Raw Data)

| Proof Type | What User Proves | What Stays Hidden |
|------------|-----------------|-------------------|
| **Identity** | "I completed KYC" | Name, DOB, Address |
| **Jurisdiction** | "I'm from allowed country" | Exact location |
| **Sanctions** | "I'm not sanctioned" | Full identity |
| **Threshold** | "Holdings < $10M" | Exact amount |
| **Source of Funds** | "Funds from salary/business" | Employer, details |
| **Age** | "I'm over 18" | Actual age |
| **Accredited** | "I'm accredited investor" | Net worth details |

---

## Compliance Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GELAP COMPLIANCE LAYER                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐      │
│   │   USER      │   │   GELAP     │   │  REGULATOR  │      │
│   │             │   │   POOL      │   │             │      │
│   └──────┬──────┘   └──────┬──────┘   └──────┬──────┘      │
│          │                 │                 │              │
│          ▼                 ▼                 ▼              │
│   ┌─────────────────────────────────────────────────┐      │
│   │              ZK COMPLIANCE PROOFS               │      │
│   ├─────────────────────────────────────────────────┤      │
│   │  • KYC Credential (hashed on-chain)            │      │
│   │  • Jurisdiction Proof                          │      │
│   │  • Sanctions Screening Proof                   │      │
│   │  • Transaction Threshold Proof                 │      │
│   │  • Source of Funds Proof                       │      │
│   └─────────────────────────────────────────────────┘      │
│          │                 │                 │              │
│          ▼                 ▼                 ▼              │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│   │  PRIVACY     │  │  VERIFIABLE  │  │  AUDITABLE   │     │
│   │  BY DEFAULT  │  │  ON DEMAND   │  │  WHEN NEEDED │     │
│   └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Threshold-Based Compliance

```
┌─────────────────────────────────────────────────────────────┐
│                   TRANSACTION THRESHOLDS                    │
├────────────────┬────────────────────────────────────────────┤
│  < $1,000      │  No KYC required                          │
│  $1K - $10K    │  Basic KYC (email, phone)                 │
│  $10K - $100K  │  Full KYC + Source of Funds               │
│  > $100K       │  Enhanced Due Diligence                   │
├────────────────┴────────────────────────────────────────────┤
│  All transactions remain PRIVATE                            │
│  Compliance proofs attached invisibly                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Regulatory Integration

### Supported Compliance Frameworks

| Framework | Region | Implementation |
|-----------|--------|----------------|
| **MiCA** | EU | Asset classification proofs |
| **FATF Travel Rule** | Global | Threshold-based disclosure |
| **FinCEN** | USA | BSA/AML compliance proofs |
| **MAS** | Singapore | Licensed entity integration |
| **FCA** | UK | Consumer protection proofs |

---

## Key Benefits

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  🔐 PRIVACY FIRST      Default private, disclose on demand │
│                                                             │
│  ✅ REGULATORY READY   Built-in compliance framework       │
│                                                             │
│  🔍 SELECTIVE PROVE    Reveal only what's needed           │
│                                                             │
│  🌍 MULTI-JURISDICTION Adaptable to local regulations      │
│                                                             │
│  📊 AUDIT TRAIL        Cryptographic proof of compliance   │
│                                                             │
│  🤝 INSTITUTIONAL OK   Banks & funds can participate       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Summary: Privacy ≠ Non-Compliance

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   TRADITIONAL FINANCE         GELAP APPROACH                │
│   ───────────────────         ──────────────                │
│                                                             │
│   All data visible      →     Private by default            │
│   to everyone                                               │
│                                                             │
│   Compliance = Full     →     Compliance = Prove only       │
│   transparency                what's necessary              │
│                                                             │
│   Privacy = Suspicious  →     Privacy = Human right         │
│                               with accountability           │
│                                                             │
│   One-size-fits-all     →     Jurisdiction-specific         │
│                               compliance modules            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```
