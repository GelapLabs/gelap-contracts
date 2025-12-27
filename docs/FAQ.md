# Frequently Asked Questions (FAQ)

## General Questions

### What is Gelap?

Gelap is a privacy-preserving shielded pool system for ERC20 tokens on Ethereum. It uses zero-knowledge proofs (via SP1 zkVM) to enable private transactions while maintaining verifiable correctness on-chain.

### How does Gelap provide privacy?

Gelap uses several cryptographic techniques:
- **Pedersen Commitments**: Hide transaction amounts and recipients
- **Nullifiers**: Prevent double-spending without revealing which note was spent
- **Merkle Trees**: Efficiently prove note ownership without revealing which note
- **Zero-Knowledge Proofs**: Validate transactions without exposing private data

### Is Gelap similar to Tornado Cash?

Yes, Gelap shares similar privacy concepts with Tornado Cash, but with key differences:
- Uses SP1 zkVM instead of Groth16/PLONK
- More flexible (supports any ERC20 token)
- Different Merkle tree implementation
- Modern architecture with better developer experience

### What tokens does Gelap support?

Gelap supports standard ERC20 tokens. However, it may not work correctly with:
- Fee-on-transfer tokens
- Rebasing tokens
- Tokens with transfer hooks
- Non-standard ERC20 implementations

Always test with small amounts first.

## Technical Questions

### What is SP1 zkVM?

SP1 is a zero-knowledge virtual machine by Succinct Labs that allows you to write ZK proofs in Rust instead of custom circuit languages. It makes ZK development more accessible and maintainable.

### Why use SP1 instead of other ZK systems?

**Advantages**:
- Write proofs in Rust (easier than circuit languages)
- Faster development iteration
- Better debugging experience
- Modular and maintainable code
- Active development and support

**Trade-offs**:
- Newer technology (less battle-tested)
- Potentially higher proof generation time
- Larger proof sizes compared to specialized circuits

### How does the Merkle tree work?

Gelap uses a 32-level binary Merkle tree:
- **Capacity**: 2^32 leaves (~4.3 billion commitments)
- **Hash Function**: keccak256 (Ethereum-native)
- **Storage**: Sparse (only stores non-zero nodes)
- **Updates**: Incremental (no full tree recomputation)

Each deposit adds a new leaf (commitment) to the tree, and the root is updated.

### What are nullifiers?

Nullifiers are unique identifiers that mark a note as spent without revealing which note it is.

**Properties**:
- Computed as: `nullifier = Hash(commitment, secret_key)`
- Deterministic for the same note and key
- Unlinkable to the commitment (without the secret key)
- Prevents double-spending

### How are commitments generated?

Commitments are Pedersen-style commitments computed as:

```
commitment = Hash(token, amount, owner_pubkey, blinding_factor)
```

The blinding factor is random and known only to the note owner, providing privacy.

## Usage Questions

### How do I deposit tokens?

1. Approve the Gelap contract to spend your tokens
2. Generate a commitment (using wallet/CLI)
3. Call `deposit(token, amount, commitment, encryptedMemo)`
4. Save your note data locally (commitment, blinding, amount)

**Example**:
```solidity
// 1. Approve
IERC20(token).approve(gelapAddress, amount);

// 2. Generate commitment (off-chain)
bytes32 commitment = generateCommitment(token, amount, pubkey, blinding);

// 3. Deposit
gelap.deposit(token, amount, commitment, memo);
```

### How do I make a private transaction?

1. Select notes to spend (inputs)
2. Define recipients and amounts (outputs)
3. Generate ZK proof using SP1 prover
4. Submit transaction with proof

**Note**: You need access to an SP1 prover service or run your own.

### How do I withdraw tokens?

1. Select notes to spend
2. Generate withdrawal proof with receiver address
3. Call `withdraw(publicInputs, proof, receiver)`
4. Tokens are sent to the receiver's public address

**Important**: The receiver address is public and visible on-chain.

### Do I need to run my own prover?

**Options**:
1. **Use a Prover Service**: Easier but requires trust
2. **Run Your Own**: More private but requires technical setup
3. **Use a Trusted Friend's**: Middle ground

For maximum privacy, run your own prover locally.

### What happens if I lose my note data?

**Unfortunately, you lose access to those funds permanently.**

Your note data (commitment, blinding factor, amount) is like a private key. Without it:
- You cannot prove ownership
- You cannot spend the note
- The funds are locked forever

**Always backup your notes securely!**

## Security Questions

### Is Gelap audited?

**Current Status**: Not yet audited

**Before Mainnet**:
- Professional security audit required
- Extensive testing on testnets
- Bug bounty program recommended

**Do not use in production without an audit.**

### Can transactions be traced?

**Privacy Guarantees**:
- Transaction amounts are hidden
- Sender and receiver identities are hidden
- Transaction graph is obscured

**Potential Leaks**:
- Timing analysis (when transactions occur)
- Amount correlation (unique amounts)
- Network analysis (IP addresses)

Use best practices to maximize privacy.

### What if there's a bug in the SP1 program?

If the SP1 program has a bug, it could:
- Allow invalid proofs to be accepted
- Enable double-spending
- Break privacy guarantees

**Mitigations**:
- Thorough testing and auditing
- Formal verification of critical logic
- Use well-tested cryptographic libraries
- Monitor for unusual activity

### Can the contract be upgraded?

**Current Version**: No, the contract is not upgradeable

**Implications**:
- Bugs cannot be fixed without migration
- Features cannot be added post-deployment
- State migration required for upgrades

**Future**: Consider implementing proxy pattern for upgradeability.

### What happens if the Merkle tree fills up?

The tree can hold 2^32 leaves (~4.3 billion). If it fills:
- New deposits will fail
- Existing notes can still be spent/withdrawn
- Migration to new contract required

