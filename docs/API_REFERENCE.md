# API Reference

## GelapShieldedAccount Contract

### State Variables

#### `merkleRoot`
```solidity
bytes32 public merkleRoot
```
The current Merkle tree root representing the private state. Updated after each deposit, transaction, or withdrawal.

#### `nullifierUsed`
```solidity
mapping(bytes32 => bool) public nullifierUsed
```
Tracks which nullifiers have been consumed to prevent double-spending.

#### `zeroHashes`
```solidity
bytes32[32] public zeroHashes
```
Precomputed zero hashes for each level of the Merkle tree (0-31).

#### `nextLeafIndex`
```solidity
uint32 public nextLeafIndex
```
The index for the next available leaf in the Merkle tree. Increments after each deposit.

#### `tree`
```solidity
mapping(uint256 => bytes32) public tree
```
Storage for Merkle tree nodes. Keys are computed using `_nodeIndex(level, index)`.

#### `sp1Verifier`
```solidity
address public sp1Verifier
```
Address of the SP1 verifier contract used to check ZK proofs.

#### `sp1ProgramVKey`
```solidity
bytes32 public sp1ProgramVKey
```
The verification key corresponding to the SP1 program.

---

## Public Functions

### `deposit`

Deposits ERC20 assets into the shielded pool by inserting a commitment into the Merkle tree.

```solidity
function deposit(
    address token,
    uint256 amount,
    bytes32 commitment,
    bytes calldata encryptedMemo
) external
```

**Parameters:**
- `token`: The ERC20 token address being deposited
- `amount`: The amount of tokens to transfer from the user
- `commitment`: The 32-byte Pedersen commitment representing the private note
- `encryptedMemo`: Opaque encrypted metadata that the receiver can later decrypt

**Requirements:**
- `token` must not be the zero address
- `amount` must be greater than 0
- Caller must have approved this contract to spend at least `amount` of `token`
- ERC20 transfer must succeed

**Effects:**
- Transfers `amount` of `token` from `msg.sender` to this contract
- Inserts `commitment` into the Merkle tree
- Updates `merkleRoot`
- Increments `nextLeafIndex`
- Emits `AccountUpdated(commitment, encryptedMemo)`

**Example:**
```solidity
// 1. Approve contract
IERC20(tokenAddress).approve(gelapAddress, 100 ether);

// 2. Generate commitment off-chain
bytes32 commitment = keccak256(abi.encodePacked(
    tokenAddress,
    100 ether,
    userPublicKey,
    blindingFactor
));

// 3. Deposit
gelap.deposit(tokenAddress, 100 ether, commitment, encryptedMemo);
```

---

### `transact`

Executes a private transaction validated via an SP1 ZK proof.

```solidity
function transact(
    bytes calldata publicInputs,
    bytes calldata proofBytes
) external
```

**Parameters:**
- `publicInputs`: ABI-encoded `PublicInputsStruct` produced by the SP1 program
- `proofBytes`: The raw proof bytes produced by the SP1 prover

**Public Inputs Structure:**
```solidity
struct PublicInputsStruct {
    bytes32 newRoot;              // Merkle root after executing the private tx
    bytes32[] nullifiers;         // Nullifiers consumed in this transaction
    bytes32[] newCommitments;     // Newly created commitments (outputs)
}
```

**Requirements:**
- SP1 proof must be valid for the given `publicInputs`
- All nullifiers must not have been used before

**Effects:**
- Verifies the ZK proof via `sp1Verifier`
- Marks all `nullifiers` as used
- Updates `merkleRoot` to `newRoot`
- Emits `AccountUpdated` for each new commitment
- Emits `TransactionExecuted(newRoot, nullifiers, newCommitments)`

**Reverts:**
- If proof verification fails
- If any nullifier has already been used ("Nullifier already used")

**Example:**
```solidity
// Off-chain: Generate proof
(bytes memory publicInputs, bytes memory proof) = prover.generateProof(inputs, outputs);

// On-chain: Submit transaction
gelap.transact(publicInputs, proof);
```

---

### `withdraw`

Withdraws assets from the shielded pool back to a public EOA using an SP1-verified ZK proof.

```solidity
function withdraw(
    bytes calldata publicInputs,
    bytes calldata proofBytes,
    address receiver
) external
```

**Parameters:**
- `publicInputs`: ABI-encoded `WithdrawPublicInputsStruct` produced by SP1
- `proofBytes`: The raw ZK proof bytes from the SP1 prover
- `receiver`: The public EOA that will receive the withdrawn funds

