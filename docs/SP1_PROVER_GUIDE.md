# SP1 Prover Integration Guide

## Overview

This guide explains how to implement the off-chain SP1 prover component for Gelap. The prover is responsible for generating zero-knowledge proofs that validate private state transitions.

## Prerequisites

- **Rust** (latest stable version)
- **SP1 SDK** installed (`cargo install sp1-cli`)
- **Foundry** for contract interaction
- Understanding of Merkle trees and cryptographic commitments

## SP1 Program Structure

The SP1 program (guest code) runs inside the zkVM and performs the heavy cryptographic computations.

### Directory Structure

```
prover/
├── program/              # SP1 guest code (runs in zkVM)
│   ├── Cargo.toml
│   └── src/
│       └── main.rs      # Main prover logic
├── script/              # Host code (orchestrates proving)
│   ├── Cargo.toml
│   └── src/
│       ├── main.rs      # CLI interface
│       └── lib.rs       # Prover utilities
└── Cargo.toml
```

## Guest Program Implementation

### Core Data Structures

```rust
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Note {
    pub token: [u8; 20],      // ERC20 token address
    pub amount: u64,           // Token amount
    pub owner: [u8; 32],       // Owner's public key
    pub blinding: [u8; 32],    // Random blinding factor
}

#[derive(Serialize, Deserialize, Debug)]
pub struct MerkleProof {
    pub leaf_index: u32,
    pub siblings: Vec<[u8; 32]>,  // 32 siblings for 32-level tree
}

#[derive(Serialize, Deserialize, Debug)]
pub struct TransactionInput {
    pub note: Note,
    pub merkle_proof: MerkleProof,
    pub secret_key: [u8; 32],
}

#[derive(Serialize, Deserialize, Debug)]
pub struct TransactionOutput {
    pub token: [u8; 20],
    pub amount: u64,
    pub recipient: [u8; 32],
}

#[derive(Serialize, Deserialize, Debug)]
pub struct PublicInputs {
    pub new_root: [u8; 32],
    pub nullifiers: Vec<[u8; 32]>,
    pub new_commitments: Vec<[u8; 32]>,
}
```

### Main Prover Logic

```rust
// program/src/main.rs
#![no_main]
sp1_zkvm::entrypoint!(main);

use sha3::{Digest, Keccak256};

pub fn main() {
    // Read private inputs from stdin
    let inputs: Vec<TransactionInput> = sp1_zkvm::io::read();
    let outputs: Vec<TransactionOutput> = sp1_zkvm::io::read();
    let current_root: [u8; 32] = sp1_zkvm::io::read();
    
    // 1. Verify Merkle inclusion proofs
    for input in &inputs {
        let commitment = compute_commitment(&input.note);
        assert!(
            verify_merkle_proof(&commitment, &input.merkle_proof, &current_root),
            "Invalid Merkle proof"
        );
    }
    
    // 2. Verify ownership and generate nullifiers
    let mut nullifiers = Vec::new();
    for input in &inputs {
        // Verify ownership by checking secret key matches public key
        let derived_pubkey = derive_public_key(&input.secret_key);
        assert_eq!(derived_pubkey, input.note.owner, "Invalid ownership");
        
        // Generate nullifier
        let commitment = compute_commitment(&input.note);
        let nullifier = compute_nullifier(&commitment, &input.secret_key);
        nullifiers.push(nullifier);
    }
    
    // 3. Verify balance conservation
    let total_input: u64 = inputs.iter().map(|i| i.note.amount).sum();
    let total_output: u64 = outputs.iter().map(|o| o.amount).sum();
    assert_eq!(total_input, total_output, "Balance mismatch");
    
    // 4. Generate new commitments
    let mut new_commitments = Vec::new();
    for output in &outputs {
        let blinding = generate_random_blinding();
        let note = Note {
            token: output.token,
            amount: output.amount,
            owner: output.recipient,
            blinding,
        };
        let commitment = compute_commitment(&note);
        new_commitments.push(commitment);
    }
    
    // 5. Compute new Merkle root
    let new_root = compute_new_root(&current_root, &new_commitments);
    
    // 6. Output public values
    let public_inputs = PublicInputs {
        new_root,
        nullifiers,
        new_commitments,
    };
    
    sp1_zkvm::io::commit(&public_inputs);
}

/// Compute Pedersen commitment for a note
fn compute_commitment(note: &Note) -> [u8; 32] {
    let mut hasher = Keccak256::new();
    hasher.update(&note.token);
    hasher.update(&note.amount.to_be_bytes());
    hasher.update(&note.owner);
    hasher.update(&note.blinding);
    hasher.finalize().into()
}

/// Compute nullifier from commitment and secret key
fn compute_nullifier(commitment: &[u8; 32], secret_key: &[u8; 32]) -> [u8; 32] {
    let mut hasher = Keccak256::new();
    hasher.update(commitment);
    hasher.update(secret_key);
    hasher.finalize().into()
}

/// Verify Merkle inclusion proof
fn verify_merkle_proof(
    leaf: &[u8; 32],
    proof: &MerkleProof,
    root: &[u8; 32]
) -> bool {
    let mut current_hash = *leaf;
    let mut index = proof.leaf_index;
    
    for sibling in &proof.siblings {
        let mut hasher = Keccak256::new();
        
        if index % 2 == 0 {
            // Current is left child
            hasher.update(&current_hash);
            hasher.update(sibling);
        } else {
            // Current is right child
            hasher.update(sibling);
            hasher.update(&current_hash);
        }
        
        current_hash = hasher.finalize().into();
        index /= 2;
    }
    
    current_hash == *root
}

/// Compute new Merkle root after inserting commitments
fn compute_new_root(
    current_root: &[u8; 32],
    new_commitments: &[[u8; 32]]
) -> [u8; 32] {
    // Implementation depends on your tree update strategy
    // This is a simplified version
    let mut root = *current_root;
    
    for commitment in new_commitments {
        root = update_tree_with_leaf(&root, commitment);
    }
    
    root
}

/// Derive public key from secret key (simplified)
fn derive_public_key(secret_key: &[u8; 32]) -> [u8; 32] {
    // In production, use proper elliptic curve cryptography
    let mut hasher = Keccak256::new();
    hasher.update(secret_key);
    hasher.finalize().into()
}

/// Generate random blinding factor
fn generate_random_blinding() -> [u8; 32] {
    // In zkVM, use deterministic randomness from inputs
    sp1_zkvm::io::read()
}

fn update_tree_with_leaf(root: &[u8; 32], leaf: &[u8; 32]) -> [u8; 32] {
    // Simplified - implement full incremental tree logic
    let mut hasher = Keccak256::new();
    hasher.update(root);
    hasher.update(leaf);
    hasher.finalize().into()
}
```

