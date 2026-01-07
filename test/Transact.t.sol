// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/GelapShieldedAccount.sol";
import "./mocks/MockSP1Verifier.sol";

/// @title TransactTest
/// @notice Tests GelapShieldedAccount's transact() logic using a mock SP1 verifier.
/// @dev SP1 proof validity is bypassed; only contract logic is tested.
contract TransactTest is Test {
    event AccountUpdated(bytes32 commitment, bytes encryptedMemo);

    GelapShieldedAccount account;
    MockSP1Verifier mockVerifier;

    // Dummy SP1 program key
    bytes32 mockVKey = bytes32(uint256(999));

    // ------------------------------------------------------------------------
    // SETUP
    // ------------------------------------------------------------------------
    /// @notice Deploys a mock verifier and the main shielded account contract.
    /// @dev console2 prints are added to show deployment flow.
    function setUp() public {
        console2.log(
            "=== SETUP: Deploying Mock SP1 Verifier and Shielded Account ==="
        );

        mockVerifier = new MockSP1Verifier();
        console2.log("MockSP1Verifier deployed at:", address(mockVerifier));

        account = new GelapShieldedAccount(address(mockVerifier), mockVKey);
        console2.log("GelapShieldedAccount deployed at:", address(account));

        console2.log("=== SETUP COMPLETE ===");
    }

    // ------------------------------------------------------------------------
    // HELPER: ABI Encode Public Inputs
    // ------------------------------------------------------------------------
    /// @notice Encodes the struct that SP1 prover would normally produce.
    function buildPublicInputs(
        bytes32 newRoot,
        bytes32[] memory nullifiers,
        bytes32[] memory commitments,
        bytes32 keyImage
    ) internal pure returns (bytes memory) {
        PublicInputsStruct memory pub = PublicInputsStruct({
            newRoot: newRoot,
            nullifiers: nullifiers,
            newCommitments: commitments,
            keyImage: keyImage
        });

        return abi.encode(pub);
    }

    // ------------------------------------------------------------------------
    // TEST 1 - Root update
    // ------------------------------------------------------------------------
    /// @notice Checks that the newRoot inside publicInputs updates contract state.
    function testTransactUpdatesRoot() public {
        console2.log("=== TEST 1: Merkle Root Update ===");

        bytes32 newRoot = keccak256("new_root");

        bytes32[] memory nullifiers = new bytes32[](0);
        bytes32[] memory commitments = new bytes32[](0);

        bytes memory pub = buildPublicInputs(
            newRoot,
            nullifiers,
            commitments,
            bytes32(0)
        );

        vm.prank(address(0xBEEF));
        account.transact(pub, hex"1234");

        console2.log("Expected Root:");
        console2.logBytes32(newRoot);
        console2.log("Actual Root:");
        console2.logBytes32(account.merkleRoot());

        assertEq(account.merkleRoot(), newRoot, "Root not updated");
        console2.log("TEST 1 PASSED - Root updated correctly");
    }

    // ------------------------------------------------------------------------
    // TEST 2 - Nullifier stored
    // ------------------------------------------------------------------------
    /// @notice Ensures nullifiers are marked as used after transaction execution.
    function testTransactSetsNullifier() public {
        console2.log("=== TEST 2: Nullifier Set ===");

        bytes32 newRoot = keccak256("root1");

        bytes32[] memory nullifiers = new bytes32[](1);
        nullifiers[0] = keccak256("nf1");

        bytes32[] memory commitments = new bytes32[](0);

        bytes memory pub = buildPublicInputs(
            newRoot,
            nullifiers,
            commitments,
            bytes32(0)
        );

        vm.prank(address(0xBEEF));
        account.transact(pub, hex"aaaa");

        console2.log("Nullifier used:", account.nullifierUsed(nullifiers[0]));

        assertTrue(
            account.nullifierUsed(nullifiers[0]),
            "Nullifier not marked"
        );
        console2.log("TEST 2 PASSED - Nullifier recorded");
    }

    // ------------------------------------------------------------------------
    // TEST 3 - Reject double spend
    // ------------------------------------------------------------------------
    /// @notice If the same nullifier is used twice, transact() must revert.
    function testTransactRejectsDoubleSpend() public {
        console2.log("=== TEST 3: Reject Double Spend ===");

        bytes32 newRoot = keccak256("root2");

        bytes32[] memory nullifiers = new bytes32[](1);
        nullifiers[0] = keccak256("nf_double");

        bytes32[] memory commitments = new bytes32[](0);

        bytes memory pub = buildPublicInputs(
            newRoot,
            nullifiers,
            commitments,
            bytes32(0)
        );

        vm.prank(address(1));
        account.transact(pub, hex"aaaa");

        console2.log("Trying double spend...");

        vm.expectRevert("Nullifier already used");
        vm.prank(address(2));
        account.transact(pub, hex"bbbb");

        console2.log("TEST 3 PASSED - Double spend prevented");
    }

    // ------------------------------------------------------------------------
    // TEST 4 - Commitment events
    // ------------------------------------------------------------------------
    /// @notice transact() must emit an event for each new commitment.
    function testTransactEmitsEventForCommitments() public {
        console2.log("=== TEST 4: Event Emission for Commitments ===");

        bytes32 newRoot = keccak256("root3");

        bytes32[] memory nullifiers = new bytes32[](0);

        bytes32[] memory commitments = new bytes32[](2);
        commitments[0] = keccak256("c1");
        commitments[1] = keccak256("c2");

        bytes memory pub = buildPublicInputs(
            newRoot,
            nullifiers,
            commitments,
            bytes32(0)
        );

        vm.startPrank(address(0xCAFE));

        console2.log("Expecting events for commitments...");

        for (uint256 i = 0; i < commitments.length; i++) {
            vm.expectEmit(true, false, false, true);
            emit AccountUpdated(commitments[i], "");
        }

        console2.log("Running transact() with 2 commitments...");

        account.transact(pub, hex"eeef");

        console2.log("TEST 4 PASSED - Events emitted");
        vm.stopPrank();
    }
}
