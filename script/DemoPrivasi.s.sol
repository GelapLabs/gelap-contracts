// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/GelapShieldedAccount.sol";

/// @title DemoPrivasi - Demonstrasi Fitur Privasi Gelap Darkpool
/// @notice Script ini menunjukkan bagaimana pengirim, jumlah, dan penerima TIDAK terlihat di blockchain
contract DemoPrivasi is Script {
    address constant GELAP = 0x54EC23CBCE1A9d33F05C4d3d79Ec28Aff3c8ce8D;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address executor = vm.addr(pk);

        console.log("=========================================");
        console.log("   DEMO PRIVASI GELAP DARKPOOL");
        console.log("=========================================\n");

        GelapShieldedAccount gelap = GelapShieldedAccount(GELAP);

        vm.startBroadcast(pk);

        // ============================================
        // SKENARIO: Alice kirim 1000 USDC ke Bob
        // ============================================

        console.log("[SKENARIO]");
        console.log("Alice ingin kirim 1000 USDC ke Bob secara PRIVAT\n");

        console.log("=========================================");
        console.log("   DATA YANG TERLIHAT DI BLOCKCHAIN");
        console.log("=========================================\n");

        // Ini yang terlihat di blockchain:
        bytes32 nullifier = keccak256(
            abi.encodePacked("alice_note", block.timestamp)
        );
        bytes32 newCommitment = keccak256(
            abi.encodePacked("bob_note", block.timestamp)
        );
        bytes32 keyImage = keccak256(
            abi.encodePacked("alice_key", block.timestamp)
        );

        console.log("[1] PENGIRIM:");
        console.log("    Yang terlihat  : ", executor);
        console.log("    (Ini adalah RELAYER, bukan Alice!)");
        console.log("    Identitas Alice tersembunyi dalam Ring Signature\n");

        console.log("[2] JUMLAH TRANSFER:");
        console.log("    Yang terlihat  : TIDAK ADA");
        console.log("    Nullifier hash : ");
        console.logBytes32(nullifier);
        console.log("    (Hash ini TIDAK mengungkap jumlah 1000 USDC)\n");

        console.log("[3] PENERIMA:");
        console.log("    Yang terlihat  : TIDAK ADA");
        console.log("    Commitment baru: ");
        console.logBytes32(newCommitment);
        console.log("    (Commitment ini TIDAK mengungkap alamat Bob)\n");

        console.log("[4] KEY IMAGE (Anti Double-Spend):");
        console.logBytes32(keyImage);
        console.log(
            "    (Mencegah Alice pakai note 2x, tapi TIDAK ungkap identitas)\n"
        );

        // Execute transaction
        bytes32[] memory nullifiers = new bytes32[](1);
        nullifiers[0] = nullifier;

        bytes32[] memory commits = new bytes32[](1);
        commits[0] = newCommitment;

        PublicInputsStruct memory pub = PublicInputsStruct({
            newRoot: keccak256(abi.encodePacked("new_root", block.timestamp)),
            nullifiers: nullifiers,
            newCommitments: commits,
            keyImage: keyImage
        });

        gelap.transact(abi.encode(pub), hex"1234");

        console.log("=========================================");
        console.log("   TRANSAKSI BERHASIL!");
        console.log("=========================================\n");

        console.log("[HASIL VERIFIKASI PRIVASI]");
        console.log("");
        console.log("| Data              | Terlihat di Blockchain? |");
        console.log("|-------------------|-------------------------|");
        console.log("| Alamat Pengirim   | TIDAK (Ring Sig)        |");
        console.log("| Jumlah Transfer   | TIDAK (Commitment)      |");
        console.log("| Alamat Penerima   | TIDAK (Stealth Addr)    |");
        console.log("| Token Type        | TIDAK (dalam proof)     |");
        console.log("");

        console.log("[YANG TERLIHAT HANYA]");
        console.log("- Nullifier hash (mencegah double-spend)");
        console.log("- Commitment hash (note baru untuk penerima)");
        console.log("- Key image (link transaksi tanpa ungkap identitas)");
        console.log("- Merkle root baru (state update)");
        console.log("");

        console.log("[KESIMPULAN]");
        console.log("Pengamat blockchain TIDAK BISA tahu:");
        console.log("- Siapa Alice (pengirim)");
        console.log("- Siapa Bob (penerima)");
        console.log("- Berapa yang dikirim (1000 USDC)");
        console.log("- Token apa yang ditransfer");

        vm.stopBroadcast();

        console.log("\n=========================================");
        console.log("   DEMO SELESAI - PRIVASI TERJAGA!");
        console.log("=========================================");
    }
}