**Monitoring**: Track tree growth and plan migration well in advance.

## Privacy Questions

### How private is Gelap really?

**Strong Privacy**:
- On-chain observers cannot see amounts
- Cannot link senders to receivers
- Cannot determine transaction graph

**Potential Weaknesses**:
- Deposits are linkable to depositor
- Withdrawals reveal receiver and amount
- Small anonymity set reduces privacy
- Side-channel attacks possible

**Best Practices**:
- Wait before withdrawing
- Use common denominations
- Mix with other users
- Use privacy tools (Tor, VPN)

### Can I be deanonymized?

**Possible Attack Vectors**:
1. **Timing Analysis**: Correlating deposit/withdrawal times
2. **Amount Correlation**: Unique amounts linking transactions
3. **Network Analysis**: IP address tracking
4. **Metadata Leaks**: Browser fingerprinting, etc.

**Protections**:
- Use random delays
- Split/combine amounts
- Use Tor or VPN
- Run prover locally

### What information is public?

**Public Information**:
- Total value locked in contract
- Number of deposits/transactions/withdrawals
- Merkle root changes
- Withdrawal receiver addresses and amounts
- Deposit commitments (but not amounts)

**Private Information**:
- Transaction amounts (except withdrawals)
- Sender identities
- Receiver identities (except withdrawals)
- Which notes are being spent

## Development Questions

### How do I integrate Gelap into my app?

**Steps**:
1. Deploy or connect to Gelap contract
2. Integrate SP1 prover (service or local)
3. Build wallet functionality for note management
4. Implement event listening for note discovery
5. Create UI for deposits/transactions/withdrawals

See [SP1 Prover Guide](./SP1_PROVER_GUIDE.md) for details.

### Can I build a wallet for Gelap?

Yes! A Gelap wallet needs to:
- Generate and store commitments
- Track notes via events
- Manage blinding factors and keys
- Interface with SP1 prover
- Submit transactions to contract

### What are the gas costs?

**Approximate Costs** (on Ethereum mainnet):
- **Deposit**: ~150,000 gas (~$30 at 30 gwei, $2000 ETH)
- **Transaction**: ~200,000 gas + (50,000 × nullifiers)
- **Withdrawal**: ~250,000 gas + (50,000 × nullifiers)

**Note**: Costs vary by network. L2s are much cheaper.

### Which networks are supported?

Gelap can be deployed on any EVM-compatible network with SP1 verifier support:
- Ethereum Mainnet
- Sepolia Testnet
- Base
- Optimism
- Arbitrum
- Polygon
- And more...

Check [SP1 Contracts](https://github.com/succinctlabs/sp1-contracts) for verifier deployments.

### Can I fork Gelap for my project?

Yes! Gelap is open-source (MIT License). You can:
- Fork and modify
- Deploy your own instance
- Build on top of it
- Integrate into your protocol

Please:
- Give credit
- Get an audit before production
- Contribute improvements back

## Troubleshooting

### Deposit transaction fails

**Common Causes**:
1. Insufficient token approval
2. Insufficient balance
3. Invalid commitment format
4. Gas limit too low

**Solutions**:
```solidity
// Check approval
uint256 allowance = token.allowance(user, gelapAddress);

// Check balance
uint256 balance = token.balanceOf(user);

// Increase gas limit
{gasLimit: 500000}
```

### Proof verification fails

**Common Causes**:
1. Incorrect ABI encoding
2. Wrong program vKey
3. Invalid Merkle proof
4. Nullifier already used

**Solutions**:
- Verify ABI encoding matches contract
- Check vKey is correct
- Ensure tree state is synchronized
- Check nullifier hasn't been used

### Transaction is too expensive

**Solutions**:
1. **Use L2s**: Deploy on Base, Optimism, or Arbitrum
2. **Batch Transactions**: Combine multiple operations
3. **Optimize Proofs**: Reduce number of nullifiers
4. **Wait for Lower Gas**: Use gas price trackers

### Cannot find my notes

**Possible Issues**:
1. Event indexing not working
2. Wrong contract address
3. Notes not backed up
4. Encrypted memo decryption failed

**Solutions**:
- Re-sync events from deployment block
- Verify contract address
- Check backup files
- Verify encryption keys

## Future Development

### What features are planned?

**Roadmap**:
- [ ] Multi-token support in single transaction
- [ ] Encrypted memo improvements
- [ ] Batch proof verification
- [ ] Upgradeable contract pattern
- [ ] Mobile wallet support
- [ ] Hardware wallet integration
- [ ] Decentralized prover network

### Can I contribute?

Yes! Contributions welcome:
- Bug reports
- Feature requests
- Code contributions
- Documentation improvements
- Testing and auditing

See GitHub repository for contribution guidelines.

### Is there a token?

**No.** Gelap is a public good infrastructure project with no token.

## Getting Help

### Where can I get support?

- **Documentation**: Read the docs in `docs/`
- **GitHub Issues**: Report bugs and ask questions
- **Discord**: Join community discussions
- **Email**: support@gelap.xyz

### How do I report a security issue?

**Do NOT** disclose publicly. Email: security@gelap.xyz

Include:
- Description of vulnerability
- Steps to reproduce
- Potential impact

See [SECURITY.md](./SECURITY.md) for responsible disclosure policy.

### Where can I learn more about ZK?

**Resources**:
- [ZK Whiteboard Sessions](https://zkhack.dev/whiteboard/)
- [ZK Learning](https://zk-learning.org/)
- [SP1 Documentation](https://docs.succinct.xyz/)
- [Awesome Zero Knowledge](https://github.com/matter-labs/awesome-zero-knowledge-proofs)

---

**Have more questions?** Open an issue on GitHub or join our Discord!
