/// A 2-in-1 module that combines managed_fungible_asset and coin_example into one module that when deployed, the
/// deployer will be creating a new managed fungible asset with the hardcoded supply config, name, symbol, and decimals.
/// The address of the asset can be obtained via get_metadata(). As a simple version, it only deals with primary stores.
module kcash_addr::kcashFA {
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use std::error;
    use std::signer;
    use std::string::utf8;
    use std::option;

    /// Only fungible asset metadata owner can make changes.
    const ENOT_OWNER: u64 = 1;
    /// Validation for bucket sum must be equal to amount.
    const EAMOUNT_SHOULD_EQUAL_TO_BUCKET_AMOUNT: u64 = 2;

    const ASSET_SYMBOL: vector<u8> = b"KFA";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Hold refs to control the minting, transfer and burning of fungible assets.
    struct ManagedFungibleAsset has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
    }

    // #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // /// The BucketStore object that holds fungible assets of differentc type associated with an account.
    // struct BucketStore has key {
    //     reward1: u64,
    //     reward2: u64,
    //     reward3: u64,
    // }

    /// BucketAssets can be passed into function for type safety and to guarantee a specific amount.
    /// BucketAssets is ephemeral and cannot be stored directly. It must be deposited back into a Bucketstore.
    // struct BucketAssets has drop {
    //     reward_amount1: u64,
    //     reward_amount2: u64,
    //     reward_amount3: u64,
    // }

    // #[view]
    // /// Return whether the provided address has a store initialized.
    // public fun bucket_exists(store: address): bool {
    //     exists<BucketStore>(store)
    // }

    /// Allow an object to hold a store for fungible assets.
    /// Applications can use this to create multiple stores for isolating fungible assets for different purposes.
    // fun create_bucket_store(
    //     store_obj: &signer
    // ){
    //     move_to(store_obj, BucketStore {
    //         reward1: 0,
    //         reward2: 0,
    //         reward3: 0,
    //     });
    // }

    /// Deposit to bucketstore
    // fun deposit_to_bucketstore(store_addr: address, ba: BucketAssets) acquires BucketStore{
    //     if (!exists<BucketStore>(store_addr)) return;
    //     let BucketAssets { reward_amount1, reward_amount2, reward_amount3 } = ba;
    //     let store = borrow_global_mut<BucketStore>(store_addr);
    //     store.reward1 = store.reward1 + reward_amount1;
    //     store.reward2 = store.reward2 + reward_amount2;
    //     store.reward3 = store.reward3 + reward_amount3;
    // }

    #[view]
    /// Return the Bucket values of the user.
    public fun get_fungible_store(store_addr: address): bool{
        // // let a = fungible_asset::balance_by_address(store_addr);
        // let ast = get_metadata();
        // // a
        fungible_asset::store_exists(store_addr)
    }

    /// Initialize metadata object and store the refs.
    // :!:>initialize
    fun init_module(admin: &signer) {
        let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            utf8(b"KCash"), /* name */
            utf8(ASSET_SYMBOL), /* symbol */
            8, /* decimals */
            utf8(b"http://example.com/favicon.ico"), /* icon */
            utf8(b"http://example.com"), /* project */
        );

        // create_bucket_store(admin);
        // Create mint/burn/transfer refs to allow creator to manage the fungible asset.
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        let metadata_object_signer = object::generate_signer(constructor_ref);
        move_to(
            &metadata_object_signer,
            ManagedFungibleAsset { mint_ref, transfer_ref, burn_ref }
        )// <:!:initialize
    }

    #[view]
    /// Return the address of the managed fungible asset that's created when this module is deployed.
    public fun get_metadata(): Object<Metadata> {
        let asset_address = object::create_object_address(&@kcash_addr, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }



    // :!:>mint
    /// Mint as the owner of metadata object and deposit to a specific account.
    public entry fun mint(admin: &signer, to: address, amount: u64, reward_amount1: u64, reward_amount2: u64, reward_amount3: u64) acquires ManagedFungibleAsset {
        // Validation for bucket sum must be equal to amount
        let bucket_amt = reward_amount1+reward_amount2+reward_amount3;
        assert!(bucket_amt == amount, error::invalid_argument(EAMOUNT_SHOULD_EQUAL_TO_BUCKET_AMOUNT));

        let asset = get_metadata();
        let managed_fungible_asset = authorized_borrow_refs(admin, asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);

        // let fa = fungible_asset::mint(&managed_fungible_asset.mint_ref, amount, reward_amount1, reward_amount2, reward_amount3);
        let fa = fungible_asset::mint(&managed_fungible_asset.mint_ref, amount);
        fungible_asset::deposit_with_ref(&managed_fungible_asset.transfer_ref, to_wallet, fa);

    }// <:!:mint_to

    /// Transfer as the owner of metadata object ignoring `frozen` field.
    public entry fun transfer(admin: &signer, from: address, to: address, amount: u64) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        fungible_asset::transfer_with_ref(transfer_ref, from_wallet, to_wallet, amount);
    }

    /// Burn fungible assets as the owner of metadata object.
    public entry fun burn(admin: &signer, from: address, amount: u64) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let burn_ref = &authorized_borrow_refs(admin, asset).burn_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        fungible_asset::burn_from(burn_ref, from_wallet, amount);
    }

    /// Freeze an account so it cannot transfer or receive fungible assets.
    public entry fun freeze_account(admin: &signer, account: address) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let wallet = primary_fungible_store::ensure_primary_store_exists(account, asset);
        fungible_asset::set_frozen_flag(transfer_ref, wallet, true);
    }

    /// Unfreeze an account so it can transfer or receive fungible assets.
    public entry fun unfreeze_account(admin: &signer, account: address) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let wallet = primary_fungible_store::ensure_primary_store_exists(account, asset);
        fungible_asset::set_frozen_flag(transfer_ref, wallet, false);
    }

    /// Withdraw as the owner of metadata object ignoring `frozen` field.
    public fun withdraw(admin: &signer, amount: u64, from: address): FungibleAsset acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        fungible_asset::withdraw_with_ref(transfer_ref, from_wallet, amount)
    }

    /// Deposit as the owner of metadata object ignoring `frozen` field.
    public fun deposit(admin: &signer, to: address, fa: FungibleAsset) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        fungible_asset::deposit_with_ref(transfer_ref, to_wallet, fa);
    }

    /// Borrow the immutable reference of the refs of `metadata`.
    /// This validates that the signer is the metadata object's owner.
    inline fun authorized_borrow_refs(
        owner: &signer,
        asset: Object<Metadata>,
    ): &ManagedFungibleAsset acquires ManagedFungibleAsset {
        assert!(object::is_owner(asset, signer::address_of(owner)), error::permission_denied(ENOT_OWNER));
        borrow_global<ManagedFungibleAsset>(object::object_address(&asset))
    }

    #[test(creator = @FACoin)]
    fun test_basic_flow(
        creator: &signer,
    ) acquires ManagedFungibleAsset {
        init_module(creator);
        let creator_address = signer::address_of(creator);
        let aaron_address = @0xface;

        mint(creator, creator_address, 100);
        let asset = get_metadata();
        assert!(primary_fungible_store::balance(creator_address, asset) == 100, 4);
        freeze_account(creator, creator_address);
        assert!(primary_fungible_store::is_frozen(creator_address, asset), 5);
        transfer(creator, creator_address, aaron_address, 10);
        assert!(primary_fungible_store::balance(aaron_address, asset) == 10, 6);

        unfreeze_account(creator, creator_address);
        assert!(!primary_fungible_store::is_frozen(creator_address, asset), 7);
        burn(creator, creator_address, 90);
    }

    #[test(creator = @FACoin, aaron = @0xface)]
    #[expected_failure(abort_code = 0x50001, location = Self)]
    fun test_permission_denied(
        creator: &signer,
        aaron: &signer
    ) acquires ManagedFungibleAsset {
        init_module(creator);
        let creator_address = signer::address_of(creator);
        mint(aaron, creator_address, 100);
    }
}
