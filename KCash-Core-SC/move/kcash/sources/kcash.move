
module KCashAdmin::kcash {
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
    use aptos_framework::object::{Self, Object, address_to_object, ExtendRef};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::event;
    use aptos_token_objects::collection;
    use aptos_token_objects::token;
    use aptos_std::string_utils::{to_string};
    use std::error;
    use std::signer;
    use std::string::{Self, String, utf8};
    use std::option;
    use std::vector;
    use aptos_std::ed25519;
    use aptos_std::hash;
    use std::bcs;
    use aptos_framework::ordered_map;
    use aptos_framework::big_ordered_map;

    /// Only fungible asset metadata owner can make changes.
    const ENOT_OWNER: u64 = 1;
    const EUSER_DO_NOT_HAVE_BUCKET_STORE: u64 = 2;
    const EAMOUNT_SHOULD_BE_EQUAL_TO_ASSETS: u64 = 3;
    const EAMOUNT_SHOULD_BE_EQUAL_OR_LESS_THAN_BUCKET_ASSETS: u64 = 4;
    const EUSER_ALREADY_HAS_BUCKET_STORE: u64 = 5;
    const EINVALID_ARGUMENTS_LENGTH: u64 = 6;
    const EINVALID_SIGNATURE: u64 = 7;
    const ESIGNATURE_ALREADY_USED: u64 = 8;
    const EINVALID_ROLE: u64 = 9;
    const EALREADY_EXIST: u64 = 10;
    const EROLE_NOT_EXIST: u64 = 11;
    const EINVALID_ARGUMENTS: u64 = 12;
    /// This function is deprecated and cannot be used.
    const EFUNCTION_DEPRECATED: u64 = 13;

