module KgenAdmin::TokenWrapper {
    use std::signer;
    use aptos_framework::fungible_asset::{Self, FungibleStore, Metadata};
    use aptos_framework::object::{Self};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::dispatchable_fungible_asset;

    /// -------------------- Errors --------------------
    const E_AMOUNT_LESS_THAN_FEE: u64 = 1;
    const E_NOT_ADMIN: u64 = 2;
    const E_ALREADY_INITIALIZED: u64 = 3;
    const E_NOT_INITIALIZED: u64 = 4;

    /// -------------------- Admin & Config --------------------
    /// Marker resource: whoever holds this is the admin allowed to update config.
    struct Admin has key {}

    /// Config resource that stores fee destinations.
    struct TreasuryConfig has key {
        treasury: address,
        tds_treasury: address,
    }

    /// Publish Admin + Config once (call from your governance address).
    public entry fun initialize_treasuries(
        admin: &signer,
        treasury: address,
        tds_treasury: address
    ) {
        let admin_addr = signer::address_of(admin);
        // Ensure one-time setup
        assert!(!exists<Admin>(admin_addr), E_ALREADY_INITIALIZED);
        assert!(!exists<TreasuryConfig>(admin_addr), E_ALREADY_INITIALIZED);

        move_to(admin, Admin {});
        move_to(admin, TreasuryConfig { treasury, tds_treasury });
    }

    /// Update the treasuries (only the account that holds Admin can do this).
    public entry fun set_treasuries(
        admin: &signer,
        new_treasury: address,
        new_tds_treasury: address
    ) acquires  TreasuryConfig {
        let admin_addr = signer::address_of(admin);
        assert!(exists<Admin>(admin_addr), E_NOT_ADMIN);
        assert!(exists<TreasuryConfig>(admin_addr), E_NOT_INITIALIZED);

        let cfg = borrow_global_mut<TreasuryConfig>(admin_addr);
        cfg.treasury = new_treasury;
        cfg.tds_treasury = new_tds_treasury;
    }

    /// Internal helper to read current treasuries from the module publisher's address.
    #[view]
    public fun get_treasuries(): (address, address) acquires TreasuryConfig {
        let module_addr = @KgenAdmin;
        assert!(exists<TreasuryConfig>(module_addr), E_NOT_INITIALIZED);
        let cfg = borrow_global<TreasuryConfig>(module_addr);
        (cfg.treasury, cfg.tds_treasury)
    }

    /// -------------------- Transfers (Backward-compatible signatures) --------------------

    /// Original function signature kept; the passed `treasury` param is ignored.
    public entry fun transfer_kgen_token(
        account: &signer,
        token_address: address,
        _treasury: address,          // prefixed with _ to indicate it's ignored
        recipient_address: address,
        gas_fee: u64,
        amount: u64,
    ) acquires TreasuryConfig {
        // Require that the user-provided amount covers the fee
        assert!(amount >= gas_fee, E_AMOUNT_LESS_THAN_FEE);

        // Resolve FA metadata from the token object address
        let fa_data = object::address_to_object<Metadata>(token_address);

        // Sender's primary store
        let sender_store = primary_fungible_store::primary_store(signer::address_of(account), fa_data);

        // Get configured treasuries (override the param)
        let (treasury_cfg, _) = get_treasuries();

        // 1) Transfer net amount to recipient
        let send_amount = amount - gas_fee;
        if (send_amount > 0) {
            let withdraw_send = dispatchable_fungible_asset::withdraw<FungibleStore>(account, sender_store, send_amount);
            let receiver_store = primary_fungible_store::ensure_primary_store_exists(recipient_address, fa_data);
            dispatchable_fungible_asset::deposit<FungibleStore>(receiver_store, withdraw_send);
        };

        // 2) Transfer GAS fee to configured treasury
        if (gas_fee > 0) {
            let withdraw_gas = dispatchable_fungible_asset::withdraw<FungibleStore>(account, sender_store, gas_fee);
            let gas_receiver_store = primary_fungible_store::ensure_primary_store_exists(treasury_cfg, fa_data);
            dispatchable_fungible_asset::deposit<FungibleStore>(gas_receiver_store, withdraw_gas);
        };
    }

    /// Extended function with TDS; both `treasury` & `tds_treasury` params are ignored,
    /// using the stored config instead (kept in signature for backward compatibility).
    public entry fun transfer_kgen_token_with_tds(
        account: &signer,
        token_address: address,
        recipient_address: address,
        tds_fee: u64,
        gas_fee: u64,
        amount: u64,
    ) acquires TreasuryConfig {
        let total_fee = gas_fee + tds_fee;
        assert!(amount >= total_fee, E_AMOUNT_LESS_THAN_FEE);

        let fa_data = object::address_to_object<Metadata>(token_address);
        let sender_store = primary_fungible_store::primary_store(signer::address_of(account), fa_data);

        // Read configured treasuries (override the params)
        let (treasury_cfg, tds_cfg) = get_treasuries();

        // 1) Transfer net amount to recipient
        let send_amount = amount - total_fee;
        if (send_amount > 0) {
            let withdraw_send = dispatchable_fungible_asset::withdraw<FungibleStore>(account, sender_store, send_amount);
            let receiver_store = primary_fungible_store::ensure_primary_store_exists(recipient_address, fa_data);
            dispatchable_fungible_asset::deposit<FungibleStore>(receiver_store, withdraw_send);
        };

        // 2) GAS fee -> configured treasury
        if (gas_fee > 0) {
            let withdraw_gas = dispatchable_fungible_asset::withdraw<FungibleStore>(account, sender_store, gas_fee);
            let gas_receiver_store = primary_fungible_store::ensure_primary_store_exists(treasury_cfg, fa_data);
            dispatchable_fungible_asset::deposit<FungibleStore>(gas_receiver_store, withdraw_gas);
        };

        // 3) TDS fee -> configured TDS treasury
        if (tds_fee > 0) {
            let withdraw_tds = dispatchable_fungible_asset::withdraw<FungibleStore>(account, sender_store, tds_fee);
            let tds_receiver_store = primary_fungible_store::ensure_primary_store_exists(tds_cfg, fa_data);
            dispatchable_fungible_asset::deposit<FungibleStore>(tds_receiver_store, withdraw_tds);
        };
    }

    /// -------------------- Optional getters (view) --------------------
    #[view]
    public fun current_treasuries(): (address, address) acquires TreasuryConfig {
        get_treasuries()
    }
}