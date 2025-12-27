# Testing Guide

## Overview

This guide covers testing strategies for the Gelap shielded pool system, including unit tests, integration tests, and security testing.

## Test Structure

```
test/
├── Deposit.t.sol          # Deposit function tests
├── Transact.t.sol         # Private transaction tests
├── Withdraw.t.sol         # Withdrawal tests
├── MerkleTree.t.sol       # Merkle tree logic tests (TODO)
├── Integration.t.sol      # End-to-end tests (TODO)
└── mocks/
    └── MockSP1Verifier.sol # Mock verifier for testing
```

## Running Tests

### Run All Tests

```bash
forge test
```

### Run Specific Test File

```bash
forge test --match-path test/Deposit.t.sol
```

### Run Specific Test Function

```bash
forge test --match-test testDepositUpdatesRoot
```

### Run with Verbosity

```bash
# Show logs
forge test -vv

# Show stack traces
forge test -vvv

# Show all details
forge test -vvvv
```

### Run with Gas Report

```bash
forge test --gas-report
```

## Unit Tests

### Deposit Tests

**File**: `test/Deposit.t.sol`

Tests cover:
- ✅ Merkle root updates after deposit
- ✅ Leaf index incrementation
- ✅ Token transfers
- ✅ Event emission
- ✅ Correct leaf storage

**Run**:
```bash
forge test --match-path test/Deposit.t.sol -vv
```

**Expected Output**:
```
Running 5 tests for test/Deposit.t.sol:DepositTest
[PASS] testDepositUpdatesRoot() (gas: 123456)
[PASS] testDepositIncrementsLeafIndex() (gas: 123456)
[PASS] testDepositTransfersTokens() (gas: 123456)
[PASS] testDepositEmitsEvent() (gas: 123456)
[PASS] testLeafStoredCorrectly() (gas: 123456)
```

### Transaction Tests

**File**: `test/Transact.t.sol`

Tests cover:
- ✅ Merkle root updates
- ✅ Nullifier tracking
- ✅ Double-spend prevention
- ✅ Event emission for commitments

**Run**:
```bash
forge test --match-path test/Transact.t.sol -vv
```

### Withdrawal Tests

**File**: `test/Withdraw.t.sol`

Tests cover:
- ✅ Successful withdrawals
- ✅ Token transfers to receiver
- ✅ Double-spend prevention
- ✅ Receiver mismatch protection

**Run**:
```bash
forge test --match-path test/Withdraw.t.sol -vv
```

## Integration Tests

### End-to-End Flow Test

Create `test/Integration.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/GelapShieldedAccount.sol";
import "./mocks/MockSP1Verifier.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("TestToken", "TTK") {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract IntegrationTest is Test {
    GelapShieldedAccount gelap;
    MockSP1Verifier verifier;
    TestToken token;
    
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    
    function setUp() public {
        verifier = new MockSP1Verifier();
        gelap = new GelapShieldedAccount(address(verifier), bytes32(uint256(1)));
        token = new TestToken();
        
        // Fund users
        token.mint(alice, 1000 ether);
        token.mint(bob, 1000 ether);
        
        // Approve contract
        vm.prank(alice);
        token.approve(address(gelap), type(uint256).max);
        
        vm.prank(bob);
        token.approve(address(gelap), type(uint256).max);
    }
    
    function testFullFlow() public {
        // 1. Alice deposits 100 tokens
        bytes32 aliceCommitment = keccak256("alice_note_1");
        
        vm.prank(alice);
        gelap.deposit(address(token), 100 ether, aliceCommitment, "");
        
        assertEq(gelap.nextLeafIndex(), 1);
        
        // 2. Bob deposits 50 tokens
        bytes32 bobCommitment = keccak256("bob_note_1");
        
        vm.prank(bob);
        gelap.deposit(address(token), 50 ether, bobCommitment, "");
        
        assertEq(gelap.nextLeafIndex(), 2);
        
        // 3. Alice sends 30 tokens to Bob (private transaction)
        bytes32[] memory nullifiers = new bytes32[](1);
        nullifiers[0] = keccak256("alice_nullifier_1");
        
        bytes32[] memory newCommitments = new bytes32[](2);
        newCommitments[0] = keccak256("bob_receives_30");
        newCommitments[1] = keccak256("alice_change_70");
        
        bytes32 newRoot = keccak256("new_root_after_tx");
        
        PublicInputsStruct memory pub = PublicInputsStruct({
            newRoot: newRoot,
            nullifiers: nullifiers,
            newCommitments: newCommitments
        });
        
        gelap.transact(abi.encode(pub), hex"proof");
        
        assertTrue(gelap.nullifierUsed(nullifiers[0]));
        assertEq(gelap.merkleRoot(), newRoot);
        
        // 4. Bob withdraws 50 tokens
        bytes32[] memory bobNullifiers = new bytes32[](2);
        bobNullifiers[0] = keccak256("bob_nullifier_1");
        bobNullifiers[1] = keccak256("bob_nullifier_2");
        
        WithdrawPublicInputsStruct memory withdrawPub = WithdrawPublicInputsStruct({
            newRoot: keccak256("final_root"),
            nullifiers: bobNullifiers,
            token: address(token),
            amount: 50 ether,
            receiver: bob,
            newCommitments: new bytes32[](0)
        });
        
        uint256 bobBalanceBefore = token.balanceOf(bob);
        
        gelap.withdraw(abi.encode(withdrawPub), hex"proof", bob);
        
        assertEq(token.balanceOf(bob), bobBalanceBefore + 50 ether);
    }
}
```

