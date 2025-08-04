#[test_only]
module kgen::kgen_test {

    use std::option;
    use aptos_framework::account;
    use aptos_framework::aptos_account;
    use aptos_framework::fungible_asset;
    use aptos_framework::primary_fungible_store;
    use kgen::kgen::{init_for_test, mint, metadata, add_treasury_address,
        update_burn_vault,
        accept_admin,
        transfer_admin,
        unfreeze_accounts,
        freeze_accounts,
        transfer, is_frozen, burn, add_minter, remove_minter_address, remove_treasury_address, pending_admin, admin
    };


    #[test_only]
    const KGEN_ADDR: address = @kgen;
    #[test_only]
    const ADMIN_ADDR: address = @admin;
    #[test_only]
    const BURN_VAULT_ADDR: address = @burn_vault;
    #[test_only]
    const TEST_TREASURY1: address = @0x100;
    #[test_only]
    const TEST_TREASURY2: address = @0x101;
    #[test_only]
    const TEST_USER1: address = @0x102;
    #[test_only]
    const TEST_USER2: address = @0x103;
    #[test_only]
    const TEST_PENDING_ADMIN: address = @0x104;
    #[test_only]
    const TEST_MINTER: address = @0x105;
    #[test_only]
    const TEST_NEW_BURN_VAULT: address = @0x106;
    #[test_only]
    const TEST_EXTRA_TREASURY: address = @0x107;



