# Confidential RWA - Activity Diagram

## Use Case: Private Real-World Asset Ownership

Enable **tokenized real-world assets** (real estate, bonds, commodities) with:
- **Hidden ownership** - No one knows who owns what
- **Private transfers** - Trade RWA tokens confidentially
- **Compliant privacy** - Selective disclosure to regulators

---

## Activity Diagram

```mermaid
flowchart TD
    Start([RWA Issuer Tokenizes Asset]) --> A[Create RWA Token]
    A --> B[Mint to Shielded Pool]
    B --> C[Generate Ownership Commitments]
    
    C --> D{Distribution Method}
    
    D -->|Public Sale| E[Investors Buy via Gelap]
    D -->|Private Placement| F[Direct Shielded Transfer]
    
    E --> G[Investor Deposits Funds]
    G --> H[Generate Purchase Proof]
    H --> I[Atomic Swap: Funds ↔ RWA Token]
    I --> J[Investor Receives Shielded RWA]
    
    F --> J
    
    J --> K[Ownership Commitment Stored]
    
    K --> L{Owner Action}
    
    L -->|Hold| M[Asset Remains Shielded]
    M --> L
    
    L -->|Transfer| N[Initiate Private Transfer]
    N --> O[Buyer Provides Shielded Key]
    O --> P[Generate Transfer Proof]
    P --> Q[Submit to RWA Contract]
    Q --> R[Ownership Transferred Privately]
    R --> L
    
    L -->|Claim Dividends| S[Dividend Distribution]
    S --> T[Generate Claim Proof]
    T --> U[Receive Dividend as Shielded Stablecoin]
    U --> L
    
    L -->|Redeem| V[Initiate Redemption]
    V --> W{Compliance Check Required?}
    
    W -->|No| X[Generate Redemption Proof]
    W -->|Yes| Y[Selective Disclosure to Verifier]
    Y --> Z[Verifier Approves]
    Z --> X
    
    X --> AA[Submit Redemption]
    AA --> AB[Burn RWA Token]
    AB --> AC[Receive Underlying Value]
    AC --> End([RWA Lifecycle Complete])
```

---

## RWA Token Lifecycle

```mermaid
sequenceDiagram
    participant Issuer
    participant Oracle
    participant Investor
    participant Gelap as Gelap RWA Pool
    participant Regulator
    
    Note over Issuer,Regulator: ISSUANCE PHASE
    Issuer->>Gelap: Tokenize $1M Real Estate
    Gelap->>Gelap: Mint 1000 RWA tokens
    Gelap->>Gelap: Each token = $1000 ownership
    
    Note over Issuer,Regulator: INVESTMENT PHASE
    Investor->>Gelap: Buy 10 tokens ($10K)
    Gelap->>Gelap: Create ownership commitment
    Gelap-->>Investor: 10 shielded RWA tokens
    
    Note over Issuer,Regulator: DIVIDEND PHASE
    Oracle->>Gelap: Report rental income
    Gelap->>Gelap: Calculate per-token dividend
    Investor->>Gelap: Claim dividend (ZK proof)
    Gelap-->>Investor: $50 USDC (shielded)
    
    Note over Issuer,Regulator: SECONDARY MARKET
    Investor->>Gelap: Sell 5 tokens to Buyer B
    Gelap->>Gelap: Private transfer
    Note over Gelap: No one knows who traded
    
    Note over Issuer,Regulator: COMPLIANCE CHECK (Optional)
    Regulator->>Investor: Request ownership proof
    Investor->>Investor: Generate selective disclosure
    Investor->>Regulator: Prove ownership without revealing all
    Regulator-->>Investor: Verified ✅
    
    Note over Issuer,Regulator: REDEMPTION PHASE
    Investor->>Gelap: Redeem 5 tokens
    Gelap->>Issuer: Burn tokens
    Issuer->>Investor: Wire $5000 to bank
```

---

## RWA Commitment Structure

```
┌─────────────────────────────────────────────────────┐
│            RWA OWNERSHIP COMMITMENT                 │
├─────────────────────────────────────────────────────┤
│                                                     │
│   Commitment = Hash(                               │
│     rwa_token_address,     // Which RWA            │
│     amount,                // Number of units      │
│     owner_shielded_key,    // Owner identity       │
│     acquisition_date,      // For tax purposes     │
│     jurisdiction_hash,     // Compliance metadata  │
│     blinding_factor        // Privacy randomness   │
│   )                                                │
│                                                     │
│   ┌───────────────────────────────────────────┐    │
│   │  Selective Disclosure Capabilities:       │    │
│   │  • Prove ownership without revealing amount│    │
│   │  • Prove holding period for tax benefits  │    │
│   │  • Prove jurisdiction for compliance      │    │
│   └───────────────────────────────────────────┘    │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## Supported RWA Types

| Asset Class | Token Representation | Yield Type |
|-------------|---------------------|------------|
| **Real Estate** | Fractional ownership | Rental income |
| **Bonds** | Debt tokens | Interest payments |
| **Commodities** | Warehouse receipts | Price appreciation |
| **Private Equity** | Share tokens | Dividends |
| **Invoices** | Receivable tokens | Discount yield |
| **Art & Collectibles** | Fractional NFTs | Sale proceeds |

---

## Privacy vs Compliance Matrix

```
┌──────────────────┬────────────────────┬───────────────────┐
│                  │  PRIVATE (Default) │  DISCLOSED        │
├──────────────────┼────────────────────┼───────────────────┤
│ Owner Identity   │  🔒 Hidden         │  📋 To Regulator  │
│ Holding Amount   │  🔒 Hidden         │  📋 On Request    │
│ Transaction Hist │  🔒 Hidden         │  📋 For Audit     │
│ Dividend Claims  │  🔒 Hidden         │  📋 Tax Reporting │
├──────────────────┼────────────────────┼───────────────────┤
│ Asset Existence  │  🌐 Public         │  🌐 Public        │
│ Total Supply     │  🌐 Public         │  🌐 Public        │
│ Issuer Info      │  🌐 Public         │  🌐 Public        │
└──────────────────┴────────────────────┴───────────────────┘
```

---

## Key Benefits for RWA

```
┌─────────────────────────────────────────────────────────┐
│  🏢 REAL ESTATE    Trade property shares privately      │
│  🏦 INSTITUTIONS   Confidential large-block trades      │
│  🌍 CROSS-BORDER   Avoid revealing wealth to hostiles   │
│  📊 COMPLIANCE     Selective disclosure when needed     │
│  💰 DIVIDENDS      Receive income privately             │
│  🔄 LIQUIDITY      24/7 private secondary market        │
└─────────────────────────────────────────────────────────┘
```

---

## Integration with Traditional Finance

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   ISSUER     │     │   GELAP      │     │  INVESTORS   │
│              │     │   RWA POOL   │     │              │
│  Bank/Fund   │────►│              │◄────│  Retail      │
│  Real Estate │     │  Private     │     │  Institution │
│  Corporation │     │  Ownership   │     │  Family Off. │
└──────────────┘     └──────────────┘     └──────────────┘
       │                    │                    │
       ▼                    ▼                    ▼
  ┌─────────┐         ┌─────────┐         ┌─────────┐
  │ Tokenize│         │ Shielded│         │ Compliant│
  │ Assets  │         │ Trading │         │ Privacy │
  └─────────┘         └─────────┘         └─────────┘
```
