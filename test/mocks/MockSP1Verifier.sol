// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@sp1/contracts/src/ISP1Verifier.sol";

/// @dev A mock verifier that always accepts any proof.
/// Used for testing the transact() function without needing real SP1 proofs.
contract MockSP1Verifier is ISP1Verifier {
    function verifyProof(
        bytes32 programVKey,
        bytes calldata publicValues,
        bytes calldata proofBytes
    ) external pure override {
        // Do nothing → always valid
    }
}
