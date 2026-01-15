// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ISP1Verifier} from "@sp1/contracts/src/ISP1Verifier.sol";

struct PublicInputsStruct {
    bytes32 newRoot; // Merkle root after executing the private tx
    bytes32[] nullifiers; // Nullifiers consumed in this transaction
    bytes32[] newCommitments; // Newly created commitments (outputs)
    bytes32 keyImage; // Key image from ring signature (anti-double-spend)
}

/// @notice Public inputs for a shielded withdrawal.
/// @dev These values are computed inside the SP1 program and exposed
///      as ABI-encoded bytes to the contract.
struct WithdrawPublicInputsStruct {
    bytes32 newRoot; // Merkle root after withdrawal is applied
    bytes32[] nullifiers; // Nullifiers spent by this withdrawal
    address token; // ERC20 token being withdrawn
    uint256 amount; // Amount of tokens to send out
    address receiver; // Public EOA receiver of the withdrawn funds
    bytes32[] newCommitments; // Optional: change notes created by the withdrawal
}

/// @notice Public inputs for a shielded swap (darkpool trade).
/// @dev Two orders are matched: Order A sells token X for token Y,
///      Order B sells token Y for token X.
struct SwapPublicInputsStruct {
    bytes32 newRoot; // Merkle root after swap execution
    bytes32[] nullifiers; // Nullifiers from both orders (exactly 2)
    bytes32[] newCommitments; // Output notes for both parties + any change
    bytes32 orderAKeyImage; // Key image from order A (anti-double-spend)
    bytes32 orderBKeyImage; // Key image from order B (anti-double-spend)
}

// Custom Errors
error InvalidToken();
error InvalidAmount();
error TokenTransferFailed();
error NullifierAlreadyUsed(bytes32 nullifier);
error InvalidReceiver();
error ReceiverMismatch();
error InvalidSwapNullifierCount();
error OrderAAlreadyExecuted();
error OrderBAlreadyExecuted();
error MerkleTreeFull();

