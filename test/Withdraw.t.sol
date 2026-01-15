// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GelapShieldedAccount.sol";
import "./mocks/MockSP1Verifier.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/console2.sol"; // logging

/// @notice Simple ERC20 token for testing withdrawals.
contract TestToken is ERC20 {
    constructor() ERC20("TestToken", "TTK") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @title WithdrawTest
/// @notice Tests the withdraw() function of GelapShieldedAccount.
/// @dev SP1 proof verification is mocked. Only contract logic is tested.
contract WithdrawTest is Test {
    GelapShieldedAccount account;
    MockSP1Verifier mockVerifier;
    TestToken token;

    bytes32 mockVKey = bytes32(uint256(777));
    address receiver = address(0xBEEF);

    function setUp() public {
        console2.log(
            "=== SETUP: Deploying verifier, token, and shielded account ==="
        );

        mockVerifier = new MockSP1Verifier();
        console2.log("MockSP1Verifier deployed at:", address(mockVerifier));

        account = new GelapShieldedAccount(address(mockVerifier), mockVKey);
        console2.log("GelapShieldedAccount deployed at:", address(account));

        token = new TestToken();
        console2.log("TestToken deployed at:", address(token));

        // Fund contract for withdrawals
        token.mint(address(account), 1_000 ether);
        console2.log("Minted 1000 TTK to the shielded account");

        console2.log("=== SETUP COMPLETE ===\n");
    }

    /// @notice Helper to encode WithdrawPublicInputsStruct
    function buildWithdrawInputs(
        bytes32 newRoot,
        bytes32[] memory nullifiers,
        address _token,
        uint256 amount,
        address _receiver,
        bytes32[] memory newCommitments
    ) internal pure returns (bytes memory) {
        WithdrawPublicInputsStruct memory pub = WithdrawPublicInputsStruct({
            newRoot: newRoot,
            nullifiers: nullifiers,
            token: _token,
            amount: amount,
            receiver: _receiver,
            newCommitments: newCommitments
        });
        return abi.encode(pub);
    }

    // ------------------------------------------------------------------------
    // TEST 1 - Withdrawal updates root + transfers funds
    // ------------------------------------------------------------------------
    function testWithdrawUpdatesRootAndTransfers() public {
        console2.log("=== TEST 1: Successful Withdrawal ===");

        bytes32 newRoot = keccak256("withdraw_root");
        bytes32[] memory nullifiers = new bytes32[](1);
        nullifiers[0] = keccak256("withdraw_nf_1");
        bytes32[] memory newCommitments = new bytes32[](0);

        console2.log("Creating withdraw proof public inputs...");

        bytes memory pub = buildWithdrawInputs(
            newRoot,
            nullifiers,
            address(token),
            10 ether,
            receiver,
            newCommitments
        );

        uint256 beforeBal = token.balanceOf(receiver);
        console2.log("Receiver balance before:", beforeBal);

        console2.log("Calling withdraw()... should succeed");
        account.withdraw(pub, hex"1234", receiver);

        console2.log("Checking updated Merkle root:");
        console2.logBytes32(account.merkleRoot());

        console2.log(
            "Checking nullifier status:",
            account.nullifierUsed(nullifiers[0])
        );

        console2.log("Receiver balance after:", token.balanceOf(receiver));

        assertEq(account.merkleRoot(), newRoot, "Root not updated");
        assertTrue(
            account.nullifierUsed(nullifiers[0]),
            "Nullifier not marked"
        );
        assertEq(
            token.balanceOf(receiver),
            beforeBal + 10 ether,
            "Receiver not paid"
        );

        console2.log("TEST 1 PASSED - Withdrawal executed correctly\n");
    }

    // ------------------------------------------------------------------------
    // TEST 2 - Double spend prevention
    // ------------------------------------------------------------------------
    function testWithdrawDoubleSpendReverts() public {
        console2.log("=== TEST 2: Double Spend Should Revert ===");

        bytes32 newRoot = keccak256("withdraw_root2");
        bytes32[] memory nullifiers = new bytes32[](1);
        nullifiers[0] = keccak256("nf_double_withdraw");
        bytes32[] memory newCommitments = new bytes32[](0);

        bytes memory pub = buildWithdrawInputs(
            newRoot,
            nullifiers,
            address(token),
            5 ether,
            receiver,
            newCommitments
        );

        console2.log("First withdraw should succeed");
        account.withdraw(pub, hex"aaaa", receiver);

        console2.log("Second withdraw using SAME nullifier should REVERT");
        vm.expectRevert(
            abi.encodeWithSelector(NullifierAlreadyUsed.selector, nullifiers[0])
        );
        account.withdraw(pub, hex"bbbb", receiver);

        console2.log("TEST 2 PASSED - Double spend prevented\n");
    }

    // ------------------------------------------------------------------------
    // TEST 3 - Receiver mismatch should revert
    // ------------------------------------------------------------------------
    function testWithdrawReceiverMismatchReverts() public {
        console2.log("=== TEST 3: Receiver Mismatch ===");

        bytes32 newRoot = keccak256("withdraw_root3");
        bytes32[] memory nullifiers = new bytes32[](0);
        bytes32[] memory newCommitments = new bytes32[](0);

        bytes memory pub = buildWithdrawInputs(
            newRoot,
            nullifiers,
            address(token),
            1 ether,
            receiver,
            newCommitments
        );

        address other = address(0xCAFE);
        console2.log(
            "Withdraw called with mismatched receiver, expected revert"
        );

        vm.expectRevert(ReceiverMismatch.selector);
        account.withdraw(pub, hex"cccc", other);

        console2.log("TEST 3 PASSED - Receiver mismatch correctly reverted\n");
    }
}
