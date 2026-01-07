# Private Swap - Activity Diagram

## Use Case: Confidential Token Exchange

User wants to swap Token A for Token B **without revealing**:
- Swap amount
- Wallet address
- Trading history

---

## Activity Diagram

```mermaid
flowchart TD
    Start([User Initiates Private Swap]) --> A[Select Token Pair]
    A --> B[Enter Swap Amount]
    B --> C{Sufficient Shielded Balance?}
    
    C -->|No| D[Deposit More Tokens]
    D --> E[Generate Commitment]
    E --> F[Submit Deposit TX]
    F --> C
    
    C -->|Yes| G[Fetch Current Pool Rates]
    G --> H[Calculate Output Amount]
    H --> I[User Confirms Swap]
    
    I --> J[Select Input Notes]
    J --> K[Build Merkle Proofs]
    K --> L[Prepare Swap Witness]
    
    L --> M[SP1 Prover: Generate ZK Proof]
    
    subgraph ZK_PROOF [ZK Proof Generation]
        M --> M1[Verify Note Ownership]
        M1 --> M2[Compute Nullifiers]
        M2 --> M3[Verify Swap Logic]
        M3 --> M4[Create Output Commitments]
        M4 --> M5[Compute New Merkle Root]
    end
    
    M5 --> N[Return Proof + Public Inputs]
    
    N --> O[Submit to Gelap Swap Contract]
    
    subgraph ON_CHAIN [On-Chain Verification]
        O --> P[Verify ZK Proof]
        P --> Q{Proof Valid?}
        Q -->|No| R[Revert Transaction]
        Q -->|Yes| S[Check Nullifiers Not Used]
        S --> T{Nullifiers Fresh?}
        T -->|No| R
        T -->|Yes| U[Execute Atomic Swap]
        U --> V[Mark Nullifiers Used]
        V --> W[Update Merkle Root]
        W --> X[Emit Swap Event]
    end
    
    X --> Y[User Receives New Shielded Notes]
    Y --> Z([Swap Complete - No Data Leaked])
    
    R --> End([Transaction Failed])
```

---

## Sequence Flow

```mermaid
sequenceDiagram
    participant User
    participant Wallet
    participant AMM as Private AMM
    participant Prover as SP1 Prover
    participant Contract as Gelap Swap
    
    User->>Wallet: Initiate swap (100 USDC → ETH)
    Wallet->>AMM: Get current rate
    AMM-->>Wallet: 1 ETH = 2000 USDC (0.05 ETH output)
    
    User->>Wallet: Confirm swap
    Wallet->>Wallet: Select USDC notes
    Wallet->>Wallet: Build Merkle proofs
    
    Wallet->>Prover: Generate swap proof
    Note over Prover: Inputs: 100 USDC note<br/>Outputs: 0.05 ETH note + change
    Prover->>Prover: Verify ownership
    Prover->>Prover: Validate swap math
    Prover->>Prover: Create nullifiers
    Prover->>Prover: Create new commitments
    Prover-->>Wallet: ZK Proof ready
    
    Wallet->>Contract: submitSwap(proof, publicInputs)
    Contract->>Contract: verifyProof()
    Contract->>Contract: checkNullifiers()
    Contract->>Contract: executeSwap()
    Contract->>Contract: updateMerkleRoot()
    Contract-->>Wallet: SwapExecuted event
    
    Wallet->>Wallet: Store new ETH note
    Wallet-->>User: ✅ Swapped 100 USDC → 0.05 ETH (Private)
```

---

## What's Private vs Public

| Data Point | Status |
|------------|--------|
| Swap amount | 🔒 Private |
| Token types | 🔒 Private |
| User address | 🔒 Private |
| Swap rate used | 🔒 Private |
| Swap occurred | 🌐 Public (event emitted) |
| Pool total liquidity | 🌐 Public |

---

## Key Components

### Private AMM Pool
```
┌─────────────────────────────────────┐
│        SHIELDED LIQUIDITY POOL      │
├─────────────────────────────────────┤
│  Token A Pool ◄──────► Token B Pool │
│       │                    │        │
│  [Hidden Balances via Commitments]  │
│                                     │
│  Swap = ZK Proof of valid trade     │
└─────────────────────────────────────┘
```

### Atomic Swap Logic (Inside ZK Proof)
```
PROVE:
  1. I own input notes worth X of Token A
  2. Output amount Y of Token B is correct per AMM formula
  3. Nullifiers are correctly derived
  4. New commitments are valid
  5. No tokens created or destroyed
```