**Public Inputs Structure:**
```solidity
struct WithdrawPublicInputsStruct {
    bytes32 newRoot;              // Merkle root after withdrawal is applied
    bytes32[] nullifiers;         // Nullifiers spent by this withdrawal
    address token;                // ERC20 token being withdrawn
    uint256 amount;               // Amount of tokens to send out
    address receiver;             // Public EOA receiver of the withdrawn funds
    bytes32[] newCommitments;     // Optional: change notes created by the withdrawal
}
```

**Requirements:**
- `receiver` must not be the zero address
- SP1 proof must be valid
- `receiver` argument must match `publicInputs.receiver`
- All nullifiers must not have been used before
- `token` must not be the zero address
- `amount` must be greater than 0
- Contract must have sufficient token balance

**Effects:**
- Verifies the ZK proof via `sp1Verifier`
- Marks all `nullifiers` as used
- Updates `merkleRoot` to `newRoot`
- Transfers `amount` of `token` to `receiver`
- Emits `WithdrawExecuted(receiver, token, amount)`
- Emits `AccountUpdated` for each new commitment (change outputs)

**Reverts:**
- If `receiver` is zero address ("Invalid receiver")
- If proof verification fails
- If receiver mismatch ("Receiver mismatch")
- If any nullifier already used ("Nullifier already used")
- If token is zero address ("Invalid token")
- If amount is zero ("Invalid amount")
- If token transfer fails ("Token transfer failed")

**Example:**
```solidity
// Off-chain: Generate withdrawal proof
(bytes memory publicInputs, bytes memory proof) = prover.generateWithdrawProof(
    notes,
    tokenAddress,
    50 ether,
    receiverAddress
);

// On-chain: Execute withdrawal
gelap.withdraw(publicInputs, proof, receiverAddress);
```

---

## Events

### `AccountUpdated`

Emitted whenever a new commitment is added to the Merkle tree.

```solidity
event AccountUpdated(bytes32 commitment, bytes encryptedMemo)
```

**Parameters:**
- `commitment`: The inserted Pedersen commitment
- `encryptedMemo`: Encrypted metadata for the receiver wallet (optional, can be empty)

**Emitted By:**
- `deposit()` - once per deposit
- `transact()` - once per new commitment
- `withdraw()` - once per change commitment

**Usage:**
Wallets and indexers should listen to this event to track new notes and build the Merkle tree state.

---

### `TransactionExecuted`

Emitted whenever a private transaction is executed via SP1.

```solidity
event TransactionExecuted(
    bytes32 newRoot,
    bytes32[] nullifiers,
    bytes32[] newCommitments
)
```

**Parameters:**
- `newRoot`: The new Merkle root after applying the transaction
- `nullifiers`: The nullifiers consumed by this transaction
- `newCommitments`: The commitments created as outputs

**Emitted By:**
- `transact()` - once per transaction

**Usage:**
Indexers can use this event to track state transitions and nullifier usage.

---

### `WithdrawExecuted`

Emitted when a shielded withdrawal is executed.

```solidity
event WithdrawExecuted(
    address indexed receiver,
    address indexed token,
    uint256 amount
)
```

**Parameters:**
- `receiver`: The public EOA that received the withdrawn tokens
- `token`: The ERC20 token that was withdrawn
- `amount`: The amount of tokens transferred out

**Emitted By:**
- `withdraw()` - once per withdrawal

**Usage:**
Track public withdrawals from the shielded pool.

---

## Internal Functions

### `_initZeroHashes`

Initializes the zero hash values used for empty Merkle nodes.

```solidity
function _initZeroHashes() internal
```

Called once during contract construction. Computes:
```
zeroHashes[0] = keccak256(abi.encodePacked(uint256(0)))
zeroHashes[i] = keccak256(abi.encodePacked(zeroHashes[i-1], zeroHashes[i-1]))
```

---

### `_nodeIndex`

Computes a compact storage index for a Merkle tree node.

```solidity
function _nodeIndex(uint256 level, uint256 index)
    internal
    pure
    returns (uint256 storageKey)
```

**Parameters:**
- `level`: The depth of the node in the tree (0-32)
- `index`: The index within that level

**Returns:**
- `storageKey`: A unique key computed as `(level << 32) | index`

---

### `_storeLeaf`

Stores a leaf node at a given index.

```solidity
function _storeLeaf(bytes32 leaf, uint32 index) internal
```