## Host Program Implementation

### Prover Service

```rust
// script/src/lib.rs
use sp1_sdk::{ProverClient, SP1Stdin};
use serde::{Deserialize, Serialize};

pub struct GelapProver {
    client: ProverClient,
    elf: &'static [u8],
}

impl GelapProver {
    pub fn new(elf: &'static [u8]) -> Self {
        let client = ProverClient::new();
        Self { client, elf }
    }
    
    /// Generate proof for a private transaction
    pub fn prove_transaction(
        &self,
        inputs: Vec<TransactionInput>,
        outputs: Vec<TransactionOutput>,
        current_root: [u8; 32],
    ) -> Result<ProofOutput, Box<dyn std::error::Error>> {
        // Prepare stdin for the zkVM
        let mut stdin = SP1Stdin::new();
        stdin.write(&inputs);
        stdin.write(&outputs);
        stdin.write(&current_root);
        
        // Generate proof
        let (pk, vk) = self.client.setup(self.elf);
        let proof = self.client.prove(&pk, stdin).run()?;
        
        // Extract public values
        let public_inputs: PublicInputs = proof.public_values.read();
        
        // Encode for Solidity
        let public_values_bytes = encode_public_inputs(&public_inputs);
        
        Ok(ProofOutput {
            vkey: vk.bytes32(),
            public_values: public_values_bytes,
            proof: proof.bytes(),
        })
    }
    
    /// Generate proof for withdrawal
    pub fn prove_withdrawal(
        &self,
        inputs: Vec<TransactionInput>,
        token: [u8; 20],
        amount: u64,
        receiver: [u8; 20],
        change_outputs: Vec<TransactionOutput>,
        current_root: [u8; 32],
    ) -> Result<ProofOutput, Box<dyn std::error::Error>> {
        // Similar to prove_transaction but with withdrawal-specific logic
        todo!("Implement withdrawal proof generation")
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ProofOutput {
    pub vkey: String,
    pub public_values: Vec<u8>,
    pub proof: Vec<u8>,
}

/// Encode PublicInputs for Solidity ABI
fn encode_public_inputs(inputs: &PublicInputs) -> Vec<u8> {
    use ethers::abi::{encode, Token};
    
    let tokens = vec![
        Token::FixedBytes(inputs.new_root.to_vec()),
        Token::Array(
            inputs.nullifiers
                .iter()
                .map(|n| Token::FixedBytes(n.to_vec()))
                .collect()
        ),
        Token::Array(
            inputs.new_commitments
                .iter()
                .map(|c| Token::FixedBytes(c.to_vec()))
                .collect()
        ),
    ];
    
    encode(&tokens)
}
```

### CLI Interface

