
/// A production-ready module for managing fungible assets and NFT marketplace operations
module distributorMarket::distributorMarket {
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
    use aptos_framework::object::{Self, Object, ConstructorRef};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use std::error;
    use std::signer;
    use std::option::{Self, Option};
    use std::string::{Self, String};
    use std::vector; 

    // ================================
    // Error Constants
    // ================================
    
    /// Only fungible asset metadata owner can make changes
    const E_NOT_OWNER: u64 = 1;
    /// Asset already exists with this symbol
    const E_ASSET_EXISTS: u64 = 2;
    /// Asset does not exist
    const E_ASSET_NOT_EXISTS: u64 = 3;
    /// Only authorized buyers can purchase NFTs
    const E_NOT_AUTHORIZED_BUYER: u64 = 4;
    /// Vault not created or does not exist
    const E_VAULT_NOT_CREATED: u64 = 5;
    /// Only owner can perform this action
    const E_ONLY_OWNER: u64 = 6;
    /// Buyer already present in the list
    const E_BUYER_ALREADY_PRESENT: u64 = 7;
    /// Buyer not found in the list
    const E_BUYER_NOT_FOUND: u64 = 8;
    /// Not an admin
    const E_NOT_ADMIN: u64 = 9;
    /// Admin already exists
    const E_ADMIN_ALREADY_EXISTS: u64 = 10;
    /// Admin not found
    const E_ADMIN_NOT_FOUND: u64 = 11;
    /// Insufficient balance
    const E_INSUFFICIENT_BALANCE: u64 = 12;
    /// Invalid amount (zero or negative)
    const E_INVALID_AMOUNT: u64 = 13;
    /// Invalid parameters
    const E_INVALID_PARAMETERS: u64 = 14;
    /// Operation not allowed
    const E_OPERATION_NOT_ALLOWED: u64 = 15;
    /// Vector length mismatch
    const E_VECTOR_LENGTH_MISMATCH: u64 = 16;

    // ================================
    // Constants
    // ================================
    
    /// Storage contract address - should be configurable in production
    const STORAGE_CONTRACT: address = @0x58582549492273975be7790f5639adf18123e2c0c2743cefd51f16cc1137e443;
    
    /// Maximum number of assets that can be batch processed
    const MAX_BATCH_SIZE: u64 = 100;
    
    /// Vault seed for resource account creation
    const VAULT_SEED: vector<u8> = b"DistributorMarket_Vault_v1";