**Parameters:**
- `leaf`: The commitment hash to store
- `index`: The leaf index in the tree

---

### `_hashPair`

Hashes a pair of Merkle tree nodes using keccak256.

```solidity
function _hashPair(bytes32 left, bytes32 right)
    internal
    pure
    returns (bytes32)
```

**Parameters:**
- `left`: The left child hash
- `right`: The right child hash

**Returns:**
- The keccak256 hash of the concatenated children

---

### `_insertLeaf`

Inserts a new leaf into the incremental Merkle tree and updates the root.

```solidity
function _insertLeaf(bytes32 leaf)
    internal
    returns (bytes32 newRoot)
```

**Parameters:**
- `leaf`: The 32-byte commitment being added to the Merkle tree

**Returns:**
- `newRoot`: The updated Merkle tree root after inserting the leaf

**Effects:**
- Stores the leaf at `nextLeafIndex`
- Computes parent nodes up to the root
- Updates `tree` mapping with new nodes
- Updates `merkleRoot`
- Increments `nextLeafIndex`

**Reverts:**
- If tree is full (nextLeafIndex >= 2^32) ("Merkle tree full")

---

## Data Structures

### PublicInputsStruct

Used for private transactions (`transact` function).

```solidity
struct PublicInputsStruct {
    bytes32 newRoot;              // Merkle root after executing the private tx
    bytes32[] nullifiers;         // Nullifiers consumed in this transaction
    bytes32[] newCommitments;     // Newly created commitments (outputs)
}
```

**ABI Encoding:**
```solidity
bytes memory publicInputs = abi.encode(PublicInputsStruct({
    newRoot: computedRoot,
    nullifiers: nullifierArray,
    newCommitments: commitmentArray
}));
```

---

### WithdrawPublicInputsStruct

Used for withdrawals (`withdraw` function).

```solidity
struct WithdrawPublicInputsStruct {
    bytes32 newRoot;              // Merkle root after withdrawal is applied
    bytes32[] nullifiers;         // Nullifiers spent by this withdrawal
    address token;                // ERC20 token being withdrawn
    uint256 amount;               // Amount of tokens to send out
    address receiver;             // Public EOA receiver of the withdrawn funds
    bytes32[] newCommitments;     // Optional: change notes created by the withdrawal
}
```

**ABI Encoding:**
```solidity
bytes memory publicInputs = abi.encode(WithdrawPublicInputsStruct({
    newRoot: computedRoot,
    nullifiers: nullifierArray,
    token: tokenAddress,
    amount: withdrawAmount,
    receiver: receiverAddress,
    newCommitments: changeCommitments
}));
```

---

## Constructor

```solidity
constructor(address verifier, bytes32 programVKey)
```

**Parameters:**
- `verifier`: Address of the SP1 verifier contract
- `programVKey`: The verification key for the SP1 program

**Effects:**
- Initializes `zeroHashes` array
- Sets `sp1Verifier` address
- Sets `sp1ProgramVKey`

**Example:**
```solidity
GelapShieldedAccount gelap = new GelapShieldedAccount(
    0x1234...5678,  // SP1 verifier address
    0xabcd...ef01   // Program verification key
);
```

---

## Error Messages

| Error Message | Function | Cause |
|--------------|----------|-------|
| "Invalid token" | `deposit`, `withdraw` | Token address is zero |
| "Invalid amount" | `deposit`, `withdraw` | Amount is zero |
| "Token transfer failed" | `deposit`, `withdraw` | ERC20 transfer returned false |
| "Nullifier already used" | `transact`, `withdraw` | Attempting to reuse a nullifier |
| "Invalid receiver" | `withdraw` | Receiver address is zero |
| "Receiver mismatch" | `withdraw` | Receiver doesn't match public inputs |
| "Merkle tree full" | `_insertLeaf` | Tree has reached 2^32 leaves |

---

## Gas Considerations

### Approximate Gas Costs

| Function | Typical Gas Cost | Notes |
|----------|-----------------|-------|
| `deposit` | ~150,000 | Includes ERC20 transfer + tree insertion |
| `transact` | ~200,000 + (50,000 × nullifiers) | Proof verification is expensive |
| `withdraw` | ~250,000 + (50,000 × nullifiers) | Includes proof + ERC20 transfer |

**Note:** Actual costs depend on:
- Number of nullifiers
- Number of new commitments
- SP1 verifier implementation
- ERC20 token implementation
- Network congestion
