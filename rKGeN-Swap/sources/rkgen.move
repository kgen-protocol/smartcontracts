module rkgen::swap {
    use std::signer;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::event;
    use aptos_framework::fungible_asset;
    use aptos_framework::fungible_asset::{Metadata, FungibleStore};
    use aptos_framework::object;
    use aptos_framework::object::{ExtendRef, Object};
    use aptos_framework::primary_fungible_store;
    use rKGenAdmin::rKGEN::{Self};

    // Errors
    /// Caller is not authorized to perform the operation
    const EUNAUTHORIZED: u64 = 1;
    /// Invalid fee rate (must be between 0 and 10000, representing 0% to 100%)
    const EINVALID_FEE_RATE: u64 = 2;
    /// Insufficient balance for the swap operation
    const EINSUFFICIENT_BALANCE: u64 = 3;
    /// Invalid swap amount (must be greater than 0)
    const EINVALID_AMOUNT: u64 = 4;
    /// Pool does not exist
    const EPOOL_NOT_EXISTS: u64 = 5;
    /// Contract not initialized
    const ENOT_INITIALIZED: u64 = 6;
    /// Swap functionality is currently paused
    const ESWAP_PAUSED: u64 = 7;
    /// Invalid gas fee amount
    const EINVALID_GAS_FEE: u64 = 8;
    /// Total gas_fees exceed swap amount
    const EFEES_EXCEED_AMOUNT: u64 = 9;
    /// Invalid swap ratio (must be between 1 and 10000, cannot exceed 1:1)
    const EINVALID_SWAP_RATIO: u64 = 10;

    // Constants
    /// Maximum fee rate in basis points (10000 = 100%)
    const MAX_FEE_RATE: u64 = 10000;
    /// Fee calculation precision (10000 = 100%)
    const FEE_PRECISION: u64 = 10000;
    /// Fee ratio precision (10000 = 100% = 1:1 ratio)
    const FEE_RATIO_PRECISION: u64 = 10000;
    /// Maximum swap ratio (10000 = 100% = 1:1, cannot exceed this)
    const MAX_SWAP_RATIO: u64 = 10000;
    /// Minimum swap ratio (1 = 0.01% = 0.0001:1, very small but not zero)
    const MIN_SWAP_RATIO: u64 = 1;

    /* ----------- Resources (Global storage) ----------*/
    // Stores references for admin, and SwapPool of rKGEN to KGEN.
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Admin has key {
        admin: address
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct SwapPool has key {
        output_token: ExtendRef,
        input_token_metadata: Object<Metadata>,
        output_token_metadata: Object<Metadata>,
        swap_fee_rate: u64,
        swap_ratio: u64,
        fee_recipient: address,
        is_paused: bool,
        total_input_token_swapped: u64,
        total_output_token_swapped: u64,
        total_fees_collected: u64,
    }


    /* Events */
    #[event]
    // Triggered when a new pool is created
    struct CreatePool has drop, store {
        input_token: Object<Metadata>,
        output_token: Object<Metadata>,
        swap_fee_rate: u64,
        swap_ratio: u64,
        fee_recipient: address,
    }

    #[event]
    // Triggered when a swap is executed
    struct Swap has drop, store {
        user: address,
        input_token_amount: u64,
        output_token_amount: u64,
        swap_fee_amount: u64,
    }

    #[event]
    // Triggered when a SponsoredSwap is executed
    struct SponsoredSwap has drop, store {
        user: address,
        input_token_amount: u64,
        output_token_amount: u64,
        swap_fee_amount: u64,
        swap_gas_fee_amount: u64,
        total_fee_amount: u64,
    }

    #[event]
    // Triggered when swap fee rate is updated
    struct SwapFeeRateUpdated has drop, store {
        old_swap_fee_rate: u64,
        new_swap_fee_rate: u64,
        updated_by: address,
    }

    #[event]
    // Triggered when fee recipient is updated
    struct FeeRecipientUpdated has drop, store {
        old_fee_recipient: address,
        new_fee_recipient: address,
        updated_by: address,
    }

    #[event]
    // Triggered when admin is updated
    struct AdminUpdated has drop, store {
        old_admin: address,
        new_admin: address,
        updated_by: address,
    }

    #[event]
    // Triggered when output token is deposited to pool
    struct OutputTokenDeposited has drop, store {
        admin: address,
        amount: u64,
    }

    #[event]
    // Triggered when output token is withdraw to pool
    struct OutputTokenWithdraw has drop, store {
        admin: address,
        amount: u64,
    }

    #[event]
    // Triggred when swap is paused or unpaused
    struct SwapPauseStatisChanges has drop, store {
        is_paused: bool,
        updated_by: address,
    }

    #[event]
    // Triggered when swap ratio is updated
    struct SwapRatioUpdated has drop, store {
        old_swap_ratio: u64,
        new_swap_ratio: u64,
        updated_by: address,
    }

    /*Views*/
    #[view]
    // get the current admin address
    public fun get_admin(): address acquires  Admin{
        assert!(exists<Admin>(@rkgen), ENOT_INITIALIZED);
        borrow_global<Admin>(@rkgen).admin
    }

    #[view]
    // get the output token balance in the pool
    public fun get_pool_balance(): u64 acquires  SwapPool {
        assert_pool();
        let pool = borrow_global<SwapPool>(@rkgen);
        let output_store = object::address_to_object<FungibleStore>(object::address_from_extend_ref(&pool.output_token));
        fungible_asset::balance(output_store)
    }

    #[view]
    // get the current swap fee rate
    public fun get_swap_fee_rate(): u64 acquires SwapPool {
        assert_pool();
        let pool = borrow_global<SwapPool>(@rkgen);
        pool.swap_fee_rate
    }

    #[view]
    // get current fee recipient
    public fun get_fee_recipient(): address acquires SwapPool {
        assert_pool();
        let pool =borrow_global<SwapPool>(@rkgen);
        pool.fee_recipient
    }

    #[view]
    // get if swap is paused
    public fun is_swap_paused(): bool acquires SwapPool {
        assert_pool();
        let pool = borrow_global<SwapPool>(@rkgen);
        pool.is_paused
    }

    #[view]
    // get total amount of input token swapped
    public fun get_total_input_token_swapped(): u64 acquires SwapPool{
        assert_pool();
        let pool = borrow_global<SwapPool>(@rkgen);
        pool.total_input_token_swapped
    }

    #[view]
    // get total amount of output token swapped out
    public fun get_total_output_token_swapped(): u64 acquires SwapPool{
        assert_pool();
        let pool = borrow_global<SwapPool>(@rkgen);
        pool.total_output_token_swapped
    }

    #[view]
    // get total fee colleted
    public fun get_total_fee_collected() :u64 acquires SwapPool{
        assert_pool();
        let pool = borrow_global<SwapPool>(@rkgen);
        pool.total_fees_collected
    }

    #[view]
    // get current swap ratio in basis points
    public fun get_swap_ratio(): u64 acquires SwapPool {
        assert_pool();
        let pool = borrow_global<SwapPool>(@rkgen);
        pool.swap_ratio
    }

    #[view]
    // get swap stats
    public fun get_swap_stats(): (u64, u64, u64, u64, u64, bool) acquires  SwapPool {
        assert_pool();
        let pool = borrow_global<SwapPool>(@rkgen);
        (pool.total_input_token_swapped, pool.total_output_token_swapped, pool.total_fees_collected, pool.swap_fee_rate, pool.swap_ratio, pool.is_paused)
    }

    #[view]
    // get calculate swap output amount
    public fun get_swap_preview(amount_in: u64): (u64, u64) acquires  SwapPool {
        assert_amount(amount_in);
        assert_pool();
        let pool = borrow_global<SwapPool>(@rkgen);

        // Calculate output amount based on swap ratio
        let swap_ratio_amount = (amount_in * pool.swap_ratio) / FEE_RATIO_PRECISION;

        // Calculate fee on the output amount
        let fee_amount = (swap_ratio_amount * pool.swap_fee_rate) / FEE_PRECISION;
        let amount_out = swap_ratio_amount - fee_amount;
        (amount_out, fee_amount)
    }

    #[view]
    // get calculate sponser swap output amount
    public fun get_sponser_swap_preview(amount_in: u64, gas_fee_amount: u64): (u64, u64, u64) acquires  SwapPool {
        assert_amount(amount_in);
        assert!(gas_fee_amount > 0, EINVALID_GAS_FEE);
        assert_pool();
        let pool = borrow_global<SwapPool>(@rkgen);

        // Calculate output amount based on swap ratio
        let output_amount = (amount_in * pool.swap_ratio) / FEE_RATIO_PRECISION;

        // Calculate swap fee and gas fee on the output amount
        let swap_fee_amount = (output_amount * pool.swap_fee_rate) / FEE_PRECISION;
        let total_fee_amount = swap_fee_amount + gas_fee_amount;
        assert!(total_fee_amount < output_amount, EFEES_EXCEED_AMOUNT);
        let amount_out = output_amount - total_fee_amount;

        (amount_out, swap_fee_amount, total_fee_amount)
    }

    // Initialize the module
    fun init_module(admin: &signer) {
        move_to(admin,
            Admin {
            admin: signer::address_of(admin)
        });
    }

    /* -----  Entry functions that can be called from outside ----- */
    // Pause or unpause the swap functionality. Can only be called by the admin.
    public entry fun pause_swap(admin: &signer, pause: bool) acquires Admin, SwapPool {
        assert_admin(admin);
        assert_pool();

        let pool = borrow_global_mut<SwapPool>(@rkgen);
        pool.is_paused = pause;

        event::emit(SwapPauseStatisChanges{
            is_paused: pause,
            updated_by: signer::address_of(admin),
        })
    }

    // Create a swap pool between input token and output token. Can only be called by the admin.
    public entry fun create_pool(admin: &signer, input_token_metadata: Object<Metadata>, output_token_metadata: Object<Metadata>, initial_fee_rate: u64, initial_swap_ratio: u64, fee_recipient: address) acquires  Admin {
        assert_admin(admin);
        assert!(initial_fee_rate <= MAX_FEE_RATE, EINVALID_FEE_RATE);
        assert_swap_ratio(initial_swap_ratio);
        assert!(!exists<SwapPool>(@rkgen), EPOOL_NOT_EXISTS);

        // Create store for output token only
        let output_token_store_constructor= &object::create_object(@rkgen);
        fungible_asset::create_store(output_token_store_constructor,output_token_metadata);
        let output_token_store_extend_ref = object::generate_extend_ref(output_token_store_constructor);

        // Create and store the swap pool at the contract address
        move_to(admin, SwapPool{
            output_token: output_token_store_extend_ref,
            input_token_metadata,
            output_token_metadata,
            swap_fee_rate: initial_fee_rate,
            swap_ratio: initial_swap_ratio,
            fee_recipient,
            is_paused: false,
            total_input_token_swapped: 0,
            total_output_token_swapped: 0,
            total_fees_collected: 0,
        });

        event::emit(CreatePool {
            input_token: input_token_metadata,
            output_token: output_token_metadata,
            swap_fee_rate: initial_fee_rate,
            swap_ratio: initial_swap_ratio,
            fee_recipient,
        });
    }
    // Swap the input token for the output token at swap ratio.
    // The input token is transferred to the admin, the output token is withdrawn from the pool,
    // and the swap fee is sent to the fee recipient.
    public entry fun swap(user: &signer, amount: u64) acquires SwapPool {
        assert_amount(amount);
        assert_pool();

        // Calculate fee and output amount
        let (amount_out, fee_amount) = get_swap_preview(amount);

        let pool = borrow_global_mut<SwapPool>(@rkgen);
        assert!(!pool.is_paused, ESWAP_PAUSED);

        let burn_vault_address = rKGEN::get_burn_vault();// rkgen.get_burn_vault()

        // Check if pool has enough output token
        let output_token_store =object::address_to_object<FungibleStore>(object::address_from_extend_ref(&pool.output_token));
        let pool_balance = fungible_asset::balance(output_token_store);
        assert!(pool_balance >= amount_out, EINSUFFICIENT_BALANCE);

        let user_addr = signer::address_of((user));
        let output_token_store_signer = &object::generate_signer_for_extending(&pool.output_token);

        // Ensure primary stores exist
        primary_fungible_store::ensure_primary_store_exists(user_addr, pool.input_token_metadata);
        primary_fungible_store::ensure_primary_store_exists(user_addr, pool.output_token_metadata);
        primary_fungible_store::ensure_primary_store_exists(burn_vault_address, pool.input_token_metadata);
        primary_fungible_store::ensure_primary_store_exists(pool.fee_recipient, pool.output_token_metadata);

        // Transfer output token from user to admin
        rKGEN::transfer(user, burn_vault_address, amount);

        // Transfer fee to fee recipient (in output token)
        if(fee_amount > 0){
            dispatchable_fungible_asset::transfer(
                output_token_store_signer,
                output_token_store,
                primary_fungible_store::primary_store(pool.fee_recipient, pool.output_token_metadata),
                fee_amount
            );
        };

        // Transfer output token from pool to user
        dispatchable_fungible_asset::transfer(
            output_token_store_signer,
            output_token_store,
            primary_fungible_store::primary_store(user_addr, pool.output_token_metadata),
            amount_out
        );

        pool.total_input_token_swapped += amount;
        pool.total_output_token_swapped += amount_out;
        pool.total_fees_collected += fee_amount;

        event::emit(Swap {
            user: user_addr,
            input_token_amount: amount,
            output_token_amount: amount_out,
            swap_fee_amount: fee_amount,
        });
    }

    // Swap sponsor: Swap the input token for the output token at swap ratio.
    // The input token is transferred to the admin, the output token is withdrawn from the pool,
    // and both the swap fee and the gas fee are sent to the fee recipient.
    public entry fun swap_sponsor(user: &signer, admin: &signer, amount: u64, swap_gas_fee_amount: u64) acquires Admin, SwapPool {
        assert_admin(admin);
        assert_amount(amount);
        assert_amount(swap_gas_fee_amount);
        assert_pool();

        // Calculate fee and output amount
        let (amount_out, swap_fee_amount, total_fee_amount) = get_sponser_swap_preview(amount, swap_gas_fee_amount);

        let pool = borrow_global_mut<SwapPool>(@rkgen);
        assert!(!pool.is_paused, ESWAP_PAUSED);

        let burn_vault_address = rKGEN::get_burn_vault();// rkgen.get_burn_vault()

        // Check if pool has enough output token
        let output_token_store = object::address_to_object<FungibleStore>(object::address_from_extend_ref(&pool.output_token));
        let pool_balance = fungible_asset::balance(output_token_store);
        assert!(pool_balance >= amount_out, EINSUFFICIENT_BALANCE);

        let user_addr = signer::address_of((user));
        let output_token_store_signer = &object::generate_signer_for_extending(&pool.output_token);

        // Ensure primary stores exist
        primary_fungible_store::ensure_primary_store_exists(user_addr, pool.input_token_metadata);
        primary_fungible_store::ensure_primary_store_exists(user_addr, pool.output_token_metadata);
        primary_fungible_store::ensure_primary_store_exists(burn_vault_address, pool.input_token_metadata);
        primary_fungible_store::ensure_primary_store_exists(pool.fee_recipient, pool.output_token_metadata);

        // Transfer output token from user to admin
        rKGEN::transfer(user, burn_vault_address, amount);

        // Transfer fee and gas_fee to fee recipient (in output token)
        if(total_fee_amount > 0){
            dispatchable_fungible_asset::transfer(
                output_token_store_signer,
                output_token_store,
                primary_fungible_store::primary_store(pool.fee_recipient, pool.output_token_metadata),
                total_fee_amount
            );
        };

        // Transfer output token from pool to user
        dispatchable_fungible_asset::transfer(
            output_token_store_signer,
            output_token_store,
            primary_fungible_store::primary_store(user_addr, pool.output_token_metadata),
            amount_out
        );

        pool.total_input_token_swapped += amount;
        pool.total_output_token_swapped += amount_out;
        pool.total_fees_collected += swap_fee_amount;

        event::emit(SponsoredSwap {
            user: user_addr,
            input_token_amount: amount,
            output_token_amount: amount_out,
            swap_fee_amount,
            swap_gas_fee_amount,
            total_fee_amount,
        });
    }

    // Update the admin address. Can only be called by the current admin.
    public entry fun update_admin(admin: &signer, new_admin: address) acquires  Admin {
        assert_admin(admin);

        let admin_resource = borrow_global_mut<Admin>(@rkgen);
        let old_admin = admin_resource.admin;
        admin_resource.admin = new_admin;

        event::emit(AdminUpdated{
            old_admin,
            new_admin,
            updated_by: signer::address_of(admin),
        });
    }
    // Update the swap rate. Can only be called by the admin.
    public entry fun update_swap_fee_rate(admin: &signer, new_swap_fee_rate: u64) acquires Admin, SwapPool {
        assert_admin(admin);
        assert!(new_swap_fee_rate <= MAX_FEE_RATE, EINVALID_FEE_RATE);
        assert_pool();

        let pool = borrow_global_mut<SwapPool>(@rkgen);
        let old_swap_fee_rate = pool.swap_fee_rate;
        pool.swap_fee_rate = new_swap_fee_rate;

        event::emit(SwapFeeRateUpdated{
            old_swap_fee_rate,
            new_swap_fee_rate,
            updated_by: signer::address_of(admin),
        });
    }


    // Update the swap ratio. Can only be called by the admin.
    // The swap ratio can only be decreased (made less favorable), never increased beyond 1:1
    public entry fun update_swap_ratio(admin: &signer, new_swap_ratio: u64) acquires Admin, SwapPool {
        assert_admin(admin);
        assert_pool();
        assert_swap_ratio(new_swap_ratio);

        let pool = borrow_global_mut<SwapPool>(@rkgen);
        let old_swap_ratio = pool.swap_ratio;

        pool.swap_ratio = new_swap_ratio;

        event::emit(SwapRatioUpdated {
            old_swap_ratio,
            new_swap_ratio,
            updated_by: signer::address_of(admin),
        });
    }

    // Update the fee recipient address. Can only be called by the admin.
    public entry fun update_fee_recipient(admin: &signer, new_fee_recipient: address) acquires Admin, SwapPool {
        assert_admin(admin);
        assert_pool();

        let pool = borrow_global_mut<SwapPool>(@rkgen);
        let old_fee_recipient = pool.fee_recipient;
        pool.fee_recipient = new_fee_recipient;

        event::emit(FeeRecipientUpdated {
            old_fee_recipient,
            new_fee_recipient,
            updated_by: signer::address_of(admin),
        });
    }

    // Deposit output Token liquidity into the pool. Can only be called by the admin.
    public entry fun deposit(admin: &signer, amount: u64)  acquires  Admin, SwapPool {
        assert_admin(admin);
        assert_amount(amount);
        assert_pool();

        let pool = borrow_global<SwapPool>(@rkgen);
        let admin_addr = signer::address_of((admin));

        // Transfer output token from admin to pool
        dispatchable_fungible_asset::transfer(
            admin,
            primary_fungible_store::primary_store(admin_addr, pool.output_token_metadata),
            object::address_to_object<FungibleStore>(object::address_from_extend_ref(&pool.output_token)),
            amount
        );

        event::emit(OutputTokenDeposited{
            admin: admin_addr,
            amount,
        })
    }

    // Withdraw output token liquidity from the pool. Can only be called by the admin.
    public entry fun withdraw(admin: &signer, amount:u64) acquires Admin, SwapPool {
        assert_admin(admin);
        assert_amount(amount);
        assert_pool();

        let pool =borrow_global<SwapPool>(@rkgen);
        let admin_addr = signer::address_of(admin);

        // Check if pool has enough output token
        let output_token_store = object::address_to_object<FungibleStore>(object::address_from_extend_ref(&pool.output_token));
        let pool_balance = fungible_asset::balance(output_token_store);
        assert!(pool_balance >= amount, EINSUFFICIENT_BALANCE);

        // Transfer output token from pool to admin
        let output_token_store_signer =&object::generate_signer_for_extending(&pool.output_token);
        dispatchable_fungible_asset::transfer(
            output_token_store_signer,
            output_token_store,
            primary_fungible_store::primary_store(admin_addr, pool.output_token_metadata),
            amount
        );

        event::emit(OutputTokenWithdraw{
            admin: admin_addr,
            amount
        });
    }

    // Assert if given signer is admin
    inline fun assert_admin(deployer: &signer) {
        assert!(borrow_global<Admin>(@rkgen).admin == signer::address_of(deployer), EUNAUTHORIZED);
    }

    // Assert if given amount is greater than 0
    inline fun assert_amount(amount: u64) {
        assert!(amount > 0, EINVALID_AMOUNT);
    }

    // Assert if swap pool exists
    inline fun assert_pool() {
        assert!(exists<SwapPool>(@rkgen), EPOOL_NOT_EXISTS);
    }

    // Assert if swap ratio is valid (between MIN and MAX, cannot exceed 1:1)
    inline fun assert_swap_ratio(swap_ratio: u64) {
        assert!(swap_ratio >= MIN_SWAP_RATIO && swap_ratio <= MAX_SWAP_RATIO, EINVALID_SWAP_RATIO);
    }

    #[test_only]
    use aptos_framework::account;

    #[test_only]
    public fun init_for_test() {
        init_module(&account::create_signer_for_test(@rkgen));
    }
}

