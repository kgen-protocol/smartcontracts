#[test_only]
module rkgen::swap_test {
    use std::signer;
    use std::string;
    use std::option;
    use aptos_framework::account;
    use aptos_framework::fungible_asset::{Self, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use rkgen::swap::{Self};

    // Test constants
    const INITIAL_BALANCE: u64 = 1000000;
    const SWAP_AMOUNT: u64 = 1000;
    const INITIAL_FEE_RATE: u64 = 300; // 3%
    const INITIAL_SWAP_RATIO: u64 = 8000; // 80% (0.8:1 ratio)
    const GAS_FEE_AMOUNT: u64 = 50;

    // Error codes for testing
    const EUNAUTHORIZED: u64 = 1;
    const EINVALID_FEE_RATE: u64 = 2;
    const EINSUFFICIENT_BALANCE: u64 = 3;
    const EINVALID_AMOUNT: u64 = 4;
    const EPOOL_NOT_EXISTS: u64 = 5;
    const ENOT_INITIALIZED: u64 = 6;
    const ESWAP_PAUSED: u64 = 7;
    const EINVALID_GAS_FEE: u64 = 8;
    const EFEES_EXCEED_AMOUNT: u64 = 9;
    const EINVALID_SWAP_RATIO: u64 = 10;

    struct TestFA has key {
        mint_ref: fungible_asset::MintRef,
        burn_ref: fungible_asset::BurnRef,
        transfer_ref: fungible_asset::TransferRef,
    }

    // Helper function to create a test fungible asset
    fun create_test_fa(creator: &signer, name: vector<u8>, symbol: vector<u8>): Object<Metadata> {
        let constructor_ref = &object::create_named_object(creator, name);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            string::utf8(name),
            string::utf8(symbol),
            8,
            string::utf8(b""),
            string::utf8(b""),
        );

        // Generate and store refs for testing
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);

        // Store TestFA at the object's address instead of creator's address
        let object_signer = object::generate_signer(constructor_ref);
        move_to(&object_signer, TestFA {
            mint_ref,
            burn_ref,
            transfer_ref,
        });

