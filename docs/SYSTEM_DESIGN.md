# Gelap System Design

## Table of Contents

1. [High-Level Overview](#high-level-overview)
2. [System Architecture](#system-architecture)
3. [Component Design](#component-design)
4. [Data Flow](#data-flow)
5. [State Management](#state-management)
6. [Cryptographic Design](#cryptographic-design)
7. [Network Architecture](#network-architecture)
8. [Scalability Design](#scalability-design)
9. [Privacy Design](#privacy-design)
10. [Security Architecture](#security-architecture)

---

## High-Level Overview

### System Purpose

Gelap is a **privacy-preserving shielded pool protocol** that enables confidential transactions of ERC20 tokens on Ethereum and EVM-compatible chains. It uses zero-knowledge proofs to hide transaction details while maintaining verifiable correctness.

### Key Design Goals

1. **Privacy**: Hide transaction amounts, senders, and receivers
2. **Security**: Prevent double-spending and invalid state transitions
3. **Decentralization**: No trusted third parties
4. **Composability**: Work with any ERC20 token
5. **Efficiency**: Optimize gas costs and proof generation time
6. **Usability**: Simple developer and user experience

### System Boundaries

```mermaid
graph TB
    subgraph "External Systems"
        A[Users/Wallets]
        B[ERC20 Tokens]
        C[Ethereum Network]
    end
    
    subgraph "Gelap System"
        D[Smart Contracts]
        E[SP1 Prover]
        F[Indexer Service]
        G[Frontend/SDK]
    end
    
    subgraph "Infrastructure"
        H[SP1 Verifier]
        I[RPC Nodes]
        J[IPFS/Storage]
    end
    
    A --> G
    G --> E
    G --> D
    D --> B
    D --> H
    D --> C
    E --> D
    F --> I
    G --> F
    G --> J
```

---

## System Architecture

### Layered Architecture

```mermaid
graph TB
    subgraph "Layer 1: User Interface"
        UI1[Web Application]
        UI2[Mobile Wallet]
        UI3[CLI Tool]
        UI4[SDK/Library]
    end
    
    subgraph "Layer 2: Application Logic"
        APP1[Wallet Manager]
        APP2[Note Manager]
        APP3[Transaction Builder]
        APP4[Event Listener]
    end
    
    subgraph "Layer 3: Cryptographic Services"
        CRYPTO1[Commitment Generator]
        CRYPTO2[Nullifier Generator]
        CRYPTO3[Merkle Proof Builder]
        CRYPTO4[Key Manager]
    end
    
    subgraph "Layer 4: Proof Generation"
        PROOF1[SP1 Prover Service]
        PROOF2[Proof Cache]
        PROOF3[Witness Generator]
    end
    
    subgraph "Layer 5: Blockchain Layer"
        BC1[GelapShieldedAccount Contract]
        BC2[SP1 Verifier Contract]
        BC3[ERC20 Tokens]
    end
    
    subgraph "Layer 6: Data Layer"
        DATA1[Note Database]
        DATA2[Merkle Tree State]
        DATA3[Event Index]
    end
    
    UI1 --> APP1
    UI2 --> APP1
    UI3 --> APP1
    UI4 --> APP1
    
    APP1 --> CRYPTO1
    APP2 --> CRYPTO1
    APP3 --> CRYPTO2
    APP4 --> DATA3
    
    CRYPTO1 --> PROOF1
    CRYPTO2 --> PROOF1
    CRYPTO3 --> PROOF1
    
    PROOF1 --> BC1
    BC1 --> BC2
    BC1 --> BC3
    
    APP2 --> DATA1
    CRYPTO3 --> DATA2
    APP4 --> DATA2
```

### Component Interaction

```mermaid
sequenceDiagram
    participant User
    participant Wallet
    participant NoteDB
    participant Prover
    participant Contract
    participant Verifier
    participant Indexer
    
    Note over User,Indexer: Deposit Flow
    User->>Wallet: Initiate deposit
    Wallet->>Wallet: Generate commitment
    Wallet->>NoteDB: Store note locally
    Wallet->>Contract: deposit(token, amount, commitment)
    Contract->>Contract: Insert into Merkle tree
    Contract-->>Indexer: Emit AccountUpdated event
    Indexer->>Indexer: Update tree state
    
    Note over User,Indexer: Private Transaction Flow
    User->>Wallet: Send to recipient
    Wallet->>NoteDB: Select input notes
    Wallet->>Indexer: Get Merkle proofs
    Wallet->>Prover: Generate proof
    Prover->>Prover: Compute nullifiers & commitments
    Prover-->>Wallet: Return proof
    Wallet->>Contract: transact(publicInputs, proof)
    Contract->>Verifier: verifyProof()
    Verifier-->>Contract: Valid
    Contract->>Contract: Update state
    Contract-->>Indexer: Emit events
    
    Note over User,Indexer: Withdrawal Flow
    User->>Wallet: Withdraw to address
    Wallet->>Prover: Generate withdrawal proof
    Prover-->>Wallet: Return proof
    Wallet->>Contract: withdraw(publicInputs, proof, receiver)
    Contract->>Verifier: verifyProof()
    Contract->>Contract: Transfer tokens
    Contract-->>Indexer: Emit WithdrawExecuted
```

---

## Component Design

### 1. Smart Contract Layer

#### GelapShieldedAccount Contract

**Responsibilities:**
- Manage Merkle tree state
- Validate ZK proofs
- Track nullifiers
- Handle token transfers
- Emit state change events

**State Variables:**
```solidity
contract GelapShieldedAccount {
    // Merkle tree state
    bytes32 public merkleRoot;
    mapping(uint256 => bytes32) public tree;
    uint32 public nextLeafIndex;
    bytes32[32] public zeroHashes;
    
    // Nullifier tracking
    mapping(bytes32 => bool) public nullifierUsed;
    
    // SP1 configuration
    address public sp1Verifier;
    bytes32 public sp1ProgramVKey;
}
```

**Design Patterns:**
- **Sparse Merkle Tree**: Only store non-zero nodes
- **Incremental Updates**: Compute only affected nodes
- **Event-Driven**: Emit events for off-chain indexing
- **Fail-Fast**: Validate inputs early

### 2. SP1 Prover Service

#### Architecture

```mermaid
graph LR
    subgraph "Prover Service"
        A[API Gateway]
        B[Request Queue]
        C[Prover Workers]
        D[Proof Cache]
        E[Witness Generator]
    end
    
    subgraph "SP1 Runtime"
        F[Guest Program]
        G[zkVM Executor]
        H[Proof Generator]
    end
    
    A --> B
    B --> C
    C --> E
    E --> F
    F --> G
    G --> H
    H --> D
    D --> A
```

**Components:**

1. **API Gateway**: REST/gRPC interface for proof requests
2. **Request Queue**: Async job processing (Redis/RabbitMQ)
3. **Prover Workers**: Parallel proof generation
4. **Proof Cache**: Cache proofs for common patterns
5. **Witness Generator**: Prepare inputs for zkVM

**Scaling Strategy:**
- Horizontal scaling of workers
- Load balancing across instances
- Proof caching for efficiency
- GPU acceleration support

### 3. Indexer Service

#### Purpose
Track all contract events and maintain synchronized state for wallets.

#### Architecture

```mermaid
graph TB
    subgraph "Indexer Service"
        A[Event Listener]
        B[Event Processor]
        C[State Builder]
        D[API Server]
    end
    
    subgraph "Data Storage"
        E[(PostgreSQL)]
        F[(Redis Cache)]
        G[Merkle Tree Store]
    end
    
    subgraph "Clients"
        H[Wallets]
        I[Analytics]
        J[Monitoring]
    end
    
    A --> B
    B --> C
    C --> E
    C --> F
    C --> G
    D --> E
    D --> F
    D --> G
    H --> D
    I --> D
    J --> D
```

**Database Schema:**

```sql
-- Commitments table
CREATE TABLE commitments (
    id SERIAL PRIMARY KEY,
    commitment BYTEA NOT NULL,
    leaf_index INTEGER NOT NULL,
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    encrypted_memo BYTEA,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Nullifiers table
CREATE TABLE nullifiers (
    id SERIAL PRIMARY KEY,
    nullifier BYTEA NOT NULL UNIQUE,
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    spent_at TIMESTAMP DEFAULT NOW()
);

-- Merkle roots table
CREATE TABLE merkle_roots (
    id SERIAL PRIMARY KEY,
    root BYTEA NOT NULL,
    leaf_count INTEGER NOT NULL,
    block_number BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Withdrawals table
CREATE TABLE withdrawals (
    id SERIAL PRIMARY KEY,
    receiver BYTEA NOT NULL,
    token BYTEA NOT NULL,
    amount NUMERIC(78, 0) NOT NULL,
    block_number BIGINT NOT NULL,
    tx_hash BYTEA NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### 4. Wallet/SDK

#### Note Management

```typescript
interface Note {
  commitment: string;      // 32 bytes
  token: string;          // 20 bytes (address)
  amount: bigint;         // uint256
  owner: string;          // 32 bytes (public key)
  blinding: string;       // 32 bytes (random)
  leafIndex?: number;     // Position in tree
  spent: boolean;         // Spent status
}

class NoteManager {
  private notes: Map<string, Note>;
  private db: Database;
  
  async addNote(note: Note): Promise<void>;
  async markSpent(commitment: string): Promise<void>;
  async getUnspentNotes(token: string): Promise<Note[]>;
  async selectNotes(amount: bigint): Promise<Note[]>;
  async syncFromChain(): Promise<void>;
}
```

#### Transaction Builder

```typescript
class TransactionBuilder {
  async buildDeposit(
    token: string,
    amount: bigint
  ): Promise<DepositTx>;
  
  async buildTransfer(
    inputs: Note[],
    outputs: Output[]
  ): Promise<TransferTx>;
  
  async buildWithdrawal(
    inputs: Note[],
    token: string,
    amount: bigint,
    receiver: string
  ): Promise<WithdrawalTx>;
}
```

---

## Data Flow

### Deposit Data Flow

```mermaid
flowchart TD
    A[User initiates deposit] --> B[Generate random blinding]
    B --> C[Compute commitment = Hash token, amount, pubkey, blinding]
    C --> D[Approve ERC20 token]
    D --> E[Call deposit token, amount, commitment, memo]
    E --> F[Contract: transferFrom tokens]
    F --> G[Contract: Insert commitment into tree]
    G --> H[Contract: Update merkleRoot]
    H --> I[Contract: Emit AccountUpdated event]
    I --> J[Wallet: Store note locally]
    I --> K[Indexer: Update tree state]
```

### Private Transaction Data Flow

```mermaid
flowchart TD
    A[User selects recipient & amount] --> B[Wallet: Select input notes]
    B --> C[Wallet: Request Merkle proofs from indexer]
    C --> D[Wallet: Prepare outputs]
    D --> E[Prover: Generate nullifiers]
    E --> F[Prover: Create output commitments]
    F --> G[Prover: Compute new Merkle root]
    G --> H[Prover: Generate ZK proof]
    H --> I[Wallet: Submit transact proof]
    I --> J[Contract: Verify proof with SP1]
    J --> K{Proof valid?}
    K -->|Yes| L[Contract: Check nullifiers not used]
    K -->|No| M[Revert]
    L --> N[Contract: Mark nullifiers as used]
    N --> O[Contract: Update merkleRoot]
    O --> P[Contract: Emit events]
    P --> Q[Indexer: Update state]
    P --> R[Recipient: Detect new note]
```

### Withdrawal Data Flow

```mermaid
flowchart TD
    A[User requests withdrawal] --> B[Wallet: Select input notes]
    B --> C[Wallet: Get Merkle proofs]
    C --> D[Prover: Generate withdrawal proof]
    D --> E[Prover: Include receiver in proof]
    E --> F[Wallet: Submit withdraw proof, receiver]
    F --> G[Contract: Verify proof]
    G --> H{Proof valid?}
    H -->|Yes| I[Contract: Validate receiver matches]
    H -->|No| J[Revert]
    I --> K{Receiver matches?}
    K -->|Yes| L[Contract: Mark nullifiers used]
    K -->|No| J
    L --> M[Contract: Transfer tokens to receiver]
    M --> N[Contract: Emit WithdrawExecuted]
    N --> O[Indexer: Record withdrawal]
```

---

## State Management

### On-Chain State

```mermaid
stateDiagram-v2
    [*] --> Empty: Deploy contract
    Empty --> HasDeposits: First deposit
    HasDeposits --> HasDeposits: More deposits
    HasDeposits --> HasTransactions: Private transaction
    HasTransactions --> HasTransactions: More transactions
    HasTransactions --> HasWithdrawals: Withdrawal
    HasWithdrawals --> HasWithdrawals: More withdrawals
    HasWithdrawals --> [*]: Contract deprecated
    
    note right of Empty
        merkleRoot = 0
        nextLeafIndex = 0
        No nullifiers
    end note
    
    note right of HasDeposits
        merkleRoot updated
        nextLeafIndex > 0
        Commitments in tree
    end note
    
    note right of HasTransactions
        Nullifiers tracked
        Root changes
        Private transfers
    end note
```

### Merkle Tree State

```mermaid
graph TB
    subgraph "Level 32 - Root"
        R[Root Hash]
    end
    
    subgraph "Level 31"
        L31_0[Hash]
        L31_1[Hash]
    end
    
    subgraph "Level 30"
        L30_0[Hash]
        L30_1[Hash]
        L30_2[Hash]
        L30_3[Hash]
    end
    
    subgraph "..."
        dots[...]
    end
    
    subgraph "Level 0 - Leaves"
        L0_0[Commitment 1]
        L0_1[Commitment 2]
        L0_2[Commitment 3]
        L0_3[Zero Hash]
    end
    
    R --> L31_0
    R --> L31_1
    L31_0 --> L30_0
    L31_0 --> L30_1
    L31_1 --> L30_2
    L31_1 --> L30_3
    L30_0 --> dots
    L30_1 --> dots
    L30_2 --> dots
    L30_3 --> dots
    dots --> L0_0
    dots --> L0_1
    dots --> L0_2
    dots --> L0_3
```

**State Transitions:**

1. **Deposit**: Add leaf → Recompute path to root
2. **Transaction**: Verify old root → Compute new root
3. **Withdrawal**: Same as transaction + token transfer

### Off-Chain State

**Wallet State:**
```typescript
interface WalletState {
  notes: Note[];              // Owned notes
  spentNotes: Set<string>;    // Spent commitments
  pendingTxs: Transaction[];  // Unconfirmed transactions
  syncedBlock: number;        // Last synced block
}
```

**Indexer State:**
```typescript
interface IndexerState {
  currentRoot: string;
  leafCount: number;
  treeNodes: Map<string, string>;
  nullifiers: Set<string>;
  lastBlock: number;
}
```

---

## Cryptographic Design

### Commitment Scheme

```mermaid
graph LR
    A[Token Address] --> H[Keccak256]
    B[Amount] --> H
    C[Owner Pubkey] --> H
    D[Blinding Factor] --> H
    H --> E[Commitment 32 bytes]
```

**Properties:**
- **Hiding**: Blinding factor hides content
- **Binding**: Cannot change values after commitment
- **Deterministic**: Same inputs → same output
- **Collision-resistant**: Hard to find two inputs with same output

### Nullifier Scheme

```mermaid
graph LR
    A[Commitment] --> H[Keccak256]
    B[Secret Key] --> H
    H --> C[Nullifier 32 bytes]
```

**Properties:**
- **Uniqueness**: One nullifier per note
- **Unlinkability**: Cannot link to commitment without secret
- **Deterministic**: Same note + key → same nullifier
- **One-time use**: Prevents double-spending

### Merkle Tree Hashing

```mermaid
graph TB
    A[Left Child] --> H[Keccak256]
    B[Right Child] --> H
    H --> C[Parent Hash]
```

**Properties:**
- **Incremental**: Only recompute affected path
- **Sparse**: Use zero hashes for empty nodes
- **Efficient**: O(log n) proof size
- **Secure**: Collision-resistant hash function

### Zero-Knowledge Proof

**Public Inputs:**
- New Merkle root
- Nullifiers
- New commitments
- (For withdrawal) Token, amount, receiver

**Private Inputs:**
- Input notes (token, amount, owner, blinding)
- Merkle proofs
- Secret key
- Output recipients

**Proof Statement:**
```
PROVE that:
  1. I know notes with valid Merkle proofs
  2. I know the secret key for these notes
  3. Sum(inputs) = Sum(outputs)
  4. Nullifiers are correctly computed
  5. New commitments are correctly formed
  6. New root is correctly computed
```

---

## Network Architecture

### Multi-Chain Deployment

```mermaid
graph TB
    subgraph "Ethereum Mainnet"
        E1[Gelap Contract]
        E2[SP1 Verifier]
    end
    
    subgraph "Base"
        B1[Gelap Contract]
        B2[SP1 Verifier]
    end
    
    subgraph "Optimism"
        O1[Gelap Contract]
        O2[SP1 Verifier]
    end
    
    subgraph "Arbitrum"
        A1[Gelap Contract]
        A2[SP1 Verifier]
    end
    
    subgraph "Shared Infrastructure"
        P[Prover Service]
        I[Indexer Service]
        W[Wallet SDK]
    end
    
    E1 --> P
    B1 --> P
    O1 --> P
    A1 --> P
    
    E1 --> I
    B1 --> I
    O1 --> I
    A1 --> I
    
    W --> E1
    W --> B1
    W --> O1
    W --> A1
```

### Service Topology

```mermaid
graph TB
    subgraph "User Tier"
        U1[Web App]
        U2[Mobile App]
        U3[CLI]
    end
    
    subgraph "API Tier - Load Balanced"
        A1[API Server 1]
        A2[API Server 2]
        A3[API Server N]
        LB[Load Balancer]
    end
    
    subgraph "Service Tier"
        S1[Prover Service]
        S2[Indexer Service]
        S3[Cache Service]
    end
    
    subgraph "Data Tier"
        D1[(PostgreSQL Primary)]
        D2[(PostgreSQL Replica)]
        D3[(Redis)]
    end
    
    subgraph "Blockchain Tier"
        B1[RPC Node 1]
        B2[RPC Node 2]
    end
    
    U1 --> LB
    U2 --> LB
    U3 --> LB
    
    LB --> A1
    LB --> A2
    LB --> A3
    
    A1 --> S1
    A1 --> S2
    A1 --> S3
    
    S1 --> D3
    S2 --> D1
    S2 --> D2
    S3 --> D3
    
    S2 --> B1
    S2 --> B2
```

---

## Scalability Design

### Horizontal Scaling

**Prover Service:**
- Stateless workers
- Queue-based job distribution
- Auto-scaling based on load
- GPU acceleration

**Indexer Service:**
- Read replicas for queries
- Write to primary only
- Event processing pipeline
- Caching layer

**API Servers:**
- Stateless REST/GraphQL
- Load balancer distribution
- CDN for static content
- Rate limiting per user

### Vertical Optimization

**Smart Contract:**
- Sparse tree storage
- Batch nullifier checks
- Optimized hash operations
- Minimal storage writes

**Prover:**
- Parallel witness generation
- Proof caching
- Incremental proving
- Hardware acceleration

### Capacity Planning

**Merkle Tree:**
- Max capacity: 2^32 leaves (4.3B)
- At 1000 deposits/day: ~11,780 years
- Monitor at 50% capacity
- Plan migration at 75%

**Database:**
- Partition by time ranges
- Archive old data
- Index optimization
- Regular vacuum

---

## Privacy Design

### Privacy Layers

```mermaid
graph TB
    subgraph "Layer 1: Cryptographic Privacy"
        L1A[Commitments hide amounts]
        L1B[Nullifiers unlinkable]
        L1C[ZK proofs hide witnesses]
    end
    
    subgraph "Layer 2: Protocol Privacy"
        L2A[No sender/receiver in events]
        L2B[Encrypted memos]
        L2C[Merkle anonymity set]
    end
    
    subgraph "Layer 3: Network Privacy"
        L3A[Tor/VPN support]
        L3B[Local prover option]
        L3C[Privacy-focused RPC]
    end
    
    subgraph "Layer 4: Usage Privacy"
        L4A[Random delays]
        L4B[Common denominations]
        L4C[Mixing strategies]
    end
```

### Anonymity Set

```mermaid
graph LR
    A[Deposit 1] --> P[Shielded Pool]
    B[Deposit 2] --> P
    C[Deposit 3] --> P
    D[Deposit N] --> P
    
    P --> W1[Withdrawal ?]
    P --> W2[Withdrawal ?]
    P --> W3[Withdrawal ?]
    
    style P fill:#333,stroke:#fff,color:#fff
```

**Anonymity Set Size = Total Deposits**

Larger set = Better privacy

### Privacy Guarantees

| Aspect | Privacy Level | Notes |
|--------|--------------|-------|
| Transaction Amount | ✅ Hidden | Except withdrawals |
| Sender Identity | ✅ Hidden | Always |
| Receiver Identity | ✅ Hidden | Except withdrawals |
| Transaction Graph | ✅ Hidden | Cannot link txs |
| Deposit Amount | ❌ Public | Visible on-chain |
| Withdrawal Amount | ❌ Public | Visible on-chain |
| Total Pool Value | ❌ Public | Sum of deposits |

---

## Security Architecture

### Defense in Depth

```mermaid
graph TB
    subgraph "Layer 1: Input Validation"
        L1[Require statements]
        L2[Type checking]
        L3[Range validation]
    end
    
    subgraph "Layer 2: Cryptographic Verification"
        L4[ZK proof verification]
        L5[Signature validation]
        L6[Merkle proof checking]
    end
    
    subgraph "Layer 3: State Protection"
        L7[Nullifier tracking]
        L8[Reentrancy guards]
        L9[Access control]
    end
    
    subgraph "Layer 4: Monitoring"
        L10[Event logging]
        L11[Anomaly detection]
        L12[Circuit breakers]
    end
```

### Attack Surface Analysis

```mermaid
mindmap
  root((Attack Surface))
    Smart Contract
      Reentrancy
      Integer overflow
      Access control
      Logic bugs
    Cryptography
      Weak randomness
      Hash collisions
      Key management
      Proof forgery
    Protocol
      Double spending
      Front-running
      MEV attacks
      Griefing
    Infrastructure
      RPC manipulation
      Indexer corruption
      Prover DOS
      Network attacks
```

### Security Controls

| Threat | Control | Implementation |
|--------|---------|----------------|
| Double-spend | Nullifier tracking | `mapping(bytes32 => bool)` |
| Invalid proofs | SP1 verification | `ISP1Verifier.verifyProof()` |
| Front-running | Receiver validation | `require(pub.receiver == receiver)` |
| Reentrancy | Checks-Effects-Interactions | State updates before external calls |
| Integer overflow | Solidity 0.8+ | Built-in overflow checks |
| Unauthorized access | Permissionless design | No admin functions |

---

## Deployment Architecture

### Infrastructure Diagram

```mermaid
graph TB
    subgraph "Production Environment"
        subgraph "Frontend"
            CDN[CloudFlare CDN]
            WEB[Web App S3/IPFS]
        end
        
        subgraph "Backend Services"
            API[API Gateway]
            PROVER[Prover Cluster]
            INDEXER[Indexer Service]
        end
        
        subgraph "Data Layer"
            DB[(PostgreSQL RDS)]
            CACHE[(Redis ElastiCache)]
            S3[(S3 Backups)]
        end
        
        subgraph "Blockchain"
            RPC1[Alchemy RPC]
            RPC2[Infura RPC]
            CONTRACT[Gelap Contract]
        end
        
        subgraph "Monitoring"
            LOGS[CloudWatch Logs]
            METRICS[Prometheus]
            ALERTS[PagerDuty]
        end
    end
    
    CDN --> WEB
    WEB --> API
    API --> PROVER
    API --> INDEXER
    PROVER --> CACHE
    INDEXER --> DB
    INDEXER --> RPC1
    INDEXER --> RPC2
    DB --> S3
    API --> LOGS
    PROVER --> METRICS
    METRICS --> ALERTS
```

---

## Conclusion

This system design provides a comprehensive blueprint for building a production-ready privacy-preserving shielded pool. The architecture balances privacy, security, scalability, and usability while maintaining decentralization principles.

### Key Design Decisions

1. **SP1 zkVM**: Modern, developer-friendly ZK framework
2. **Sparse Merkle Tree**: Efficient storage and updates
3. **Event-Driven**: Decoupled components via events
4. **Stateless Services**: Horizontal scalability
5. **Defense in Depth**: Multiple security layers

### Next Steps

1. Implement core components
2. Deploy to testnet
3. Security audit
4. Performance optimization
5. Production deployment
