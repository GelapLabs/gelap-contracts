# Deployment Guide

## Prerequisites

- **Foundry** installed (`foundryup`)
- **RPC URL** for target network
- **Private key** with sufficient ETH for gas
- **SP1 Verifier** contract address (or deploy your own)

## Network Configuration

### Supported Networks

| Network | Chain ID | SP1 Verifier Address |
|---------|----------|---------------------|
| Ethereum Mainnet | 1 | TBD |
| Sepolia Testnet | 11155111 | TBD |
| Base Mainnet | 8453 | TBD |
| Base Sepolia | 84532 | TBD |
| Optimism | 10 | TBD |
| Arbitrum One | 42161 | TBD |

> **Note**: Check [SP1 Contracts Deployments](https://github.com/succinctlabs/sp1-contracts/tree/main/contracts/deployments) for latest verifier addresses.

## Environment Setup

### Create `.env` File

```bash
# .env
PRIVATE_KEY=0x...
RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_KEY

# SP1 Configuration
SP1_VERIFIER_ADDRESS=0x...
SP1_PROGRAM_VKEY=0x...
```

### Load Environment

```bash
source .env
```

## Deployment Steps

### 1. Compile Contracts

```bash
forge build
```

Verify compilation succeeds:
```
[⠊] Compiling...
[⠒] Compiling 3 files with 0.8.30
[⠢] Solc 0.8.30 finished in 1.23s
Compiler run successful!
```

### 2. Deploy SP1 Verifier (Optional)

If you need to deploy your own SP1 verifier:

```bash
# This depends on SP1 contracts repository
# Follow SP1 documentation for verifier deployment
```

### 3. Create Deployment Script

Create `script/DeployGelap.s.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {GelapShieldedAccount} from "../src/GelapShieldedAccount.sol";

contract DeployGelap is Script {
    function run() external {
        // Load configuration from environment
        address verifier = vm.envAddress("SP1_VERIFIER_ADDRESS");
        bytes32 programVKey = vm.envBytes32("SP1_PROGRAM_VKEY");
        
        console.log("Deploying GelapShieldedAccount...");
        console.log("SP1 Verifier:", verifier);
        console.logBytes32(programVKey);
        
        // Start broadcasting transactions
        vm.startBroadcast();
        
        // Deploy contract
        GelapShieldedAccount gelap = new GelapShieldedAccount(
            verifier,
            programVKey
        );
        
        vm.stopBroadcast();
        
        console.log("GelapShieldedAccount deployed at:", address(gelap));
        console.log("Initial Merkle Root:");
        console.logBytes32(gelap.merkleRoot());
        console.log("Next Leaf Index:", gelap.nextLeafIndex());
    }
}
```

### 4. Run Deployment

#### Dry Run (Simulation)

```bash
forge script script/DeployGelap.s.sol:DeployGelap \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  -vvvv
```

#### Actual Deployment

```bash
forge script script/DeployGelap.s.sol:DeployGelap \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### 5. Verify Deployment

Check the deployment output:

```
== Logs ==
  Deploying GelapShieldedAccount...
  SP1 Verifier: 0x1234...5678
  0xabcd...ef01
  GelapShieldedAccount deployed at: 0x9876...5432
  Initial Merkle Root:
  0x0000...0000
  Next Leaf Index: 0

== Return ==
0: address 0x9876543210987654321098765432109876543210
```

### 6. Verify on Etherscan

If auto-verification fails, manually verify:

```bash
forge verify-contract \
  --chain-id 11155111 \
  --num-of-optimizations 200 \
  --watch \
  --constructor-args $(cast abi-encode "constructor(address,bytes32)" $SP1_VERIFIER_ADDRESS $SP1_PROGRAM_VKEY) \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version v0.8.30+commit.e3d7d0e \
  0x9876...5432 \
  src/GelapShieldedAccount.sol:GelapShieldedAccount
```

## Post-Deployment Configuration

### 1. Save Deployment Info

Create `deployments.json`:

```json
{
  "sepolia": {
    "chainId": 11155111,
    "contracts": {
      "GelapShieldedAccount": {
        "address": "0x9876543210987654321098765432109876543210",
        "deployer": "0x...",
        "deploymentTx": "0x...",
        "blockNumber": 12345678,
        "timestamp": "2025-12-27T13:00:00Z"
      }
    },
    "configuration": {
      "sp1Verifier": "0x1234567890123456789012345678901234567890",
      "sp1ProgramVKey": "0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
    }
  }
}
```

### 2. Test Deployment

Create a test script to verify contract functionality:

```bash
# Test reading contract state
cast call $GELAP_ADDRESS "merkleRoot()" --rpc-url $RPC_URL

# Test reading nextLeafIndex
cast call $GELAP_ADDRESS "nextLeafIndex()" --rpc-url $RPC_URL

# Test reading sp1Verifier
cast call $GELAP_ADDRESS "sp1Verifier()" --rpc-url $RPC_URL
```

### 3. Initialize Monitoring

Set up event monitoring:

```javascript
// monitor.js
const { ethers } = require('ethers');

const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const gelap = new ethers.Contract(
  process.env.GELAP_ADDRESS,
  GELAP_ABI,
  provider
);

// Listen for deposits
gelap.on('AccountUpdated', (commitment, encryptedMemo, event) => {
  console.log('New deposit:', {
    commitment,
    encryptedMemo,
    blockNumber: event.blockNumber,
    txHash: event.transactionHash
  });
});

// Listen for transactions
gelap.on('TransactionExecuted', (newRoot, nullifiers, newCommitments, event) => {
  console.log('Transaction executed:', {
    newRoot,
    nullifiers,
    newCommitments,
    blockNumber: event.blockNumber
  });
});

// Listen for withdrawals
gelap.on('WithdrawExecuted', (receiver, token, amount, event) => {
  console.log('Withdrawal:', {
    receiver,
    token,
    amount: ethers.formatEther(amount),
    blockNumber: event.blockNumber
  });
});
```

## Upgrade Strategy

### Current Contract (Non-Upgradeable)

The current `GelapShieldedAccount` is **not upgradeable**. To upgrade:

1. Deploy new contract version
2. Migrate state (if possible)
3. Update frontend/prover to use new address

### Future: Upgradeable Pattern

Consider implementing UUPS or Transparent Proxy pattern:

```solidity
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract GelapShieldedAccountV2 is GelapShieldedAccount, UUPSUpgradeable {
    function _authorizeUpgrade(address newImplementation) internal override {
        // Add access control
    }
}
```

## Security Checklist

Before mainnet deployment:

- [ ] **Audit**: Get professional security audit
- [ ] **Testing**: Run comprehensive test suite
- [ ] **Testnet**: Deploy and test on testnet first
- [ ] **SP1 Verification**: Verify SP1 verifier is correct
- [ ] **Program VKey**: Ensure vKey matches your SP1 program
- [ ] **Access Control**: Review if any admin functions needed
- [ ] **Emergency Pause**: Consider adding pause mechanism
- [ ] **Monitoring**: Set up alerts for unusual activity
- [ ] **Documentation**: Update all documentation
- [ ] **Bug Bounty**: Consider launching bug bounty program

## Gas Optimization

### Deployment Gas Costs

Approximate gas costs:

| Network | Gas Price | Deployment Cost |
|---------|-----------|----------------|
| Ethereum Mainnet | 30 gwei | ~0.15 ETH |
| Base | 0.001 gwei | ~$0.50 |
| Optimism | 0.001 gwei | ~$0.50 |
| Arbitrum | 0.1 gwei | ~$5 |

### Optimization Tips

1. **Compiler Settings**:
```toml
# foundry.toml
[profile.default]
optimizer = true
optimizer_runs = 200
via_ir = true
```

2. **Deployment Parameters**:
```bash
# Use higher gas limit if needed
--gas-limit 5000000
```

## Troubleshooting

### Common Deployment Issues

**Issue**: "Insufficient funds for gas"
```bash
# Solution: Fund deployer address
cast send --value 0.1ether $DEPLOYER_ADDRESS --rpc-url $RPC_URL
```

**Issue**: "Nonce too low"
```bash
# Solution: Reset nonce
cast nonce $DEPLOYER_ADDRESS --rpc-url $RPC_URL
```

**Issue**: "Contract verification failed"
```bash
# Solution: Check compiler version and optimization settings
forge verify-contract --help
```

**Issue**: "SP1 Verifier not found"
```bash
# Solution: Verify SP1 verifier address is correct
cast code $SP1_VERIFIER_ADDRESS --rpc-url $RPC_URL
```

## Multi-Network Deployment

### Deploy to Multiple Networks

Create `deploy-all.sh`:

```bash
#!/bin/bash

NETWORKS=("sepolia" "base-sepolia" "optimism-sepolia")

for network in "${NETWORKS[@]}"; do
  echo "Deploying to $network..."
  
  # Load network-specific config
  source .env.$network
  
  # Deploy
  forge script script/DeployGelap.s.sol:DeployGelap \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY
  
  echo "Deployed to $network!"
done
```

## Monitoring and Maintenance

### Set Up Alerts

Use services like:
- **Tenderly** for transaction monitoring
- **OpenZeppelin Defender** for security monitoring
- **The Graph** for indexing events

### Regular Checks

- Monitor contract balance
- Track nullifier usage
- Check Merkle tree growth
- Monitor gas costs
- Review unusual transactions

## Rollback Plan

If issues are discovered:

1. **Pause Operations** (if pause mechanism exists)
2. **Notify Users** via official channels
3. **Investigate Issue** with security team
4. **Deploy Fix** to testnet first
5. **Migrate State** if necessary
6. **Resume Operations** after verification

## Next Steps

After deployment:

1. ✅ Deploy contract
2. ✅ Verify on block explorer
3. ✅ Test basic functionality
4. 🔲 Deploy prover service
5. 🔲 Deploy frontend
6. 🔲 Set up monitoring
7. 🔲 Announce to community
8. 🔲 Launch bug bounty

## Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [SP1 Documentation](https://docs.succinct.xyz/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Ethereum Gas Tracker](https://etherscan.io/gastracker)
