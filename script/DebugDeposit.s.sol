// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGelapShieldedAccount {
    function deposit(
        address token,
        uint256 amount,
        bytes32 commitment,
        bytes calldata encryptedMemo
    ) external;
    function nextLeafIndex() external view returns (uint32);
    function merkleRoot() external view returns (bytes32);
}

contract DebugDeposit is Script {
    address constant SHIELD = 0x0D5Ff322a648a6Ff62C5deA028ea222dFefc5225;
    address constant TOKEN = 0x0A7853C1074722A766a27d4090986bF8A74DA39f;

    function run() external {
        // Check state before
        IGelapShieldedAccount shield = IGelapShieldedAccount(SHIELD);
        console.log("--- PRE-DEPOSIT STATE ---");
        console.log("Next Leaf Index:", shield.nextLeafIndex());
        console.log("Merkle Root:", vm.toString(shield.merkleRoot()));

        // Check token balance
        IERC20 token = IERC20(TOKEN);
        address user = vm.envAddress("USER_ADDRESS");
        uint256 balance = token.balanceOf(user);
        uint256 allowance = token.allowance(user, SHIELD);
        console.log("User:", user);
        console.log("Balance:", balance);
        console.log("Allowance:", allowance);

        // Attempt deposit
        uint256 depositAmount = 1 ether; // 1 mUSDT (18 decimals)
        bytes32 commitment = keccak256(
            abi.encodePacked(block.timestamp, user, depositAmount)
        );

        console.log("--- ATTEMPTING DEPOSIT ---");
        console.log("Amount:", depositAmount);
        console.log("Commitment:", vm.toString(commitment));

        if (balance < depositAmount) {
            console.log("ERROR: Insufficient balance");
            return;
        }

        if (allowance < depositAmount) {
            console.log("Approving token...");
            vm.startBroadcast();
            token.approve(SHIELD, type(uint256).max);
            vm.stopBroadcast();
            console.log("Approved!");
        }

        vm.startBroadcast();
        try shield.deposit(TOKEN, depositAmount, commitment, "") {
            console.log("DEPOSIT SUCCESS!");
        } catch Error(string memory reason) {
            console.log("DEPOSIT FAILED - Reason:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("DEPOSIT FAILED - Low level error");
            console.logBytes(lowLevelData);
        }
        vm.stopBroadcast();

        // Check state after
        console.log("--- POST-DEPOSIT STATE ---");
        console.log("Next Leaf Index:", shield.nextLeafIndex());
    }
}