    #[test]
    // Test the minting of a token
    fun test_mint() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        add_treasury_address(&admin_signer, TEST_TREASURY1);
        let amount = 1000u64;
        mint(&admin_signer, TEST_TREASURY1, amount);
        assert!(primary_fungible_store::balance(TEST_TREASURY1, metadata()) == (amount), 6000);
        assert!(fungible_asset::supply(metadata()) == option::some(amount as u128), 6001);
    }

    #[test]
    // Test the minting of a token with zero amount
    fun test_mint_zero_amount() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        add_treasury_address(&admin_signer, TEST_TREASURY1);
        mint(&admin_signer, TEST_TREASURY1, 0);
        assert!(primary_fungible_store::balance(TEST_TREASURY1, metadata()) == 0, 6002);
        assert!(fungible_asset::supply(metadata()) == option::some(0 as u128), 6003);
    }
    #[test]
    // Test the minting of a token to a non-minter address
    #[expected_failure(abort_code = kgen::kgen::ENOT_MINTER_ADDRESS)]
    fun test_mint_non_minter() {
        init_for_test();
        let bad_signer = account::create_signer_for_test(TEST_USER1);
        mint(&bad_signer, TEST_TREASURY1, 1000);
    }

    #[test]
    // Test the minting of a token to a non-treasury address
    #[expected_failure(abort_code = kgen::kgen::ENOT_TREASURY_ADDRESS)]
    fun test_mint_not_treasury() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        mint(&admin_signer, TEST_TREASURY1, 1000);
    }

    #[test]
    // Test the minting of a token to a frozen receiving address
    #[expected_failure(abort_code = kgen::kgen::EFROZEN_RECEIVING)]
    fun test_mint_to_frozen_receiving() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        add_treasury_address(&admin_signer, TEST_TREASURY1);
        let accounts = vector[TEST_TREASURY1];
        let sending_flags = vector[false];
        let receiving_flags = vector[true];
        freeze_accounts(&admin_signer, accounts, sending_flags, receiving_flags);
        mint(&admin_signer, TEST_TREASURY1, 1000);
        assert!(primary_fungible_store::balance(TEST_TREASURY1, metadata()) == (1000), 1001);
    }

    #[test]
    // Test the normal transfer of a token
    fun test_normal_transfer() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        let treasury1_signer = account::create_signer_for_test(TEST_TREASURY1);
        add_treasury_address(&admin_signer, TEST_TREASURY1);
        mint(&admin_signer, TEST_TREASURY1, 1000);
        aptos_account::transfer_fungible_assets(&treasury1_signer, metadata(), TEST_USER1, 500);
        assert!(primary_fungible_store::balance(TEST_TREASURY1, metadata()) == 500, 8000);
        assert!(primary_fungible_store::balance(TEST_USER1, metadata()) == 500, 8001);
    }

    #[test]
    // Test the transfer of a token from a frozen sending address
    #[expected_failure(abort_code = kgen::kgen::EFROZEN_SENDING)]
    fun test_normal_transfer_frozen_sending() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        let treasury1_signer = account::create_signer_for_test(TEST_TREASURY1);
        add_treasury_address(&admin_signer, TEST_TREASURY1);
        mint(&admin_signer, TEST_TREASURY1, 1000);
        let accounts = vector[TEST_TREASURY1];
        let sending_flags = vector[true];
        let receiving_flags = vector[false];
        freeze_accounts(&admin_signer, accounts, sending_flags, receiving_flags);
        primary_fungible_store::transfer(&treasury1_signer, metadata(), TEST_USER1, 500);
    }

    #[test]
    // Test the transfer of a token to a frozen receiving address
    #[expected_failure(abort_code = kgen::kgen::EFROZEN_RECEIVING)]
    fun test_normal_transfer_frozen_receiving() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        let treasury1_signer = account::create_signer_for_test(TEST_TREASURY1);
        add_treasury_address(&admin_signer, TEST_TREASURY1);
        mint(&admin_signer, TEST_TREASURY1, 1000);
        let accounts = vector[TEST_USER1];
        let sending_flags = vector[false];
        let receiving_flags = vector[true];
        freeze_accounts(&admin_signer, accounts, sending_flags, receiving_flags);
        primary_fungible_store::transfer(&treasury1_signer, metadata(), TEST_USER1, 500);
    }

    #[test]
    // Test the admin transfer of a token
    fun test_admin_transfer() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        add_treasury_address(&admin_signer, TEST_TREASURY1);
        mint(&admin_signer, TEST_TREASURY1, 1000);
        let accounts = vector[TEST_TREASURY1];
        let sending_flags = vector[true];
        let receiving_flags = vector[true];
        freeze_accounts(&admin_signer, accounts, sending_flags, receiving_flags);
        transfer(&admin_signer, TEST_TREASURY1, TEST_USER1, 500);
        assert!(primary_fungible_store::balance(TEST_TREASURY1, metadata()) == 500, 9000);
        assert!(primary_fungible_store::balance(TEST_USER1, metadata()) == 500, 9001);
    }

    #[test]
    #[expected_failure(abort_code = kgen::kgen::ENOT_FROZEN)]
    // Test the admin transfer of a token to a non-frozen account
    fun test_admin_transfer_not_frozen() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        add_treasury_address(&admin_signer, TEST_TREASURY1);
        mint(&admin_signer, TEST_TREASURY1, 1000);
        transfer(&admin_signer, TEST_TREASURY1, TEST_USER1, 500);
    }

    #[test]
    #[expected_failure(abort_code = kgen::kgen::EUNAUTHORIZED)]
    // Test the admin transfer of a token by a non-admin
    fun test_admin_transfer_non_admin() {
        init_for_test();
        let bad_signer = account::create_signer_for_test(TEST_USER1);
        transfer(&bad_signer, TEST_TREASURY1, TEST_USER1, 500);
    }

    #[test]
    // Test the burning of a token
    fun test_burn() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        add_treasury_address(&admin_signer, BURN_VAULT_ADDR);
        mint(&admin_signer, BURN_VAULT_ADDR, 1000);
        burn(&admin_signer, BURN_VAULT_ADDR, 500);
        assert!(primary_fungible_store::balance(BURN_VAULT_ADDR, metadata()) == 500, 10000);
        assert!(fungible_asset::supply(metadata()) == option::some(500u128), 10001);
    }

    #[test]
    // Test the burning of a token with zero amount
    fun test_burn_zero_amount() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        burn(&admin_signer, BURN_VAULT_ADDR, 0);
        assert!(fungible_asset::supply(metadata()) == option::some(0u128), 10002);
    }

    #[test]
    #[expected_failure(abort_code = kgen::kgen::ENOT_BURNVAULT)]
    // Test the burning of a token to a non-burn vault
    fun test_burn_not_burn_vault() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        burn(&admin_signer, TEST_USER1, 500);
    }

    #[test]
    #[expected_failure(abort_code = kgen::kgen::EUNAUTHORIZED)]
    // Test the burning of a token by a non-admin
    fun test_burn_non_admin() {
        init_for_test();
        let bad_signer = account::create_signer_for_test(TEST_USER1);
        burn(&bad_signer, BURN_VAULT_ADDR, 500);
    }

    #[test]
    // Test the freezing of accounts
    fun test_freeze_accounts() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        let accounts = vector[TEST_USER1, TEST_USER2];
        let sending_flags = vector[true, false];
        let receiving_flags = vector[false, true];
        freeze_accounts(&admin_signer, accounts, sending_flags, receiving_flags);
        let (sending1, receiving1) = is_frozen(TEST_USER1);
        assert!(sending1 && !receiving1, 11000);
        let (sending2, receiving2) = is_frozen(TEST_USER2);
        assert!(!sending2 && receiving2, 11001);
    }

    #[test]
    #[expected_failure(abort_code = kgen::kgen::EARGUMENT_VECTORS_LENGTH_MISMATCH)]
    // Test the freezing of accounts with a length mismatch in the sending flags
    fun test_freeze_accounts_length_mismatch_sending() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        let accounts = vector[TEST_USER1];
        let sending_flags = vector[true, false];
        let receiving_flags = vector[true];
        freeze_accounts(&admin_signer, accounts, sending_flags, receiving_flags);
    }

    #[test]
    #[expected_failure(abort_code = kgen::kgen::EARGUMENT_VECTORS_LENGTH_MISMATCH)]
    // Test the freezing of accounts with a length mismatch in the receiving flags
    fun test_freeze_accounts_length_mismatch_receiving() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        let accounts = vector[TEST_USER1];
        let sending_flags = vector[true];
        let receiving_flags = vector[true, false];
        freeze_accounts(&admin_signer, accounts, sending_flags, receiving_flags);
    }

    #[test]
    #[expected_failure(abort_code = kgen::kgen::EUNAUTHORIZED)]
    // Test the freezing of accounts by a non-admin
    fun test_freeze_accounts_non_admin() {
        init_for_test();
        let bad_signer = account::create_signer_for_test(TEST_USER1);
        let accounts = vector[TEST_USER1];
        let sending_flags = vector[true];
        let receiving_flags = vector[false];
        freeze_accounts(&bad_signer, accounts, sending_flags, receiving_flags);
    }

    #[test]
    // Test the unfreezing of accounts
    fun test_unfreeze_accounts() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        let accounts = vector[TEST_USER1, TEST_USER2];
        let sending_flags = vector[true, false];
        let receiving_flags = vector[false, true];
        freeze_accounts(&admin_signer, accounts, sending_flags, receiving_flags);
        let unfreeze_sending = vector[true, false];
        let unfreeze_receiving = vector[false, true];
        unfreeze_accounts(&admin_signer, accounts, unfreeze_sending, unfreeze_receiving);
        let (sending1, receiving1) = is_frozen(TEST_USER1);
        assert!(!sending1 && !receiving1, 12000);
        let (sending2, receiving2) = is_frozen(TEST_USER2);
        assert!(!sending2 && !receiving2, 12001);
    }

    #[test]
    // Test the unfreezing of accounts that are not frozen
    fun test_unfreeze_accounts_not_frozen() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        let accounts = vector[TEST_USER1];
        let unfreeze_sending = vector[true];
        let unfreeze_receiving = vector[true];
        unfreeze_accounts(&admin_signer, accounts, unfreeze_sending, unfreeze_receiving); // No change
        let (sending, receiving) = is_frozen(TEST_USER1);
        assert!(!sending && !receiving, 12002);
    }

    #[test]
    #[expected_failure(abort_code = kgen::kgen::EARGUMENT_VECTORS_LENGTH_MISMATCH)]
    // Test the unfreezing of accounts with a length mismatch in the sending flags
    fun test_unfreeze_accounts_length_mismatch_sending() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        let accounts = vector[TEST_USER1];
        let unfreeze_sending = vector[true, false];
        let unfreeze_receiving = vector[true];
        unfreeze_accounts(&admin_signer, accounts, unfreeze_sending, unfreeze_receiving);
    }

    #[test]
    #[expected_failure(abort_code = kgen::kgen::EARGUMENT_VECTORS_LENGTH_MISMATCH)]
    // Test the unfreezing of accounts with a length mismatch in the receiving flags
    fun test_unfreeze_accounts_length_mismatch_receiving() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        let accounts = vector[TEST_USER1];
        let unfreeze_sending = vector[true];
        let unfreeze_receiving = vector[true, false];
        unfreeze_accounts(&admin_signer, accounts, unfreeze_sending, unfreeze_receiving);
    }

    #[test]
    #[expected_failure(abort_code = kgen::kgen::EUNAUTHORIZED)]
    // Test the unfreezing of accounts by a non-admin
    fun test_unfreeze_accounts_non_admin() {
        init_for_test();
        let bad_signer = account::create_signer_for_test(TEST_USER1);
        let accounts = vector[TEST_USER1];
        let unfreeze_sending = vector[true];
        let unfreeze_receiving = vector[false];
        unfreeze_accounts(&bad_signer, accounts, unfreeze_sending, unfreeze_receiving);
    }
    #[test]
    // Test the transfer of admin
    fun test_transfer_admin() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        transfer_admin(&admin_signer, TEST_PENDING_ADMIN);
        assert!(pending_admin() == TEST_PENDING_ADMIN, 13000);
    }

    #[test]
    #[expected_failure(abort_code = kgen::kgen::ESAME_ADMIN)]
    // Test the transfer of admin to the same address
    fun test_transfer_admin_same_address() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        transfer_admin(&admin_signer, ADMIN_ADDR);
    }

    #[test]
    #[expected_failure(abort_code = kgen::kgen::EUNAUTHORIZED)]
    // Test the transfer of admin by a non-admin
    fun test_transfer_admin_non_admin() {
        init_for_test();
        let bad_signer = account::create_signer_for_test(TEST_USER1);
        transfer_admin(&bad_signer, TEST_PENDING_ADMIN);
    }

    #[test]
    // Test the acceptance of admin
    fun test_accept_admin() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        let pending_signer = account::create_signer_for_test(TEST_PENDING_ADMIN);
        transfer_admin(&admin_signer, TEST_PENDING_ADMIN);
        accept_admin(&pending_signer);
        assert!(admin() == TEST_PENDING_ADMIN, 14000);
        assert!(pending_admin() == @0x0, 14001);
    }

    #[test]
    #[expected_failure(abort_code = kgen::kgen::EUNAUTHORIZED)]
    // Test the acceptance of admin that is not pending
    fun test_accept_admin_not_pending() {
        init_for_test();
        let bad_signer = account::create_signer_for_test(TEST_USER1);
        accept_admin(&bad_signer);
    }


    #[test]
    #[expected_failure(abort_code = kgen::kgen::EUNAUTHORIZED)]
    // Test the update of the burn vault by a non-admin
    fun test_update_burn_vault_non_admin() {
        init_for_test();
        let bad_signer = account::create_signer_for_test(TEST_USER1);
        update_burn_vault(&bad_signer, TEST_NEW_BURN_VAULT);
    }

    #[test]
    // Test the full flow of the module
    fun test_full_flow() {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        let pending_signer = account::create_signer_for_test(TEST_PENDING_ADMIN);
        let minter_signer = account::create_signer_for_test(TEST_MINTER);
        let treasury1_signer = account::create_signer_for_test(TEST_TREASURY1);

        // Add minter and treasuries
        add_minter(&admin_signer, TEST_MINTER);
        add_treasury_address(&admin_signer, TEST_TREASURY1);
        add_treasury_address(&admin_signer, TEST_TREASURY2);

        // Mint using admin and new minter
        mint(&admin_signer, TEST_TREASURY1, 1000);
        mint(&minter_signer, TEST_TREASURY2, 2000);
        assert!(primary_fungible_store::balance(TEST_TREASURY1, metadata()) == 1000, 16000);
        assert!(primary_fungible_store::balance(TEST_TREASURY2, metadata()) == 2000, 16001);

        // Normal transfer
        primary_fungible_store::transfer(&treasury1_signer, metadata(), TEST_USER1, 300);
        assert!(primary_fungible_store::balance(TEST_USER1, metadata()) == 300, 16002);

        // Freeze accounts
        let accounts = vector[TEST_USER1];
        let sending_flags = vector[true];
        let receiving_flags = vector[true];
        freeze_accounts(&admin_signer, accounts, sending_flags, receiving_flags);
        let (sending, receiving) = is_frozen(TEST_USER1);
        assert!(sending && receiving, 16003);

        // Admin transfer from frozen account
        transfer(&admin_signer, TEST_USER1, TEST_USER2, 100);
        assert!(primary_fungible_store::balance(TEST_USER1, metadata()) == 200, 16004);
        assert!(primary_fungible_store::balance(TEST_USER2, metadata()) == 100, 16005);

        // Unfreeze partially
        let unfreeze_sending = vector[false];
        let unfreeze_receiving = vector[true];
        unfreeze_accounts(&admin_signer, accounts, unfreeze_sending, unfreeze_receiving);
        let (sending2, receiving2) = is_frozen(TEST_USER1);
        assert!(sending2 && !receiving2, 16006);

        // Can receive but not send
        primary_fungible_store::transfer(&treasury1_signer, metadata(), TEST_USER1, 100);
        assert!(primary_fungible_store::balance(TEST_USER1, metadata()) == 300, 16007);

        // Burn
        primary_fungible_store::transfer(&treasury1_signer, metadata(), BURN_VAULT_ADDR, 200);
        burn(&admin_signer, BURN_VAULT_ADDR, 200);
        assert!(primary_fungible_store::balance(BURN_VAULT_ADDR, metadata()) == 0, 16008);
        assert!(fungible_asset::supply(metadata()) == option::some(2800u128), 16009); // 3000 minted - 200 burned

        // Update burn vault
        update_burn_vault(&admin_signer, TEST_NEW_BURN_VAULT);

        // Transfer admin and accept
        transfer_admin(&admin_signer, TEST_PENDING_ADMIN);
        accept_admin(&pending_signer);
        assert!(admin() == TEST_PENDING_ADMIN, 16010);

        // New admin can operate (e.g., add treasury)
        add_treasury_address(&pending_signer, TEST_EXTRA_TREASURY);

        // Remove minter and treasury
        remove_minter_address(&pending_signer, TEST_MINTER);
        remove_treasury_address(&pending_signer, TEST_TREASURY2);
    }
}
