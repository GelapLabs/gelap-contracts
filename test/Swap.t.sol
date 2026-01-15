// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/GelapShieldedAccount.sol";
import "./mocks/MockSP1Verifier.sol";

/// @title SwapTest
/// @notice Tests GelapShieldedAccount's executeSwap() logic using a mock SP1 verifier.
/// @dev SP1 proof validity is bypassed; only contract logic is tested.
contract SwapTest is Test {
    event AccountUpdated(bytes32 commitment, bytes encryptedMemo);
    event SwapExecuted(
        bytes32 newRoot,
        bytes32 orderAKeyImage,
        bytes32 orderBKeyImage
    );

    GelapShieldedAccount account;
    MockSP1Verifier mockVerifier;

    bytes32 mockVKey = bytes32(uint256(999));

    // ------------------------------------------------------------------------
    // SETUP
    // ------------------------------------------------------------------------
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
    // HELPER: Build Swap Public Inputs
    // ------------------------------------------------------------------------
    function buildSwapPublicInputs(
        bytes32 newRoot,
        bytes32[] memory nullifiers,
        bytes32[] memory commitments,
        bytes32 orderAKeyImage,
        bytes32 orderBKeyImage
    ) internal pure returns (bytes memory) {
        SwapPublicInputsStruct memory pub = SwapPublicInputsStruct({
            newRoot: newRoot,
            nullifiers: nullifiers,
            newCommitments: commitments,
            orderAKeyImage: orderAKeyImage,
            orderBKeyImage: orderBKeyImage
        });

        return abi.encode(pub);
    }

    // ------------------------------------------------------------------------
    // TEST 1 - Basic swap updates root
    // ------------------------------------------------------------------------
    function testSwapUpdatesRoot() public {
        console2.log("=== TEST 1: Swap Updates Merkle Root ===");

        bytes32 newRoot = keccak256("swap_root");

        bytes32[] memory nullifiers = new bytes32[](2);
        nullifiers[0] = keccak256("order_a_nullifier");
        nullifiers[1] = keccak256("order_b_nullifier");

        bytes32[] memory commitments = new bytes32[](2);
        commitments[0] = keccak256("output_a");
        commitments[1] = keccak256("output_b");

        bytes32 keyImageA = keccak256("key_image_a");
        bytes32 keyImageB = keccak256("key_image_b");

        bytes memory pub = buildSwapPublicInputs(
            newRoot,
            nullifiers,
            commitments,
            keyImageA,
            keyImageB
        );

        vm.prank(address(0xBEEF));
        account.executeSwap(pub, hex"1234");

        console2.log("Expected Root:");
        console2.logBytes32(newRoot);
        console2.log("Actual Root:");
        console2.logBytes32(account.merkleRoot());

        assertEq(account.merkleRoot(), newRoot, "Root not updated");
        console2.log("TEST 1 PASSED - Swap root updated correctly");
    }

    // ------------------------------------------------------------------------
    // TEST 2 - Swap sets nullifiers
    // ------------------------------------------------------------------------
    function testSwapSetsNullifiers() public {
        console2.log("=== TEST 2: Swap Sets Both Nullifiers ===");

        bytes32 newRoot = keccak256("root_2");

        bytes32[] memory nullifiers = new bytes32[](2);
        nullifiers[0] = keccak256("nf_a");
        nullifiers[1] = keccak256("nf_b");

        bytes32[] memory commitments = new bytes32[](2);
        commitments[0] = keccak256("c1");
        commitments[1] = keccak256("c2");

        bytes32 keyImageA = keccak256("kia");
        bytes32 keyImageB = keccak256("kib");

        bytes memory pub = buildSwapPublicInputs(
            newRoot,
            nullifiers,
            commitments,
            keyImageA,
            keyImageB
        );

        vm.prank(address(0xCAFE));
        account.executeSwap(pub, hex"abcd");

        assertTrue(account.nullifierUsed(nullifiers[0]), "Nullifier A not set");
        assertTrue(account.nullifierUsed(nullifiers[1]), "Nullifier B not set");
        assertTrue(account.nullifierUsed(keyImageA), "Key image A not set");
        assertTrue(account.nullifierUsed(keyImageB), "Key image B not set");

        console2.log("TEST 2 PASSED - All nullifiers and key images recorded");
    }

    // ------------------------------------------------------------------------
    // TEST 3 - Reject swap with wrong nullifier count
    // ------------------------------------------------------------------------
    function testSwapRejectsWrongNullifierCount() public {
        console2.log("=== TEST 3: Reject Swap with Wrong Nullifier Count ===");

        bytes32 newRoot = keccak256("root_3");

        // Only 1 nullifier instead of 2
        bytes32[] memory nullifiers = new bytes32[](1);
        nullifiers[0] = keccak256("only_one");

        bytes32[] memory commitments = new bytes32[](2);
        commitments[0] = keccak256("c1");
        commitments[1] = keccak256("c2");

        bytes32 keyImageA = keccak256("kia");
        bytes32 keyImageB = keccak256("kib");

        bytes memory pub = buildSwapPublicInputs(
            newRoot,
            nullifiers,
            commitments,
            keyImageA,
            keyImageB
        );

        vm.expectRevert(InvalidSwapNullifierCount.selector);
        vm.prank(address(0xDEAD));
        account.executeSwap(pub, hex"1234");

        console2.log("TEST 3 PASSED - Wrong nullifier count rejected");
    }

    // ------------------------------------------------------------------------
    // TEST 4 - Reject double spend on nullifier
    // ------------------------------------------------------------------------
    function testSwapRejectsDoubleSpendNullifier() public {
        console2.log("=== TEST 4: Reject Double Spend on Nullifier ===");

        bytes32 newRoot = keccak256("root_4");

        bytes32[] memory nullifiers = new bytes32[](2);
        nullifiers[0] = keccak256("reused_nf");
        nullifiers[1] = keccak256("new_nf");

        bytes32[] memory commitments = new bytes32[](2);
        commitments[0] = keccak256("c1");
        commitments[1] = keccak256("c2");

        bytes32 keyImageA = keccak256("kia_4");
        bytes32 keyImageB = keccak256("kib_4");

        bytes memory pub = buildSwapPublicInputs(
            newRoot,
            nullifiers,
            commitments,
            keyImageA,
            keyImageB
        );

        // First swap should succeed
        vm.prank(address(1));
        account.executeSwap(pub, hex"aaaa");

        // Second swap with same nullifier should fail
        bytes32[] memory nullifiers2 = new bytes32[](2);
        nullifiers2[0] = keccak256("reused_nf"); // Same nullifier!
        nullifiers2[1] = keccak256("different_nf");

        bytes memory pub2 = buildSwapPublicInputs(
            keccak256("root_4b"),
            nullifiers2,
            commitments,
            keccak256("new_kia"),
            keccak256("new_kib")
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                NullifierAlreadyUsed.selector,
                nullifiers2[0]
            )
        );
        vm.prank(address(2));
        account.executeSwap(pub2, hex"bbbb");

        console2.log("TEST 4 PASSED - Double spend on nullifier prevented");
    }

    // ------------------------------------------------------------------------
    // TEST 5 - Reject order replay via key image
    // ------------------------------------------------------------------------
    function testSwapRejectsOrderReplay() public {
        console2.log("=== TEST 5: Reject Order Replay via Key Image ===");

        bytes32 newRoot = keccak256("root_5");
        bytes32 reusedKeyImage = keccak256("reused_key_image");

        bytes32[] memory nullifiers = new bytes32[](2);
        nullifiers[0] = keccak256("nf_5a");
        nullifiers[1] = keccak256("nf_5b");

        bytes32[] memory commitments = new bytes32[](2);
        commitments[0] = keccak256("c1");
        commitments[1] = keccak256("c2");

        bytes memory pub = buildSwapPublicInputs(
            newRoot,
            nullifiers,
            commitments,
            reusedKeyImage,
            keccak256("kib_5")
        );

        // First swap should succeed
        vm.prank(address(1));
        account.executeSwap(pub, hex"aaaa");

        // Second swap with same key image should fail
        bytes32[] memory nullifiers2 = new bytes32[](2);
        nullifiers2[0] = keccak256("nf_5c");
        nullifiers2[1] = keccak256("nf_5d");

        bytes memory pub2 = buildSwapPublicInputs(
            keccak256("root_5b"),
            nullifiers2,
            commitments,
            reusedKeyImage,
            keccak256("new_kib")
        );

        vm.expectRevert(OrderAAlreadyExecuted.selector);
        vm.prank(address(2));
        account.executeSwap(pub2, hex"bbbb");

        console2.log("TEST 5 PASSED - Order replay via key image prevented");
    }

    // ------------------------------------------------------------------------
    // TEST 6 - Swap emits correct events
    // ------------------------------------------------------------------------
    function testSwapEmitsEvents() public {
        console2.log("=== TEST 6: Swap Emits Correct Events ===");

        bytes32 newRoot = keccak256("root_6");

        bytes32[] memory nullifiers = new bytes32[](2);
        nullifiers[0] = keccak256("nf_6a");
        nullifiers[1] = keccak256("nf_6b");

        bytes32[] memory commitments = new bytes32[](2);
        commitments[0] = keccak256("output_6a");
        commitments[1] = keccak256("output_6b");

        bytes32 keyImageA = keccak256("kia_6");
        bytes32 keyImageB = keccak256("kib_6");

        bytes memory pub = buildSwapPublicInputs(
            newRoot,
            nullifiers,
            commitments,
            keyImageA,
            keyImageB
        );

        // Expect SwapExecuted event
        vm.expectEmit(true, true, true, true);
        emit SwapExecuted(newRoot, keyImageA, keyImageB);

        vm.prank(address(0xCAFE));
        account.executeSwap(pub, hex"cafe");

        console2.log("TEST 6 PASSED - SwapExecuted event emitted");
    }
}