**Run**:
```bash
forge test --match-path test/Integration.t.sol -vvv
```

## Fuzz Testing

### Deposit Fuzz Test

```solidity
function testFuzzDeposit(uint256 amount) public {
    // Bound amount to reasonable range
    amount = bound(amount, 1, 1000000 ether);
    
    // Mint tokens to user
    token.mint(user, amount);
    
    vm.startPrank(user);
    token.approve(address(gelap), amount);
    
    bytes32 commitment = keccak256(abi.encodePacked(amount));
    
    uint32 indexBefore = gelap.nextLeafIndex();
    gelap.deposit(address(token), amount, commitment, "");
    
    assertEq(gelap.nextLeafIndex(), indexBefore + 1);
    assertEq(token.balanceOf(address(gelap)), amount);
    vm.stopPrank();
}
```

**Run**:
```bash
forge test --match-test testFuzzDeposit
```

## Invariant Testing

### Invariant: Total Supply Conservation

```solidity
contract InvariantTest is Test {
    GelapShieldedAccount gelap;
    TestToken token;
    Handler handler;
    
    function setUp() public {
        MockSP1Verifier verifier = new MockSP1Verifier();
        gelap = new GelapShieldedAccount(address(verifier), bytes32(uint256(1)));
        token = new TestToken();
        
        handler = new Handler(gelap, token);
        
        targetContract(address(handler));
    }
    
    function invariant_totalSupplyConserved() public {
        uint256 contractBalance = token.balanceOf(address(gelap));
        uint256 totalDeposited = handler.totalDeposited();
        uint256 totalWithdrawn = handler.totalWithdrawn();
        
        assertEq(contractBalance, totalDeposited - totalWithdrawn);
    }
}

contract Handler {
    GelapShieldedAccount public gelap;
    TestToken public token;
    
    uint256 public totalDeposited;
    uint256 public totalWithdrawn;
    
    constructor(GelapShieldedAccount _gelap, TestToken _token) {
        gelap = _gelap;
        token = _token;
    }
    
    function deposit(uint256 amount) public {
        amount = bound(amount, 1, 1000 ether);
        
        token.mint(address(this), amount);
        token.approve(address(gelap), amount);
        
        bytes32 commitment = keccak256(abi.encodePacked(amount, block.timestamp));
        gelap.deposit(address(token), amount, commitment, "");
        
        totalDeposited += amount;
    }
}
```

**Run**:
```bash
forge test --match-test invariant
```

## Gas Benchmarking

### Create Gas Report

```bash
forge test --gas-report > gas-report.txt
```

### Optimize Gas Usage

Compare gas costs before and after optimization:

```bash
# Before optimization
forge test --gas-report | grep "deposit"

# After optimization
forge test --gas-report | grep "deposit"
```

## Coverage Analysis

### Generate Coverage Report

```bash
forge coverage
```

### Detailed Coverage

```bash
forge coverage --report lcov
genhtml lcov.info -o coverage
```

Open `coverage/index.html` in browser.

## Security Testing

### Static Analysis with Slither

```bash
# Install Slither
pip3 install slither-analyzer

# Run analysis
slither src/GelapShieldedAccount.sol
```

### Mythril Analysis

```bash
# Install Mythril
pip3 install mythril

# Run analysis
myth analyze src/GelapShieldedAccount.sol
```

### Aderyn Analysis

```bash
# Install Aderyn
cargo install aderyn

# Run analysis
aderyn src/
```

## Continuous Integration

### GitHub Actions Workflow

Create `.github/workflows/test.yml`:

```yaml
name: Tests

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: recursive
      
      - name: Install Foundry
        uses: foundry-rs/foundry-toolchain@v1
      
      - name: Run tests
        run: forge test -vvv
      
      - name: Generate gas report
        run: forge test --gas-report
      
      - name: Check coverage
        run: forge coverage
```

## Test Checklist

Before deployment:

- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] Fuzz tests pass
- [ ] Invariant tests pass
- [ ] Gas usage is optimized
- [ ] Coverage > 90%
- [ ] Static analysis clean
- [ ] No security vulnerabilities
- [ ] Edge cases tested
- [ ] Error messages verified

## Common Test Patterns

### Expect Revert

```solidity
vm.expectRevert("Error message");
contract.functionThatReverts();
```

### Expect Event

```solidity
vm.expectEmit(true, true, true, true);
emit EventName(arg1, arg2);
contract.functionThatEmits();
```

### Time Manipulation

```solidity
vm.warp(block.timestamp + 1 days);
```

### Prank (Impersonate)

```solidity
vm.prank(alice);
contract.function();
```

## Troubleshooting

### Test Fails with "Out of Gas"

```bash
# Increase gas limit
forge test --gas-limit 30000000
```

### Mock Verifier Not Working

Check that `MockSP1Verifier` implements `ISP1Verifier` correctly.

### Events Not Emitted

Use `-vvvv` to see detailed logs:
```bash
forge test -vvvv
```

## Next Steps

1. Add more edge case tests
2. Implement property-based testing
3. Add stress tests
4. Test with real SP1 proofs
5. Perform security audit
