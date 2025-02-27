module B2CPurchaseAggregator::b2c_purchase_aggregator {
    use aptos_framework::event;
    use aptos_framework::account::{Self};
    use std::error;
    use std::vector;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::{Metadata};
    use aptos_framework::primary_fungible_store;
    use std::signer;
    use aptos_std::hash;
    use aptos_std::ed25519;
    use std::bcs;

    const ENOT_INITIALIZED: u64 = 1;
    const EINVALID_ARGUMENTS_LENGTH: u64 = 2;
    const EINVALID_SIGNATURE: u64 = 3;
    const EINVALID_ARGUMENTS: u64 = 4;
    const EALREADY_EXIST: u64 = 5;
    const ENOT_OWNER: u64 = 6;
    const EROLE_NOT_EXIST: u64 = 7;
    const ENOT_AUTHORIZED: u64 = 8;

    const SEED: vector<u8> = b"b2c-purchase-aggregator";
    const FA_METADATA_ADDRESS: address =
        @0x357b0b74bc833e95a115ad22604854d6b0fca151cecd94111770e5d6ffc9dc2b;

    struct AdminStore has key {
        admin: address,
        signer_vec: vector<vector<u8>>,
        treasury_account: address,
        treasury_account_cap: account::SignerCapability,
        fa_metadata_address: address,
        update_treasury_account: address
    }

    struct PurchaseData has drop, store {
        from: address,
        amount: u64,
        nonce: u64
    }

    struct ManagedNonce has key{
        nonce: u64
    }

    #[event]
    struct Purchase has drop, store {
        from: address,
        amount: u64
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

    fun signature_verification(
        messageHash: vector<u8>, signature: vector<u8>
    ): bool acquires AdminStore {
        let m_vec = borrow_global<AdminStore>(@B2CPurchaseAggregator).signer_vec;
        let len = vector::length(&m_vec);
        assert!(len > 0, error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        // let res = false;
        let i = 0;

        // Converting Signature Bytes into Ed25519 Signature
        let signatureEd = ed25519::new_signature_from_bytes(signature);
        while (i < len) {
            let pubkey = vector::borrow(&m_vec, i);

            // Converting Public Key Bytes into UnValidated Public Key
            let unValidatedPublickkey =
                ed25519::new_unvalidated_public_key_from_bytes(*pubkey);

            // Verifying Signature using Message Hash and public key
            let res =
                ed25519::signature_verify_strict(
                    &signatureEd, &unValidatedPublickkey, messageHash
                );
            if (res) {
                return true
            } else {
                i = i + 1;
            }
        };
        return false
    }

    inline fun is_signer(signer_pubkey: &vector<u8>): bool acquires AdminStore {
        let t_vec = borrow_global<AdminStore>(@B2CPurchaseAggregator).signer_vec;
        vector::contains(&t_vec, signer_pubkey)
    }

    public fun is_owner(account: address): bool {
        account == @B2CPurchaseAggregator
    }

    fun get_resource_account_sign(): signer acquires AdminStore {
        account::create_signer_with_capability(
            &borrow_global_mut<AdminStore>(@B2CPurchaseAggregator).treasury_account_cap
        )
    }

    inline fun get_metadata_object(object: address): Object<Metadata> {
        object::address_to_object<Metadata>(object)
    }

    fun init_module(admin: &signer) {
        // Verify the caller is the module owner
        assert!(
            is_owner(signer::address_of(admin)),
            error::permission_denied(ENOT_INITIALIZED)
        );

        let (_, treasury_account_cap) = account::create_resource_account(admin, SEED);

        let s_vec = vector::empty<vector<u8>>();
        vector::push_back(
            &mut s_vec, account::get_authentication_key(signer::address_of(admin))
        );
        move_to(
            admin,
            AdminStore {
                admin: signer::address_of(admin),
                signer_vec: s_vec,
                treasury_account: signer::address_of(admin),
                treasury_account_cap: treasury_account_cap,
                fa_metadata_address: FA_METADATA_ADDRESS,
                update_treasury_account: signer::address_of(admin)
            }
        );
        move_to(admin, ManagedNonce{nonce: 0});

       
    }

    public entry fun initiate_purchase(
        from: &signer,
        amount: u64,
        signature: vector<u8>
    ) acquires AdminStore, ManagedNonce {
        assert!(amount >= 0, error::invalid_argument(EINVALID_ARGUMENTS));
        let nonce = ensure_nonce(from);
        let purchase_data = PurchaseData { from: signer::address_of(from), amount, nonce };
        let purchase_data_bytes = bcs::to_bytes<PurchaseData>(&purchase_data);
        let purchase_data_hash = hash::sha2_256(purchase_data_bytes);
        let is_signature_valid = signature_verification(purchase_data_hash, signature);
        assert!(is_signature_valid, error::permission_denied(EINVALID_SIGNATURE));

        let fa_token_address =
            borrow_global<AdminStore>(@B2CPurchaseAggregator).fa_metadata_address;
        let treasury = &get_resource_account_sign();

        primary_fungible_store::transfer(
            treasury,
            get_metadata_object(fa_token_address),
            signer::address_of(from),
            amount
        );

        primary_fungible_store::transfer(
            from,
            get_metadata_object(fa_token_address),
            @B2CPurchaseAggregator,
            amount
        );

        update_nonce(&signer::address_of(from));
        event::emit<Purchase>(Purchase { from: signer::address_of(from), amount: amount })

    }

    public entry fun add_signer_role(
        admin: &signer, new_pubkey: vector<u8>
    ) acquires AdminStore {
        // Check if the new signer already exists in the minter list
        assert!(!is_signer(&new_pubkey), error::invalid_argument(EALREADY_EXIST));

        // Ensure that only the contract owner can add a new signer
        assert!(
            is_owner(signer::address_of(admin)),
            error::permission_denied(ENOT_OWNER)
        );

        // Get the AdminStore role storage reference
        let signer_struct = borrow_global_mut<AdminStore>(@B2CPurchaseAggregator);
        vector::push_back<vector<u8>>(&mut signer_struct.signer_vec, new_pubkey);
    }

    public entry fun remove_signer_role(admin: &signer, signr: vector<u8>) acquires AdminStore {
        // Ensure signer address should exist in the list
        assert!(is_signer(&signr), error::invalid_argument(EROLE_NOT_EXIST));

        // Ensure only owner can remove the signer role
        assert!(
            is_owner(signer::address_of(admin)),
            error::permission_denied(ENOT_OWNER)
        );

        // Get the signer role storage ref
        let signer_struct = borrow_global_mut<AdminStore>(@B2CPurchaseAggregator);

        // Find the index of the signer address in list
        let (_, i) = vector::index_of(&signer_struct.signer_vec, &signr);
        vector::remove(&mut signer_struct.signer_vec, i);
    }

    public entry fun withdraw_from_treasury(
        from: &signer, to: address, amount: u64
    ) acquires AdminStore {
        assert!(
            is_owner(signer::address_of(from)),
            error::permission_denied(ENOT_OWNER)
        );

        let fa_token_address =
            borrow_global<AdminStore>(@B2CPurchaseAggregator).fa_metadata_address;
        let treasury = &get_resource_account_sign();

        primary_fungible_store::transfer(
            treasury,
            get_metadata_object(fa_token_address),
            to,
            amount
        );
    }

    // public entry fun initiate_treasury_account_update(
    //     admin: &signer, treasury: address
    // ) acquires AdminStore {
    //     assert!(
    //         is_owner(signer::address_of(admin)),
    //         error::permission_denied(ENOT_OWNER)
    //     );
    //     let adminStore = borrow_global_mut<AdminStore>(@B2CPurchaseAggregator);
    //     adminStore.update_treasury_account = treasury;
    // }

    // public entry fun accept_treasury_account_update(treasury: &signer) acquires AdminStore {
    //     let adminStore = borrow_global_mut<AdminStore>(@B2CPurchaseAggregator);
    //     assert!(
    //         adminStore.update_treasury_account == signer::address_of(treasury),
    //         error::permission_denied(ENOT_AUTHORIZED)
    //     );
    //     adminStore.treasury_account = signer::address_of(treasury);
    //     let (_, treasury_account_cap) = account::create_resource_account(treasury, SEED);
    //     adminStore.treasury_account_cap = treasury_account_cap;
    // }

    public entry fun update_fa_metadata_address(
        admin: &signer, new_fa_metadata_address: address
    ) acquires AdminStore {
        assert!(
            is_owner(signer::address_of(admin)),
            error::permission_denied(ENOT_OWNER)
        );
        let adminStore = borrow_global_mut<AdminStore>(@B2CPurchaseAggregator);
        adminStore.fa_metadata_address = new_fa_metadata_address;
    }

    //view functions
    #[view]
    public fun get_signers(): vector<vector<u8>> acquires AdminStore {
        borrow_global<AdminStore>(@B2CPurchaseAggregator).signer_vec
    }

    #[view]
    public fun get_treasury_account(): address acquires AdminStore {
        borrow_global<AdminStore>(@B2CPurchaseAggregator).treasury_account
    }

    #[view]
    public fun get_nonce(admin: address) : u64 acquires ManagedNonce{
        if (exists<ManagedNonce>(admin)) borrow_global_mut<ManagedNonce>(admin).nonce else 0
    }
}
