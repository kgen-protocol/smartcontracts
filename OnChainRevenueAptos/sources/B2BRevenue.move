module b2b::settlement_v1 {
    use std::string::{Self, String};
    use std::bcs;
    use std::vector;
    use std::signer;
    use aptos_framework::fungible_asset::{Metadata};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_std::smart_table::{Self, SmartTable};

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

    /// ================================
    /// EVENTS 
    /// ================================
    #[event]
    struct PartnerCreated has drop, store { dp_id: u64, resource_account: address, initial_balance: u64 }

    #[event]
    struct BankCreated has drop, store { bank_id: String, resource_account: address, initial_balance: u64 }

    #[event]
    struct SettlementExecuted has drop, store { order_id: String, dp_id: u64, amount: u64, bank_id: String, asset: address, timestamp: u64 }

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
        partners: SmartTable<u64, PartnerInfo>,
        bank_accounts: SmartTable<String, BankAccountInfo>,
        processed_orders: SmartTable<String, bool>,

        dp_ids: vector<u64>,
        bank_ids: vector<String>,
    }

    /// ================================
    /// INITIALIZATION
    /// ================================
    fun init_module(deployer: &signer) {
        let deployer_addr = signer::address_of(deployer);
        if (exists<Registry>(deployer_addr)) return;

        move_to(deployer, Registry {
            super_admin: deployer_addr,
            pending_super_admin: @0x0,
            admin: deployer_addr,
            revenue_vault: @RevenueContractV2, // Revenue goes to RevenueContractV2
            partners: smart_table::new(),
            bank_accounts: smart_table::new(),
            processed_orders: smart_table::new(),
            dp_ids: vector::empty(),
            bank_ids: vector::empty()
        });
    }

    /// Set revenue vault address (can be called after deployment)
    public entry fun set_revenue_vault(admin: &signer, revenue_vault: address) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b);
        let caller_addr = signer::address_of(admin);
        assert!(caller_addr == registry.super_admin, E_NOT_SUPER_ADMIN);
        registry.revenue_vault = revenue_vault;
    }

    /// ================================
    /// GOVERNANCE & ADMIN METHODS
    /// ================================
    public entry fun update_admin(caller: &signer, new_admin: address) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b);
        let caller_addr = signer::address_of(caller);
        assert!(caller_addr == registry.super_admin || caller_addr == registry.admin, E_NOT_ADMIN);
        registry.admin = new_admin;
    }

    public entry fun transfer_super_admin(super_admin: &signer, new_super_admin: address) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b);
        let caller_addr = signer::address_of(super_admin);
        assert!(caller_addr == registry.super_admin, E_NOT_SUPER_ADMIN);
        registry.pending_super_admin = new_super_admin;
        event::emit(SuperAdminNominated { old_super: caller_addr, pending_super: new_super_admin });
    }

    public entry fun accept_super_admin(new_admin: &signer) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b);
        let caller_addr = signer::address_of(new_admin);
        assert!(caller_addr == registry.pending_super_admin, E_NOT_PENDING_ADMIN);
        registry.super_admin = caller_addr;
        registry.pending_super_admin = @0x0;
        event::emit(SuperAdminAccepted { new_super: caller_addr });
    }
    /// ================================
    /// FREEZE / UNFREEZE
    /// ================================
    public entry fun set_partner_status(
        admin: &signer,
        dp_id: u64,
        active: bool
    ) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b);
        assert!(signer::address_of(admin) == registry.admin, E_NOT_ADMIN);

        let partner = smart_table::borrow_mut(&mut registry.partners, dp_id);
        partner.is_active = active;
    }

    public entry fun set_bank_status(
        admin: &signer,
        bank_id: String,
        active: bool
    ) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b);
        assert!(signer::address_of(admin) == registry.admin, E_NOT_ADMIN);

        let bank = smart_table::borrow_mut(&mut registry.bank_accounts, bank_id);
        bank.is_active = active;
    }

    /// ================================
    /// BANK WITHDRAWAL (Super Admin Only)
    /// ================================
    public entry fun withdraw_from_bank(
        super_admin: &signer,
        bank_id: String,
        asset: Object<Metadata>,
        amount: u64,
        recipient: address
    ) acquires Registry {
        let registry = borrow_global<Registry>(@b2b);
        assert!(signer::address_of(super_admin) == registry.super_admin, E_NOT_SUPER_ADMIN);

         assert!(amount > 0, E_INVALID_AMOUNT);

        let bank = smart_table::borrow(&registry.bank_accounts, bank_id);
        assert!(bank.is_active, E_INACTIVE);

        let bank_signer = object::generate_signer_for_extending(&bank.extend_ref);

        let fa = primary_fungible_store::withdraw(&bank_signer, asset, amount);
        primary_fungible_store::deposit(recipient, fa);

        event::emit(BankWithdrawal { bank_id, recipient, amount, asset: object::object_address(&asset) });
    }

    /// ================================
    /// REGISTRATION WITH INITIAL BALANCE
    /// ================================
    public entry fun create_partner(
        admin: &signer,
        dp_id: u64,
        asset: Object<Metadata>,
        initial_balance: u64
    ) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b);
        assert!(signer::address_of(admin) == registry.admin, E_NOT_ADMIN);

        assert!(
            !smart_table::contains(&registry.partners, dp_id),
            E_ALREADY_EXISTS
        );

        let constructor_ref = object::create_named_object(admin, bcs::to_bytes(&dp_id));
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let partner_addr = signer::address_of(&object::generate_signer(&constructor_ref));

        if (initial_balance > 0) {
            let fa = primary_fungible_store::withdraw(admin, asset, initial_balance);
            primary_fungible_store::deposit(partner_addr, fa);
        };

        smart_table::add(&mut registry.partners, dp_id, PartnerInfo { resource_account: partner_addr, extend_ref, is_active: true });
        vector::push_back(&mut registry.dp_ids, dp_id);

        event::emit(PartnerCreated { dp_id, resource_account: partner_addr, initial_balance });
    }

    public entry fun create_bank(
        admin: &signer,
        bank_id: String,
        asset: Object<Metadata>,
        initial_balance: u64
    ) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b);
        assert!(signer::address_of(admin) == registry.admin, E_NOT_ADMIN);

        assert!(
            !smart_table::contains(&registry.bank_accounts, bank_id),
            E_ALREADY_EXISTS
        );

        let constructor_ref = object::create_named_object(admin, *string::bytes(&bank_id));
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let bank_addr = signer::address_of(&object::generate_signer(&constructor_ref));

        if (initial_balance > 0) {
            let fa = primary_fungible_store::withdraw(admin, asset, initial_balance);
            primary_fungible_store::deposit(bank_addr, fa);
        };

        // FIX: Removed .clone() and used copy for the first usage
        smart_table::add(&mut registry.bank_accounts, copy bank_id, BankAccountInfo { resource_account: bank_addr, extend_ref, is_active: true });
        vector::push_back(&mut registry.bank_ids, bank_id);

        event::emit(BankCreated { bank_id: copy bank_id, resource_account: bank_addr, initial_balance });
    }

    /// ================================
    /// SINGLE-ORDER SETTLEMENT
    /// ================================
    public entry fun execute_single_settlement(
        admin: &signer,
        asset: Object<Metadata>,
        order_id: String,
        dp_id: u64,
        amount: u64,
        bank_id: String
    ) acquires Registry {
        let registry = borrow_global_mut<Registry>(@b2b);
        assert!(signer::address_of(admin) == registry.admin, E_NOT_ADMIN);
        assert!(amount > 0, E_INVALID_AMOUNT);

        assert!(
            !smart_table::contains(&registry.processed_orders, order_id),
            E_ORDER_ALREADY_PROCESSED
        );

        let bank = smart_table::borrow(&registry.bank_accounts, bank_id);
        assert!(bank.is_active, E_INACTIVE);

        let partner = smart_table::borrow(&registry.partners, dp_id);
        assert!(partner.is_active, E_INACTIVE);

        smart_table::add(&mut registry.processed_orders, copy order_id, true);

        let bank_signer = object::generate_signer_for_extending(&bank.extend_ref);
        let partner_signer = object::generate_signer_for_extending(&partner.extend_ref);

        // Step 1: Treasury -> Partner
        let fa = primary_fungible_store::withdraw(&bank_signer, asset, amount);
        primary_fungible_store::deposit(partner.resource_account, fa);

        // Step 2: Partner -> Revenue Vault
        let fa_rev = primary_fungible_store::withdraw(&partner_signer, asset, amount);
        primary_fungible_store::deposit(registry.revenue_vault, fa_rev);

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
    /// VIEW METHODS
    /// ================================
    #[view]
    public fun get_registry_info(): (address, address, address) acquires Registry {
        let reg = borrow_global<Registry>(@b2b);
        (reg.super_admin, reg.admin, reg.revenue_vault)
    }

    #[view]
    public fun list_all_partners(): vector<u64> acquires Registry { borrow_global<Registry>(@b2b).dp_ids }

    #[view]
    public fun list_all_banks(): vector<String> acquires Registry { borrow_global<Registry>(@b2b).bank_ids }
}