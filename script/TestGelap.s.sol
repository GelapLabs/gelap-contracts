// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/GelapShieldedAccount.sol";

/// @title TestGelap - Simplified E2E test
contract TestGelap is Script {
    address constant GELAP = 0x54EC23CBCE1A9d33F05C4d3d79Ec28Aff3c8ce8D;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        console.log("=== E2E TEST ===");

        GelapShieldedAccount gelap = GelapShieldedAccount(GELAP);

        vm.startBroadcast(pk);

        // Test transact
        _testTransact(gelap);

        // Test swap
        _testSwap(gelap);

        vm.stopBroadcast();

        console.log("\n=== ALL TESTS PASSED ===");
    }

    function _testTransact(GelapShieldedAccount gelap) internal {
        console.log("\n[TEST 1] Private Transaction");

        bytes32[] memory nullifiers = new bytes32[](1);
        nullifiers[0] = keccak256(abi.encodePacked("tx_nf", block.timestamp));

        bytes32[] memory commits = new bytes32[](1);
        commits[0] = keccak256("tx_commit");

        PublicInputsStruct memory pub = PublicInputsStruct({
            newRoot: keccak256("tx_root"),
            nullifiers: nullifiers,
            newCommitments: commits,
            keyImage: keccak256("tx_key")
        });

        gelap.transact(abi.encode(pub), hex"1234");
        console.log("Transact: SUCCESS");
    }

    function _testSwap(GelapShieldedAccount gelap) internal {
        console.log("\n[TEST 2] Swap Execution");

        bytes32[] memory nullifiers = new bytes32[](2);
        nullifiers[0] = keccak256(abi.encodePacked("swap_a", block.timestamp));
        nullifiers[1] = keccak256(abi.encodePacked("swap_b", block.timestamp));

        bytes32[] memory commits = new bytes32[](2);
        commits[0] = keccak256("out_a");
        commits[1] = keccak256("out_b");

        SwapPublicInputsStruct memory pub = SwapPublicInputsStruct({
            newRoot: keccak256("swap_root"),
            nullifiers: nullifiers,
            newCommitments: commits,
            orderAKeyImage: keccak256(abi.encodePacked("kia", block.timestamp)),
            orderBKeyImage: keccak256(abi.encodePacked("kib", block.timestamp))
        });

        gelap.executeSwap(abi.encode(pub), hex"1234");
        console.log("Swap: SUCCESS");
    }
}
