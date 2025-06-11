module KGeN::oracle_keys {
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::{
        Self,
        MintRef,
        TransferRef,
        BurnRef,
        Metadata,
        FungibleAsset
    };
    use aptos_framework::primary_fungible_store;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::function_info;
    use std::signer;
    use std::option;
    use aptos_std::string_utils::{to_string};
    use std::error;
    use std::vector;
    use std::event;
    use std::string::{Self, String, utf8};

    // ========= Constants =========

    /// Address already exists in whitelist
    const EALREADY_EXIST: u64 = 1;
    /// Address not whitelisted
    const ENOT_WHITELIST_ADDRESS: u64 = 2;
    /// Sender not whitelisted
    const ENOT_WHITELIST_SENDER: u64 = 3;
    /// Receiver not whitelisted
    const ENOT_WHITELIST_RECEIVER: u64 = 4;
    /// Invalid sender or receiver
    const EINVALIDRECEIVERORSENDER: u64 = 8;

    // Metadata for the fungible asset
    const ASSET_SYMBOL: vector<u8> = b"KGeN Key"; // Symbol of the token
    const METADATA_NAME: vector<u8> = b"KGeN Oracle Key Token"; // Name of the token
    const ICON_URI: vector<u8> = b"https://prod-image-bucket.kgen.io/assets/rkgen-logo.png"; // Icon URI
    const PROJECT_URI: vector<u8> = b"https://kgen.io"; // Project URI

    // ========= Structs =========

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // Stores mint, transfer, and burn references for the fungible asset
    struct ManagedKeyAsset has key {
        mint_ref: MintRef, // Reference to mint tokens
        transfer_ref: TransferRef, // Reference to transfer tokens
        burn_ref: BurnRef // Reference to burn tokens
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // Stores the admin address
    struct Admin has key {
        admin: address // Address of the admin
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // Manages whitelisted sender and receiver addresses
    struct WhiteListed has key {
        sender_vec: vector<address>, // Whitelisted sender addresses
        receiver_vec: vector<address> // Whitelisted receiver addresses
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // Defines addresses allowed to mint and burn tokens
    struct MintingManager has key {
        minter: address, // Address allowed to mint tokens
        burnable: address // Address allowed to burn tokens
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // Controls a flag for enabling/disabling operations
    struct DispatcherFlag has key {
        flag: bool // Flag to enable/disable certain operations
    }

    // ========= Events =========

    #[event]
    // Emitted when tokens are minted to a whitelisted user
    struct MintedToWhitelistedUser has drop, store {
        whitelisted_user_address: address, // Address of the whitelisted user
        amount: u64 // Amount of tokens minted
    }

    #[event]
    // Emitted when tokens are transferred
    struct Transfer has drop, store {
        from: address, // Sender's address
        receiver: address, // Receiver's address
        amount: u64 // Amount transferred
    }

    #[event]
    // Emitted when a receiver address is added to the whitelist
    struct AddedReceiverAddress has drop, store {
        msg: String, // Message indicating addition
        added_address: address // Address added to receiver whitelist
    }

    #[event]
    // Emitted when a receiver address is removed from the whitelist
    struct RemovedReceiverAddress has drop, store {
        msg: String, // Message indicating removal
        removed_address: address // Address removed from receiver whitelist
    }

    #[event]
    // Emitted when a sender address is added to the whitelist
    struct AddedSenderAddress has drop, store {
        msg: String, // Message indicating addition
        added_address: address // Address added to sender whitelist
    }

    #[event]
    // Emitted when a sender address is removed from the whitelist
    struct RemovedSenderAddress has drop, store {
        msg: String, // Message indicating removal
        removed_address: address // Address removed from sender whitelist
    }

    #[event]
    // Emitted when the dispatcher flag state changes
    struct FlagStateChanged has drop, store {
        msg: String, // Message indicating flag state change
        new_state: bool // New state of the flag
    }

    #[event]
    // Emitted when Minted to Oracle Node
    struct MintedToOracleNode has drop, store {
        to: address,
        amount: u64
    }

    // ========= Initialization =========

    // Initializes the module, setting up the admin, whitelists, and fungible asset
    fun init_module(admin: &signer) {
        // Initialize the dispatcher flag to false
        move_to(admin, DispatcherFlag { flag: false });

        // Set the minter and burnable addresses to the admin
        move_to(
            admin,
            MintingManager {
                minter: signer::address_of(admin),
                burnable: signer::address_of(admin)
            }
        );

        // Store the admin's address
        move_to(
            admin,
            Admin { admin: signer::address_of(admin) }
        );

        // Initialize empty sender and receiver whitelists
        let s_vec = vector::empty<address>();
        let r_vec = vector::empty<address>();
        move_to(
            admin,
            WhiteListed { sender_vec: s_vec, receiver_vec: r_vec }
        );

        // Create the fungible asset with metadata
        let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::some(200_000_000_00000000), // Maximum supply
            utf8(METADATA_NAME),
            utf8(ASSET_SYMBOL),
            0, // Decimals
            utf8(ICON_URI),
            utf8(PROJECT_URI)
        );

        // Generate mint, burn, and transfer references
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        let metadata_object_signer = object::generate_signer(constructor_ref);

        // Store the references in ManagedKeyAsset
        move_to(
            &metadata_object_signer,
            ManagedKeyAsset { mint_ref, transfer_ref, burn_ref }
        );

        // Override deposit and withdraw functions for whitelist checks
        let deposit =
            function_info::new_function_info(
                admin,
                string::utf8(b"oracle_keys"),
                string::utf8(b"deposit")
            );
        let withdraw =
            function_info::new_function_info(
                admin,
                string::utf8(b"oracle_keys"),
                string::utf8(b"withdraw")
            );
        dispatchable_fungible_asset::register_dispatch_functions(
            constructor_ref,
            option::some(withdraw),
            option::some(deposit),
            option::none()
        );
    }

    // ========= Dispatchable Hooks =========

    // Deposits fungible assets into a store (no additional checks)
    public fun deposit<T: key>(
        store: Object<T>, fa: FungibleAsset, _transfer_ref: &TransferRef
    ) {
        fungible_asset::deposit(store, fa);
    }

    // Withdraws fungible assets with a sender whitelist check
    public fun withdraw<T: key>(
        store: Object<T>, amount: u64, transfer_ref: &TransferRef
    ): FungibleAsset acquires WhiteListed {
        let owner = object::owner(store);
        assert!(verify_sender(&owner), error::unauthenticated(ENOT_WHITELIST_SENDER));
        fungible_asset::withdraw_with_ref(transfer_ref, store, amount)
    }

    // ========= View Functions =========

    // Returns the metadata object for the fungible asset
    #[view]
    public fun get_metadata(): Object<Metadata> {
        let asset_address = object::create_object_address(&@KGeN, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }

    // Returns the balance of an account for this fungible asset
    #[view]
    public fun get_balance(account: address): u64 {
        let asset = get_metadata();
        primary_fungible_store::balance(account, asset)
    }

    // Returns the list of whitelisted sender addresses
    #[view]
    public fun get_whitelisted_sender(): vector<address> acquires WhiteListed {
        borrow_global<WhiteListed>(@KGeN).sender_vec
    }

    // Returns the list of whitelisted receiver addresses
    #[view]
    public fun get_whitelisted_receiver(): vector<address> acquires WhiteListed {
        borrow_global<WhiteListed>(@KGeN).receiver_vec
    }

    // Returns the current state of the dispatcher flag
    #[view]
    public fun get_flag(): bool acquires DispatcherFlag {
        borrow_global<DispatcherFlag>(@KGeN).flag
    }

    // ========= Minting =========

    // Mints tokens to a whitelisted receiver
    public entry fun mint(
        minter: &signer, receiver: address, amount: u64
    ) acquires ManagedKeyAsset, MintingManager, WhiteListed {
        assert_minter(&signer::address_of(minter));
        assert!(
            verify_whitelist_receiver(&receiver),
            error::unauthenticated(ENOT_WHITELIST_ADDRESS)
        );
        let asset = get_metadata();
        let to_wallet =
            primary_fungible_store::ensure_primary_store_exists(receiver, asset);
        let mint_ref_borrow = &authorized_borrow_refs(asset).mint_ref;
        let fa = fungible_asset::mint(mint_ref_borrow, amount);
        let transfer_ref_borrow = &authorized_borrow_refs(asset).transfer_ref;
        fungible_asset::deposit_with_ref(transfer_ref_borrow, to_wallet, fa);
        event::emit(MintedToWhitelistedUser { whitelisted_user_address: receiver, amount });
    }

    // Mints tokens for an oracle (no whitelist check)
    package fun mint_for_oracle(to: address, amount: u64) acquires ManagedKeyAsset {
        let asset = get_metadata();
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        let mint_ref_borrow = &authorized_borrow_refs(asset).mint_ref;
        let fa = fungible_asset::mint(mint_ref_borrow, amount);
        let transfer_ref_borrow = &authorized_borrow_refs(asset).transfer_ref;
        fungible_asset::deposit_with_ref(transfer_ref_borrow, to_wallet, fa);
        event::emit(MintedToOracleNode { to, amount });
    }

    // ========= Transfers =========

    // Transfers all tokens from one address to another
    package fun transfer_keys(from: address, to: address) acquires ManagedKeyAsset, DispatcherFlag {
        manage_flag(true);
        let asset = get_metadata();
        let amount = primary_fungible_store::balance(from, asset);
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        let transfer_ref_borrow = &authorized_borrow_refs(asset).transfer_ref;
        fungible_asset::transfer_with_ref(
            transfer_ref_borrow,
            from_wallet,
            to_wallet,
            amount
        );
        manage_flag(false);

        event::emit(Transfer { from, receiver: to, amount });

    }

    // Burns a specific amount of tokens from an address
    package fun burn(from: address, amount: u64) acquires ManagedKeyAsset {
        let asset = get_metadata();
        let burn_ref = &authorized_borrow_refs(asset).burn_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        fungible_asset::burn_from(burn_ref, from_wallet, amount);
    }

    // Transfers a specific amount of tokens between addresses
    public entry fun transfer(
        sender: &signer, to: address, amount: u64
    ) acquires ManagedKeyAsset, WhiteListed, DispatcherFlag {
        let dispatcher_flag = borrow_global<DispatcherFlag>(@KGeN);
        assert!(dispatcher_flag.flag, error::permission_denied(ENOT_WHITELIST_ADDRESS));
        assert!(
            verify_sender(&signer::address_of(sender)) || verify_receiver(&to),
            error::unauthenticated(EINVALIDRECEIVERORSENDER)
        );
        let asset = get_metadata();
        let from_wallet =
            primary_fungible_store::primary_store(signer::address_of(sender), asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        let transfer_ref_borrow = &authorized_borrow_refs(asset).transfer_ref;
        fungible_asset::transfer_with_ref(
            transfer_ref_borrow,
            from_wallet,
            to_wallet,
            amount
        );
        event::emit(Transfer { from: signer::address_of(sender), receiver: to, amount });
    }

    // ========= Whitelist Management =========

    // Adds an address to the receiver whitelist
    public entry fun add_whitelist_receiver_address(
        admin: &signer, new_address: address
    ) acquires WhiteListed, Admin {
        assert_admin(admin);
        assert!(!verify_receiver(&new_address), error::already_exists(EALREADY_EXIST));
        let r_struct = borrow_global_mut<WhiteListed>(@KGeN);
        vector::push_back(&mut r_struct.receiver_vec, new_address);
        event::emit(
            AddedReceiverAddress {
                msg: to_string(&utf8(b"New Receiver Address Whitelisted")),
                added_address: new_address
            }
        );
    }

    // Removes an address from the receiver whitelist
    public entry fun remove_whitelist_receiver(
        admin: &signer, receiver_address: address
    ) acquires WhiteListed, Admin {
        assert_admin(admin);
        assert!(
            verify_receiver(&receiver_address),
            error::invalid_argument(ENOT_WHITELIST_RECEIVER)
        );
        let r_struct = borrow_global_mut<WhiteListed>(@KGeN);
        let (_, j) = vector::index_of(&r_struct.receiver_vec, &receiver_address);
        vector::remove(&mut r_struct.receiver_vec, j);
        event::emit(
            RemovedReceiverAddress {
                msg: to_string(&utf8(b"Receiver Address Removed From Whitelist")),
                removed_address: receiver_address
            }
        );
    }

    // Adds an address to the sender whitelist
    public entry fun add_whitelist_sender(
        admin: &signer, new_address: address
    ) acquires Admin, WhiteListed {
        assert_admin(admin);
        assert!(!verify_sender(&new_address), error::already_exists(EALREADY_EXIST));
        let s_struct = borrow_global_mut<WhiteListed>(@KGeN);
        vector::push_back(&mut s_struct.sender_vec, new_address);
        event::emit(
            AddedSenderAddress {
                msg: to_string(&utf8(b"New Sender Address Whitelisted")),
                added_address: new_address
            }
        );
    }

    // Removes an address from the sender whitelist
    public entry fun remove_whitelist_sender(
        admin: &signer, sender_address: address
    ) acquires WhiteListed, Admin {
        assert_admin(admin);
        assert!(
            verify_sender(&sender_address),
            error::invalid_argument(ENOT_WHITELIST_SENDER)
        );
        let s_struct = borrow_global_mut<WhiteListed>(@KGeN);
        let (_, j) = vector::index_of(&s_struct.sender_vec, &sender_address);
        vector::remove(&mut s_struct.sender_vec, j);
        event::emit(
            RemovedSenderAddress {
                msg: to_string(&utf8(b"Sender Address Removed From Whitelist")),
                removed_address: sender_address
            }
        );
    }

    // ========= Flag Management =========

    // Sets the dispatcher flag state
    public entry fun set_flag(admin: &signer, state: bool) acquires Admin, DispatcherFlag {
        assert_admin(admin);
        let dispatcher_flag = borrow_global_mut<DispatcherFlag>(@KGeN);
        dispatcher_flag.flag = state;
        event::emit(
            FlagStateChanged {
                msg: to_string(&utf8(b"Dispatcher flag state changed")),
                new_state: state
            }
        );
    }

    // ========= Helper Functions =========

    // Borrows the ManagedKeyAsset resource for authorized operations
    inline fun authorized_borrow_refs(
        asset: Object<Metadata>
    ): &ManagedKeyAsset acquires ManagedKeyAsset {
        borrow_global<ManagedKeyAsset>(object::object_address(&asset))
    }

    // Verifies if an address is in the receiver whitelist
    inline fun verify_whitelist_receiver(invoker: &address): bool {
        let t_vec = borrow_global<WhiteListed>(@KGeN).receiver_vec;
        vector::contains(&t_vec, invoker)
    }

    // Asserts that the caller is the designated minter
    inline fun assert_minter(deployer: &address) {
        assert!(
            borrow_global<MintingManager>(@KGeN).minter == *deployer,
            error::unauthenticated(ENOT_WHITELIST_ADDRESS)
        );
    }

    // Verifies if an address is in the receiver whitelist
    inline fun verify_receiver(receiver: &address): bool acquires WhiteListed {
        let l = borrow_global<WhiteListed>(@KGeN).receiver_vec;
        vector::contains(&l, receiver)
    }

    // Asserts that the caller is the admin
    inline fun assert_admin(deployer: &signer) {
        assert!(
            borrow_global<Admin>(@KGeN).admin == signer::address_of(deployer),
            error::unauthenticated(ENOT_WHITELIST_ADDRESS)
        );
    }

    // Verifies if an address is in the sender whitelist
    inline fun verify_sender(sender: &address): bool acquires WhiteListed {
        let l = borrow_global<WhiteListed>(@KGeN).sender_vec;
        vector::contains(&l, sender)
    }

    // Updates the dispatcher flag state
    inline fun manage_flag(state: bool) acquires DispatcherFlag {
        let dispatcher_flag = borrow_global_mut<DispatcherFlag>(@KGeN);
        dispatcher_flag.flag = state;
    }
}
