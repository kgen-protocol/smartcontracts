/// A module that allows creating and managing multiple fungible assets.
/// Each asset is identified by its symbol and can be minted, transferred, and burned independently.
/// Includes buyer role management for NFT purchases.
module distributorMarket::distributorMarket{
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use std::error;
    use std::signer;
    use std::option;
    use std::string::{Self, utf8, String};
    use aptos_framework::event;  
    use std::vector; 
    use aptos_framework::account;

    /// Only fungible asset metadata owner can make changes.
    const ENOT_OWNER: u64 = 1;
    /// Asset already exists
    const EASSET_EXISTS: u64 = 2;
    /// Asset does not exist
    const EASSET_NOT_EXISTS: u64 = 3;
    /// Only authorized buyers can purchase NFTs
    const ENOT_AUTHORIZED_BUYER: u64 = 4;
    /// Vault not created
    const EVAULT_NOT_CREATED: u64 = 5;
    /// Only owner can perform this action
    const EONLY_OWNER: u64 = 6;
    /// Buyer already present in the list
    const EBUYER_ALREADY_PRESENT: u64 = 7;
    /// Buyer not found in the list
    const EBUYER_NOT_FOUND: u64 = 8;
    const ENOT_ADMIN : u64 = 9;
    const STORAGE_CONTRACT:address = @0x58582549492273975be7790f5639adf18123e2c0c2743cefd51f16cc1137e443;
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Hold refs to control the minting, transfer and burning of fungible assets.
    struct ManagedFungibleAsset has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
    }

    /// Vault structure to manage authorized buyers and admins
    struct Vault has key {
        owner: address,
        authorized_buyers: vector<address>,
        admins_list: vector<address>,
    }

    #[event]
    struct PurchaseNftEvent has drop, store {
        cp: address,
        kgenWallet: address,
        paymentToken:address,
        amount: u64,
        quantity: u64,
        utr: String,
    }

    #[event]
    struct TokenCreatedEvent has drop, store {
        creator: address,
        token_name: String,
        asset_symbol: String,
        decimals: u8,
        asset_address: address,
    }

    #[event]
    struct BuyerAddedEvent has drop, store {
        admin: address,
        buyer: address,
    }

    #[event]
    struct BuyerRemovedEvent has drop, store {
        admin: address,
        buyer: address,
    }

    /// Initialize the vault for buyer management
    public entry fun initialize_vault(account: &signer) {
        let owner_address = signer::address_of(account);
        let vault_address = get_vault_address();
        
        // Check if vault already exists
        assert!(!exists<Vault>(vault_address), error::already_exists(EVAULT_NOT_CREATED));
        let (resource_address, signer_capability) = account::create_resource_account(account, b"vault");
        let admins = vector::empty<address>();
        vector::push_back(&mut admins, signer::address_of(account)); 
        move_to(&resource_address, Vault {
            owner: owner_address,
            authorized_buyers: vector::empty<address>(),
            admins_list: vector::singleton<address>(owner_address),
        });
    }

    /// Get the vault address (using module address)

    fun get_vault_address():address{
        account::create_resource_address(&@distributorMarket, b"vault")
    }

    /// Create a new fungible asset with specified parameters
    public entry fun create_token(
        admin: &signer,
        token_name: String,
        asset_symbol: String,
        decimals: u8,
        icon_uri: String,
        project_uri: String
    ) acquires Vault {
        let symbol_bytes = *string::bytes(&asset_symbol);
        let asset_address = object::create_object_address(&@distributorMarket, symbol_bytes);
        assert!(is_admin(signer::address_of(admin)),ENOT_ADMIN);
        // Check if asset already exists
        assert!(!object::object_exists<Metadata>(asset_address), error::already_exists(EASSET_EXISTS));
        
        let constructor_ref = &object::create_named_object(admin, symbol_bytes);

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            token_name, /* name */
            asset_symbol, /* symbol */
            decimals, /* decimals */
            icon_uri, /* icon */
            project_uri, /* project */
        );

        // Create mint/burn/transfer refs to allow creator to manage the fungible asset.
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        let metadata_object_signer = object::generate_signer(constructor_ref);
        
        move_to(
            &metadata_object_signer,
            ManagedFungibleAsset { mint_ref, transfer_ref, burn_ref }
        );

        // Emit token creation event
        event::emit<TokenCreatedEvent>(TokenCreatedEvent {
            creator: signer::address_of(admin),
            token_name,
            asset_symbol,
            decimals,
            asset_address,
        });
    }


    #[view]
    /// Return the address of the managed fungible asset based on symbol.
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
    public fun get_balance(account: address, asset_symbol: String): u64 {
        if (!asset_exists(asset_symbol)) {
            return 0
        };
        let asset = get_metadata(asset_symbol);
        primary_fungible_store::balance(account, asset)
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
        vector::contains(&vault.admins_list, &admin_address)
    }

    /// Mint tokens to a specific account
    public entry fun mint(
        admin: &signer, 
        to: address, 
        amount: u64,
        asset_symbol: String
    ) acquires ManagedFungibleAsset,Vault {
        assert!(is_admin(signer::address_of(admin)),ENOT_ADMIN);
        let asset = get_metadata(asset_symbol);
        let managed_fungible_asset = authorized_borrow_refs(signer::address_of(admin), asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        let fa = fungible_asset::mint(&managed_fungible_asset.mint_ref, amount);
        fungible_asset::deposit_with_ref(&managed_fungible_asset.transfer_ref, to_wallet, fa);
    }

    /// Burn tokens from a specific account
    public entry fun burn(
        admin: &signer,
        from: address,
        amount: u64,
        asset_symbol: String
    ) acquires ManagedFungibleAsset,Vault {
        assert!(is_admin(signer::address_of(admin)),ENOT_ADMIN);
        let asset = get_metadata(asset_symbol);
        let managed_fungible_asset = authorized_borrow_refs(signer::address_of(admin), asset);
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        let fa = fungible_asset::withdraw_with_ref(&managed_fungible_asset.transfer_ref, from_wallet, amount);
        fungible_asset::burn(&managed_fungible_asset.burn_ref, fa);
    }

    inline fun get_metadata_object(object: address): Object<Metadata> {
        object::address_to_object<Metadata>(object)
    }

    /// Transfer tokens from sender's account to recipient
    public entry fun transfer_from_sender(
        sender: &signer,
        to: address,
        amount: u64,
        asset_symbol: String
    ) {
        let asset = get_metadata(asset_symbol);
        primary_fungible_store::transfer(sender, asset, to, amount);
    }

    /// Batch mint multiple tokens to an account
    public entry fun batch_mint(
        admin: &signer,
        to: address,
        asset_symbols: vector<String>,
        amounts: vector<u64>
    ) acquires ManagedFungibleAsset,Vault {
        let len = vector::length(&asset_symbols);
        assert!(len == vector::length(&amounts), error::invalid_argument(4));
        assert!(is_admin(signer::address_of(admin)),ENOT_ADMIN);
        let i = 0;
        while (i < len) {
            let symbol = *vector::borrow(&asset_symbols, i);
            let amount = *vector::borrow(&amounts, i);
            mint(admin, to, amount, symbol);
            i = i + 1;
        };
    }

    /// Purchase NFT function with buyer authorization check
    public entry fun purchase_nft(
        buyer: &signer,
        cp: address,
        paymentToken: address,
        nft_quantity: u64,
        payment_amount: u64,
        nft_asset_symbol: String,
        utr: String,
    ) acquires ManagedFungibleAsset, Vault { 
        let buyer_address = signer::address_of(buyer);
        // Check if buyer is authorized
        assert!(is_authorized_buyer(buyer_address), error::permission_denied(ENOT_AUTHORIZED_BUYER));
        // Transfer NFT from CP to buyer
        let nft_asset = get_metadata(nft_asset_symbol);
        let nft_transfer_ref = &authorized_borrow_refs(cp, nft_asset).transfer_ref;
        let cp_nft_wallet = primary_fungible_store::primary_store(cp, nft_asset);
        let storage_nft_wallet = primary_fungible_store::ensure_primary_store_exists(STORAGE_CONTRACT, nft_asset);
        fungible_asset::transfer_with_ref(nft_transfer_ref, cp_nft_wallet, storage_nft_wallet, nft_quantity);
        
        let payment_asset = get_metadata_object(paymentToken);
        primary_fungible_store::ensure_primary_store_exists(cp, payment_asset);
        // Transfer payment from buyer to CP
        primary_fungible_store::transfer(buyer, payment_asset, cp, payment_amount);

        // Emit purchase event
        event::emit<PurchaseNftEvent>(PurchaseNftEvent {
            cp: cp,
            kgenWallet: buyer_address, 
            amount: payment_amount,
            paymentToken:paymentToken,
            quantity: nft_quantity,
            utr: utr,
        });
    }

    /// Add address to authorized buyers list
    public entry fun add_address_to_buyer_list(account: &signer, addr: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), error::not_found(EVAULT_NOT_CREATED));
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vector::contains(&vault.admins_list, &signer::address_of(account)), error::permission_denied(EONLY_OWNER));
        assert!(!vector::contains(&vault.authorized_buyers, &addr), error::already_exists(EBUYER_ALREADY_PRESENT));
        vector::push_back(&mut vault.authorized_buyers, addr);
        
        // Emit buyer added event
        event::emit<BuyerAddedEvent>(BuyerAddedEvent {
            admin: signer::address_of(account),
            buyer: addr,
        });
    }

    /// Remove address from authorized buyers list
    public entry fun remove_address_from_buyer_list(account: &signer, addr: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), error::not_found(EVAULT_NOT_CREATED));
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vector::contains(&vault.admins_list, &signer::address_of(account)), error::permission_denied(EONLY_OWNER));
        assert!(vector::contains(&vault.authorized_buyers, &addr), error::not_found(EBUYER_NOT_FOUND));
        let (found, i) = vector::index_of(&vault.authorized_buyers, &addr);
        assert!(found, error::not_found(EBUYER_NOT_FOUND));
        vector::remove(&mut vault.authorized_buyers, i);
        
        // Emit buyer removed event
        event::emit<BuyerRemovedEvent>(BuyerRemovedEvent {
            admin: signer::address_of(account),
            buyer: addr,
        });
    }

    /// Add admin to the admins list
    public entry fun add_admin(account: &signer, new_admin: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), error::not_found(EVAULT_NOT_CREATED));
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(signer::address_of(account) == vault.owner, error::permission_denied(EONLY_OWNER));
        assert!(!vector::contains(&vault.admins_list, &new_admin), error::already_exists(EBUYER_ALREADY_PRESENT));
        vector::push_back(&mut vault.admins_list, new_admin);
    }

    /// Remove admin from the admins list
    public entry fun remove_admin(account: &signer, admin_to_remove: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), error::not_found(EVAULT_NOT_CREATED));
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(signer::address_of(account) == vault.owner, error::permission_denied(EONLY_OWNER));
        assert!(vector::contains(&vault.admins_list, &admin_to_remove), error::not_found(EBUYER_NOT_FOUND));
        let (found, i) = vector::index_of(&vault.admins_list, &admin_to_remove);
        assert!(found, error::not_found(EBUYER_NOT_FOUND));
        vector::remove(&mut vault.admins_list, i);
    }

    /// Borrow the immutable reference of the refs of `metadata`.
    /// This validates that the signer is the metadata object's owner.
    inline fun authorized_borrow_refs(
        owner: address,
        asset: Object<Metadata>,
    ): &ManagedFungibleAsset acquires ManagedFungibleAsset {
        assert!(object::is_owner(asset, owner), error::permission_denied(ENOT_OWNER));
        borrow_global<ManagedFungibleAsset>(object::object_address(&asset))
    }
}