    const ASSET_SYMBOL: vector<u8> = b"FA";
    const METADATA_NAME: vector<u8> = b"KCash";
    const ICON_URI: vector<u8> = b"https://kgen.io/favicon.ico";
    const PROJECT_URI: vector<u8> = b"https://kgen.io";
    const BUCKET_CORE_SEED: vector<u8> = b"BA";
    const BUCKET_COLLECTION_DESCRIPTION: vector<u8> = b"Bucket collections";
    const BUCKET_COLLECTION_NAME: vector<u8> = b"Bucket store";
    const FIRST_SIGNER_KEY: vector<u8> = x"d8ff85937b161599d385ef471fa544907a17452cc38afc2c953a8326bf4a7399";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct ManagedFungibleAsset has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct AdminTransferRole has key {
        transfer_role_vec: vector<address>,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct AdminSigner has key {
        signer_vec: vector<vector<u8>>,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct AdminMinterRole has key {
        mint_role_vec: vector<address>,
    }

    struct ManagedNonce has key{
        nonce: u64
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct BucketCore has key {
        bucket_ext_ref: ExtendRef,
    }

    // Kept for storage layout compatibility
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct BucketStore has key{
        reward1: u64,
        reward2: u64,
        reward3: u64,
    }

    /* Structs involved in creation of message for the signature involving methods*/
    struct AdminTransferSignature has drop, store {
        from: address,
        to: address,
        method: String,
        nonce: u64,
        deductionFromSender: vector<u64>,
        additionToRecipient: vector<u64>,
    }

    struct AdminTransferSignatureBulk has drop, store {
        from: address,
        to: vector<address>,
        method: String,
        nonce: u64,
        deductionFromSender1: vector<u64>,
        deductionFromSender2: vector<u64>,
        deductionFromSender3: vector<u64>,
        additionToRecipient1: vector<u64>,
        additionToRecipient2: vector<u64>,
        additionToRecipient3: vector<u64>,
    }

    struct BucketStoreV1 has store {
        reward1: u64,
        reward2: u64,
        reward3: u64,
    }

    struct RewardsBucket has key {
        buckets: ordered_map::OrderedMap<address, BucketStoreV1>,
    }
    struct RewardsBucketV1 has key {
        buckets: big_ordered_map::BigOrderedMap<address, BucketStoreV1>,
    }

    public entry fun initialize_new_buckets(admin: &signer) {
        assert!(!exists<RewardsBucketV1>(signer::address_of(admin)),EALREADY_EXIST);
        let buckets = big_ordered_map::new<address, BucketStoreV1>();
        move_to(admin, RewardsBucketV1 { buckets });
    }

    struct UserTransferWithSign has drop, store{
        from: address,
        to: address,
        method: String,
        amount: u64,
        nonce: u64,
    }

    struct UserTransferWithSignBulk has drop, store {
        from: address,
        method: String,
        nonce: u64,
        to_vec: vector<address>,
        amount_vec: vector<u64>,
    }

    #[event]
    struct DepositToBucket has drop, store {
        receiver: address,
        reward1: u64,
        reward2: u64,
        reward3: u64,
    }
    #[event]
    struct WithdrawFromBucket has drop, store {
        owner: address,
        amount: u64,
    }
    #[event]
    struct TransferBetweenBuckets has drop, store {
        sender: address,
        receiver: address,
        transfered_amount: u64,
    }

    #[event]
    struct SignVerify has drop, store{
        signatureEd: ed25519::Signature,
        result: bool,
    }

    #[event]
    struct AddRole has drop, store{
        role: String,
        added_user: address,
    }

    #[event]
    struct RemoveRole has drop, store{
        role: String,
        removed_user: address,
    }

    // :!:>initialize
    fun init_module(admin: &signer) {
        let bucket_constructor_ref = &object::create_named_object(admin, BUCKET_CORE_SEED);
        let bucket_ext_ref = object::generate_extend_ref(bucket_constructor_ref);
        let bucket_signer = object::generate_signer(bucket_constructor_ref);
        move_to(&bucket_signer, BucketCore{
            bucket_ext_ref,
        });

        create_bucket_store_collection(&bucket_signer);

        let m_vec = vector::empty<address>();
        vector::push_back<address>(&mut m_vec, signer::address_of(admin));
        move_to(admin, AdminMinterRole{mint_role_vec: m_vec});

        let t_vec = vector::empty<address>();
        vector::push_back<address>(&mut t_vec, signer::address_of(admin));
        move_to(admin, AdminTransferRole{transfer_role_vec: t_vec});

        let s_vec = vector::empty<vector<u8>>();
        vector::push_back<vector<u8>>(&mut s_vec, FIRST_SIGNER_KEY);
        move_to(admin, AdminSigner{signer_vec: s_vec});

        move_to(admin, ManagedNonce{nonce: 0});
        let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            utf8(METADATA_NAME), 
            utf8(ASSET_SYMBOL), 
            0, 
            utf8(ICON_URI), 
            utf8(PROJECT_URI), 
        );

        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        let metadata_object_signer = object::generate_signer(constructor_ref);
        move_to(
            &metadata_object_signer,
            ManagedFungibleAsset { mint_ref, transfer_ref, burn_ref }
        )
    }

    /* *** Access control functions *** */

    inline fun is_owner(owner: address) : bool{
        owner == @KCashAdmin
    }

    inline fun verifyMinter(minter: &address): bool acquires AdminMinterRole{
        let m_vec = borrow_global<AdminMinterRole>(@KCashAdmin).mint_role_vec;
        assert!(!vector::is_empty(&m_vec), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        vector::contains(&m_vec, minter)
    }

    inline fun is_signer(signer_pubkey: &vector<u8>): bool acquires AdminSigner{
        let t_vec = borrow_global<AdminSigner>(@KCashAdmin).signer_vec;
        assert!(!vector::is_empty(&t_vec), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        vector::contains(&t_vec, signer_pubkey)
    }

    inline fun verifyAdminTransfer(admin_transfer: &address): bool acquires AdminTransferRole{
        let t_vec = borrow_global<AdminTransferRole>(@KCashAdmin).transfer_role_vec;
        assert!(!vector::is_empty(&t_vec), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        vector::contains(&t_vec, admin_transfer)
    }

    /* *** Viewable functions *** */
    #[view]
    public fun get_nonce(admin: address) : u64 acquires ManagedNonce{
        if (exists<ManagedNonce>(admin)) borrow_global_mut<ManagedNonce>(admin).nonce else 0
    }

    #[view]
    public fun get_minter(): vector<address> acquires AdminMinterRole{
        borrow_global_mut<AdminMinterRole>(@KCashAdmin).mint_role_vec
    }

    #[view]
    public fun get_signers(): vector<vector<u8>> acquires AdminSigner{
        borrow_global_mut<AdminSigner>(@KCashAdmin).signer_vec
    }

    #[view]
    public fun get_admin_transfer(): vector<address> acquires AdminTransferRole{
        borrow_global_mut<AdminTransferRole>(@KCashAdmin).transfer_role_vec
    }

    #[view]
    public fun has_bucket_store(owner_addr: address):bool acquires RewardsBucketV1 {
        let token_address = get_bucket_user_address(&owner_addr);
        let rewards_bucket = borrow_global<RewardsBucketV1>(@KCashAdmin);
        (exists<BucketStore>(token_address) ||  rewards_bucket.buckets.contains(&owner_addr))
    }

    #[view]
    public fun get_bucket_store(owner_addr: address): (u64, u64, u64) acquires BucketStore,RewardsBucketV1 {
        let rewards_bucket = borrow_global<RewardsBucketV1>(@KCashAdmin);
        if (rewards_bucket.buckets.contains(&owner_addr)) {
            let bucket_ref = rewards_bucket.buckets.borrow(&owner_addr);
            (bucket_ref.reward1, bucket_ref.reward2, bucket_ref.reward3)
        } else if(has_bucket_store(owner_addr)){
            let token_address = get_bucket_user_address(&owner_addr);
            let bs = borrow_global<BucketStore>(token_address);
            (bs.reward1, bs.reward2, bs.reward3)
        }
        else {
            (0, 0, 0)
        }
    }

    fun create_bucket_storeV1(user: &address) acquires BucketStore, RewardsBucketV1 {
        let already_new = {
            let view = borrow_global<RewardsBucketV1>(@KCashAdmin);
            view.buckets.contains(user)
        };

        if (already_new) {
            return; 
        };
        let token_address = get_bucket_user_address(user);
        let has_old_bs = exists<BucketStore>(token_address);
  
        if (!has_old_bs) {
            let rb_mut = borrow_global_mut<RewardsBucketV1>(@KCashAdmin);
            let new_bucket = BucketStoreV1 { reward1: 0, reward2: 0, reward3: 0 };
            big_ordered_map::add(&mut rb_mut.buckets, *user, new_bucket);
        } else {
            let (r1, r2, r3) = {
                let old_ref = borrow_global<BucketStore>(token_address);
                (old_ref.reward1, old_ref.reward2, old_ref.reward3)
            }; 
            let migrated = BucketStoreV1 { reward1: r1, reward2: r2, reward3: r3 };
            let rb_mut = borrow_global_mut<RewardsBucketV1>(@KCashAdmin);
            big_ordered_map::add(&mut rb_mut.buckets, *user, migrated);
        }
    }

    public entry fun create_user_new_bucket( amdin:&signer,userAddress:address) acquires BucketStore,RewardsBucketV1 {
        assert!(is_owner(signer::address_of(amdin)), error::permission_denied(ENOT_OWNER));
        create_bucket_storeV1(&userAddress);
    }

    #[view]
    public fun is_new_bucket_extis(user:address) :bool acquires RewardsBucketV1 {
        let rewards_bucket = borrow_global_mut<RewardsBucketV1>(@KCashAdmin);
        rewards_bucket.buckets.contains(&user)
    }

    #[view]
    public fun get_metadata(): Object<Metadata> {
        let asset_address = object::create_object_address(&@KCashAdmin, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }

    fun signature_verification(messageHash: vector<u8>, signature: vector<u8>): bool acquires AdminSigner{
        let m_vec = borrow_global<AdminSigner>(@KCashAdmin).signer_vec;
        let len = vector::length(&m_vec);
        assert!(len > 0, error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        let i = 0;
        let signatureEd = ed25519::new_signature_from_bytes(signature);
        while (i < len) {
            let pubkey = vector::borrow(&m_vec, i);
            let unValidatedPublickkey = ed25519:: new_unvalidated_public_key_from_bytes(*pubkey);
            let res = ed25519::signature_verify_strict(&signatureEd, &unValidatedPublickkey, messageHash);
            if(res) {
                event::emit<SignVerify>(SignVerify{signatureEd, result: true});
                return true
            }
            else{
                i = i + 1;
            }
        };
        event::emit<SignVerify>(SignVerify{signatureEd, result: false});
        return false
    }

    fun create_bucket_store_collection(creator: &signer) {
        let description = utf8(BUCKET_COLLECTION_DESCRIPTION);
        let name = utf8(BUCKET_COLLECTION_NAME);
        let uri = utf8(PROJECT_URI);

        collection::create_unlimited_collection(
            creator,
            description,
            name,
            option::none(),
            uri,
        );
    }

    fun create_bucket_store(user: &address) acquires BucketCore,RewardsBucketV1 {
        let description = utf8(BUCKET_COLLECTION_DESCRIPTION);
        let name = utf8(BUCKET_COLLECTION_NAME);
        let uri = utf8(PROJECT_URI);
        assert!(!has_bucket_store(*user), error::already_exists(EUSER_ALREADY_HAS_BUCKET_STORE));

        let constructor_ref = token::create_named_token(
            &get_bucket_signer(get_bucket_signer_address()),
            name,
            description,
            get_bucket_user_name(user),
            option::none(),
            uri,
        );

        let token_signer = object::generate_signer(&constructor_ref);
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);

        let new_bs = BucketStore{
            reward1: 0,
            reward2: 0,
            reward3: 0,
        };
        move_to(&token_signer, new_bs);
        object::transfer_with_ref(object::generate_linear_transfer_ref(&transfer_ref), *user);
    }

    fun get_bucket_signer_address(): address {
        object::create_object_address(&@KCashAdmin, BUCKET_CORE_SEED)
    }

    fun get_bucket_signer(bucket_signer_address: address): signer acquires BucketCore {
        object::generate_signer_for_extending(&borrow_global<BucketCore>(bucket_signer_address).bucket_ext_ref)
    }

    fun get_bucket_user_name(owner_addr: &address): String {
        let token_name = string::utf8(METADATA_NAME);
        string::append(&mut token_name, to_string(owner_addr));
        token_name
    }

    fun get_bucket_user_address(creator_addr: &address): (address) {
        let bucket_address = token::create_token_address(
            &get_bucket_signer_address(),
            &utf8(BUCKET_COLLECTION_NAME),
            &get_bucket_user_name(creator_addr),
        );
        bucket_address
    }

    fun ensure_bucket_store_exist(user: &address) acquires BucketCore , RewardsBucketV1{
        if(!has_bucket_store(*user)){
            create_bucket_store(user);
        }
    }

    inline fun update_nonce(admin: &address) acquires ManagedNonce{
        let c = borrow_global_mut<ManagedNonce>(*admin);
        c.nonce = c.nonce + 1;
    }

    inline fun ensure_nonce(user: &signer) : u64 acquires ManagedNonce{
        if (!exists<ManagedNonce>(signer::address_of(user))){
            move_to(user, ManagedNonce{ nonce: 0 });
            0
        }
        else borrow_global_mut<ManagedNonce>(signer::address_of(user)).nonce
    }

    // Still used by internal new functions (with r1=0, r2=0)
    fun deposit_to_bucketV1(user: address, r1: u64, r2: u64, r3: u64) acquires RewardsBucketV1,BucketStore {
        create_bucket_storeV1(&user);
        let rewards_bucket_mut = borrow_global_mut<RewardsBucketV1>(@KCashAdmin);
        let bucket_ref = rewards_bucket_mut.buckets.borrow_mut(&user);
        bucket_ref.reward1 = bucket_ref.reward1 + r1;
        bucket_ref.reward2 = bucket_ref.reward2 + r2;
        bucket_ref.reward3 = bucket_ref.reward3 + r3;
    }

    // Active: Logic updated to prioritize reward3
    fun withdraw_amount_from_bucket(owner: address, amount: u64) acquires RewardsBucketV1,BucketStore{
        assert!(has_bucket_store(owner), error::invalid_argument(EUSER_DO_NOT_HAVE_BUCKET_STORE));
        create_bucket_storeV1(&owner);
        let rewards_bucket = borrow_global_mut<RewardsBucketV1>(@KCashAdmin);
        let bs = rewards_bucket.buckets.borrow_mut(&owner);           
        assert!(bs.reward1+bs.reward2+bs.reward3 >= amount, error::invalid_argument(EAMOUNT_SHOULD_BE_EQUAL_OR_LESS_THAN_BUCKET_ASSETS));
        
        if (bs.reward3 >= amount){
            bs.reward3 = bs.reward3 - amount;
        } else if (bs.reward3 + bs.reward2 >= amount){
            bs.reward2 = bs.reward2 - (amount - bs.reward3);
            bs.reward3 = 0;
        } else {
            bs.reward1 = bs.reward1 - (amount - bs.reward2 - bs.reward3);
            bs.reward2 = 0;
            bs.reward3 = 0;
        };
        event::emit(WithdrawFromBucket { owner, amount });
    }

    #[deprecated]
    fun withdraw_rewards_from_bucket(_owner: address, _r1: u64, _r2: u64, _r3: u64) {
        abort error::invalid_state(EFUNCTION_DEPRECATED)
        /* 
        // Original Logic:
        assert!(has_bucket_store(owner), error::invalid_argument(EUSER_DO_NOT_HAVE_BUCKET_STORE));
        create_bucket_storeV1(&owner);
        let rewards_bucket = borrow_global_mut<RewardsBucketV1>(@KCashAdmin);
        let bs = rewards_bucket.buckets.borrow_mut(&owner);
        assert!(bs.reward1 >= r1 && bs.reward2 >= r2 && bs.reward3 >= r3, error::invalid_argument(EAMOUNT_SHOULD_BE_EQUAL_OR_LESS_THAN_BUCKET_ASSETS));
        bs.reward1 = bs.reward1 - r1;
        bs.reward2 = bs.reward2 - r2;
        bs.reward3 = bs.reward3 - r3;
        event::emit(WithdrawFromBucket { owner, amount: r1+r2+r3 });
        */
    }

    #[deprecated]
    fun admin_transfer_reward3_to_user_bucket_internal(_admin: &signer, _user: &address, _amount: u64, _index: u8) {
        abort error::invalid_state(EFUNCTION_DEPRECATED)
        /*
        // Original Logic:
        create_bucket_storeV1(&signer::address_of(admin));
        create_bucket_storeV1(user);
        {   
            let rewards_bucket = borrow_global_mut<RewardsBucketV1>(@KCashAdmin);
            let bs = rewards_bucket.buckets.borrow_mut(&signer::address_of(admin));
            assert!(bs.reward3 >= amount, error::invalid_argument(EAMOUNT_SHOULD_BE_EQUAL_OR_LESS_THAN_BUCKET_ASSETS));
            bs.reward3 = bs.reward3 - amount;
        };

        if (index == 1) {
            deposit_to_bucketV1(*user, amount, 0, 0);
        } else {
            deposit_to_bucketV1(*user, 0, amount, 0);
        };
        transfer_internal(admin, user, amount);
        */
    }

    fun transfer_internal(from: &signer, to: &address, amount: u64) acquires ManagedFungibleAsset{
        let asset = get_metadata();
        let transfer_ref = authorized_borrow_transfer_refs(asset);
        let from_wallet = primary_fungible_store::primary_store(signer::address_of(from), asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(*to, asset);
        fungible_asset::transfer_with_ref(transfer_ref, from_wallet, to_wallet, amount);
    }

    // Helper for active transfers (internal usage)
    fun user_transfer_internal(from: &signer, to: &address, amount: &u64, index: u8) acquires RewardsBucketV1, BucketStore,ManagedFungibleAsset{
        create_bucket_storeV1(&signer::address_of(from));
        create_bucket_storeV1(to);
        {
            let rb_mut = borrow_global_mut<RewardsBucketV1>(@KCashAdmin);
            let bucket_sender = rb_mut.buckets.borrow_mut(&signer::address_of(from));
            assert!(bucket_sender.reward3 >= *amount, error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
            bucket_sender.reward3 = bucket_sender.reward3 - *amount;
        };
        // Deprecated indices will just deposit to R3 in this simplified internal version, or you could abort.
        // Since we are deprecating the public entry points that use indices 0 and 1, 
        // we assume valid calls only come from index 2 (R3) logic.
        if (index == 2) {
             deposit_to_bucketV1(*to, 0, 0, *amount);
        } else {
             // Fallback for deprecated paths if reached internally
             deposit_to_bucketV1(*to, 0, 0, *amount);
        };
        
        transfer_internal(from, to, *amount);
        event::emit(TransferBetweenBuckets { sender: signer::address_of(from), receiver: *to,  transfered_amount: *amount });
    }

    /* -----  Entry functions ----- */

    public entry fun add_minter(admin: &signer, new_minter: address) acquires AdminMinterRole{
        assert!(is_owner(signer::address_of(admin)), error::permission_denied(ENOT_OWNER));
        assert!(!verifyMinter(&new_minter), error::invalid_argument(EALREADY_EXIST));
        let mint_struct = borrow_global_mut<AdminMinterRole>(@KCashAdmin);
        vector::push_back<address>(&mut mint_struct.mint_role_vec, new_minter);
        event::emit(AddRole { role: to_string(&std::string::utf8(b"AdminMinterRole")) , added_user: new_minter, });
    }

    public entry fun add_signer_pkey(admin: &signer, new_pubkey: vector<u8>) acquires AdminSigner{
        assert!(!is_signer(&new_pubkey), error::invalid_argument(EALREADY_EXIST));
        assert!(is_owner(signer::address_of(admin)), error::permission_denied(ENOT_OWNER));
        let signer_struct = borrow_global_mut<AdminSigner>(@KCashAdmin);
        vector::push_back<vector<u8>>(&mut signer_struct.signer_vec, new_pubkey);
    }

    public entry fun add_admin_transfer(admin: &signer, new_admin_transfer: address) acquires AdminTransferRole{
        assert!(is_owner(signer::address_of(admin)), error::permission_denied(ENOT_OWNER));
        assert!(!verifyAdminTransfer(&new_admin_transfer), error::invalid_argument(EALREADY_EXIST));
        let transfer_struct = borrow_global_mut<AdminTransferRole>(@KCashAdmin);
        vector::push_back<address>(&mut transfer_struct.transfer_role_vec, new_admin_transfer);
        event::emit(AddRole { role: to_string(&std::string::utf8(b"AdminTransferRole")) , added_user: new_admin_transfer, });
    }

    public entry fun remove_minter_role(admin: &signer, minter: address) acquires AdminMinterRole{
        assert!(verifyMinter(&minter), error::invalid_argument(EROLE_NOT_EXIST));
        assert!(is_owner(signer::address_of(admin)), error::permission_denied(ENOT_OWNER));
        let minter_struct = borrow_global_mut<AdminMinterRole>(@KCashAdmin);
        let (_, j) = vector::index_of(&minter_struct.mint_role_vec, &minter);
        vector::remove(&mut minter_struct.mint_role_vec, j);
        event::emit(RemoveRole { role: to_string(&std::string::utf8(b"AdminMinterRole")) , removed_user: minter, });
    }

    public entry fun remove_admin_transfer_role(admin: &signer, admin_transfer: address) acquires AdminTransferRole{
        assert!(verifyAdminTransfer(&admin_transfer), error::invalid_argument(EROLE_NOT_EXIST));
        assert!(is_owner(signer::address_of(admin)), error::permission_denied(ENOT_OWNER));
        let transfer_struct = borrow_global_mut<AdminTransferRole>(@KCashAdmin);
        let (_, i) = vector::index_of(&transfer_struct.transfer_role_vec, &admin_transfer);
        vector::remove(&mut transfer_struct.transfer_role_vec, i);
        event::emit(RemoveRole { role: to_string(&std::string::utf8(b"AdminTransferRole")) , removed_user: admin_transfer, });
    }

    public entry fun remove_signer_role(admin: &signer, signr: vector<u8>) acquires AdminSigner{
        assert!(is_signer(&signr), error::invalid_argument(EROLE_NOT_EXIST));
        assert!(is_owner(signer::address_of(admin)), error::permission_denied(ENOT_OWNER));
        let signer_struct = borrow_global_mut<AdminSigner>(@KCashAdmin);
        let (_, i) = vector::index_of(&signer_struct.signer_vec, &signr);
        vector::remove(&mut signer_struct.signer_vec, i);
    }

    // :!:>mint
    /// UPDATED: Mint now only deals with reward3 logic (amount).
    public entry fun mint(
        admin: &signer, 
        to: address, 
        amount: u64
    ) acquires ManagedFungibleAsset, AdminMinterRole ,RewardsBucketV1,BucketStore{
        assert!(verifyMinter(&signer::address_of(admin)), error::invalid_argument(EINVALID_ROLE));
        assert!(amount > 0, error::invalid_argument(EINVALID_ARGUMENTS));
        
        let asset = get_metadata();
        let mint_ref_borrow = authorized_borrow_mint_refs(admin, asset);
        let transfer_ref_borrow = authorized_borrow_transfer_refs(asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);

        let fa = fungible_asset::mint(mint_ref_borrow, amount);
        
        // Always deposit to reward3 (r1=0, r2=0)
        deposit_to_bucketV1(to, 0, 0, amount);
        
        fungible_asset::deposit_with_ref(transfer_ref_borrow, to_wallet, fa);
        fungible_asset::set_frozen_flag(transfer_ref_borrow, to_wallet, true);

    }// <:!:mint_to

    /// UPDATED: Bulk mint now only deals with reward3 logic.
    public entry fun bulk_mint(
        admin: &signer, 
        to_vec: vector<address>, 
        amt_vec: vector<u64>
    ) acquires ManagedFungibleAsset, AdminMinterRole,RewardsBucketV1,BucketStore{
        assert!(verifyMinter(&signer::address_of(admin)), error::invalid_argument(EINVALID_ROLE));
        let len = vector::length(&to_vec);
        assert!(len == vector::length(&amt_vec), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        
        let i = 0;
        while (i < len) {
            let to = vector::borrow(&to_vec, i);
            let amount = vector::borrow(&amt_vec, i);
            mint(admin, *to, *amount);
            i = i + 1; 
        }
    }

    // DEPRECATED with Hard Abort
    #[deprecated]
    public entry fun admin_transfer(_admin: &signer, _to: address, _deductionFromSender: vector<u64>, _additionToRecipient: vector<u64>) {
        abort error::invalid_state(EFUNCTION_DEPRECATED)
        /*
        // Original Logic:
        assert!(verifyAdminTransfer(&signer::address_of(admin)), error::invalid_argument(EINVALID_ROLE));
        assert!(vector::length(&deductionFromSender) == vector::length(&additionToRecipient), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));

        let (r1, r2, r3) = (*vector::borrow(&deductionFromSender, 0), *vector::borrow(&deductionFromSender, 1), *vector::borrow(&deductionFromSender, 2));
        let (a1, a2, a3) = (*vector::borrow(&additionToRecipient, 0), *vector::borrow(&additionToRecipient, 1), *vector::borrow(&additionToRecipient, 2));
        assert!(a1+a2+a3 == r1+r2+r3, error::invalid_argument(EAMOUNT_SHOULD_BE_EQUAL_TO_ASSETS));

        withdraw_rewards_from_bucket(signer::address_of(admin), r1, r2, r3);
        deposit_to_bucketV1(to, a1, a2, a3);
        transfer_internal(admin, &to, r1+r2+r3);
        */
    }
    
    // NEW: Replacement Admin Transfer for Reward3 only
    public entry fun admin_transfer_reward3(admin: &signer, to: address, amount: u64)
        acquires ManagedFungibleAsset,AdminTransferRole,RewardsBucketV1,BucketStore
    {
        assert!(verifyAdminTransfer(&signer::address_of(admin)), error::invalid_argument(EINVALID_ROLE));
        // Deduct from sender (Reward3)
        withdraw_amount_from_bucket(signer::address_of(admin), amount);
        // Add to recipient (Reward3)
        deposit_to_bucketV1(to, 0, 0, amount);
        // Transfer FA
        transfer_internal(admin, &to, amount);
    }

    // DEPRECATED with Hard Abort
    #[deprecated]
    public entry fun admin_transfer_bulk(_admin: &signer, _to_vec: vector<address>, _deductionFromSender_vec: vector<vector<u64>>, _additionToRecipient_vec: vector<vector<u64>>) {
        abort error::invalid_state(EFUNCTION_DEPRECATED)
        /*
        // Original Logic:
        assert!(verifyAdminTransfer(&signer::address_of(admin)), error::invalid_argument(EINVALID_ROLE));
        let len = vector::length(&deductionFromSender_vec);
        assert!(len == vector::length(&additionToRecipient_vec) && len == vector::length(&to_vec), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        let i = 0;
        while (i < len){
            let to = vector::borrow(&to_vec, i);
            let deductionFromSender = vector::borrow(&deductionFromSender_vec, i);
            let additionToRecipient = vector::borrow(&additionToRecipient_vec, i);
            admin_transfer(admin, *to, *deductionFromSender, *additionToRecipient);
            i = i + 1;
        }
        */
    }

    // DEPRECATED with Hard Abort
    #[deprecated]
    public entry fun admin_transfer_reward3_to_user_bucket1(_admin: &signer, _to: address, _amount: u64) {
        abort error::invalid_state(EFUNCTION_DEPRECATED)
        /*
        // Original Logic:
        assert!(verifyAdminTransfer(&signer::address_of(admin)), error::invalid_argument(EINVALID_ROLE));
        assert!(amount >= 0, error::invalid_argument(EINVALID_ARGUMENTS));
        admin_transfer_reward3_to_user_bucket_internal(admin, &to, amount, 1);
        */
    }

    // DEPRECATED with Hard Abort
    #[deprecated]
    public entry fun admin_transfer_reward3_to_user_bucket1_bulk(_admin: &signer, _to_vec: vector<address>, _amount_vec: vector<u64>) {
        abort error::invalid_state(EFUNCTION_DEPRECATED)
        /*
        // Original Logic:
        assert!(vector::length(&to_vec) == vector::length(&amount_vec), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        assert!(verifyAdminTransfer(&signer::address_of(admin)), error::invalid_argument(EINVALID_ROLE));
        let len = vector::length(&to_vec);
        assert!(len == vector::length(&amount_vec), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        let i = 0;
        while (i < len) {
            let to = vector::borrow(&to_vec, i);
            assert!(has_bucket_store(*to), error::invalid_argument(EUSER_DO_NOT_HAVE_BUCKET_STORE));
            let amount = vector::borrow(&amount_vec, i);
            admin_transfer_reward3_to_user_bucket_internal(admin, to, *amount, 1);
            i = i + 1;
        }
        */
    }

    // DEPRECATED with Hard Abort
    #[deprecated]
    public entry fun admin_transfer_reward3_to_user_bucket2(_admin: &signer, _to: address, _amount: u64) {
        abort error::invalid_state(EFUNCTION_DEPRECATED)
        /*
        // Original Logic:
        assert!(verifyAdminTransfer(&signer::address_of(admin)), error::invalid_argument(EINVALID_ROLE));
        assert!(amount >= 0, error::invalid_argument(EINVALID_ARGUMENTS));
        admin_transfer_reward3_to_user_bucket_internal(admin, &to, amount, 2); 
        */
    }

    // DEPRECATED with Hard Abort
    #[deprecated]
    public entry fun admin_transfer_reward3_to_user_bucket2_bulk(_admin: &signer, _to_vec: vector<address>, _amount_vec: vector<u64>) {
        abort error::invalid_state(EFUNCTION_DEPRECATED)
        /*
        // Original Logic:
        assert!(vector::length(&to_vec) == vector::length(&amount_vec), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        assert!(verifyAdminTransfer(&signer::address_of(admin)), error::invalid_argument(EINVALID_ROLE));
        let len = vector::length(&to_vec);
        assert!(len == vector::length(&amount_vec), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        let i = 0;
        while (i < len) {
            let to = vector::borrow(&to_vec, i);
            let amount = vector::borrow(&amount_vec, i);
            admin_transfer_reward3_to_user_bucket_internal(admin, to, *amount, 2);
            i = i + 1;
        }
        */
    }

    /* *** Admin Methods that requires signature *** */
    
    // DEPRECATED with Hard Abort
    #[deprecated]
    public entry fun admin_transfer_with_signature(_admin: &signer, _to: address, _deductnFromSender: vector<u64>, _additnToRecipient: vector<u64>, _signature: vector<u8>) {
        abort error::invalid_state(EFUNCTION_DEPRECATED)
        /*
        // Original Logic:
        assert!(verifyAdminTransfer(&signer::address_of(admin)), error::invalid_argument(EINVALID_ROLE));
        let nonce = ensure_nonce(admin);
        let message = AdminTransferSignature{
            from: signer::address_of(admin),
            to,
            method: string::utf8(b"admin_transfer_with_signature"),
            nonce,
            deductionFromSender: deductnFromSender,
            additionToRecipient: additnToRecipient,
        };    
        let messag_bytes = bcs::to_bytes<AdminTransferSignature>(&message);
        let message_hash = hash::sha2_256(messag_bytes);

        let is_signature_valid = signature_verification(message_hash, signature);
        assert!(is_signature_valid, error::permission_denied(EINVALID_SIGNATURE));

        assert!(vector::length(&deductnFromSender) == vector::length(&additnToRecipient), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        let (r1, r2, r3) = (*vector::borrow(&deductnFromSender, 0), *vector::borrow(&deductnFromSender, 1), *vector::borrow(&deductnFromSender, 2));
        let (a1, a2, a3) = (*vector::borrow(&additnToRecipient, 0), *vector::borrow(&additnToRecipient, 1), *vector::borrow(&additnToRecipient, 2));
        assert!(a1+a2+a3 == r1+r2+r3, error::invalid_argument(EAMOUNT_SHOULD_BE_EQUAL_TO_ASSETS));

        withdraw_rewards_from_bucket(signer::address_of(admin), r1, r2, r3);
        deposit_to_bucketV1(to, a1, a2, a3);
        transfer_internal(admin, &to, r1+r2+r3);
        update_nonce(&signer::address_of(admin));
        */
    }

    // DEPRECATED with Hard Abort
    #[deprecated]
    public entry fun admin_transfer_with_signature_bulk(_admin: &signer, _to_vec: vector<address>, _deductnFromSender1: vector<u64>, _deductnFromSender2: vector<u64>, _deductnFromSender3: vector<u64>, _additnToRecipient1: vector<u64>, _additnToRecipient2: vector<u64>, _additnToRecipient3: vector<u64>, _signature: vector<u8>) {
        abort error::invalid_state(EFUNCTION_DEPRECATED)
        /*
        // Original Logic:
        assert!(verifyAdminTransfer(&signer::address_of(admin)), error::invalid_argument(EINVALID_ROLE));

        let nonce = ensure_nonce(admin);
        let message1 = AdminTransferSignatureBulk{
            from: signer::address_of(admin),
            to: to_vec,
            method: string::utf8(b"admin_transfer_with_signature_bulk"),
            nonce,
            deductionFromSender1: deductnFromSender1,
            deductionFromSender2: deductnFromSender2,
            deductionFromSender3: deductnFromSender3,
            additionToRecipient1: additnToRecipient1,
            additionToRecipient2: additnToRecipient2,
            additionToRecipient3: additnToRecipient3,
        };
                
        let messag_bytes = bcs::to_bytes<AdminTransferSignatureBulk>(&message1);
        let message_hash = hash::sha2_256(messag_bytes);

        let is_signature_valid = signature_verification(message_hash, signature);

        assert!(is_signature_valid, error::permission_denied(EINVALID_SIGNATURE));

        assert!(vector::length(&deductnFromSender1) == vector::length(&additnToRecipient1), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        assert!(vector::length(&deductnFromSender2) == vector::length(&additnToRecipient2), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        assert!(vector::length(&deductnFromSender3) == vector::length(&additnToRecipient3), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        let len = vector::length(&deductnFromSender1);
        let i = 0;

        while (i < len) {
            let d1 = vector::borrow(&deductnFromSender1, i);
            let d2 = vector::borrow(&deductnFromSender2, i);
            let d3 = vector::borrow(&deductnFromSender3, i);
            let a1 = vector::borrow(&additnToRecipient1, i);
            let a2 = vector::borrow(&additnToRecipient2, i);
            let a3 = vector::borrow(&additnToRecipient3, i);
            let toa = vector::borrow(&to_vec, i);
            
            assert!(*d1 + *d2 + *d3 == *a1 + *a2 + *a3, error::invalid_argument(EAMOUNT_SHOULD_BE_EQUAL_TO_ASSETS));
            withdraw_rewards_from_bucket(signer::address_of(admin), *d1, *d2, *d3);
            deposit_to_bucketV1(*toa, *a1, *a2, *a3);
            transfer_internal(admin, toa, *a1 + *a2 + *a3);
            i = i + 1;
        };
        update_nonce(&signer::address_of(admin));
        */
    }

    /* -----  Any one can invoke these fun ----- */

    /// UPDATED: Transfer now uses r3 primarily
    public entry fun transfer(from: &signer, to: address, amount: u64) 
        acquires ManagedFungibleAsset ,RewardsBucketV1,BucketStore {
        assert!(has_bucket_store(signer::address_of(from)), error::invalid_argument(EUSER_DO_NOT_HAVE_BUCKET_STORE));
        assert!(amount >= 0, error::invalid_argument(EINVALID_ARGUMENTS));
        // Withdraw from sender (r3 priority)
        withdraw_amount_from_bucket(signer::address_of(from), amount);
        // Deposit to receiver (strictly r3)
        deposit_to_bucketV1(to, 0, 0, amount);
        event::emit(TransferBetweenBuckets { sender: signer::address_of(from), receiver: to,  transfered_amount: amount });
        transfer_internal(from, &to, amount);
    }

    public entry fun bulk_transfer(from: &signer, receiver_vec: vector<address>, amount_vec: vector<u64>)
        acquires ManagedFungibleAsset ,RewardsBucketV1,BucketStore{
        assert!(has_bucket_store(signer::address_of(from)), error::invalid_argument(EUSER_DO_NOT_HAVE_BUCKET_STORE));
        let len = vector::length(&receiver_vec);
        assert!(len == vector::length(&amount_vec), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        let i = 0;
        while (i < len) {
            let to = vector::borrow(&receiver_vec, i);
            let amount = vector::borrow(&amount_vec, i);
            transfer(from, *to, *amount);
            i = i + 1;
        }
    }   

    // DEPRECATED with Hard Abort
    #[deprecated]
    public entry fun transfer_to_reward3(_sender: &signer, _to: address, _bucket: vector<u64>) {
        abort error::invalid_state(EFUNCTION_DEPRECATED)
        /*
        // Original Logic:
        assert!(has_bucket_store(signer::address_of(sender)), error::invalid_argument(EUSER_DO_NOT_HAVE_BUCKET_STORE));
        let (r1, r2, r3) = (vector::borrow(&bucket, 0), vector::borrow(&bucket, 1), vector::borrow(&bucket, 2));
        let amount = *r1 + *r2 + *r3;
        assert!(amount >= 0, error::invalid_argument(EINVALID_ARGUMENTS));
        create_bucket_storeV1(&signer::address_of(sender));
        create_bucket_storeV1(&to);
        
        let rewards_bucket = borrow_global_mut<RewardsBucketV1>(@KCashAdmin);
        let bucketSender = rewards_bucket.buckets.borrow_mut(&signer::address_of(sender));
        assert!(bucketSender.reward1 >= *r1, error::invalid_argument(EAMOUNT_SHOULD_BE_EQUAL_OR_LESS_THAN_BUCKET_ASSETS));
        assert!(bucketSender.reward2 >= *r2, error::invalid_argument(EAMOUNT_SHOULD_BE_EQUAL_OR_LESS_THAN_BUCKET_ASSETS));
        assert!(bucketSender.reward3 >= *r3, error::invalid_argument(EAMOUNT_SHOULD_BE_EQUAL_OR_LESS_THAN_BUCKET_ASSETS));
        
        if (amount == *r1) {
            bucketSender.reward1 = bucketSender.reward1 - *r1;
        } else {
            if (*r1 != 0) {
                bucketSender.reward1 = bucketSender.reward1 - *r1;
            };
            if (*r2 != 0) {
                bucketSender.reward2 = bucketSender.reward2 - *r2;
            };
            if (*r3 != 0) {
                bucketSender.reward3 = bucketSender.reward3 - *r3;
            }
        };

        deposit_to_bucketV1(to, 0, 0, amount);
        transfer_internal(sender, &to, amount);
        event::emit(TransferBetweenBuckets { sender: signer::address_of(sender), receiver: to,  transfered_amount: amount });
        */
    }

    // DEPRECATED with Hard Abort
    #[deprecated]
    public entry fun transfer_to_reward3_bulk(_sender: &signer, _to_vec: vector<address>, _bucket_vec: vector<vector<u64>>) {
        abort error::invalid_state(EFUNCTION_DEPRECATED)
        /*
        // Original Logic:
        let len = vector::length(&to_vec);
        assert!(len == vector::length(&bucket_vec), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        let i = 0;
        while (i < len) {
            let to = vector::borrow(&to_vec, i);
            let bucket = vector::borrow(&bucket_vec, i);
            transfer_to_reward3(sender, *to, *bucket);
            i = i + 1;
        }
        */
    }   

    public entry fun transfer_reward3_to_reward3 (from: &signer, to: address, amount: u64) acquires ManagedFungibleAsset,RewardsBucketV1,BucketStore{
        assert!(has_bucket_store(signer::address_of(from)), error::invalid_argument(EUSER_DO_NOT_HAVE_BUCKET_STORE));
        user_transfer_internal(from, &to, &amount, 2);
    }

    public entry fun transfer_reward3_to_reward3_bulk (from: &signer, to_vec: vector<address>, amount_vec: vector<u64>) 
        acquires ManagedFungibleAsset,RewardsBucketV1,BucketStore{
        let len = vector::length(&to_vec);
        assert!(len == vector::length(&amount_vec), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        let i = 0;
        while (i < len) {
            let to = vector::borrow(&to_vec, i);
            let amount = vector::borrow(&amount_vec, i);
            transfer_reward3_to_reward3(from, *to, *amount);
            i = i + 1; 
        }
    }

    /* *** Methods that requires signature *** */

    // DEPRECATED with Hard Abort
    #[deprecated]
    public entry fun transfer_reward3_to_reward1(_from: &signer, _to: address, _amount: u64, _signature: vector<u8>) {
        abort error::invalid_state(EFUNCTION_DEPRECATED)
        /*
        // Original Logic:
        assert!(amount >= 0, error::invalid_argument(EINVALID_ARGUMENTS));
        let nonce = ensure_nonce(from);
        let message = UserTransferWithSign{
            from: signer::address_of(from),
            to,
            method: string::utf8(b"transfer_reward3_to_reward1"),
            amount,
            nonce
        };
                
        let messag_bytes = bcs::to_bytes<UserTransferWithSign>(&message);
        let message_hash = hash::sha2_256(messag_bytes);
        let is_signature_valid = signature_verification(message_hash, signature);
        assert!(is_signature_valid, error::permission_denied(EINVALID_SIGNATURE));

        assert!(has_bucket_store(signer::address_of(from)), error::invalid_argument(EUSER_DO_NOT_HAVE_BUCKET_STORE));
        user_transfer_internal(from, &to, &amount, 0);
        update_nonce(&signer::address_of(from));
        */
    }

    // DEPRECATED with Hard Abort
    #[deprecated]
    public entry fun transfer_reward3_to_reward1_bulk(_from: &signer, _to_vec: vector<address>, _amount_vec: vector<u64>, _signature: vector<u8>) {
        abort error::invalid_state(EFUNCTION_DEPRECATED)
        /*
        // Original Logic:
        let len = vector::length(&to_vec);
        assert!(len == vector::length(&amount_vec), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));

        let nonce = ensure_nonce(from);
        let message = UserTransferWithSignBulk{
            from: signer::address_of(from),
            method: string::utf8(b"transfer_reward3_to_reward1_bulk"),
            nonce,
            to_vec,
            amount_vec,
        };
                
        let messag_bytes = bcs::to_bytes<UserTransferWithSignBulk>(&message);
        let message_hash = hash::sha2_256(messag_bytes);
        let is_signature_valid = signature_verification(message_hash, signature);
        assert!(is_signature_valid, error::permission_denied(EINVALID_SIGNATURE));

        assert!(has_bucket_store(signer::address_of(from)), error::invalid_argument(EUSER_DO_NOT_HAVE_BUCKET_STORE));
        let i = 0;
        while (i < len) {
            let to = vector::borrow(&to_vec, i);
            let amount = vector::borrow(&amount_vec, i);
            user_transfer_internal(from, to, amount, 0);
            i = i + 1;
        };
        update_nonce(&signer::address_of(from));
        */
    }

    // DEPRECATED with Hard Abort
    #[deprecated]
    public entry fun transfer_reward3_to_reward2(_from: &signer, _to: address, _amount: u64, _signature: vector<u8>) {
        abort error::invalid_state(EFUNCTION_DEPRECATED)
        /*
        // Original Logic:
        let nonce = ensure_nonce(from);

        let message = UserTransferWithSign{
            from: signer::address_of(from),
            to,
            method: string::utf8(b"transfer_reward3_to_reward2"),
            amount,
            nonce
        };
        let messag_bytes = bcs::to_bytes<UserTransferWithSign>(&message);
        let message_hash = hash::sha2_256(messag_bytes);
        let is_signature_valid = signature_verification(message_hash, signature);
        assert!(is_signature_valid, error::permission_denied(EINVALID_SIGNATURE));

        assert!(has_bucket_store(signer::address_of(from)), error::invalid_argument(EUSER_DO_NOT_HAVE_BUCKET_STORE));
        user_transfer_internal(from, &to, &amount, 1);
        update_nonce(&signer::address_of(from));
        */
    }

    // DEPRECATED with Hard Abort
    #[deprecated]
    public entry fun transfer_reward3_to_reward2_bulk(_from: &signer, _to_vec: vector<address>, _amount_vec: vector<u64>, _signature: vector<u8>) {
        abort error::invalid_state(EFUNCTION_DEPRECATED)
        /*
        // Original Logic:
        let len = vector::length(&to_vec);
        assert!(len == vector::length(&amount_vec), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        let nonce = ensure_nonce(from);
                
        let message = UserTransferWithSignBulk{
            from: signer::address_of(from),
            method: string::utf8(b"transfer_reward3_to_reward2_bulk"),
            nonce,
            to_vec,
            amount_vec,
        };
                
        let messag_bytes = bcs::to_bytes<UserTransferWithSignBulk>(&message);
        let message_hash = hash::sha2_256(messag_bytes);
        let is_signature_valid = signature_verification(message_hash, signature);
        assert!(is_signature_valid, error::permission_denied(EINVALID_SIGNATURE));

        assert!(has_bucket_store(signer::address_of(from)), error::invalid_argument(EUSER_DO_NOT_HAVE_BUCKET_STORE));
        let i = 0;
        while (i < len) {
            let to = vector::borrow(&to_vec, i);
            let amount = vector::borrow(&amount_vec, i);
            user_transfer_internal(from, to, amount, 1);
            i = i + 1;
        };
        update_nonce(&signer::address_of(from));
        */
    }

    /// UPDATED: Burn now also decreases the bucket store balance to keep FA and Bucket synchronized.
    /// It primarily deducts from reward3.
    public entry fun burn(admin: &signer, from: address, amount: u64) acquires ManagedFungibleAsset, RewardsBucketV1, BucketStore {
        // Withdraw from bucket first to ensure sufficient balance and update state
        withdraw_amount_from_bucket(from, amount);

        let asset = get_metadata();
        let burn_ref = &authorized_borrow_refs(admin, asset).burn_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        fungible_asset::burn_from(burn_ref, from_wallet, amount);
    }

    #[view]
    public fun fetch_fungible_token_balance(owner: address): u64 {
        let asset_address = object::create_object_address(&@KCashAdmin, ASSET_SYMBOL);
        let meta_obj = address_to_object<0x1::object::ObjectCore>(asset_address);
        primary_fungible_store::balance<0x1::object::ObjectCore>(owner, meta_obj)
    }

    public entry fun update_user_bucket(admin: &signer, userAddress: address) acquires BucketStore, ManagedFungibleAsset {
        let ft_balance = fetch_fungible_token_balance(userAddress);
        let token_address = get_bucket_user_address(&userAddress);
        let bs = borrow_global<BucketStore>(token_address);
        // This logic assumes r3 is main. 
        if (bs.reward3 > ft_balance) {
             let amount_to_transfer = bs.reward3 - ft_balance;
             transfer_internal(admin, &userAddress, amount_to_transfer);
        }
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
    public fun withdraw(admin: &signer, amount: u64, from: address): FungibleAsset acquires ManagedFungibleAsset, RewardsBucketV1, BucketStore {
        // Must update bucket state too
        withdraw_amount_from_bucket(from, amount);
        
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        fungible_asset::withdraw_with_ref(transfer_ref, from_wallet, amount)
    }

    public entry fun reset_user_bucketV1(admin:&signer,user:address) acquires RewardsBucketV1 {
        let rewards_bucket_mut = borrow_global_mut<RewardsBucketV1>(@KCashAdmin);
        assert!(is_owner(signer::address_of(admin)), error::permission_denied(ENOT_OWNER));
        let bucket_ref = rewards_bucket_mut.buckets.borrow_mut(&user);
        bucket_ref.reward1 = 0;
        bucket_ref.reward2 = 0;
        bucket_ref.reward3 = 0;
    } 

    /// Deposit as the owner of metadata object ignoring `frozen` field.
    public fun deposit(admin: &signer, to: address, fa: FungibleAsset) acquires ManagedFungibleAsset, RewardsBucketV1, BucketStore {
        let amount = fungible_asset::amount(&fa);
        // Deposit to reward3
        deposit_to_bucketV1(to, 0, 0, amount);

        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        fungible_asset::deposit_with_ref(transfer_ref, to_wallet, fa);
    }
 
    inline fun authorized_borrow_mint_refs(owner: &signer, asset: Object<Metadata>, ): &MintRef acquires ManagedFungibleAsset, AdminMinterRole{
        assert!(verifyMinter(&signer::address_of(owner)), error::invalid_argument(EINVALID_ROLE));
        let ref = borrow_global<ManagedFungibleAsset>(object::object_address(&asset));
        &ref.mint_ref
    }

    inline fun authorized_borrow_transfer_refs(asset: Object<Metadata>, ): &TransferRef acquires ManagedFungibleAsset{
        let ref = borrow_global<ManagedFungibleAsset>(object::object_address(&asset));
        &ref.transfer_ref
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

    #[test(creator = @KCashAdmin)]
    fun test_basic_flow(
        creator: &signer,
    ) acquires ManagedFungibleAsset, AdminMinterRole ,RewardsBucketV1,BucketStore {
        init_module(creator);
        let creator_address = signer::address_of(creator);
        let aaron_address = @0xface;

        // Updated mint call: only (admin, to, amount)
        mint(creator, creator_address, 100);
        
        let asset = get_metadata();
        assert!(primary_fungible_store::balance(creator_address, asset) == 100, 4);
        freeze_account(creator, creator_address);
        assert!(primary_fungible_store::is_frozen(creator_address, asset), 5);
        
        // Transfer triggers withdraw from bucket, then transfer FA
        transfer(creator, aaron_address, 10);
        assert!(primary_fungible_store::balance(aaron_address, asset) == 10, 6);

        unfreeze_account(creator, creator_address);
        assert!(!primary_fungible_store::is_frozen(creator_address, asset), 7);
        
        // Burn now handles bucket updates
        burn(creator, creator_address, 90);
    }

    #[test(creator = @KCashAdmin, aaron = @0xface)]
    #[expected_failure(abort_code = 0x50001, location = Self)]
    fun test_permission_denied(
        creator: &signer,
        aaron: &signer
    ) acquires ManagedFungibleAsset, AdminMinterRole ,RewardsBucketV1,BucketStore {
        init_module(creator);
        let creator_address = signer::address_of(creator);
        mint(aaron, creator_address, 100);
    }
}