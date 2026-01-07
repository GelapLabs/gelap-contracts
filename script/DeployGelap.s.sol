// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/GelapShieldedAccount.sol";

contract DeployGelap is Script {
    function run() external {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // SP1 Verifier address - use mock for testnet or real SP1 verifier
        // For Mantle Sepolia, we'll use a mock initially
        address sp1Verifier = vm.envOr("SP1_VERIFIER", address(0));

        // Placeholder program vKey (will be replaced with real one)
        bytes32 programVKey = vm.envOr("PROGRAM_VKEY", bytes32(uint256(1)));

        console.log("Deploying GelapShieldedAccount...");
        console.log("SP1 Verifier:", sp1Verifier);
        console.log("Program vKey:");
        console.logBytes32(programVKey);

        vm.startBroadcast(deployerPrivateKey);

        // If no verifier provided, deploy mock verifier first
        if (sp1Verifier == address(0)) {
            console.log(
                "No SP1 Verifier provided, deploying MockSP1Verifier..."
            );
            MockSP1Verifier mockVerifier = new MockSP1Verifier();
            sp1Verifier = address(mockVerifier);
            console.log("MockSP1Verifier deployed at:", sp1Verifier);
        }

        // Deploy the main contract
        GelapShieldedAccount gelap = new GelapShieldedAccount(
            sp1Verifier,
            programVKey
        );

        console.log("GelapShieldedAccount deployed at:", address(gelap));
        console.log("Merkle Root:", uint256(gelap.merkleRoot()));

        vm.stopBroadcast();

        // Log deployment info
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network: Mantle Sepolia");
        console.log("GelapShieldedAccount:", address(gelap));
        console.log("SP1Verifier:", sp1Verifier);
    }
}

// Inline MockSP1Verifier for deployment
contract MockSP1Verifier {
    function verifyProof(
        bytes32,
        bytes calldata,
        bytes calldata
    ) external pure {
        // Always passes - for testnet only!
    }
}
