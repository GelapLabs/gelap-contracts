// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {GelapShieldedAccount} from "../src/GelapShieldedAccount.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev Simple mintable ERC20 token used for unit testing.
contract TestToken is ERC20 {
    constructor() ERC20("TestToken", "TTK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract DepositTest is Test {

    event AccountUpdated(bytes32 commitment, bytes encryptedMemo);
    
    GelapShieldedAccount account;
    TestToken token;

    address user = address(0xBEEF);

    address mockVerifier = address(0xDEAD);
    bytes32 mockVKey = bytes32(uint256(123));

    function setUp() public {
        console.log("=== SETUP START ===");

        account = new GelapShieldedAccount(mockVerifier, mockVKey);
        console.log("Deployed GelapShieldedAccount at:");
        console.logAddress(address(account));

        token = new TestToken();
        console.log("Deployed TestToken at:");
        console.logAddress(address(token));

        token.mint(user, 1_000 ether);
        console.log("Minted 1000 TTK to user:");
        console.logAddress(user);

        vm.startPrank(user);
        token.approve(address(account), type(uint256).max);
        vm.stopPrank();

        console.log("User approved GelapShieldedAccount to spend TTK");
        console.log("=== SETUP COMPLETE ===\n");
    }

    function testDepositUpdatesRoot() public {
        console.log("\n--- testDepositUpdatesRoot ---");

        bytes32 initialRoot = account.merkleRoot();
        console.log("Initial Merkle Root:");
        console.logBytes32(initialRoot);

        bytes32 commitment = keccak256("commitment_1");
        console.log("Commitment to insert:");
        console.logBytes32(commitment);

        vm.prank(user);
        account.deposit(address(token), 10 ether, commitment, "");

        bytes32 newRoot = account.merkleRoot();
        console.log("New Merkle Root:");
        console.logBytes32(newRoot);

        assertTrue(newRoot != initialRoot, "Root should update after deposit");
    }

    function testDepositIncrementsLeafIndex() public {
        console.log("\n--- testDepositIncrementsLeafIndex ---");

        console.log("Initial leaf index:");
        console.logUint(account.nextLeafIndex());
        
        bytes32 commitment = keccak256("leaf_1");

        vm.prank(user);
        account.deposit(address(token), 1 ether, commitment, "");

        console.log("Leaf index after 1 deposit:");
        console.logUint(account.nextLeafIndex());

        assertEq(account.nextLeafIndex(), 1);
    }

    function testDepositTransfersTokens() public {
        console.log("\n--- testDepositTransfersTokens ---");

        uint256 before = token.balanceOf(address(account));
        console.log("Balance before deposit:");
        console.logUint(before);

        bytes32 commitment = keccak256("leaf_2");

        vm.prank(user);
        account.deposit(address(token), 5 ether, commitment, "");

        uint256 afterBal = token.balanceOf(address(account));
        console.log("Balance after deposit:");
        console.logUint(afterBal);

        assertEq(afterBal, before + 5 ether, "Contract must receive tokens");
    }

    function testDepositEmitsEvent() public {
        console.log("\n--- testDepositEmitsEvent ---");

        bytes32 commitment = keccak256("leaf_3");
        bytes memory memo = "hello";

        console.log("Expecting event AccountUpdated");
        console.log("Commitment:");
        console.logBytes32(commitment);
        console.log("Memo:");
        console.logBytes(memo);

        vm.prank(user);

        vm.expectEmit(true, true, true, true);
        emit AccountUpdated(commitment, memo);

        account.deposit(address(token), 3 ether, commitment, memo);
    }

    function testLeafStoredCorrectly() public {
        console.log("\n--- testLeafStoredCorrectly ---");

        bytes32 commitment = keccak256("leaf_4");

        vm.prank(user);
        account.deposit(address(token), 1 ether, commitment, "");

        uint256 key = (uint256(0) << 32) | uint256(0);
        console.log("Expected leaf storage key:");
        console.logUint(key);

        bytes32 stored = account.tree(key);

        console.log("Stored leaf value:");
        console.logBytes32(stored);

        console.log("Expected leaf value:");
        console.logBytes32(commitment);

        assertEq(stored, commitment, "Leaf not stored correctly");
    }
}