        object::object_from_constructor_ref<Metadata>(constructor_ref)
    }

    // Helper function to mint test tokens - UPDATED
    fun mint_test_tokens(fa: Object<Metadata>, to: address, amount: u64) acquires TestFA {
        let test_fa = borrow_global<TestFA>(object::object_address(&fa));
        let fa_store = primary_fungible_store::ensure_primary_store_exists(to, fa);
        fungible_asset::mint_to(&test_fa.mint_ref, fa_store, amount);
    }

    // Setup function for tests - FIXED VERSION with proper token distribution
    fun setup_test(): (signer, signer, signer, signer, Object<Metadata>, Object<Metadata>) acquires TestFA {
        let admin = account::create_signer_for_test(@rkgen);
        let user = account::create_signer_for_test(@0x123);
        let fee_recipient = account::create_signer_for_test(@0x456);
        let token_creator = account::create_signer_for_test(@0x789);

        // Initialize the swap module
        swap::init_for_test();

        // Create test fungible assets
        let input_fa = create_test_fa(&token_creator, b"rKGEN", b"rKGEN");
        let output_fa = create_test_fa(&token_creator, b"KGEN", b"KGEN");

        // Mint tokens to user (input tokens for swapping)
        mint_test_tokens(input_fa, signer::address_of(&user), INITIAL_BALANCE);

        // Mint tokens to admin (output tokens for pool liquidity)
        mint_test_tokens(output_fa, signer::address_of(&admin), INITIAL_BALANCE);

        // Also mint some input tokens to admin so the primary store exists
        mint_test_tokens(input_fa, signer::address_of(&admin), INITIAL_BALANCE);

        (admin, user, fee_recipient, token_creator, input_fa, output_fa)
    }

    #[test]
    #[expected_failure(abort_code = ENOT_INITIALIZED, location = rkgen::swap)]
    public fun test_get_admin_not_initialized() {
        // Try to get admin without initialization
        swap::get_admin();
    }

    #[test]
    public fun test_create_pool_success() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(
            &admin,
            input_fa,
            output_fa,
            INITIAL_FEE_RATE,
            INITIAL_SWAP_RATIO,
            signer::address_of(&fee_recipient)
        );

        // Verify pool creation
        assert!(swap::get_swap_fee_rate() == INITIAL_FEE_RATE, 0);
        assert!(swap::get_swap_ratio() == INITIAL_SWAP_RATIO, 1);
        assert!(swap::get_fee_recipient() == signer::address_of(&fee_recipient), 2);
        assert!(!swap::is_swap_paused(), 3);
        assert!(swap::get_total_input_token_swapped() == 0, 4);
        assert!(swap::get_total_output_token_swapped() == 0, 5);
        assert!(swap::get_total_fee_collected() == 0, 6);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED, location = rkgen::swap)]
    public fun test_create_pool_unauthorized() acquires TestFA {
        let (_, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Try to create pool with non-admin user
        swap::create_pool(
            &user,
            input_fa,
            output_fa,
            INITIAL_FEE_RATE,
            INITIAL_SWAP_RATIO,
            signer::address_of(&fee_recipient)
        );
    }

    #[test]
    #[expected_failure(abort_code = EINVALID_FEE_RATE, location = rkgen::swap)]
    public fun test_create_pool_invalid_fee_rate() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Try to create pool with invalid fee rate (> 100%)
        swap::create_pool(
            &admin,
            input_fa,
            output_fa,
            10001, // Invalid fee rate
            INITIAL_SWAP_RATIO,
            signer::address_of(&fee_recipient)
        );
    }

    #[test]
    #[expected_failure(abort_code = EINVALID_SWAP_RATIO, location = rkgen::swap)]
    public fun test_create_pool_invalid_swap_ratio_too_high() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Try to create pool with invalid swap ratio (> 100%)
        swap::create_pool(
            &admin,
            input_fa,
            output_fa,
            INITIAL_FEE_RATE,
            10001, // Invalid swap ratio
            signer::address_of(&fee_recipient)
        );
    }

    #[test]
    #[expected_failure(abort_code = EINVALID_SWAP_RATIO, location = rkgen::swap)]
    public fun test_create_pool_invalid_swap_ratio_too_low() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Try to create pool with invalid swap ratio (< minimum)
        swap::create_pool(
            &admin,
            input_fa,
            output_fa,
            INITIAL_FEE_RATE,
            0, // Invalid swap ratio
            signer::address_of(&fee_recipient)
        );
    }

    #[test]
    public fun test_deposit_success() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Deposit tokens to pool
        let deposit_amount = 5000;
        swap::deposit(&admin, deposit_amount);

        // Check pool balance
        assert!(swap::get_pool_balance() == deposit_amount, 0);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED, location = rkgen::swap)]
    public fun test_deposit_unauthorized() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Try to deposit with non-admin user
        swap::deposit(&user, 1000);
    }

    #[test]
    #[expected_failure(abort_code = EINVALID_AMOUNT, location = rkgen::swap)]
    public fun test_deposit_invalid_amount() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Try to deposit zero amount
        swap::deposit(&admin, 0);
    }

    #[test]
    #[expected_failure(abort_code = EPOOL_NOT_EXISTS, location = rkgen::swap)]
    public fun test_deposit_pool_not_exists() acquires TestFA {
        let (admin, _, _, _, _, _) = setup_test();

        // Try to deposit without creating pool
        swap::deposit(&admin, 1000);
    }

    #[test]
    public fun test_withdraw_success() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool and deposit
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        let deposit_amount = 5000;
        swap::deposit(&admin, deposit_amount);

        // Withdraw tokens from pool
        let withdraw_amount = 2000;
        let initial_balance = primary_fungible_store::balance(signer::address_of(&admin), output_fa);
        swap::withdraw(&admin, withdraw_amount);

        // Check balances
        assert!(swap::get_pool_balance() == deposit_amount - withdraw_amount, 0);
        let final_balance = primary_fungible_store::balance(signer::address_of(&admin), output_fa);
        assert!(final_balance == initial_balance + withdraw_amount, 1);
    }

    #[test]
    #[expected_failure(abort_code = EINSUFFICIENT_BALANCE, location = rkgen::swap)]
    public fun test_withdraw_insufficient_balance() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool and deposit
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 1000);

        // Try to withdraw more than available
        swap::withdraw(&admin, 2000);
    }

    #[test]
    public fun test_swap_success() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool and deposit liquidity
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 10000);

        // Perform swap
        let initial_input_balance = primary_fungible_store::balance(signer::address_of(&user), input_fa);
        let initial_output_balance = primary_fungible_store::balance(signer::address_of(&user), output_fa);

        swap::swap(&user, SWAP_AMOUNT);

        // Verify swap results
        let final_input_balance = primary_fungible_store::balance(signer::address_of(&user), input_fa);
        let final_output_balance = primary_fungible_store::balance(signer::address_of(&user), output_fa);

        assert!(final_input_balance == initial_input_balance - SWAP_AMOUNT, 0);
        assert!(final_output_balance > initial_output_balance, 1);
        assert!(swap::get_total_input_token_swapped() == SWAP_AMOUNT, 2);
        assert!(swap::get_total_output_token_swapped() > 0, 3);
        assert!(swap::get_total_fee_collected() > 0, 4);
    }

    #[test]
    #[expected_failure(abort_code = EINVALID_AMOUNT, location = rkgen::swap)]
    public fun test_swap_invalid_amount() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool and deposit liquidity
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 10000);

        // Try to swap zero amount
        swap::swap(&user, 0);
    }

    #[test]
    #[expected_failure(abort_code = ESWAP_PAUSED, location = rkgen::swap)]
    public fun test_swap_when_paused() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool and deposit liquidity
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 10000);

        // Pause swap
        swap::pause_swap(&admin, true);

        // Try to swap when paused
        swap::swap(&user, SWAP_AMOUNT);
    }

    #[test]
    #[expected_failure(abort_code = EINSUFFICIENT_BALANCE, location = rkgen::swap)]
    public fun test_swap_insufficient_pool_balance() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool without depositing liquidity
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Try to swap without pool liquidity
        swap::swap(&user, SWAP_AMOUNT);
    }

    #[test]
    public fun test_swap_sponsor_success() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool and deposit liquidity
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 10000);

        // Perform sponsored swap
        let initial_input_balance = primary_fungible_store::balance(signer::address_of(&user), input_fa);
        let initial_output_balance = primary_fungible_store::balance(signer::address_of(&user), output_fa);
        let initial_fee_balance = primary_fungible_store::balance(signer::address_of(&fee_recipient), output_fa);

        swap::swap_sponsor(&user, &admin, SWAP_AMOUNT, GAS_FEE_AMOUNT);

        // Verify sponsored swap results
        let final_input_balance = primary_fungible_store::balance(signer::address_of(&user), input_fa);
        let final_output_balance = primary_fungible_store::balance(signer::address_of(&user), output_fa);
        let final_fee_balance = primary_fungible_store::balance(signer::address_of(&fee_recipient), output_fa);

        assert!(final_input_balance == initial_input_balance - SWAP_AMOUNT, 0);
        assert!(final_output_balance > initial_output_balance, 1);
        assert!(final_fee_balance > initial_fee_balance, 2);
        assert!(swap::get_total_input_token_swapped() == SWAP_AMOUNT, 3);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED, location = rkgen::swap)]
    public fun test_swap_sponsor_unauthorized_admin() acquires TestFA {
        let (_, user, _, _, _, _) = setup_test();
        let fake_admin = account::create_signer_for_test(@0x999);

        // Try sponsored swap with unauthorized admin
        swap::swap_sponsor(&user, &fake_admin, SWAP_AMOUNT, GAS_FEE_AMOUNT);
    }

    // #[test]
    // #[expected_failure(abort_code = EINVALID_GAS_FEE, location = rkgen::swap)]
    // public fun test_swap_sponsor_invalid_gas_fee() acquires TestFA {
    //     let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();
    //
    //     // Create pool and deposit liquidity
    //     swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
    //     swap::deposit(&admin, 10000);
    //
    //     // Try sponsored swap with zero gas fee
    //     swap::swap_sponsor(&user, &admin, SWAP_AMOUNT, 0);
    // }

    #[test]
    #[expected_failure(abort_code = EFEES_EXCEED_AMOUNT, location = rkgen::swap)]
    public fun test_swap_sponsor_fees_exceed_amount() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool with very high fee rate
        swap::create_pool(&admin, input_fa, output_fa, 9000, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient)); // 90% fee
        swap::deposit(&admin, 10000);

        // Try sponsored swap where fees exceed output
        swap::swap_sponsor(&user, &admin, SWAP_AMOUNT, 500); // High gas fee
    }

    #[test]
    public fun test_pause_swap() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Test pause
        swap::pause_swap(&admin, true);
        assert!(swap::is_swap_paused(), 0);

        // Test unpause
        swap::pause_swap(&admin, false);
        assert!(!swap::is_swap_paused(), 1);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED, location = rkgen::swap)]
    public fun test_pause_swap_unauthorized() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Try to pause with non-admin user
        swap::pause_swap(&user, true);
    }

    #[test]
    public fun test_update_admin() acquires TestFA {
        let (admin, user, _, _, _, _) = setup_test();
        let new_admin_address = signer::address_of(&user);

        // Update admin
        swap::update_admin(&admin, new_admin_address);

        // Verify admin update
        assert!(swap::get_admin() == new_admin_address, 0);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED, location = rkgen::swap)]
    public fun test_update_admin_unauthorized() acquires TestFA {
        let (_, user, _, _, _, _) = setup_test();

        // Try to update admin with non-admin user
        swap::update_admin(&user, @0x999);
    }

    #[test]
    public fun test_update_swap_fee_rate() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Update fee rate
        let new_fee_rate = 500; // 5%
        swap::update_swap_fee_rate(&admin, new_fee_rate);

        // Verify fee rate update
        assert!(swap::get_swap_fee_rate() == new_fee_rate, 0);
    }

    #[test]
    #[expected_failure(abort_code = EINVALID_FEE_RATE, location = rkgen::swap)]
    public fun test_update_swap_fee_rate_invalid() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Try to update with invalid fee rate
        swap::update_swap_fee_rate(&admin, 10001);
    }

    #[test]
    public fun test_update_swap_ratio() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Update swap ratio
        let new_swap_ratio = 7000; // 70%
        swap::update_swap_ratio(&admin, new_swap_ratio);

        // Verify swap ratio update
        assert!(swap::get_swap_ratio() == new_swap_ratio, 0);
    }

    #[test]
    #[expected_failure(abort_code = EINVALID_SWAP_RATIO, location = rkgen::swap)]
    public fun test_update_swap_ratio_invalid() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Try to update with invalid swap ratio
        swap::update_swap_ratio(&admin, 10001);
    }

    #[test]
    public fun test_update_fee_recipient() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Update fee recipient
        let new_fee_recipient = signer::address_of(&user);
        swap::update_fee_recipient(&admin, new_fee_recipient);

        // Verify fee recipient update
        assert!(swap::get_fee_recipient() == new_fee_recipient, 0);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED, location = rkgen::swap)]
    public fun test_update_fee_recipient_unauthorized() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Try to update fee recipient with non-admin user
        swap::update_fee_recipient(&user, @0x999);
    }

    #[test]
    public fun test_get_swap_preview() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Test swap preview
        let (amount_out, fee_amount) = swap::get_swap_preview(SWAP_AMOUNT);
        assert!(amount_out > 0, 0);
        assert!(fee_amount > 0, 1);
        assert!(amount_out + fee_amount <= SWAP_AMOUNT * INITIAL_SWAP_RATIO / 10000, 2);
    }

    #[test]
    #[expected_failure(abort_code = EINVALID_AMOUNT, location = rkgen::swap)]
    public fun test_get_swap_preview_invalid_amount() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Try preview with zero amount
        swap::get_swap_preview(0);
    }

    #[test]
    public fun test_get_sponsor_swap_preview() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Test sponsor swap preview
        let (amount_out, swap_fee_amount, total_fee_amount) = swap::get_sponser_swap_preview(SWAP_AMOUNT, GAS_FEE_AMOUNT);
        assert!(amount_out > 0, 0);
        assert!(swap_fee_amount > 0, 1);
        assert!(total_fee_amount == swap_fee_amount + GAS_FEE_AMOUNT, 2);
    }

    #[test]
    #[expected_failure(abort_code = EINVALID_GAS_FEE, location = rkgen::swap)]
    public fun test_get_sponsor_swap_preview_invalid_gas_fee() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Try preview with zero gas fee
        swap::get_sponser_swap_preview(SWAP_AMOUNT, 0);
    }

    #[test]
    public fun test_get_swap_stats() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool and perform swap
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 10000);
        swap::swap(&user, SWAP_AMOUNT);

        // Test swap stats
        let (total_input, total_output, total_fees, fee_rate, swap_ratio, is_paused) = swap::get_swap_stats();
        assert!(total_input == SWAP_AMOUNT, 0);
        assert!(total_output > 0, 1);
        assert!(total_fees > 0, 2);
        assert!(fee_rate == INITIAL_FEE_RATE, 3);
        assert!(swap_ratio == INITIAL_SWAP_RATIO, 4);
        assert!(!is_paused, 5);
    }

    #[test]
    #[expected_failure(abort_code = EPOOL_NOT_EXISTS, location = rkgen::swap)]
    public fun test_view_functions_pool_not_exists() acquires TestFA {
        setup_test();

        // Try to call view function without creating pool
        swap::get_pool_balance();
    }

    #[test]
    public fun test_edge_case_minimum_swap_ratio() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool with minimum swap ratio
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, 1000, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 10000);

        // Test swap preview with minimum ratio
        let (amount_out, fee_amount) = swap::get_swap_preview(SWAP_AMOUNT);
        assert!(amount_out > 0, 0);
        assert!(fee_amount >= 0, 1);
    }

    #[test]
    public fun test_edge_case_maximum_swap_ratio() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool with maximum swap ratio (1:1)
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, 10000, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 10000);

        // Test swap preview with maximum ratio
        let (amount_out, fee_amount) = swap::get_swap_preview(SWAP_AMOUNT);
        assert!(amount_out > 0, 0);
        assert!(fee_amount >= 0, 1);

        // Perform actual swap with 1:1 ratio
        swap::swap(&user, SWAP_AMOUNT);
        assert!(swap::get_total_input_token_swapped() == SWAP_AMOUNT, 2);
    }

    #[test]
    public fun test_edge_case_zero_fee_rate() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool with zero fee rate
        swap::create_pool(&admin, input_fa, output_fa, 0, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 10000);

        // Test swap with zero fees
        let (amount_out, fee_amount) = swap::get_swap_preview(SWAP_AMOUNT);
        assert!(amount_out > 0, 0);
        assert!(fee_amount == 0, 1);

        // Perform actual swap
        swap::swap(&user, SWAP_AMOUNT);
        assert!(swap::get_total_fee_collected() == 0, 2);
    }

    #[test]
    public fun test_edge_case_maximum_fee_rate() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool with maximum fee rate (100%)
        swap::create_pool(&admin, input_fa, output_fa, 10000, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 10000);

        // Test swap preview with maximum fee
        let (_, fee_amount) = swap::get_swap_preview(SWAP_AMOUNT);
        // With 100% fee rate, user should get very little output
        assert!(fee_amount > 0, 0);
    }

    #[test]
    public fun test_admin_role_transfer_and_operations() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();
        let new_admin = account::create_signer_for_test(@0x888);

        // Create pool with original admin
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Transfer admin role
        swap::update_admin(&admin, signer::address_of(&new_admin));

        // Original admin should no longer have access
        // New admin should be able to perform admin operations
        swap::pause_swap(&new_admin, true);
        assert!(swap::is_swap_paused(), 0);

        swap::pause_swap(&new_admin, false);
        assert!(!swap::is_swap_paused(), 1);

        // Test other admin operations with new admin
        swap::update_swap_fee_rate(&new_admin, 400);
        assert!(swap::get_swap_fee_rate() == 400, 2);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED, location = rkgen::swap)]
    public fun test_old_admin_loses_access_after_transfer() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();
        let new_admin = account::create_signer_for_test(@0x888);

        // Create pool and transfer admin
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::update_admin(&admin, signer::address_of(&new_admin));

        // Old admin should no longer have access
        swap::pause_swap(&admin, true);
    }

    #[test]
    public fun test_fee_recipient_receives_fees() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool and deposit liquidity
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 10000);

        // Check initial fee recipient balance
        let initial_fee_balance = primary_fungible_store::balance(signer::address_of(&fee_recipient), output_fa);

        // Perform swap
        swap::swap(&user, SWAP_AMOUNT);

        // Check that fee recipient received fees
        let final_fee_balance = primary_fungible_store::balance(signer::address_of(&fee_recipient), output_fa);
        assert!(final_fee_balance > initial_fee_balance, 0);
    }

    #[test]
    public fun test_sponsored_swap_fee_distribution() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool and deposit liquidity
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 10000);

        // Check initial balances
        let initial_fee_balance = primary_fungible_store::balance(signer::address_of(&fee_recipient), output_fa);

        // Perform sponsored swap
        swap::swap_sponsor(&user, &admin, SWAP_AMOUNT, GAS_FEE_AMOUNT);

        // Check that fee recipient received both swap fee and gas fee
        let final_fee_balance = primary_fungible_store::balance(signer::address_of(&fee_recipient), output_fa);
        assert!(final_fee_balance > initial_fee_balance, 0);

        // The difference should include both swap fee and gas fee
        let total_fees_sent = final_fee_balance - initial_fee_balance;
        assert!(total_fees_sent > GAS_FEE_AMOUNT, 1); // Should be swap_fee + gas_fee
    }

    #[test]
    public fun test_pool_balance_management() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Test initial pool balance
        assert!(swap::get_pool_balance() == 0, 0);

        // Deposit and check balance
        let deposit_amount = 5000;
        swap::deposit(&admin, deposit_amount);
        assert!(swap::get_pool_balance() == deposit_amount, 1);

        // Perform swap and check balance decreases
        let initial_pool_balance = swap::get_pool_balance();
        swap::swap(&user, SWAP_AMOUNT);
        let final_pool_balance = swap::get_pool_balance();
        assert!(final_pool_balance < initial_pool_balance, 2);

        // Withdraw and check balance
        let withdraw_amount = 1000;
        swap::withdraw(&admin, withdraw_amount);
        assert!(swap::get_pool_balance() == final_pool_balance - withdraw_amount, 3);
    }

    #[test]
    public fun test_comprehensive_state_changes() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Test initial state
        let (total_input, total_output, total_fees, _, _, is_paused) = swap::get_swap_stats();
        assert!(total_input == 0, 0);
        assert!(total_output == 0, 1);
        assert!(total_fees == 0, 2);
        assert!(!is_paused, 3);

        // Deposit liquidity
        swap::deposit(&admin, 10000);

        // Perform swap and check state changes
        swap::swap(&user, SWAP_AMOUNT);
        let (new_total_input, new_total_output, new_total_fees, _, _, _) = swap::get_swap_stats();
        assert!(new_total_input > total_input, 4);
        assert!(new_total_output > total_output, 5);
        assert!(new_total_fees > total_fees, 6);

        // Update parameters and verify
        let new_fee_rate = 500;
        let new_swap_ratio = 7000;
        swap::update_swap_fee_rate(&admin, new_fee_rate);
        swap::update_swap_ratio(&admin, new_swap_ratio);

        assert!(swap::get_swap_fee_rate() == new_fee_rate, 7);
        assert!(swap::get_swap_ratio() == new_swap_ratio, 8);
    }

    #[test]
    public fun test_boundary_value_swaps() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool with specific parameters for boundary testing
        swap::create_pool(&admin, input_fa, output_fa, 1, 1, signer::address_of(&fee_recipient)); // Minimal fee and ratio
        swap::deposit(&admin, 100000);

        // Test swap with amount = 1 (minimum)
        swap::swap(&user, 1);
        assert!(swap::get_total_input_token_swapped() == 1, 0);

        // Test larger swap
        let large_amount = 10000;
        swap::swap(&user, large_amount);
        assert!(swap::get_total_input_token_swapped() == 1 + large_amount, 1);
    }

    #[test]
    public fun test_all_view_functions_consistency() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool and perform operations
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 10000);
        swap::swap(&user, SWAP_AMOUNT);

        // Test all view functions return consistent values
        let admin_addr = swap::get_admin();
        let fee_rate = swap::get_swap_fee_rate();
        let fee_recip = swap::get_fee_recipient();
        let is_paused = swap::is_swap_paused();
        let total_input = swap::get_total_input_token_swapped();
        let total_output = swap::get_total_output_token_swapped();
        let total_fees = swap::get_total_fee_collected();
        let swap_ratio = swap::get_swap_ratio();

        // Verify consistency with get_swap_stats
        let (stats_input, stats_output, stats_fees, stats_fee_rate, stats_ratio, stats_paused) = swap::get_swap_stats();
        assert!(total_input == stats_input, 0);
        assert!(total_output == stats_output, 1);
        assert!(total_fees == stats_fees, 2);
        assert!(fee_rate == stats_fee_rate, 3);
        assert!(swap_ratio == stats_ratio, 4);
        assert!(is_paused == stats_paused, 5);

        // Verify admin address consistency
        assert!(admin_addr == signer::address_of(&admin), 6);
        assert!(fee_recip == signer::address_of(&fee_recipient), 7);
    }

    #[test]
    public fun test_complex_multi_operation_scenario() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();
        let user2 = account::create_signer_for_test(@0xabc);

        // Mint tokens for second user
        mint_test_tokens(input_fa, signer::address_of(&user2), INITIAL_BALANCE);
        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 50000);

        // Multiple users perform swaps
        swap::swap(&user, 1000);
        swap::swap(&user2, 2000);
        swap::swap_sponsor(&user, &admin, 500, 25);

        // Admin operations
        swap::pause_swap(&admin, true);
        swap::pause_swap(&admin, false);
        swap::update_swap_fee_rate(&admin, 400);
        swap::update_swap_ratio(&admin, 9000);

        // More swaps with new parameters
        swap::swap(&user2, 1500);

        // Verify final state
        let total_expected_input = 1000 + 2000 + 500 + 1500;
        assert!(swap::get_total_input_token_swapped() == total_expected_input, 0);
        assert!(swap::get_total_output_token_swapped() > 0, 1);
        assert!(swap::get_total_fee_collected() > 0, 2);
        assert!(swap::get_swap_fee_rate() == 400, 3);
        assert!(swap::get_swap_ratio() == 9000, 4);
    }
    // Additional test cases to cover missing lines

    #[test]
    #[expected_failure(abort_code = EPOOL_NOT_EXISTS, location = rkgen::swap)]
    public fun test_create_pool_already_exists() acquires TestFA {
        let (admin, _, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool first time - should succeed
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Try to create pool again - should fail with EPOOL_NOT_EXISTS
        // Note: The assertion is !exists<SwapPool>(@rkgen), so when pool exists, it should fail
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
    }

    #[test]
    #[expected_failure(abort_code = ESWAP_PAUSED, location = rkgen::swap)]
    public fun test_swap_sponsor_when_paused() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool and deposit liquidity
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 10000);

        // Pause swap - this covers !pool.is_paused assertion in swap_sponsor
        swap::pause_swap(&admin, true);

        // Try to perform sponsored swap when paused - should fail
        swap::swap_sponsor(&user, &admin, SWAP_AMOUNT, GAS_FEE_AMOUNT);
    }

    #[test]
    #[expected_failure(abort_code = EINSUFFICIENT_BALANCE, location = rkgen::swap)]
    public fun test_swap_sponsor_insufficient_pool_balance() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool with very small liquidity
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 100); // Very small amount

        // Try to swap large amount - should fail due to insufficient pool balance
        // This covers the pool_balance >= amount_out assertion in swap_sponsor
        swap::swap_sponsor(&user, &admin, 5000, GAS_FEE_AMOUNT); // Much larger than pool balance
    }

    #[test]
    public fun test_swap_sponsor_with_zero_total_fee() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool with zero fee rate
        swap::create_pool(&admin, input_fa, output_fa, 0, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 10000);

        // Perform sponsored swap with minimal gas fee
        let minimal_gas_fee = 1;
        let initial_fee_balance = primary_fungible_store::balance(signer::address_of(&fee_recipient), output_fa);

        swap::swap_sponsor(&user, &admin, SWAP_AMOUNT, minimal_gas_fee);

        // Verify that fee recipient received the gas fee (total_fee_amount > 0 path)
        let final_fee_balance = primary_fungible_store::balance(signer::address_of(&fee_recipient), output_fa);
        assert!(final_fee_balance > initial_fee_balance, 0);
        assert!(final_fee_balance - initial_fee_balance == minimal_gas_fee, 1);
    }

    #[test]
    public fun test_swap_sponsor_fee_transfer_execution() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool with normal fee rate
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 10000);

        // Check initial fee recipient balance
        let initial_fee_balance = primary_fungible_store::balance(signer::address_of(&fee_recipient), output_fa);

        // Perform sponsored swap
        swap::swap_sponsor(&user, &admin, SWAP_AMOUNT, GAS_FEE_AMOUNT);

        // Verify the total_fee_amount > 0 condition was executed and transfer happened
        let final_fee_balance = primary_fungible_store::balance(signer::address_of(&fee_recipient), output_fa);
        let total_fees_received = final_fee_balance - initial_fee_balance;

        // Should receive both swap fee and gas fee
        assert!(total_fees_received > GAS_FEE_AMOUNT, 0);

        // Verify the exact fee calculation matches preview
        let (_, _, total_fee_amount) = swap::get_sponser_swap_preview(SWAP_AMOUNT, GAS_FEE_AMOUNT);
        assert!(total_fees_received == total_fee_amount, 1);
    }

    #[test]
    public fun test_regular_swap_fee_transfer_execution() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool with normal fee rate
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 10000);

        // Check initial fee recipient balance
        let initial_fee_balance = primary_fungible_store::balance(signer::address_of(&fee_recipient), output_fa);

        // Perform regular swap
        swap::swap(&user, SWAP_AMOUNT);

        // Verify the fee_amount > 0 condition was executed and transfer happened
        let final_fee_balance = primary_fungible_store::balance(signer::address_of(&fee_recipient), output_fa);
        let fees_received = final_fee_balance - initial_fee_balance;

        // Should receive swap fee
        assert!(fees_received > 0, 0);

        // Verify the exact fee calculation matches preview
        let (_, fee_amount) = swap::get_swap_preview(SWAP_AMOUNT);
        assert!(fees_received == fee_amount, 1);
    }

    #[test]
    public fun test_regular_swap_zero_fee_no_transfer() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool with zero fee rate
        swap::create_pool(&admin, input_fa, output_fa, 0, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));
        swap::deposit(&admin, 10000);

        // Check initial fee recipient balance
        let initial_fee_balance = primary_fungible_store::balance(signer::address_of(&fee_recipient), output_fa);

        // Perform regular swap with zero fee
        swap::swap(&user, SWAP_AMOUNT);

        // Verify no fee transfer happened (fee_amount == 0 case)
        let final_fee_balance = primary_fungible_store::balance(signer::address_of(&fee_recipient), output_fa);
        assert!(final_fee_balance == initial_fee_balance, 0);

        // Verify fee calculation shows zero
        let (_, fee_amount) = swap::get_swap_preview(SWAP_AMOUNT);
        assert!(fee_amount == 0, 1);
    }

    #[test]
    public fun test_swap_with_exact_pool_balance() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Calculate exact amount needed for a specific swap
        let (amount_out, fee_amount) = swap::get_swap_preview(SWAP_AMOUNT);
        let exact_pool_amount = amount_out + fee_amount;

        // Deposit exactly what's needed
        swap::deposit(&admin, exact_pool_amount);

        // Verify pool balance
        assert!(swap::get_pool_balance() == exact_pool_amount, 0);

        // Perform swap - should work with exact balance
        swap::swap(&user, SWAP_AMOUNT);

        // Pool should be nearly empty after the swap
        let remaining_balance = swap::get_pool_balance();
        assert!(remaining_balance < exact_pool_amount, 1);
    }

    #[test]
    public fun test_swap_sponsor_with_exact_pool_balance() acquires TestFA {
        let (admin, user, fee_recipient, _, input_fa, output_fa) = setup_test();

        // Create pool
        swap::create_pool(&admin, input_fa, output_fa, INITIAL_FEE_RATE, INITIAL_SWAP_RATIO, signer::address_of(&fee_recipient));

        // Calculate exact amount needed for sponsored swap
        let (amount_out, _, total_fee_amount) = swap::get_sponser_swap_preview(SWAP_AMOUNT, GAS_FEE_AMOUNT);
        let exact_pool_amount = amount_out + total_fee_amount;

        // Deposit exactly what's needed
        swap::deposit(&admin, exact_pool_amount);

        // Perform sponsored swap - should work with exact balance
        swap::swap_sponsor(&user, &admin, SWAP_AMOUNT, GAS_FEE_AMOUNT);

        // Pool should be nearly empty after the swap
        let remaining_balance = swap::get_pool_balance();
        assert!(remaining_balance < exact_pool_amount, 0);
    }
}