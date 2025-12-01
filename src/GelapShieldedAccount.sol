// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GelapShieldedAccount {
    bytes32 public merkleRoot;
    mapping(bytes32 => bool) public nullifierUsed;

    event AccountUpdated(bytes32 commitment, bytes encryptedMemo);

    constructor(address verifier, bytes32 programVKey) {
        // simpen dulu tapi belum dipakai
    }

    function deposit(address token, uint256 amount, bytes32 commitment, bytes calldata encryptedMemo) external {
        // implement di task berikut
    }

    function transact(bytes calldata publicInputs, bytes calldata proofBytes) external {
        // kosong dulu
    }

    function withdraw(bytes calldata publicInputs, bytes calldata proofBytes, address receiver) external {
        // kosong dulu
    }
}