contract GelapShieldedAccount is ReentrancyGuard {
    using SafeERC20 for IERC20;

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

    /// @notice Emitted whenever a private transaction is executed via SP1.
    ///         (i.e. internal transfer within the shielded pool).
    /// @param newRoot The new Merkle root after applying the transaction.
    /// @param nullifiers The nullifiers consumed by this transaction.
    /// @param newCommitments The commitments created as outputs.
    event TransactionExecuted(
        bytes32 newRoot,
        bytes32[] nullifiers,
        bytes32[] newCommitments
    );

    /// @notice Emitted when a shielded withdrawal is executed.
    /// @param receiver The public EOA that received the withdrawn tokens.
    /// @param token The ERC20 token that was withdrawn.
    /// @param amount The amount of tokens transferred out.
    event WithdrawExecuted(
        address indexed receiver,
        address indexed token,
        uint256 amount
    );

    /// @notice Emitted when a shielded swap (darkpool trade) is executed.
    /// @param newRoot The new Merkle root after the swap.
    /// @param orderAKeyImage Key image from order A.
    /// @param orderBKeyImage Key image from order B.
    event SwapExecuted(
        bytes32 newRoot,
        bytes32 orderAKeyImage,
        bytes32 orderBKeyImage
    );

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
    ) external nonReentrant {
        // 1. Transfer the tokens from user to this contract
        // The user must call approve() before deposit()
        if (token == address(0)) revert InvalidToken();
        if (amount == 0) revert InvalidAmount();

        // Use SafeERC20 to handle non-standard tokens (like USDT) and revert on failure
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // 2. Insert the commitment into the Merkle tree
        bytes32 newRoot = _insertLeaf(commitment);

        // 3. Update global Merkle root
        merkleRoot = newRoot;

        // 4. Emit event for wallets to track state changes
        emit AccountUpdated(commitment, encryptedMemo);
    }

    /// @notice Executes a private transaction validated via an SP1 ZK proof.
    /// @dev This function delegates all heavy checking (balances, ring signatures,
    ///      Pedersen commitments, Merkle inclusion proofs, etc.) to the SP1 program.
    ///      On-chain, we only:
    ///        1) Verify the SP1 proof is valid for the given public inputs.
    ///        2) Check that all nullifiers are new (no double spend).
    ///        3) Update the Merkle root to the new value.
    ///        4) Emit an event for indexers / wallets.
    /// @param publicInputs ABI-encoded public inputs as produced by the SP1 program.
    /// @param proofBytes The raw proof bytes produced by the SP1 prover.
    function transact(
        bytes calldata publicInputs,
        bytes calldata proofBytes
    ) external {
        // 1. Verify the SP1 proof against the configured program verification key.
        ISP1Verifier(sp1Verifier).verifyProof(
            sp1ProgramVKey,
            publicInputs,
            proofBytes
        );

        // 2. Decode the public inputs into our structured format.
        PublicInputsStruct memory pub = abi.decode(
            publicInputs,
            (PublicInputsStruct)
        );

        // 3. Ensure none of the nullifiers were used before (no double spending).
        uint256 n = pub.nullifiers.length;
        for (uint256 i = 0; i < n; i++) {
            bytes32 nf = pub.nullifiers[i];
            if (nullifierUsed[nf]) revert NullifierAlreadyUsed(nf);
            nullifierUsed[nf] = true;
        }

        // 4. Update the global Merkle root to the one computed in the SP1 program.
        merkleRoot = pub.newRoot;

        // 5. Emit an event so off-chain indexers and wallets can follow state changes.
        //    You may want a dedicated TransactionExecuted event; for now we reuse
        //    AccountUpdated semantics for commitments.
        for (uint256 j = 0; j < pub.newCommitments.length; j++) {
            // No encrypted memo here yet; can be extended later.
            emit AccountUpdated(pub.newCommitments[j], "");
        }

        emit TransactionExecuted(
            pub.newRoot,
            pub.nullifiers,
            pub.newCommitments
        );
    }

    /// @notice Withdraws assets from the shielded pool back to a public EOA
    ///         using an SP1-verified ZK proof.
    /// @dev The SP1 program is responsible for proving:
    ///        - The caller controls a valid shielded balance.
    ///        - The nullifiers correspond to unspent notes.
    ///        - The new Merkle root is computed correctly.
    ///        - The withdrawn amount does not exceed the shielded balance.
    ///      On-chain we:
    ///        1) Verify the SP1 proof.
    ///        2) Check and mark nullifiers as used.
    ///        3) Update the Merkle root.
    ///        4) Transfer ERC20 tokens to the receiver.
    /// @param publicInputs ABI-encoded WithdrawPublicInputsStruct produced by SP1.
    /// @param proofBytes The raw ZK proof bytes from the SP1 prover.
    /// @param receiver The public EOA that will receive the withdrawn funds.
    function withdraw(
        bytes calldata publicInputs,
        bytes calldata proofBytes,
        address receiver
    ) external nonReentrant {
        if (receiver == address(0)) revert InvalidReceiver();

        // 1. Verify proof with SP1 verifier.
        ISP1Verifier(sp1Verifier).verifyProof(
            sp1ProgramVKey,
            publicInputs,
            proofBytes
        );

        // 2. Decode public inputs into a concrete struct.
        WithdrawPublicInputsStruct memory pub = abi.decode(
            publicInputs,
            (WithdrawPublicInputsStruct)
        );

        // 3. Ensure the receiver argument matches the public input to prevent
        //    user-controlled redirection after proof generation.
        if (pub.receiver != receiver) revert ReceiverMismatch();

        // 4. Prevent double spending by marking all nullifiers as used.
        uint256 n = pub.nullifiers.length;
        for (uint256 i = 0; i < n; i++) {
            bytes32 nf = pub.nullifiers[i];
            if (nullifierUsed[nf]) revert NullifierAlreadyUsed(nf);
            nullifierUsed[nf] = true;
        }

        // 5. Update the Merkle root to the new post-withdrawal root.
        merkleRoot = pub.newRoot;

        // 6. Transfer ERC20 tokens from the shielded contract to the receiver.
        if (pub.token == address(0)) revert InvalidToken();
        if (pub.amount == 0) revert InvalidAmount();

        // Use SafeERC20 to handle non-standard tokens
        IERC20(pub.token).safeTransfer(receiver, pub.amount);

        // 7. Emit event for indexers / UI to track public withdrawals.
        emit WithdrawExecuted(receiver, pub.token, pub.amount);

        // 8. Optionally inform indexers about new change commitments.
        for (uint256 j = 0; j < pub.newCommitments.length; j++) {
            emit AccountUpdated(pub.newCommitments[j], "");
        }
    }

    /// @notice Executes a shielded swap (darkpool trade) between two matched orders.
    /// @dev The SP1 program verifies:
    ///      - Both orders have valid ring signatures
    ///      - Token compatibility (A.sell == B.buy and vice versa)
    ///      - Price compatibility (min amounts satisfied)
    ///      - Commitment validity
    ///      - Correct nullifier and output computation
    /// @param publicInputs ABI-encoded SwapPublicInputsStruct from SP1 program.
    /// @param proofBytes The raw proof bytes from SP1 prover.
    function executeSwap(
        bytes calldata publicInputs,
        bytes calldata proofBytes
    ) external {
        // 1. Verify the SP1 proof
        ISP1Verifier(sp1Verifier).verifyProof(
            sp1ProgramVKey,
            publicInputs,
            proofBytes
        );

        // 2. Decode public inputs
        SwapPublicInputsStruct memory pub = abi.decode(
            publicInputs,
            (SwapPublicInputsStruct)
        );

        // 3. Ensure exactly 2 nullifiers (one per order)
        if (pub.nullifiers.length != 2) revert InvalidSwapNullifierCount();

        // 4. Prevent double-spending: mark nullifiers as used
        for (uint256 i = 0; i < pub.nullifiers.length; i++) {
            bytes32 nf = pub.nullifiers[i];
            if (nullifierUsed[nf]) revert NullifierAlreadyUsed(nf);
            nullifierUsed[nf] = true;
        }

        // 5. Prevent order replay: track key images
        // 5. Prevent order replay: track key images
        if (nullifierUsed[pub.orderAKeyImage]) revert OrderAAlreadyExecuted();
        if (nullifierUsed[pub.orderBKeyImage]) revert OrderBAlreadyExecuted();
        nullifierUsed[pub.orderAKeyImage] = true;
        nullifierUsed[pub.orderBKeyImage] = true;

        // 6. Update Merkle root
        merkleRoot = pub.newRoot;

        // 7. Emit events for new commitments
        for (uint256 j = 0; j < pub.newCommitments.length; j++) {
            emit AccountUpdated(pub.newCommitments[j], "");
        }

        // 8. Emit swap event
        emit SwapExecuted(pub.newRoot, pub.orderAKeyImage, pub.orderBKeyImage);
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
    function _nodeIndex(
        uint256 level,
        uint256 index
    ) internal pure returns (uint256 storageKey) {
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
    function _hashPair(
        bytes32 left,
        bytes32 right
    ) internal pure returns (bytes32) {
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
        if (index >= (1 << 32)) revert MerkleTreeFull();

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
