// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {GelapShieldedAccount} from "../src/GelapShieldedAccount.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev Simple mintable ERC20 token used for unit testing.
///      Allows us to emulate real deposit flows without relying on external contracts.
contract TestToken is ERC20 {
    constructor() ERC20("TestToken", "TTK") {}

    /// @notice Mint tokens to an address (testing only).
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @title DepositTest
/// @notice Test suite validating the deposit() behavior for GelapShieldedAccount.
/// @dev All tests in this file ensure correct Merkle tree behavior, token transfer,
///      and event emission when a user deposits into the shielded pool.
contract DepositTest is Test {

    /// @notice Event must be redeclared so Foundry can detect and match it in expectEmit().
    event AccountUpdated(bytes32 commitment, bytes encryptedMemo);
    
    GelapShieldedAccount account;
    TestToken token;

    /// @dev The user performing deposits in all tests.
    address user = address(0xBEEF);

    /// @dev Mock SP1 verifier + vKey (unused until Part 2, but required by constructor).
    address mockVerifier = address(0xDEAD);
    bytes32 mockVKey = bytes32(uint256(123));

    /// @notice Initializes the test environment.
    /// @dev Deploys the shielded account, deploys the test token, mints funds,
    ///      and sets necessary approvals for deposit().
    function setUp() public {
        // Deploy Gelap shielded account with dummy SP1 config.
        account = new GelapShieldedAccount(mockVerifier, mockVKey);

        // Deploy a simple ERC20 test token.
        token = new TestToken();

        // Mint tokens to the user so they can deposit.
        token.mint(user, 1_000 ether);

        // User approves the shielded account to spend tokens on their behalf.
        vm.startPrank(user);
        token.approve(address(account), type(uint256).max);
        vm.stopPrank();
    }

    /// @notice Tests that a deposit modifies the Merkle root.
    /// @dev A changing root means the Merkle tree correctly inserted a new leaf.
    function testDepositUpdatesRoot() public {
        bytes32 initialRoot = account.merkleRoot();
        bytes32 commitment = keccak256("commitment_1");

        vm.prank(user);
        account.deposit(address(token), 10 ether, commitment, "");

        bytes32 newRoot = account.merkleRoot();

        assertTrue(newRoot != initialRoot, "Root should update after deposit");
    }

    /// @notice Ensures that each deposit increments the next leaf index.
    /// @dev Merkle tree must maintain sequential leaf insertions.
    function testDepositIncrementsLeafIndex() public {
        assertEq(account.nextLeafIndex(), 0);

        bytes32 commitment = keccak256("leaf_1");

        vm.prank(user);
        account.deposit(address(token), 1 ether, commitment, "");

        assertEq(account.nextLeafIndex(), 1);
    }

    /// @notice Tests that tokens are transferred correctly into the shielded pool.
    /// @dev deposit() should perform an ERC20 transferFrom().
    function testDepositTransfersTokens() public {
        uint256 before = token.balanceOf(address(account));
        bytes32 commitment = keccak256("leaf_2");

        vm.prank(user);
        account.deposit(address(token), 5 ether, commitment, "");

        uint256 afterBal = token.balanceOf(address(account));

        assertEq(afterBal, before + 5 ether, "Contract must receive tokens");
    }

    /// @notice Ensures that deposit() emits the correct AccountUpdated event.
    /// @dev Frontend & wallets rely on this event to track new private notes.
    function testDepositEmitsEvent() public {
        bytes32 commitment = keccak256("leaf_3");
        bytes memory memo = "hello";

        vm.prank(user);

        // Tell Foundry to expect this event with the given arguments.
        vm.expectEmit(true, true, true, true);
        emit AccountUpdated(commitment, memo);

        account.deposit(address(token), 3 ether, commitment, memo);
    }

    /// @notice Verifies that the inserted leaf is stored in the correct Merkle tree position.
    /// @dev For the first deposit, the leaf should be stored at (level=0, index=0).
    function testLeafStoredCorrectly() public {
        bytes32 commitment = keccak256("leaf_4");

        vm.prank(user);
        account.deposit(address(token), 1 ether, commitment, "");

        // Compute the node key for level 0, index 0.
        uint256 key = (uint256(0) << 32) | uint256(0);

        bytes32 stored = account.tree(key);

        assertEq(stored, commitment, "Leaf not stored correctly");
    }
}
