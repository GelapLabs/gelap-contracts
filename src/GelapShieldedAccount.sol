// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GelapShieldedAccount {
    // ------------------------------------------------------------------------
    // Merkle Tree State
    // ------------------------------------------------------------------------

    /// @notice The current Merkle tree root that represents the private state.
    /// @dev This root changes every time a deposit or private transaction occurs.
    bytes32 public merkleRoot;

    /// @notice Tracks which nullifiers have been used to prevent double-spending.
    mapping(bytes32 => bool) public nullifierUsed;

    /// @notice Precomputed zero hashes for each level of the Merkle tree.
    /// @dev zeroHashes[i] represents the default hash at depth i.
    bytes32[32] public zeroHashes;

    /// @notice The index for the next available leaf in the Merkle tree.
    /// @dev Used for incremental tree insertion.
    uint32 public nextLeafIndex;

    /// @notice Storage for Merkle tree nodes.
    /// @dev Keys are computed using _nodeIndex(level, index).
    mapping(uint256 => bytes32) public tree;

    // ------------------------------------------------------------------------
    // SP1 Verifier Configuration
    // ------------------------------------------------------------------------
    /// @notice Address of the SP1 verifier contract used to check ZK proofs.
    address public sp1Verifier;

    /// @notice The verification key (vKey) corresponding to the SP1 program.
    /// @dev This identifies which program the proof must correspond to.
    bytes32 public sp1ProgramVKey;

    // ------------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------------

    /// @notice Emitted whenever a new commitment is added to the Merkle tree.
    /// @param commitment The inserted Pedersen commitment.
    /// @param encryptedMemo Encrypted metadata for the receiver wallet (optional).
    event AccountUpdated(bytes32 commitment, bytes encryptedMemo);

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------

    constructor(address verifier, bytes32 programVKey) {
        /// @dev Initialize the default zero hashes used for Merkle tree generation.
        _initZeroHashes();

        // Store SP1 verifier configuration.
        sp1Verifier = verifier;
        sp1ProgramVKey = programVKey;
    }

    // ------------------------------------------------------------------------
    // Public API — To Be Implemented
    // ------------------------------------------------------------------------

    /// @notice Deposits ERC20 assets into the shielded pool by inserting a commitment
    ///         into the Merkle tree.
    /// @dev The caller must approve this contract to spend `amount` of the ERC20 token
    ///      before calling this function. The function transfers the tokens, updates
    ///      the Merkle tree with the provided commitment, and emits an event so that
    ///      the frontend/wallet can track the private state.
    /// @param token The ERC20 token being deposited.
    /// @param amount The amount of tokens to transfer from the user.
    /// @param commitment The 32-byte Pedersen commitment representing the private note.
    /// @param encryptedMemo Opaque encrypted metadata that the receiver can later decrypt.
    function deposit(
        address token,
        uint256 amount,
        bytes32 commitment,
        bytes calldata encryptedMemo
    ) external {
        // 1. Transfer the tokens from user to this contract
        // The user must call approve() before deposit()
        require(token != address(0), "Invalid token");
        require(amount > 0, "Invalid amount");

        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(success, "Token transfer failed");

        // 2. Insert the commitment into the Merkle tree
        bytes32 newRoot = _insertLeaf(commitment);

        // 3. Update global Merkle root
        merkleRoot = newRoot;

        // 4. Emit event for wallets to track state changes
        emit AccountUpdated(commitment, encryptedMemo);
    }


    /// @notice Executes a private transaction validated through an SP1 ZK proof.
    /// @dev This will update the Merkle root and mark nullifiers as used.
    function transact(bytes calldata publicInputs, bytes calldata proofBytes) external {
        // Implementation for SP1 integration will be added in Part 2
    }

    /// @notice Withdraws assets back to a public EOA using a private proof.
    /// @dev Also requires SP1 proof validation.
    function withdraw(
        bytes calldata publicInputs,
        bytes calldata proofBytes,
        address receiver
    ) external {
        // Implementation will be added in Part 2
    }

    // ------------------------------------------------------------------------
    // Merkle Tree Internals (Part 1)
    // ------------------------------------------------------------------------

    /// @notice Initializes the zero hash values used for empty Merkle nodes.
    /// @dev zeroHashes[0] is the base hash; higher levels are hashed recursively.
    function _initZeroHashes() internal {
        zeroHashes[0] = keccak256(abi.encodePacked(uint256(0)));

        // Compute each zero hash by hashing the previous level with itself.
        for (uint256 i = 1; i < 32; i++) {
            zeroHashes[i] = keccak256(
                abi.encodePacked(zeroHashes[i - 1], zeroHashes[i - 1])
            );
        }
    }

    /// @notice Computes a compact storage index for a Merkle tree node.
    /// @param level The depth of the node in the tree.
    /// @param index The index within that level.
    /// @return storageKey A unique key for storing the node in the mapping.
    function _nodeIndex(uint256 level, uint256 index)
        internal
        pure
        returns (uint256 storageKey)
    {
        return (level << 32) | index;
    }

    /// @notice Stores a leaf node at a given index.
    /// @param leaf The commitment hash to store.
    /// @param index The leaf index in the tree.
    function _storeLeaf(bytes32 leaf, uint32 index) internal {
        uint256 key = _nodeIndex(0, index);
        tree[key] = leaf;
    }

    /// @notice Hashes a pair of Merkle tree nodes using keccak256.
    /// @dev This is the fundamental hashing operation used to compute
    ///      parent nodes in the incremental Merkle tree.
    ///      The inputs are expected to be 32-byte values representing
    ///      the left and right children of a tree level.
    /// @param left The left child hash.
    /// @param right The right child hash.
    /// @return The keccak256 hash of the concatenated children.
    function _hashPair(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(left, right));
    }

        /// @notice Inserts a new leaf into the incremental Merkle tree and updates the root.
    /// @dev This function places the leaf at the current nextLeafIndex, then iteratively
    ///      computes the parent nodes up to the root. Uninitialized sibling nodes use
    ///      the precomputed zeroHashes[level] value.
    /// @param leaf The 32-byte commitment being added to the Merkle tree.
    /// @return newRoot The updated Merkle tree root after inserting the leaf.
    function _insertLeaf(bytes32 leaf) internal returns (bytes32 newRoot) {
        uint32 index = nextLeafIndex;
        require(index < (1 << 32), "Merkle tree full");

        // Store the leaf at level 0
        tree[_nodeIndex(0, index)] = leaf;

        bytes32 currentHash = leaf;
        uint32 currentIndex = index;

        // Iterate through all 32 levels
        for (uint256 level = 0; level < 32; level++) {

            // Determine whether this node is a left or right child
            if (currentIndex % 2 == 0) {
                // It is a left child → get right sibling
                bytes32 right = tree[_nodeIndex(level, currentIndex + 1)];

                // If right sibling not initialized, use zero hash
                if (right == bytes32(0)) {
                    right = zeroHashes[level];
                }

                // Compute parent = H(left, right)
                currentHash = _hashPair(currentHash, right);

            } else {
                // It is a right child → get left sibling
                bytes32 left = tree[_nodeIndex(level, currentIndex - 1)];

                // Left sibling MUST exist (or zeroHash)
                if (left == bytes32(0)) {
                    left = zeroHashes[level];
                }

                // Compute parent = H(left, right)
                currentHash = _hashPair(left, currentHash);
            }

            // Move index to parent layer
            currentIndex /= 2;

            // Store parent node
            tree[_nodeIndex(level + 1, currentIndex)] = currentHash;
        }

        // Update global Merkle root and increment index
        newRoot = currentHash;
        merkleRoot = newRoot;
        nextLeafIndex = index + 1;
    }
}
