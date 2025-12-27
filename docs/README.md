# Gelap Documentation

Welcome to the Gelap documentation! Gelap is a privacy-preserving shielded pool system for ERC20 tokens built with SP1 zkVM.

## 📚 Documentation Index

### Getting Started
- [Architecture Overview](./ARCHITECTURE.md) - System design and core components
- [API Reference](./API_REFERENCE.md) - Complete contract API documentation

### Development
- [SP1 Prover Guide](./SP1_PROVER_GUIDE.md) - Build the off-chain prover
- [Testing Guide](./TESTING.md) - Test your implementation
- [Deployment Guide](./DEPLOYMENT.md) - Deploy to networks

### Additional Resources
- [Security Considerations](./SECURITY.md) - Security best practices
- [FAQ](./FAQ.md) - Frequently asked questions

## 🚀 Quick Start

### 1. Clone and Install

```bash
git clone https://github.com/your-org/gelap-contracts
cd gelap-contracts
forge install
```

### 2. Run Tests

```bash
forge test
```

### 3. Deploy

```bash
# Set up environment
cp .env.example .env
# Edit .env with your configuration

# Deploy to testnet
forge script script/DeployGelap.s.sol --rpc-url $RPC_URL --broadcast
```

## 🏗️ Project Structure

```
gelap-contracts/
├── src/
│   └── GelapShieldedAccount.sol    # Main contract
├── test/
│   ├── Deposit.t.sol               # Deposit tests
│   ├── Transact.t.sol              # Transaction tests
│   ├── Withdraw.t.sol              # Withdrawal tests
│   └── mocks/
│       └── MockSP1Verifier.sol     # Mock verifier
├── script/
│   └── DeployGelap.s.sol           # Deployment script
├── docs/                           # Documentation
└── lib/                            # Dependencies
```

## 🔑 Key Features

- **Privacy**: Hide transaction amounts and participants
- **Zero-Knowledge Proofs**: Powered by SP1 zkVM
- **ERC20 Support**: Works with any ERC20 token
- **Merkle Tree**: Efficient state management
- **Double-Spend Protection**: Nullifier tracking

## 📖 Core Concepts

### Commitments
Private notes representing token ownership. Each commitment contains:
- Token address
- Amount
- Owner's public key
- Blinding factor (randomness)

### Nullifiers
Unique identifiers that prevent double-spending without revealing which note was spent.

### Merkle Tree
A 32-level tree storing all commitments. The root represents the current state.

### SP1 zkVM
Zero-knowledge virtual machine that proves correct state transitions off-chain.

## 🔗 Links

- **GitHub**: [gelap-contracts](https://github.com/your-org/gelap-contracts)
- **SP1 Docs**: [docs.succinct.xyz](https://docs.succinct.xyz/)
- **Foundry**: [book.getfoundry.sh](https://book.getfoundry.sh/)

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## 📄 License

MIT License - see LICENSE file for details

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/your-org/gelap-contracts/issues)
- **Discord**: [Join our Discord](#)
- **Email**: support@gelap.xyz

## ⚠️ Disclaimer

This software is in active development and has not been audited. Use at your own risk. Do not use in production without a professional security audit.