```rust
// script/src/main.rs
use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "gelap-prover")]
#[command(about = "Gelap SP1 Prover CLI")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate proof for a private transaction
    Transact {
        #[arg(short, long)]
        inputs: PathBuf,
        
        #[arg(short, long)]
        outputs: PathBuf,
        
        #[arg(short, long)]
        root: String,
    },
    
    /// Generate proof for withdrawal
    Withdraw {
        #[arg(short, long)]
        inputs: PathBuf,
        
        #[arg(short, long)]
        token: String,
        
        #[arg(short, long)]
        amount: u64,
        
        #[arg(short, long)]
        receiver: String,
    },
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();
    
    // Load ELF binary
    const ELF: &[u8] = include_bytes!("../../program/elf/riscv32im-succinct-zkvm-elf");
    
    let prover = GelapProver::new(ELF);
    
    match cli.command {
        Commands::Transact { inputs, outputs, root } => {
            // Load inputs from JSON files
            let inputs_data = std::fs::read_to_string(inputs)?;
            let outputs_data = std::fs::read_to_string(outputs)?;
            
            let inputs: Vec<TransactionInput> = serde_json::from_str(&inputs_data)?;
            let outputs: Vec<TransactionOutput> = serde_json::from_str(&outputs_data)?;
            let root: [u8; 32] = hex::decode(&root)?.try_into().unwrap();
            
            // Generate proof
            let proof_output = prover.prove_transaction(inputs, outputs, root)?;
            
            // Output as JSON
            println!("{}", serde_json::to_string_pretty(&proof_output)?);
        }
        
        Commands::Withdraw { .. } => {
            todo!("Implement withdraw command")
        }
    }
    
    Ok(())
}
```

## Building and Running

### Build the SP1 Program

```bash
cd prover/program
cargo prove build
```

### Run the Prover

```bash
# Create input files
cat > inputs.json << EOF
[
  {
    "note": {
      "token": "0x...",
      "amount": 100,
      "owner": "0x...",
      "blinding": "0x..."
    },
    "merkle_proof": {
      "leaf_index": 0,
      "siblings": ["0x...", ...]
    },
    "secret_key": "0x..."
  }
]
EOF

cat > outputs.json << EOF
[
  {
    "token": "0x...",
    "amount": 100,
    "recipient": "0x..."
  }
]
EOF

# Generate proof
cargo run --release -- transact \
  --inputs inputs.json \
  --outputs outputs.json \
  --root 0x1234...
```

## Integration with Smart Contract

### Submit Transaction

```javascript
// Using ethers.js
const proofData = JSON.parse(proofOutput);

const tx = await gelapContract.transact(
  proofData.public_values,
  proofData.proof
);

await tx.wait();
console.log("Transaction executed!");
```

## Performance Optimization

### Caching Merkle Proofs
- Maintain local database of tree state
- Cache sibling paths for frequently used notes
- Use incremental tree updates

### Parallel Proof Generation
- Generate proofs for multiple transactions in parallel
- Use proof aggregation if supported by SP1

### Hardware Acceleration
- Use GPU acceleration for proof generation
- Consider cloud-based proving services

## Security Considerations

### Input Validation
- Validate all inputs before proof generation
- Check note ownership
- Verify balance sufficiency

### Randomness
- Use cryptographically secure randomness for blinding factors
- Never reuse blinding factors

### Key Management
- Store secret keys securely
- Use hardware wallets when possible
- Implement key derivation (BIP-32/44)

## Testing

### Unit Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_commitment_computation() {
        let note = Note {
            token: [0u8; 20],
            amount: 100,
            owner: [1u8; 32],
            blinding: [2u8; 32],
        };
        
        let commitment = compute_commitment(&note);
        assert_eq!(commitment.len(), 32);
    }
    
    #[test]
    fn test_merkle_proof_verification() {
        // Test Merkle proof logic
    }
}
```

### Integration Tests

```rust
#[test]
fn test_full_proof_generation() {
    let prover = GelapProver::new(ELF);
    
    // Create test inputs
    let inputs = vec![/* ... */];
    let outputs = vec![/* ... */];
    let root = [0u8; 32];
    
    // Generate proof
    let result = prover.prove_transaction(inputs, outputs, root);
    assert!(result.is_ok());
}
```

## Troubleshooting

### Common Issues

**Issue**: Proof verification fails on-chain
- **Solution**: Ensure ABI encoding matches exactly
- Check that vKey is correct
- Verify Merkle root computation matches contract

**Issue**: Slow proof generation
- **Solution**: Use release builds (`--release`)
- Enable hardware acceleration
- Reduce circuit complexity

**Issue**: Merkle proof invalid
- **Solution**: Verify tree state is synchronized
- Check sibling hash computation
- Ensure correct tree depth (32 levels)

## Next Steps

1. Implement full Merkle tree synchronization
2. Add support for multiple token types
3. Implement encrypted memo decryption
4. Build wallet integration
5. Deploy prover as a service