    // ================================
    // Resource Structures
    // ================================

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Holds references to control minting, transfer and burning of fungible assets
    struct ManagedFungibleAsset has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
        /// Additional metadata for the asset
        creator: address,
        created_at: u64,
        /// Flag to pause/unpause operations
        is_paused: bool,
    }

    /// Vault structure to manage authorized buyers, admins, and system state
    struct Vault has key {
        /// Contract owner (immutable after creation)
        owner: address,
        /// List of addresses authorized to buy NFTs
        authorized_buyers: vector<address>,
        /// List of admin addresses
        admins_list: vector<address>,
        /// Signer capability for the vault
        signer_cap: SignerCapability,
        /// Emergency pause flag
        is_paused: bool,
        /// Creation timestamp
        created_at: u64,
        /// Storage contract address (configurable)
        storage_contract: address,
    }

    // ================================
    // Event Structures
    // ================================

    #[event]
    struct PurchaseNftEvent has drop, store {
        cp: address,
        kgen_wallet: address,
        payment_token: address,
        amount: u64,
        quantity: u64,
        utr: String,
        timestamp: u64,
    }

    #[event]
    struct TokenCreatedEvent has drop, store {
        creator: address,
        token_name: String,
        asset_symbol: String,
        decimals: u8,
        asset_address: address,
        timestamp: u64,
    }

    #[event]
    struct BuyerAddedEvent has drop, store {
        admin: address,
        buyer: address,
        timestamp: u64,
    }

    #[event]
    struct BuyerRemovedEvent has drop, store {
        admin: address,
        buyer: address,
        timestamp: u64,
    }

    #[event]
    struct AdminAddedEvent has drop, store {
        owner: address,
        new_admin: address,
        timestamp: u64,
    }

    #[event]
    struct AdminRemovedEvent has drop, store {
        owner: address,
        removed_admin: address,
        timestamp: u64,
    }

    #[event]
    struct MintEvent has drop, store {
        admin: address,
        to: address,
        asset_symbol: String,
        amount: u64,
        timestamp: u64,
    }

    #[event]
    struct BurnEvent has drop, store {
        admin: address,
        from: address,
        asset_symbol: String,
        amount: u64,
        timestamp: u64,
    }

    #[event]
    struct TransferEvent has drop, store {
        from: address,
        to: address,
        asset_symbol: String,
        amount: u64,
        timestamp: u64,
    }

    #[event]
    struct EmergencyPauseEvent has drop, store {
        owner: address,
        is_paused: bool,
        timestamp: u64,
    }

    // ================================
    // Initialization Functions
    // ================================

    /// Initialize the vault for buyer management
    /// Can only be called once
    public entry fun initialize_vault(account: &signer) {
        let owner_address = signer::address_of(account);
        let vault_address = get_vault_address();
        
        // Ensure vault doesn't already exist
        assert!(!exists<Vault>(vault_address), error::already_exists(E_VAULT_NOT_CREATED));
        
        let (resource_address, signer_capability) = account::create_resource_account(
            account, 
            VAULT_SEED
        );
        
        // Initialize admin list with the creator
        let admins = vector::empty<address>();
        vector::push_back(&mut admins, owner_address);
        
        move_to(&resource_address, Vault {
            owner: owner_address,
            authorized_buyers: vector::empty<address>(),
            admins_list: admins,
            signer_cap: signer_capability,
            is_paused: false,
            created_at: timestamp::now_seconds(),
            storage_contract: STORAGE_CONTRACT,
        });
    }

    // ================================
    // View Functions
    // ================================

    #[view]
    /// Get all admin addresses
    public fun get_admins(): vector<address> acquires Vault {
        let vault_address = get_vault_address();
        if (!exists<Vault>(vault_address)) {
            return vector::empty<address>()
        };
        let vault = borrow_global<Vault>(vault_address);
        vault.admins_list
    }

    #[view]
    /// Get all authorized buyer addresses
    public fun get_authorized_buyers(): vector<address> acquires Vault {
        let vault_address = get_vault_address();
        if (!exists<Vault>(vault_address)) {
            return vector::empty<address>()
        };
        let vault = borrow_global<Vault>(vault_address);
        vault.authorized_buyers
    }

    #[view]
    /// Get vault owner
    public fun get_vault_owner(): address acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), error::not_found(E_VAULT_NOT_CREATED));
        let vault = borrow_global<Vault>(vault_address);
        vault.owner
    }

    #[view]
    /// Check if vault is paused
    public fun is_vault_paused(): bool acquires Vault {
        let vault_address = get_vault_address();
        if (!exists<Vault>(vault_address)) {
            return true // Assume paused if vault doesn't exist
        };
        let vault = borrow_global<Vault>(vault_address);
        vault.is_paused
    }

    #[view]
    /// Get the vault address using deterministic address generation
    public fun get_vault_address(): address {
        account::create_resource_address(&@distributorMarket, VAULT_SEED)
    }

    #[view]
    /// Return the metadata object for a given asset symbol
    public fun get_metadata(asset_symbol: String): Object<Metadata> {
        let asset_symbol_bytes = *string::bytes(&asset_symbol);
        let asset_address = object::create_object_address(&@distributorMarket, asset_symbol_bytes);
        object::address_to_object<Metadata>(asset_address)
    }

    #[view]
    /// Check if a fungible asset exists for given symbol
    public fun asset_exists(asset_symbol: String): bool {
        let asset_symbol_bytes = *string::bytes(&asset_symbol);
        let asset_address = object::create_object_address(&@distributorMarket, asset_symbol_bytes);
        object::object_exists<Metadata>(asset_address)
    }

    #[view]
    /// Get the balance of a specific asset for an account
    public fun get_balance(account_addr: address, asset_symbol: String): u64 {
        if (!asset_exists(asset_symbol)) {
            return 0
        };
        let asset = get_metadata(asset_symbol);
        primary_fungible_store::balance(account_addr, asset)
    }

    #[view]
    /// Check if an address is an authorized buyer
    public fun is_authorized_buyer(buyer_address: address): bool acquires Vault {
        let vault_address = get_vault_address();
        if (!exists<Vault>(vault_address)) {
            return false
        };
        let vault = borrow_global<Vault>(vault_address);
        vector::contains(&vault.authorized_buyers, &buyer_address)
    }

    #[view]
    /// Check if an address is an admin
    public fun is_admin(admin_address: address): bool acquires Vault {
        let vault_address = get_vault_address();
        if (!exists<Vault>(vault_address)) {
            return false
        };
        let vault = borrow_global<Vault>(vault_address);
        vector::contains(&vault.admins_list, &admin_address) || vault.owner == admin_address
    }

    #[view]
    /// Check if an address is the vault owner
    public fun is_owner(address: address): bool acquires Vault {
        let vault_address = get_vault_address();
        if (!exists<Vault>(vault_address)) {
            return false
        };
        let vault = borrow_global<Vault>(vault_address);
        vault.owner == address
    }

    #[view]
    /// Get asset information including creation details
    public fun get_asset_info(asset_symbol: String): (address, u64, bool) acquires ManagedFungibleAsset {
        assert!(asset_exists(asset_symbol), error::not_found(E_ASSET_NOT_EXISTS));
        let asset = get_metadata(asset_symbol);
        let asset_address = object::object_address(&asset);
        let managed_asset = borrow_global<ManagedFungibleAsset>(asset_address);
        (managed_asset.creator, managed_asset.created_at, managed_asset.is_paused)
    }

    // ================================
    // Asset Management Functions
    // ================================

    /// Create a new fungible asset with specified parameters
    /// Only admins can create new assets
    public entry fun create_token(
        admin: &signer,
        token_name: String,
        asset_symbol: String,
        decimals: u8,
        icon_uri: String,
        project_uri: String
    ) acquires Vault {
        // Validate inputs
        assert!(!string::is_empty(&token_name), error::invalid_argument(E_INVALID_PARAMETERS));
        assert!(!string::is_empty(&asset_symbol), error::invalid_argument(E_INVALID_PARAMETERS));
        assert!(decimals <= 18, error::invalid_argument(E_INVALID_PARAMETERS)); // Reasonable decimal limit
        
        let admin_address = signer::address_of(admin);
        assert!(is_admin(admin_address), error::permission_denied(E_NOT_ADMIN));
        assert!(!is_vault_paused(), error::unavailable(E_OPERATION_NOT_ALLOWED));

        let symbol_bytes = *string::bytes(&asset_symbol);
        let asset_address = object::create_object_address(&@distributorMarket, symbol_bytes);
        
        // Check if asset already exists
        assert!(!object::object_exists<Metadata>(asset_address), error::already_exists(E_ASSET_EXISTS));
        
        let constructor_ref = &object::create_named_object(admin, symbol_bytes);

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            token_name,
            asset_symbol,
            decimals,
            icon_uri,
            project_uri,
        );

        // Create mint/burn/transfer refs
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        let metadata_object_signer = object::generate_signer(constructor_ref);
        
        move_to(
            &metadata_object_signer,
            ManagedFungibleAsset { 
                mint_ref, 
                transfer_ref, 
                burn_ref,
                creator: admin_address,
                created_at: timestamp::now_seconds(),
                is_paused: false,
            }
        );

        // Emit token creation event
        event::emit<TokenCreatedEvent>(TokenCreatedEvent {
            creator: admin_address,
            token_name,
            asset_symbol,
            decimals,
            asset_address,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// Mint tokens to a specific account
    /// Only admins can mint tokens
    public entry fun mint(
        admin: &signer, 
        to: address, 
        amount: u64,
        asset_symbol: String
    ) acquires ManagedFungibleAsset, Vault {
        let admin_address = signer::address_of(admin);
        
        // Validations
        assert!(amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
        assert!(is_admin(admin_address), error::permission_denied(E_NOT_ADMIN));
        assert!(!is_vault_paused(), error::unavailable(E_OPERATION_NOT_ALLOWED));
        assert!(asset_exists(asset_symbol), error::not_found(E_ASSET_NOT_EXISTS));

        let asset = get_metadata(asset_symbol);
        let managed_fungible_asset = authorized_borrow_refs(admin_address, asset);
        assert!(!managed_fungible_asset.is_paused, error::unavailable(E_OPERATION_NOT_ALLOWED));
        
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        let fa = fungible_asset::mint(&managed_fungible_asset.mint_ref, amount);
        fungible_asset::deposit_with_ref(&managed_fungible_asset.transfer_ref, to_wallet, fa);

        // Emit mint event
        event::emit<MintEvent>(MintEvent {
            admin: admin_address,
            to,
            asset_symbol,
            amount,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// Burn tokens from a specific account
    /// Only admins can burn tokens
    public entry fun burn(
        admin: &signer,
        from: address,
        amount: u64,
        asset_symbol: String
    ) acquires ManagedFungibleAsset, Vault {
        let admin_address = signer::address_of(admin);
        
        // Validations
        assert!(amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
        assert!(is_admin(admin_address), error::permission_denied(E_NOT_ADMIN));
        assert!(!is_vault_paused(), error::unavailable(E_OPERATION_NOT_ALLOWED));
        assert!(asset_exists(asset_symbol), error::not_found(E_ASSET_NOT_EXISTS));

        let asset = get_metadata(asset_symbol);
        let managed_fungible_asset = authorized_borrow_refs(admin_address, asset);
        assert!(!managed_fungible_asset.is_paused, error::unavailable(E_OPERATION_NOT_ALLOWED));
        
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        let current_balance = fungible_asset::balance(from_wallet);
        assert!(current_balance >= amount, error::invalid_argument(E_INSUFFICIENT_BALANCE));
        
        let fa = fungible_asset::withdraw_with_ref(&managed_fungible_asset.transfer_ref, from_wallet, amount);
        fungible_asset::burn(&managed_fungible_asset.burn_ref, fa);

        // Emit burn event
        event::emit<BurnEvent>(BurnEvent {
            admin: admin_address,
            from,
            asset_symbol,
            amount,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// Transfer tokens from sender's account to recipient
    public entry fun transfer_from_sender(
        sender: &signer,
        to: address,
        amount: u64,
        asset_symbol: String
    ) acquires Vault {
        // Validations
        assert!(amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
        assert!(!is_vault_paused(), error::unavailable(E_OPERATION_NOT_ALLOWED));
        assert!(asset_exists(asset_symbol), error::not_found(E_ASSET_NOT_EXISTS));

        let sender_address = signer::address_of(sender);
        let asset = get_metadata(asset_symbol);
        
        // Check balance before transfer
        let current_balance = get_balance(sender_address, asset_symbol);
        assert!(current_balance >= amount, error::invalid_argument(E_INSUFFICIENT_BALANCE));
        
        primary_fungible_store::transfer(sender, asset, to, amount);

        // Emit transfer event
        event::emit<TransferEvent>(TransferEvent {
            from: sender_address,
            to,
            asset_symbol,
            amount,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// Admin-controlled transfer function
    public entry fun transfer(
        from: address, 
        to: address, 
        quantity: u64,
        asset_symbol: String
    ) acquires ManagedFungibleAsset {
        // Validations
        assert!(quantity > 0, error::invalid_argument(E_INVALID_AMOUNT));
        assert!(asset_exists(asset_symbol), error::not_found(E_ASSET_NOT_EXISTS));

        let asset = get_metadata(asset_symbol);
        let transfer_ref = &authorized_borrow_refs(from, asset).transfer_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        
        // Check balance before transfer
        let current_balance = fungible_asset::balance(from_wallet);
        assert!(current_balance >= quantity, error::invalid_argument(E_INSUFFICIENT_BALANCE));
        
        fungible_asset::transfer_with_ref(transfer_ref, from_wallet, to_wallet, quantity);

        // Emit transfer event
        event::emit<TransferEvent>(TransferEvent {
            from,
            to,
            asset_symbol,
            amount: quantity,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// Batch mint multiple tokens to an account
    /// Useful for airdrops or bulk operations
    public entry fun batch_mint(
        admin: &signer,
        to: address,
        asset_symbols: vector<String>,
        amounts: vector<u64>
    ) acquires ManagedFungibleAsset, Vault {
        let len = vector::length(&asset_symbols);
        assert!(len == vector::length(&amounts), error::invalid_argument(E_VECTOR_LENGTH_MISMATCH));
        assert!(len > 0 && len <= MAX_BATCH_SIZE, error::invalid_argument(E_INVALID_PARAMETERS));
        
        let admin_address = signer::address_of(admin);
        assert!(is_admin(admin_address), error::permission_denied(E_NOT_ADMIN));
        assert!(!is_vault_paused(), error::unavailable(E_OPERATION_NOT_ALLOWED));

        let i = 0;
        while (i < len) {
            let symbol = *vector::borrow(&asset_symbols, i);
            let amount = *vector::borrow(&amounts, i);
            mint(admin, to, amount, symbol);
            i = i + 1;
        };
    }

    // ================================
    // Marketplace Functions
    // ================================

    /// Purchase NFT function with comprehensive validation
    public entry fun purchase_nft(
        buyer: &signer,
        cp: address,
        payment_token: address,
        nft_quantity: u64,
        payment_amount: u64,
        nft_asset_symbol: String,
        utr: String,
    ) acquires ManagedFungibleAsset, Vault { 
        let buyer_address = signer::address_of(buyer);
        
        // Validations
        assert!(nft_quantity > 0, error::invalid_argument(E_INVALID_AMOUNT));
        assert!(payment_amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
        assert!(!string::is_empty(&utr), error::invalid_argument(E_INVALID_PARAMETERS));
        assert!(is_authorized_buyer(buyer_address), error::permission_denied(E_NOT_AUTHORIZED_BUYER));
        assert!(!is_vault_paused(), error::unavailable(E_OPERATION_NOT_ALLOWED));
        assert!(asset_exists(nft_asset_symbol), error::not_found(E_ASSET_NOT_EXISTS));

        let vault = borrow_global<Vault>(get_vault_address());
        
        // Check NFT balance of CP
        let cp_nft_balance = get_balance(cp, nft_asset_symbol);
        assert!(cp_nft_balance >= nft_quantity, error::invalid_argument(E_INSUFFICIENT_BALANCE));

        // Check payment token balance of buyer
        let payment_asset = get_metadata_object(payment_token);
        let buyer_payment_balance = primary_fungible_store::balance(buyer_address, payment_asset);
        assert!(buyer_payment_balance >= payment_amount, error::invalid_argument(E_INSUFFICIENT_BALANCE));

        // Transfer NFT from CP to storage contract
        transfer(cp, vault.storage_contract, nft_quantity, nft_asset_symbol);   

        // Ensure CP has a store for payment token
        primary_fungible_store::ensure_primary_store_exists(cp, payment_asset);
        
        // Transfer payment from buyer to CP
        primary_fungible_store::transfer(buyer, payment_asset, cp, payment_amount);

        // Emit purchase event
        event::emit<PurchaseNftEvent>(PurchaseNftEvent {
            cp,
            kgen_wallet: buyer_address, 
            amount: payment_amount,
            payment_token,
            quantity: nft_quantity,
            utr,
            timestamp: timestamp::now_seconds(),
        });
    }

    // ================================
    // Admin Management Functions
    // ================================

    /// Add address to authorized buyers list
    /// Only admins can add buyers
    public entry fun add_authorized_buyer(admin: &signer, buyer_addr: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), error::not_found(E_VAULT_NOT_CREATED));
        
        let admin_address = signer::address_of(admin);
        assert!(is_admin(admin_address), error::permission_denied(E_NOT_ADMIN));
        assert!(!is_vault_paused(), error::unavailable(E_OPERATION_NOT_ALLOWED));

        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(!vector::contains(&vault.authorized_buyers, &buyer_addr), 
                error::already_exists(E_BUYER_ALREADY_PRESENT));
        
        vector::push_back(&mut vault.authorized_buyers, buyer_addr);
        
        event::emit<BuyerAddedEvent>(BuyerAddedEvent {
            admin: admin_address,
            buyer: buyer_addr,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// Remove address from authorized buyers list
    /// Only admins can remove buyers
    public entry fun remove_authorized_buyer(admin: &signer, buyer_addr: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), error::not_found(E_VAULT_NOT_CREATED));
        
        let admin_address = signer::address_of(admin);
        assert!(is_admin(admin_address), error::permission_denied(E_NOT_ADMIN));
        assert!(!is_vault_paused(), error::unavailable(E_OPERATION_NOT_ALLOWED));

        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vector::contains(&vault.authorized_buyers, &buyer_addr), 
                error::not_found(E_BUYER_NOT_FOUND));
        
        let (found, i) = vector::index_of(&vault.authorized_buyers, &buyer_addr);
        assert!(found, error::not_found(E_BUYER_NOT_FOUND));
        vector::remove(&mut vault.authorized_buyers, i);
        
        event::emit<BuyerRemovedEvent>(BuyerRemovedEvent {
            admin: admin_address,
            buyer: buyer_addr,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// Add admin to the admins list
    /// Only owner can add admins
    public entry fun add_admin(owner: &signer, new_admin: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), error::not_found(E_VAULT_NOT_CREATED));
        
        let owner_address = signer::address_of(owner);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vault.owner == owner_address, error::permission_denied(E_ONLY_OWNER));
        assert!(!vault.is_paused, error::unavailable(E_OPERATION_NOT_ALLOWED));
        assert!(!vector::contains(&vault.admins_list, &new_admin), 
                error::already_exists(E_ADMIN_ALREADY_EXISTS));
        
        vector::push_back(&mut vault.admins_list, new_admin);
        
        event::emit<AdminAddedEvent>(AdminAddedEvent {
            owner: owner_address,
            new_admin,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// Remove admin from the admins list
    /// Only owner can remove admins
    public entry fun remove_admin(owner: &signer, admin_to_remove: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), error::not_found(E_VAULT_NOT_CREATED));
        
        let owner_address = signer::address_of(owner);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vault.owner == owner_address, error::permission_denied(E_ONLY_OWNER));
        assert!(!vault.is_paused, error::unavailable(E_OPERATION_NOT_ALLOWED));
        assert!(vector::contains(&vault.admins_list, &admin_to_remove), 
                error::not_found(E_ADMIN_NOT_FOUND));
        
        let (found, i) = vector::index_of(&vault.admins_list, &admin_to_remove);
        assert!(found, error::not_found(E_ADMIN_NOT_FOUND));
        vector::remove(&mut vault.admins_list, i);
        
        event::emit<AdminRemovedEvent>(AdminRemovedEvent {
            owner: owner_address,
            removed_admin: admin_to_remove,
            timestamp: timestamp::now_seconds(),
        });
    }

    // ================================
    // Emergency Functions
    // ================================

    /// Emergency pause/unpause the entire vault
    /// Only owner can perform this action
    public entry fun emergency_pause(owner: &signer, pause: bool) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), error::not_found(E_VAULT_NOT_CREATED));
        
        let owner_address = signer::address_of(owner);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vault.owner == owner_address, error::permission_denied(E_ONLY_OWNER));
        
        vault.is_paused = pause;
        
        event::emit<EmergencyPauseEvent>(EmergencyPauseEvent {
            owner: owner_address,
            is_paused: pause,
            timestamp: timestamp::now_seconds(),
        });
    }
    // ================================
    // inline Functions
    // ================================
    inline fun authorized_borrow_refs(
        owner: address,
        asset: Object<Metadata>,
    ): &ManagedFungibleAsset acquires ManagedFungibleAsset {
        assert!(object::is_owner(asset, owner), error::permission_denied(E_NOT_OWNER));
        borrow_global<ManagedFungibleAsset>(object::object_address(&asset))
    }
    inline fun get_metadata_object(object: address): Object<Metadata> {
        object::address_to_object<Metadata>(object)
    }
}