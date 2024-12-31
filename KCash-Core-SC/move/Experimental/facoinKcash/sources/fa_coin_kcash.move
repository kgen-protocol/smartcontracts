/// A 2-in-1 module that combines managed_fungible_asset and coin_example into one module that when deployed, the
/// deployer will be creating a new managed fungible asset with the hardcoded supply config, name, symbol, and decimals.
/// The address of the asset can be obtained via get_metadata(). As a simple version, it only deals with primary stores.
module FACoinAddr::fa_coin_kcash {
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use std::error;
    use std::signer;
    use std::string::utf8;
    use std::option;
    use std::vector;

    /// Map key already exists
    const EKEY_ALREADY_EXISTS: u64 = 1;
    /// Map key is not found
    const EKEY_NOT_FOUND: u64 = 2;
    /// Only fungible asset metadata owner can make changes.
    /// 
    const ENOT_OWNER: u64 = 3;

    const EAMOUNT_SHOULD_BE_EQUAL_TO_ASSETS: u64 = 4;


    const ASSET_SYMBOL: vector<u8> = b"KFA";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Hold refs to control the minting, transfer and burning of fungible assets.
    struct ManagedFungibleAsset has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
    }

    struct BucketAssets has copy, drop, store{
        reward1: u64,
        reward2: u64,
        reward3: u64,
    }

    struct BucketStore has key, copy{
        data: vector<BucketMap>,
    }

    struct BucketMap has copy, drop, store {
        key: address,
        value: BucketAssets,
    }

    public fun init_bucket_store(admin: &signer){
        let ba = BucketAssets{
            reward1:0,
            reward2:0,
            reward3:0,
        };
        let bm = BucketMap{
            key: signer::address_of(admin),
            value: ba,
        };
        let bs = BucketStore { data: vector::empty()};
        vector::push_back(&mut bs.data, bm);
        move_to(
            admin,
            bs
        );
    }

    /// Initialize metadata object and store the refs.
    // :!:>initialize
    fun init_module(admin: &signer) {
        let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            utf8(b"KCashFA"), /* name */
            utf8(ASSET_SYMBOL), /* symbol */
            8, /* decimals */
            utf8(b"http://example.com/favicon.ico"), /* icon */
            utf8(b"http://example.com"), /* project */
        );
        init_bucket_store(admin);
        
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
        let asset_address = object::create_object_address(&@FACoinAddr, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }

    //TODO: add Bucket param
    // :!:>mint
    /// Mint as the owner of metadata object and deposit to a specific account.
    public entry fun mint(admin: &signer, to: address, amount: u64, reward1: u64, reward2: u64, reward3: u64) acquires ManagedFungibleAsset, BucketStore {
        assert!(reward1+reward2+reward3 == amount, error::invalid_argument(EAMOUNT_SHOULD_BE_EQUAL_TO_ASSETS));
        let asset = get_metadata();
        let managed_fungible_asset = authorized_borrow_refs(admin, asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);

        let ba = BucketAssets{
            reward1,
            reward2,
            reward3,
        };

        let fa = fungible_asset::mint(&managed_fungible_asset.mint_ref, amount);
        
        //pupulate bucket props
        deposit_to_bucket(signer::address_of(admin), to, ba);

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

    #[view]
    public fun length(admin: address): u64 acquires BucketStore{
        let bucket_map = borrow_global_mut<BucketStore>(admin).data;
        vector::length(&bucket_map)
    }
    

    // Insert key/Bucket value pair or update an existing key to a new value
    fun deposit_to_bucket(
        admin: address,
        key: address,
        value: BucketAssets
    ) acquires BucketStore{
        let bucket_store = borrow_global_mut<BucketStore>(admin);
        let bucket_map = bucket_store.data;

        let maybe_idx = find(&bucket_map, &key);
        if(option::is_some(&maybe_idx)){
            let idx = option::extract(&mut maybe_idx);
            let exist_ba = &mut vector::borrow_mut(&mut bucket_map, idx).value;

            let new_ba = BucketAssets{
                reward1: value.reward1+exist_ba.reward1,
                reward2: value.reward2+exist_ba.reward2,
                reward3: value.reward3+exist_ba.reward3,
            };

            let len = vector::length(&bucket_map);
            vector::push_back(&mut bucket_map, BucketMap { key, value: new_ba });
            vector::swap(&mut bucket_map, idx, len);
            vector::pop_back(&mut bucket_map);
            // return (std::option::some(key), std::option::some(value))
        }
        else{
            vector::push_back(&mut bucket_map, BucketMap { key, value });
        }
    }

    #[view]
    /// To view the reward of the user
    public fun getRewards(admin: address) : BucketStore acquires BucketStore{
        let bucket_map = borrow_global_mut<BucketStore>(admin);
        *bucket_map
        // let maybe_idx = find(&bucket_map, &user);
        // // assert!(option::is_some(&maybe_idx), error::invalid_argument(EKEY_NOT_FOUND));

        // let idx = option::extract(&mut maybe_idx);
        // let bs = vector::borrow_mut(&mut bucket_map, idx).value;
        // bs.reward1
    }

    /// To check if the key is already presents
    fun contains_key(
        map: &vector<BucketMap>,
        key: &address,
    ): bool {
        let maybe_idx = find(map, key);
        option::is_some(&maybe_idx)
    }

    /// To find out the index of the user bucket store in the map
    fun find(
        map: &vector<BucketMap>,
        key: &address,
    ): option::Option<u64> {
        let leng = vector::length(map);
        let i = 0;
        while (i < leng) {
            let element = vector::borrow(map, i);
            if (&element.key == key) {
                return option::some(i)
            };
            i = i + 1;
        };
        option::none<u64>()
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

    #[test(creator = @FACoinAddr)]
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

    #[test(creator = @FACoinAddr, aaron = @0xface)]
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
