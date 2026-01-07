# Shielded Vault - Activity Diagram

## Use Case: Private Yield Farming & Asset Storage

User wants to:
- Store assets in a **yield-generating vault** privately
- Earn yield **without revealing** holdings or earnings
- Withdraw anytime with privacy preserved

---

## Activity Diagram

```mermaid
flowchart TD
    Start([User Wants Private Yield]) --> A{Has Shielded Balance?}
    
    A -->|No| B[Deposit Tokens to Gelap]
    B --> C[Generate Commitment]
    C --> D[Tokens Now Shielded]
    D --> A
    
    A -->|Yes| E[Select Vault Strategy]
    E --> F[Enter Deposit Amount]
    F --> G[Review Vault Terms]
    G --> H{User Confirms?}
    H -->|No| End1([Cancelled])
    
    H -->|Yes| I[Select Input Notes]
    I --> J[Build Merkle Proofs]
    J --> K[Prepare Vault Deposit Witness]
    
    K --> L[SP1 Prover: Generate Proof]
    
    subgraph ZK_VAULT_DEPOSIT [ZK Vault Deposit Proof]
        L --> L1[Verify Note Ownership]
        L1 --> L2[Compute Nullifiers]
        L2 --> L3[Create Vault Position Commitment]
        L3 --> L4[Lock Period Encoded in Commitment]
    end
    
    L4 --> M[Submit to Shielded Vault Contract]
    
    subgraph ON_CHAIN_DEPOSIT [On-Chain Vault Entry]
        M --> N[Verify ZK Proof]
        N --> O[Mark Nullifiers Used]
        O --> P[Register Vault Position]
        P --> Q[Start Yield Accrual]
        Q --> R[Emit VaultDeposit Event]
    end
    
    R --> S[User Has Shielded Vault Position]
    
    S --> T{Action?}
    T -->|Check Yield| U[Query Accrued Yield Privately]
    U --> T
    
    T -->|Claim Yield| V[Generate Yield Claim Proof]
    V --> W[Claim Yield as New Shielded Note]
    W --> T
    
    T -->|Withdraw| X[Generate Withdrawal Proof]
    
    subgraph ZK_VAULT_WITHDRAW [ZK Vault Withdrawal Proof]
        X --> X1[Prove Vault Position Ownership]
        X1 --> X2[Verify Lock Period Passed]
        X2 --> X3[Calculate Principal + Yield]
        X3 --> X4[Create Exit Commitment]
    end
    
    X4 --> Y[Submit Withdrawal TX]
    Y --> Z[Receive Shielded Notes: Principal + Yield]
    Z --> End2([Vault Exit Complete])
```

---

## Vault Position Lifecycle

```mermaid
sequenceDiagram
    participant User
    participant Wallet
    participant Prover
    participant Vault as Shielded Vault
    participant Yield as Yield Source
    
    Note over User,Yield: DEPOSIT PHASE
    User->>Wallet: Deposit 1000 USDC to Vault
    Wallet->>Prover: Generate vault entry proof
    Prover-->>Wallet: Proof ready
    Wallet->>Vault: enterVault(proof)
    Vault->>Vault: Create position commitment
    Vault-->>User: Position active (hidden)
    
    Note over User,Yield: YIELD ACCRUAL (Continuous)
    loop Every Block
        Yield->>Vault: Distribute yield
        Vault->>Vault: Update hidden balances
    end
    
    Note over User,Yield: CLAIM YIELD (Optional)
    User->>Wallet: Claim accrued yield
    Wallet->>Prover: Generate claim proof
    Prover-->>Wallet: Proof ready
    Wallet->>Vault: claimYield(proof)
    Vault-->>Wallet: Yield as new shielded note
    
    Note over User,Yield: WITHDRAWAL PHASE
    User->>Wallet: Exit vault
    Wallet->>Prover: Generate exit proof
    Prover-->>Wallet: Proof ready
    Wallet->>Vault: exitVault(proof)
    Vault->>Vault: Verify lock period
    Vault->>Vault: Calculate final amount
    Vault-->>Wallet: Principal + remaining yield
    Wallet-->>User: ✅ 1050 USDC (shielded)
```

---

## Vault Position Structure

```
┌─────────────────────────────────────────────────┐
│           SHIELDED VAULT POSITION               │
├─────────────────────────────────────────────────┤
│                                                 │
│   Position Commitment = Hash(                  │
│     principal_amount,                          │
│     entry_timestamp,                           │
│     lock_period,                               │
│     owner_pubkey,                              │
│     vault_id,                                  │
│     blinding_factor                            │
│   )                                            │
│                                                 │
│   ┌───────────────────────────────────────┐    │
│   │  Only owner can prove:                │    │
│   │  - They own this position             │    │
│   │  - Lock period status                 │    │
│   │  - Accrued yield amount               │    │
│   └───────────────────────────────────────┘    │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## Privacy Guarantees

| Data Point | Visibility |
|------------|------------|
| Deposit amount | 🔒 Private |
| Depositor identity | 🔒 Private |
| Vault position size | 🔒 Private |
| Yield earned | 🔒 Private |
| Withdrawal amount | 🔒 Private |
| Total vault TVL | 🌐 Public |
| Vault APY | 🌐 Public |

---

## Supported Vault Strategies

| Strategy | Description | Risk |
|----------|-------------|------|
| **Stable Yield** | Lending USDC/USDT | Low |
| **LP Farming** | Provide liquidity privately | Medium |
| **Restaking** | Stake LSTs for extra yield | Medium |
| **Delta Neutral** | Market-neutral strategies | Low-Med |

---

## Key Benefits

```
┌─────────────────────────────────────────────────┐
│  🔐 PRIVACY         No one sees your holdings   │
│  📈 YIELD           Earn while staying private  │
│  🛡️ SECURITY        ZK-verified positions       │
│  💧 FLEXIBILITY     Claim yield anytime         │
│  🔗 COMPOSABLE      Stack with other DeFi       │
└─────────────────────────────────────────────────┘
```
