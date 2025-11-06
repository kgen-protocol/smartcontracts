module b2b_contract::order_management_v1 {
    use std::string::{Self, String};
    use aptos_framework::fungible_asset::{Self, FungibleStore, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::timestamp;
    use aptos_framework::event;
    use aptos_std::smart_table::{Self, SmartTable};
    use std::signer;
    use aptos_framework::account;

    /// Resource account address for storing all contract data
    const RESOURCE_ACCOUNT: address = @b2b_contract;

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_INVALID_ORDER_ID: u64 = 2;
    const E_INVALID_PRODUCT_ID: u64 = 3;
    const E_INVALID_UTR: u64 = 4;
    const E_INVALID_QUANTITY: u64 = 5;
    const E_INVALID_AMOUNT: u64 = 6;
    const E_ORDER_ALREADY_EXISTS: u64 = 7;
    const E_INSUFFICIENT_BALANCE: u64 = 8;
    const E_INVALID_ADDRESS: u64 = 9;
    const E_NOT_INITIALIZED: u64 = 10;
    const E_ALREADY_INITIALIZED: u64 = 11;

    // ---- added error codes for withdrawal role / whitelist ----
    const E_RECIPIENT_NOT_WHITELISTED: u64 = 12;

    /// Order structure - mapped by order_id (String)
    struct Order has store, drop, copy {
        order_id: String,
        dp_id: String,
        product_id: String,
        purchase_utr: String,
        purchase_date: String,
        quantity: u64,
        order_value: u64,
        timestamp: u64,
        customer: address,
    }

    /// Event for order placement
    #[event]
    struct OrderPlacedEvent has store, drop, copy {
        order_id: String,
        dp_id: String,
        product_id: String,
        utr: String,
        quantity: u64,
        amount: u64,
        timestamp: u64,
        customer: address,
    }

    /// Event for withdrawals
    #[event]
    struct WithdrawalEvent has store, drop, copy {
        recipient: address,
        amount: u64,
        timestamp: u64,
        admin: address,
    }

    /// Event for admin changes
    #[event]
    struct AdminUpdatedEvent has store, drop, copy {
        admin_address: address,
        is_admin: bool,
        timestamp: u64,
        updated_by: address,
    }

    /// Event holder for storing event handles
    struct B2bRevenueEventHolder has key {
        order_placed: event::EventHandle<OrderPlacedEvent>,
    }

    /// Wrapper struct to hold SmartTable for orders - now using String keys
    struct OrderRegistry has key {
        orders: SmartTable<String, Order>,
        total_orders: u64,
    }

    /// Main contract storage - stored at resource account address
    struct OrderStore has key {
        admins: SmartTable<address, bool>,
        // ---- added: withdrawal role addresses ----
        withdrawers: SmartTable<address, bool>,
        // ---- added: whitelist of allowed recipient addresses for withdrawal role ----
        whitelist: SmartTable<address, bool>,
        token_store: Object<FungibleStore>,
        token_metadata: Object<Metadata>,
    }

    /// Initialize contract at resource account address
    public entry fun initialize(
        account: &signer,
        metadata: Object<Metadata>
    ) {
        let account_addr = signer::address_of(account);
        assert!(account_addr == RESOURCE_ACCOUNT, E_NOT_AUTHORIZED);
        assert!(!exists<OrderStore>(RESOURCE_ACCOUNT), E_ALREADY_INITIALIZED);

        let constructor_ref = &object::create_object(account_addr);
        let token_store = fungible_asset::create_store(constructor_ref, metadata);

        let admins = smart_table::new<address, bool>();
        smart_table::add(&mut admins, account_addr, true);

        // ---- added: init withdrawers + whitelist tables ----
        let withdrawers = smart_table::new<address, bool>();
        let whitelist = smart_table::new<address, bool>();

        // Create event holder
        move_to(account, B2bRevenueEventHolder {
            order_placed: account::new_event_handle<OrderPlacedEvent>(account),
        });

        // Create SmartTable with String keys for orders
        let orders_map = smart_table::new<String, Order>();
        
        move_to(account, OrderRegistry {
            orders: orders_map,
            total_orders: 0,
        });

        move_to(account, OrderStore {
            admins,
            withdrawers,
            whitelist,
            token_store,
            token_metadata: metadata,
        });
    }

    /// Deposit order - using order_id (String) as the key
    public entry fun deposit_order(
        customer: &signer,
        order_id: String,
        dp_id: String,
        product_id: String,
        purchase_utr: String,
        purchase_date: String,
        quantity: u64,
        amount: u64,
    ) acquires OrderStore, OrderRegistry, B2bRevenueEventHolder {
        assert!(exists<OrderStore>(RESOURCE_ACCOUNT), E_NOT_INITIALIZED);
        assert!(string::length(&order_id) > 0, E_INVALID_ORDER_ID);
        assert!(string::length(&dp_id) > 0, E_INVALID_ORDER_ID);
        assert!(string::length(&product_id) > 0, E_INVALID_PRODUCT_ID);
        assert!(string::length(&purchase_utr) > 0, E_INVALID_UTR);
        assert!(quantity > 0, E_INVALID_QUANTITY);
        assert!(amount > 0, E_INVALID_AMOUNT);

        let store = borrow_global_mut<OrderStore>(RESOURCE_ACCOUNT);
        let registry = borrow_global_mut<OrderRegistry>(RESOURCE_ACCOUNT);
        
        // Check if order_id already exists
        assert!(!smart_table::contains(&registry.orders, order_id), E_ORDER_ALREADY_EXISTS);

        let customer_addr = signer::address_of(customer);
        let customer_store = primary_fungible_store::primary_store(customer_addr, store.token_metadata);
        
        // Transfer tokens using dispatchable_fungible_asset for tokens with hooks
        dispatchable_fungible_asset::transfer(
            customer,
            customer_store,
            store.token_store,
            amount
        );

        let current_time = timestamp::now_seconds();

        // Store order in SmartTable using order_id (String) as key
        smart_table::add(&mut registry.orders, order_id, Order {
            order_id,
            dp_id,
            product_id,
            purchase_utr,
            purchase_date,
            quantity,
            order_value: amount,
            timestamp: current_time,
            customer: customer_addr,
        });

        registry.total_orders = registry.total_orders + 1;

        // Get event holder and emit event
        let b2b_revenue_event_holder = borrow_global_mut<B2bRevenueEventHolder>(RESOURCE_ACCOUNT);
        
        event::emit_event<OrderPlacedEvent>(
            &mut b2b_revenue_event_holder.order_placed,
            OrderPlacedEvent {
                order_id,
                dp_id,
                product_id,
                utr: purchase_utr,
                quantity,
                amount,
                timestamp: current_time,
                customer: customer_addr,
            }
        );
    }

    /// Withdraw tokens - admin OR withdrawal role
    /// - Admins: can withdraw to any non-zero address
    /// - Withdrawal role: can withdraw only to whitelisted recipient addresses
    public entry fun withdraw_tokens(
        admin: &signer,
        recipient: address,
        amount: u64,
    ) acquires OrderStore {
        assert!(exists<OrderStore>(RESOURCE_ACCOUNT), E_NOT_INITIALIZED);
        assert!(recipient != @0x0, E_INVALID_ADDRESS);
        assert!(amount > 0, E_INVALID_AMOUNT);

        let store = borrow_global_mut<OrderStore>(RESOURCE_ACCOUNT);
        let caller = signer::address_of(admin);

        let is_admin =
            smart_table::contains(&store.admins, caller) &&
            *smart_table::borrow(&store.admins, caller);

        let is_withdrawer =
            smart_table::contains(&store.withdrawers, caller) &&
            *smart_table::borrow(&store.withdrawers, caller);

        // at least one role required
        assert!(is_admin || is_withdrawer, E_NOT_AUTHORIZED);

        if (!is_admin) {
            // withdrawal-role path must use whitelisted recipient
            assert!(
                smart_table::contains(&store.whitelist, recipient) &&
                *smart_table::borrow(&store.whitelist, recipient),
                E_RECIPIENT_NOT_WHITELISTED
            );
        };

        assert!(fungible_asset::balance(store.token_store) >= amount, E_INSUFFICIENT_BALANCE);

        // Get or create recipient store
        let recipient_store = primary_fungible_store::ensure_primary_store_exists(
            recipient, 
            store.token_metadata
        );

        // Transfer tokens using dispatchable_fungible_asset for tokens with hooks
        dispatchable_fungible_asset::transfer(
            admin,
            store.token_store,
            recipient_store,
            amount
        );

        // Emit event
        event::emit(WithdrawalEvent {
            recipient,
            amount,
            timestamp: timestamp::now_seconds(),
            admin: caller,
        });
    }

    /// Set admin status
    public entry fun set_admin(
        admin: &signer,
        new_admin: address,
        is_admin: bool,
    ) acquires OrderStore {
        assert!(exists<OrderStore>(RESOURCE_ACCOUNT), E_NOT_INITIALIZED);
        assert!(new_admin != @0x0, E_INVALID_ADDRESS);

        let store = borrow_global_mut<OrderStore>(RESOURCE_ACCOUNT);
        let admin_addr = signer::address_of(admin);
        
        assert!(
            smart_table::contains(&store.admins, admin_addr) && 
            *smart_table::borrow(&store.admins, admin_addr),
            E_NOT_AUTHORIZED
        );

        if (smart_table::contains(&store.admins, new_admin)) {
            smart_table::upsert(&mut store.admins, new_admin, is_admin);
        } else {
            smart_table::add(&mut store.admins, new_admin, is_admin);
        };

        // Emit event
        event::emit(AdminUpdatedEvent {
            admin_address: new_admin,
            is_admin,
            timestamp: timestamp::now_seconds(),
            updated_by: admin_addr,
        });
    }

    // ---- added: manage withdrawal role (admin only) ----
    public entry fun set_withdrawer(
        admin: &signer,
        addr: address,
        is_withdrawer: bool,
    ) acquires OrderStore {
        assert!(exists<OrderStore>(RESOURCE_ACCOUNT), E_NOT_INITIALIZED);
        assert!(addr != @0x0, E_INVALID_ADDRESS);

        let store = borrow_global_mut<OrderStore>(RESOURCE_ACCOUNT);
        let admin_addr = signer::address_of(admin);

        assert!(
            smart_table::contains(&store.admins, admin_addr) &&
            *smart_table::borrow(&store.admins, admin_addr),
            E_NOT_AUTHORIZED
        );

        if (smart_table::contains(&store.withdrawers, addr)) {
            smart_table::upsert(&mut store.withdrawers, addr, is_withdrawer);
        } else {
            smart_table::add(&mut store.withdrawers, addr, is_withdrawer);
        };
    }

    // ---- added: manage whitelist for withdrawal role (admin only) ----
    public entry fun set_whitelisted(
        admin: &signer,
        addr: address,
        is_whitelisted: bool,
    ) acquires OrderStore {
        assert!(exists<OrderStore>(RESOURCE_ACCOUNT), E_NOT_INITIALIZED);
        assert!(addr != @0x0, E_INVALID_ADDRESS);

        let store = borrow_global_mut<OrderStore>(RESOURCE_ACCOUNT);
        let admin_addr = signer::address_of(admin);

        assert!(
            smart_table::contains(&store.admins, admin_addr) &&
            *smart_table::borrow(&store.admins, admin_addr),
            E_NOT_AUTHORIZED
        );

        if (smart_table::contains(&store.whitelist, addr)) {
            smart_table::upsert(&mut store.whitelist, addr, is_whitelisted);
        } else {
            smart_table::add(&mut store.whitelist, addr, is_whitelisted);
        };
    }

    // ========== View Functions ==========

    #[view]
    public fun get_order(order_id: String): (String, String, String, String, u64, u64, u64, address) acquires OrderRegistry {
        assert!(exists<OrderRegistry>(RESOURCE_ACCOUNT), E_NOT_INITIALIZED);
        let registry = borrow_global<OrderRegistry>(RESOURCE_ACCOUNT);
        assert!(smart_table::contains(&registry.orders, order_id), E_INVALID_ORDER_ID);
        
        let order = smart_table::borrow(&registry.orders, order_id);
        (
            order.dp_id,
            order.product_id,
            order.purchase_utr,
            order.purchase_date,
            order.quantity,
            order.order_value,
            order.timestamp,
            order.customer,
        )
    }

    #[view]
    public fun get_order_full(order_id: String): (String, String, String, String, String, u64, u64, u64, address) acquires OrderRegistry {
        assert!(exists<OrderRegistry>(RESOURCE_ACCOUNT), E_NOT_INITIALIZED);
        let registry = borrow_global<OrderRegistry>(RESOURCE_ACCOUNT);
        assert!(smart_table::contains(&registry.orders, order_id), E_INVALID_ORDER_ID);
        
        let order = smart_table::borrow(&registry.orders, order_id);
        (
            order.order_id,
            order.dp_id,
            order.product_id,
            order.purchase_utr,
            order.purchase_date,
            order.quantity,
            order.order_value,
            order.timestamp,
            order.customer,
        )
    }

    #[view]
    public fun get_balance(): u64 acquires OrderStore {
        assert!(exists<OrderStore>(RESOURCE_ACCOUNT), E_NOT_INITIALIZED);
        let store = borrow_global<OrderStore>(RESOURCE_ACCOUNT);
        fungible_asset::balance(store.token_store)
    }

    #[view]
    public fun is_admin(user: address): bool acquires OrderStore {
        if (!exists<OrderStore>(RESOURCE_ACCOUNT)) return false;
        let store = borrow_global<OrderStore>(RESOURCE_ACCOUNT);
        smart_table::contains(&store.admins, user) && 
        *smart_table::borrow(&store.admins, user)
    }

    // ---- added: view helpers (optional) ----
    #[view]
    public fun is_withdrawer(user: address): bool acquires OrderStore {
        if (!exists<OrderStore>(RESOURCE_ACCOUNT)) return false;
        let store = borrow_global<OrderStore>(RESOURCE_ACCOUNT);
        smart_table::contains(&store.withdrawers, user) &&
        *smart_table::borrow(&store.withdrawers, user)
    }

    #[view]
    public fun is_whitelisted(addr: address): bool acquires OrderStore {
        if (!exists<OrderStore>(RESOURCE_ACCOUNT)) return false;
        let store = borrow_global<OrderStore>(RESOURCE_ACCOUNT);
        smart_table::contains(&store.whitelist, addr) &&
        *smart_table::borrow(&store.whitelist, addr)
    }

    #[view]
    public fun order_exists(order_id: String): bool acquires OrderRegistry {
        if (!exists<OrderRegistry>(RESOURCE_ACCOUNT)) return false;
        let registry = borrow_global<OrderRegistry>(RESOURCE_ACCOUNT);
        smart_table::contains(&registry.orders, order_id)
    }

    #[view]
    public fun get_token_metadata(): Object<Metadata> acquires OrderStore {
        assert!(exists<OrderStore>(RESOURCE_ACCOUNT), E_NOT_INITIALIZED);
        let store = borrow_global<OrderStore>(RESOURCE_ACCOUNT);
        store.token_metadata
    }

    #[view]
    public fun get_total_orders(): u64 acquires OrderRegistry {
        assert!(exists<OrderRegistry>(RESOURCE_ACCOUNT), E_NOT_INITIALIZED);
        let registry = borrow_global<OrderRegistry>(RESOURCE_ACCOUNT);
        registry.total_orders
    }
}
