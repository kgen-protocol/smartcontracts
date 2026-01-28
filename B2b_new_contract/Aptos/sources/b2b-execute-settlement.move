module b2b_execute_settlement::settlement_v1 {
    use std::string::{String};
    use std::vector;
    use std::signer;
    use aptos_framework::fungible_asset::{Metadata};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_std::smart_table::{Self, SmartTable};

    // External contract dependency
    use b2b_contract::order_management_v1;

    /// ================================
    /// ERRORS
    /// ================================
    const E_NOT_ADMIN: u64 = 1;
    const E_ALREADY_EXISTS: u64 = 2;
    const E_INACTIVE: u64 = 4;
    const E_INVALID_AMOUNT: u64 = 5;
    const E_NOT_SUPER_ADMIN: u64 = 7;
    const E_NOT_PENDING_ADMIN: u64 = 8;
    const E_ORDER_ALREADY_PROCESSED: u64 = 9;
    const E_WITHDRAWAL_EXECUTED: u64 = 10;
    const E_ALREADY_INITIALIZED: u64 = 11;
    const E_NOT_FOUND: u64 = 12;
    const E_INVALID_BANK: u64 = 13;
    const E_INVALID_PARTNER: u64 = 14;
    const E_INSUFFICIENT_BANK_BALANCE: u64 = 15;
    const E_CIRCULAR_ALIAS: u64 = 16;
    const E_INVALID_ORDER_ID: u64 = 17;
    const E_INVALID_PRODUCT_ID: u64 = 18;
    const E_INVALID_UTR: u64 = 19;
    const E_INVALID_QUANTITY: u64 = 20;
    const E_INVALID_ADDRESS: u64 = 21;
    const E_INVALID_DP_ID: u64 = 22;


    #[event]
    struct PartnerCreated has drop, store { dp_id: String, resource_account: address }

    #[event]
    struct BankCreated has drop, store { bank_id: String, resource_account: address }

    #[event]
    struct SettlementExecuted has drop, store { order_id: String, dp_id: String, amount: u64, bank_id: String, asset: address, timestamp: u64 }

    #[event]
    struct SuperAdminNominated has drop, store { old_super: address, pending_super: address }

    #[event]
    struct SuperAdminAccepted has drop, store { new_super: address }

    #[event]
    struct BankWithdrawal has drop, store { bank_id: String, recipient: address, amount: u64, asset: address }

    /// ================================
    /// DATA STRUCTURES
    /// ================================
    struct PartnerInfo has store {
        resource_account: address,
        extend_ref: ExtendRef,
        is_active: bool,
    }

    struct BankAccountInfo has store {
        resource_account: address,
        extend_ref: ExtendRef,
        is_active: bool,
    }

    struct Registry has key {
        super_admin: address,
        pending_super_admin: address,
        admin: address,
        revenue_vault: address,
        partners: SmartTable<String, PartnerInfo>,
        bank_accounts: SmartTable<String, BankAccountInfo>,
        alias_to_master_partner: SmartTable<String, String>,
        tracked_assets: vector<address>,
        dp_ids: vector<String>,
        bank_ids: vector<String>,
    }

    /// ================================
    /// VIEW STRUCTS
    /// ================================
    struct AssetBalance has copy, drop, store {
        asset_metadata: address,
        balance: u64
    }

    struct BankSummary has copy, drop, store {
        bank_id: String,
        resource_account: address,
        is_active: bool
    }

    struct BankReport has copy, drop, store {
        bank_id: String,
        resource_account: address,
        is_active: bool,
        balances: vector<AssetBalance>
    }

    struct PartnerSummary has copy, drop, store {
        dp_id: String,
        resource_account: address,
        is_active: bool,
        alias_names: vector<String>
    }

    struct PartnerReport has copy, drop, store {
        dp_id: String,
        resource_account: address,
        is_active: bool,
        balances: vector<AssetBalance>
    }

    /// ================================
    /// INITIALIZATION
    /// ================================
    fun init_module(deployer: &signer) {
        let deployer_addr = signer::address_of(deployer);
        assert!(!exists<Registry>(deployer_addr), E_ALREADY_INITIALIZED);

        move_to(deployer, Registry {
            super_admin: deployer_addr,
            pending_super_admin: @0x0,
            admin: deployer_addr,
            revenue_vault: @b2b_contract,
            partners: smart_table::new(),
            alias_to_master_partner: smart_table::new(),
            bank_accounts: smart_table::new(),
            tracked_assets: vector::empty(),
            dp_ids: vector::empty(),
            bank_ids: vector::empty(),
        });
    }

    #[test_only]
    public fun init_for_test(deployer: &signer) {
        init_module(deployer);
    }

    /// ================================
    /// GOVERNANCE & ADMIN METHODS
    /// ================================
    public entry fun set_revenue_vault(admin: &signer, revenue_vault: address) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b_execute_settlement);
        let caller_addr = signer::address_of(admin);
        assert!(caller_addr == registry.super_admin, E_NOT_SUPER_ADMIN);
        registry.revenue_vault = revenue_vault;
    }

    /// ================================
    /// GOVERNANCE & ADMIN METHODS
    /// ================================
    public entry fun update_admin(caller: &signer, new_admin: address) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b_execute_settlement);
        let caller_addr = signer::address_of(caller);
        assert!(caller_addr == registry.super_admin, E_NOT_SUPER_ADMIN);
        registry.admin = new_admin;
    }

    public entry fun transfer_super_admin(super_admin: &signer, new_super_admin: address) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b_execute_settlement);
        let caller_addr = signer::address_of(super_admin);
        assert!(caller_addr == registry.super_admin, E_NOT_SUPER_ADMIN);
        registry.pending_super_admin = new_super_admin;
        event::emit(SuperAdminNominated { old_super: caller_addr, pending_super: new_super_admin });
    }

    public entry fun accept_super_admin(new_admin: &signer) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b_execute_settlement);
        let caller_addr = signer::address_of(new_admin);
        assert!(caller_addr == registry.pending_super_admin, E_NOT_PENDING_ADMIN);
        registry.super_admin = caller_addr;
        registry.pending_super_admin = @0x0;
        event::emit(SuperAdminAccepted { new_super: caller_addr });
    }

    public entry fun set_partner_status(admin: &signer, dp_id: String, active: bool) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b_execute_settlement);
        assert!(signer::address_of(admin) == registry.super_admin, E_NOT_SUPER_ADMIN);
        let partner = registry.partners.borrow_mut(dp_id);
        partner.is_active = active;
    }

    public entry fun set_bank_status(admin: &signer, bank_id: String, active: bool) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b_execute_settlement);
        assert!(signer::address_of(admin) == registry.super_admin, E_NOT_SUPER_ADMIN);
        let bank = registry.bank_accounts.borrow_mut(bank_id);
        bank.is_active = active;
    }

    public entry fun fund_bank(
        wallet: &signer,
        bank_id: String,
        asset: Object<Metadata>,
        amount: u64
    ) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b_execute_settlement);
        assert!(amount > 0, E_INVALID_AMOUNT);
        let bank = registry.bank_accounts.borrow(bank_id);
        assert!(bank.is_active, E_INACTIVE);
        let fa = primary_fungible_store::withdraw(wallet, asset, amount);
        primary_fungible_store::deposit(bank.resource_account, fa);
        register_asset_internal(registry, object::object_address(&asset));
    }

    public entry fun withdraw_from_bank(
        super_admin: &signer,
        bank_id: String,
        asset: Object<Metadata>,
        amount: u64,
        recipient: address
    ) acquires Registry {
        let registry = borrow_global<Registry>(@b2b_execute_settlement);
        assert!(signer::address_of(super_admin) == registry.super_admin, E_NOT_SUPER_ADMIN);
        assert!(amount > 0, E_INVALID_AMOUNT);
        let bank = registry.bank_accounts.borrow(bank_id);
        assert!(bank.is_active, E_INACTIVE);

        let bank_balance = primary_fungible_store::balance(bank.resource_account, asset);
        assert!(bank_balance >= amount, E_INSUFFICIENT_BANK_BALANCE);

        let bank_signer = object::generate_signer_for_extending(&bank.extend_ref);
        let fa = primary_fungible_store::withdraw(&bank_signer, asset, amount);
        primary_fungible_store::deposit(recipient, fa);
        event::emit(BankWithdrawal { bank_id, recipient, amount, asset: object::object_address(&asset) });
    }


    /// ================================
    /// REGISTRATION
    /// ================================
    public entry fun create_partner(
        admin: &signer,
        dp_id: String
    ) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b_execute_settlement);
        assert!(signer::address_of(admin) == registry.super_admin, E_NOT_SUPER_ADMIN);
        assert!(!registry.partners.contains(dp_id), E_ALREADY_EXISTS);

        // Use dp_id in seeds for object creation to ensure uniqueness per ID
        let constructor_ref = object::create_named_object(admin, *dp_id.bytes());
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let partner_signer = object::generate_signer(&constructor_ref);
        let partner_addr = signer::address_of(&partner_signer);

        registry.partners.add(dp_id, PartnerInfo { resource_account: partner_addr, extend_ref, is_active: true });
        registry.dp_ids.push_back(dp_id);
        event::emit(PartnerCreated { dp_id, resource_account: partner_addr });
    }

    public entry fun create_partner_alias(
        admin: &signer,
        existing_dp_id: String,
        new_alias_dp_id: String
    ) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b_execute_settlement);
        assert!(signer::address_of(admin) == registry.super_admin, E_NOT_SUPER_ADMIN);

        // Prevent circular references
        assert!(existing_dp_id != new_alias_dp_id, E_CIRCULAR_ALIAS);
        assert!(!registry.alias_to_master_partner.contains(existing_dp_id), E_CIRCULAR_ALIAS);
        assert!(!registry.alias_to_master_partner.contains(new_alias_dp_id), E_ALREADY_EXISTS);

        // Check for deeper circular chains
        let current_id = existing_dp_id;
        let depth = 0;
        while (registry.alias_to_master_partner.contains(current_id) && depth < 10) {
            current_id = *registry.alias_to_master_partner.borrow(current_id);
            assert!(current_id != new_alias_dp_id, E_CIRCULAR_ALIAS);
            depth = depth + 1;
        };

        // 1. Get the address from the existing partner
        let existing_partner = registry.partners.borrow(existing_dp_id);
        let _vault_addr = existing_partner.resource_account;

        // 2. Map the new alias to the Master ID
        registry.alias_to_master_partner.add(new_alias_dp_id, existing_dp_id);

        // 3. (Optional but recommended) Add to your ID list so it shows in views
        registry.dp_ids.push_back(new_alias_dp_id);
    }

    public entry fun create_bank(
        admin: &signer,
        bank_id: String
    ) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b_execute_settlement);
        assert!(signer::address_of(admin) == registry.super_admin, E_NOT_SUPER_ADMIN);
        assert!(!registry.bank_accounts.contains(bank_id), E_ALREADY_EXISTS);

        let constructor_ref = object::create_named_object(admin, *bank_id.bytes());
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let bank_signer = object::generate_signer(&constructor_ref);
        let bank_addr = signer::address_of(&bank_signer);
        registry.bank_accounts.add(
            copy bank_id,
            BankAccountInfo { resource_account: bank_addr, extend_ref, is_active: true }
        );
        registry.bank_ids.push_back(bank_id);
        event::emit(BankCreated { bank_id: copy bank_id, resource_account: bank_addr });
    }

    public entry fun execute_single_settlement(
        admin: &signer,
        asset: Object<Metadata>,
        order_id: String,
        dp_id: String,
        amount: u64,
        bank_id: String,
        product_id: String,
        purchase_utr: String,
        purchase_date: String,
        quantity: u64
    ) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b_execute_settlement);
        assert!(
            signer::address_of(admin) == registry.super_admin ||
                signer::address_of(admin) == registry.admin,
            E_NOT_ADMIN
        );
        assert!(amount > 0, E_INVALID_AMOUNT);
        assert!(order_id.length() > 0, E_INVALID_ORDER_ID);
        assert!(product_id.length() > 0, E_INVALID_PRODUCT_ID);
        assert!(purchase_utr.length() > 0, E_INVALID_UTR);
        assert!(dp_id.length() > 0, E_INVALID_DP_ID);
        assert!(quantity > 0, E_INVALID_QUANTITY);

        assert!(registry.bank_accounts.contains(bank_id), E_INVALID_BANK);
        let bank = registry.bank_accounts.borrow(bank_id);
        assert!(bank.is_active, E_INVALID_BANK);

        // Check if dp_id exists in partners table, if not check alias table
        let partner = if (registry.partners.contains(dp_id)) {
            registry.partners.borrow(dp_id)
        } else if (registry.alias_to_master_partner.contains(dp_id)) {
            let master_dp_id = registry.alias_to_master_partner.borrow(dp_id);
            registry.partners.borrow(*master_dp_id)
        } else {
            abort E_INVALID_PARTNER
        };
        assert!(partner.is_active, E_INVALID_PARTNER);

        // Check if bank has sufficient balance
        let bank_balance = primary_fungible_store::balance(bank.resource_account, asset);
        assert!(bank_balance >= amount, E_INSUFFICIENT_BANK_BALANCE);

        let bank_signer = object::generate_signer_for_extending(&bank.extend_ref);
        let partner_signer = object::generate_signer_for_extending(&partner.extend_ref);

        // 1 Bank to Partner
        let fa = primary_fungible_store::withdraw(&bank_signer, asset, amount);
        primary_fungible_store::deposit(partner.resource_account, fa);

        // 2 Partner to Revenue - Create settlement order
        let fa_rev = primary_fungible_store::withdraw(&partner_signer, asset, amount);


        order_management_v1::create_settlement_order(
            order_id,
            dp_id,
            product_id,
            purchase_utr,
            purchase_date,
            quantity,
            amount,
            partner.resource_account,
            fa_rev
        );

        event::emit(SettlementExecuted {
            order_id,
            dp_id,
            amount,
            bank_id,
            asset: object::object_address(&asset),
            timestamp: timestamp::now_seconds()
        });
    }

    /// ================================
    /// STORE ASSET ADDRESSES TO TRACK BALANCES
    /// ================================
    fun register_asset_internal(registry: &mut Registry, asset_addr: address) {
        assert!(asset_addr != @0x0, E_INVALID_ADDRESS);
        assert!(registry.tracked_assets.length() < 100, E_INVALID_AMOUNT); // Reuse error code for limit
        if (!registry.tracked_assets.contains(&asset_addr)) {
            registry.tracked_assets.push_back(asset_addr);
        };
    }

    public entry fun remove_tracked_asset(admin: &signer, asset_addr: address) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b_execute_settlement);
        assert!(signer::address_of(admin) == registry.super_admin, E_NOT_SUPER_ADMIN);

        let (found, index) = registry.tracked_assets.index_of(&asset_addr);
        assert!(found, E_NOT_FOUND);

        registry.tracked_assets.swap_remove(index);
    }

    #[view]
    public fun get_registry_info(): (address, address, address) acquires Registry {
        let reg = borrow_global<Registry>(@b2b_execute_settlement);
        (reg.super_admin, reg.admin, reg.revenue_vault)
    }

    #[view]
    public fun get_all_banks(): vector<BankSummary> acquires Registry {
        let registry = borrow_global<Registry>(@b2b_execute_settlement);
        let result = vector::empty<BankSummary>();
        let i = 0;
        while (i < registry.bank_ids.length()) {
            let id = registry.bank_ids[i];
            let info = registry.bank_accounts.borrow(id);
            result.push_back(
                BankSummary { bank_id: id, resource_account: info.resource_account, is_active: info.is_active }
            );
            i += 1;
        };
        result
    }

    #[view]
    public fun get_bank_detail(bank_id: String): BankReport acquires Registry {
        let registry = borrow_global<Registry>(@b2b_execute_settlement);
        assert!(registry.bank_accounts.contains(bank_id), E_INVALID_BANK);
        let info = registry.bank_accounts.borrow(bank_id);
        let balances = vector::empty<AssetBalance>();
        let i = 0;
        while (i < registry.tracked_assets.length()) {
            let addr = registry.tracked_assets[i];
            let bal = primary_fungible_store::balance(
                info.resource_account,
                object::address_to_object<Metadata>(addr)
            );
            balances.push_back(AssetBalance { asset_metadata: addr, balance: bal });
            i += 1;
        };
        BankReport { bank_id, resource_account: info.resource_account, is_active: info.is_active, balances }
    }


    #[view]
    public fun get_all_partners(): vector<PartnerSummary> acquires Registry {
        let registry = borrow_global<Registry>(@b2b_execute_settlement);
        let result = vector::empty<PartnerSummary>();
        let i = 0;
        while (i < registry.dp_ids.length()) {
            let id = registry.dp_ids[i];
            if (registry.partners.contains(id)) {
                let info = registry.partners.borrow(id);
                let aliases = vector::empty<String>();
                let j = 0;
                while (j < registry.dp_ids.length()) {
                    let alias_id = registry.dp_ids[j];
                    if (registry.alias_to_master_partner.contains(alias_id) &&
                        *registry.alias_to_master_partner.borrow(alias_id) == id) {
                        aliases.push_back(alias_id);
                    };
                    j += 1;
                };
                result.push_back(
                    PartnerSummary { dp_id: id, resource_account: info.resource_account, is_active: info.is_active, alias_names: aliases }
                );
            };
            i += 1;
        };
        result
    }

    #[view]
    public fun get_partner_detail(dp_id: String): PartnerReport acquires Registry {
        let registry = borrow_global<Registry>(@b2b_execute_settlement);
        
        // Check if dp_id exists in partners table, if not check alias table
        let (master_dp_id, info) = if (registry.partners.contains(dp_id)) {
            (dp_id, registry.partners.borrow(dp_id))
        } else if (registry.alias_to_master_partner.contains(dp_id)) {
            let master_id = *registry.alias_to_master_partner.borrow(dp_id);
            (master_id, registry.partners.borrow(master_id))
        } else {
            abort E_INVALID_PARTNER
        };
        
        let balances = vector::empty<AssetBalance>();
        let i = 0;
        while (i < registry.tracked_assets.length()) {
            let addr = registry.tracked_assets[i];
            let bal = primary_fungible_store::balance(
                info.resource_account,
                object::address_to_object<Metadata>(addr)
            );
            balances.push_back(AssetBalance { asset_metadata: addr, balance: bal });
            i += 1;
        };
        PartnerReport { dp_id: master_dp_id, resource_account: info.resource_account, is_active: info.is_active, balances }
    }

    // Getter functions for test access
    #[test_only]
    public fun get_asset_balance_amount(balance: &AssetBalance): u64 {
        balance.balance
    }

    #[test_only]
    public fun get_bank_report_balances(report: &BankReport): &vector<AssetBalance> {
        &report.balances
    }

    #[test_only]
    public fun get_partner_summary_is_active(summary: &PartnerSummary): bool {
        summary.is_active
    }

    #[test_only]
    public fun get_bank_summary_is_active(summary: &BankSummary): bool {
        summary.is_active
    }
}