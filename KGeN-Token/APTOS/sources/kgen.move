module kgen::kgen {
    use std::option;
    use std::vector;
    use std::signer::{Self, address_of};
    use std::string::{Self, utf8, String};
    use aptos_std::big_ordered_map::{Self, BigOrderedMap};
    use aptos_framework::event;
    use aptos_framework::function_info;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::object::{Self, ExtendRef, Object};
    use aptos_framework::fungible_asset::{Self, BurnRef, MintRef, TransferRef, MutateMetadataRef, FungibleStore,
        Metadata, FungibleAsset
    };

    // Errors
    /// Caller is not authorized to make this call
    const EUNAUTHORIZED: u64 = 1;
    /// The account is frozen and cannot perform the operation
    const EFROZEN: u64 = 2;
    /// The sender account is frozen and cannot send tokens
    const EFROZEN_SENDING: u64 = 3;
    /// The recipient account is frozen and cannot receive tokens
    const EFROZEN_RECEIVING: u64 = 4;
    /// The account is not frozen so the operation is not allowed
    const ENOT_FROZEN: u64 = 5;
    /// The length of the vectors do not match
    const EARGUMENT_VECTORS_LENGTH_MISMATCH: u64 = 6;
    /// Cannot transfer admin to the same address
    const ESAME_ADMIN: u64 = 7;
    /// Invalid asset
    const EINVALID_ASSET: u64 = 8;
    /// Provided address is not a burn vault address
    const ENOT_BURNVAULT: u64 = 9;
    /// When Address already exists
    const EALREADY_EXIST: u64 = 10;
    /// When given Address not treasury address
    const ENOT_TREASURY_ADDRESS: u64 = 11;
    /// When given Address not minter address
    const ENOT_MINTER_ADDRESS: u64 = 12;
    /// The Token is paused.
    const EPAUSED: u64 = 13;


    // Constants
    const KGEN_NAME: vector<u8> = b"KGEN";
    const KGEN_SYMBOL: vector<u8> = b"KGEN";
    const KGEN_DECIMALS: u8 = 8;
    const KGEN_ICON_URI: vector<u8> = b"";
    const PROJECT_URI: vector<u8> = b"";
    const KGEN_MAX_SUPPLY: u128 = 100_000_000_000_000_000;

    // KGEN Resource for Management
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct KgenManagement has key {
        extend_ref: ExtendRef,
        mint_ref: MintRef,
        burn_ref: BurnRef,
        transfer_ref: TransferRef,
        mutate_metadata_ref: MutateMetadataRef,
        admin: address,
        pending_admin: address,
        burn_vault: address,
        freeze_sending: BigOrderedMap<address, bool>,
        freeze_receiving: BigOrderedMap<address, bool>,
        minter_vec: vector<address>,
        treasury_vec: vector<address>,
        paused: bool
    }

    // Events
    #[event]
    // Triggered when new tokens are minted
    struct Mint has drop, store {
        to: address,
        amount: u64
    }

    #[event]
    // Triggered when tokens are burned
    struct Burn has drop, store {
        from: address,
        store: Object<FungibleStore>,
        amount: u64
    }

    #[event]
    // Triggered when accounts are frozen
    struct Freeze has drop, store {
        account: address,
        freeze_sending: bool,
        freeze_receiving: bool
    }

    #[event]
    // Triggered when accounts are unfrozen
    struct Unfreeze has drop, store {
        account: address,
        unfreeze_sending: bool,
        unfreeze_receiving: bool
    }

    #[event]
    // Triggered when admin is transferred
    struct TransferAdmin has drop, store {
        admin: address,
        pending_admin: address
    }

    #[event]
    // Triggered when admin accepts transfer
    struct AcceptAdmin has drop, store {
        old_admin: address,
        new_admin: address
    }

    #[event]
    // Triggered when new address added to treasury
    struct AddTreasuryAddress has drop, store {
        added_address: address
    }

    #[event]
    // Triggered when new address removed from treasury
    struct RemoveTreasuryAddress has drop, store {
        removed_address: address
    }

    #[event]
    // Triggered when new address added to minter
    struct AddMinterAddress has drop, store {
        added_address: address
    }

    // Triggered when new address removed from minter
    #[event]
    struct RemoveMinterAddress has drop, store {
        removed_address: address
    }

    #[event]
    // Triggered when burn vault is updated
    struct UpdateBurnVault has drop, store {
        old_burn_vault: address,
        new_burn_vault: address
    }

    #[event]
    // Triggered when pause is updated
    struct UpdatePause has drop, store {
        is_paused: bool
    }

    // Views
    #[view]
    // Get the address of the KGEN token
    public fun kgen_address(): address {
        object::create_object_address(&@kgen, KGEN_SYMBOL)
    }

    #[view]
    // Get the metadata of the KGEN token
    public fun metadata(): Object<Metadata> {
        object::address_to_object(kgen_address())
    }

    #[view]
    // Get the metadata of the KGEN token
    public fun admin(): address acquires KgenManagement {
        let kgen_management_ref = get_kgen_management_ref();
        kgen_management_ref.admin
    }

    #[view]
    // Check if the token is paused
    public fun is_paused(): bool acquires KgenManagement {
        let management = get_kgen_management_ref();
        management.paused
    }

    #[view]
    // Check if an account is frozen for sending and receiving
    public fun is_frozen(account: address): (bool, bool) acquires KgenManagement {
        let management = get_kgen_management_ref();
        management.is_frozen_internal(account)
    }

    #[view]
    // Get the burn vault
    public fun burn_vault(): address acquires KgenManagement {
        let management = get_kgen_management_ref();
        management.burn_vault
    }

    // Initialize the module
    fun init_module(kgen_signer: &signer) {
        // Create the token with primary store support.
        let constructor_ref = &object::create_named_object(kgen_signer, KGEN_SYMBOL);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::some(KGEN_MAX_SUPPLY),
            utf8(KGEN_NAME),
            utf8(KGEN_SYMBOL),
            KGEN_DECIMALS,
            string::utf8(KGEN_ICON_URI),
            string::utf8(PROJECT_URI)
        );

        // Set ALL stores for the fungible asset to untransferable.
        fungible_asset::set_untransferable(constructor_ref);

        // Create mint/burn/transfer/mutate_metadata_ref refs to allow admin to manage the token.
        let metadata_object_signer = &object::generate_signer(constructor_ref);
        move_to(
            metadata_object_signer,
            KgenManagement {
                extend_ref: object::generate_extend_ref(constructor_ref),
                mint_ref: fungible_asset::generate_mint_ref(constructor_ref),
                burn_ref: fungible_asset::generate_burn_ref(constructor_ref),
                transfer_ref: fungible_asset::generate_transfer_ref(constructor_ref),
                mutate_metadata_ref: fungible_asset::generate_mutate_metadata_ref(constructor_ref),
                admin: @admin,
                pending_admin: @0x0,
                burn_vault: @burn_vault,
                freeze_sending: big_ordered_map::new_with_reusable(),
                freeze_receiving: big_ordered_map::new_with_reusable(),
                treasury_vec: vector::empty(),
                minter_vec: vector[@admin],
                paused: false
            }
        );

        let deposit =
            function_info::new_function_info(
                kgen_signer,
                string::utf8(b"kgen"),
                string::utf8(b"deposit")
            );
        let withdraw =
            function_info::new_function_info(
                kgen_signer,
                string::utf8(b"kgen"),
                string::utf8(b"withdraw")
            );
        dispatchable_fungible_asset::register_dispatch_functions(
            constructor_ref,
            option::some(withdraw),
            option::some(deposit),
            option::none()
        );
    }

    // Entry Functions
    /// Mint new tokens to the specified treasury address. Can only be called by the admin.
    public entry fun mint(
        minter: &signer,
        to: address,
        amount: u64
    ) acquires KgenManagement {
        let management = get_kgen_management_ref();
        management.assert_is_minter(&address_of(minter));
        management.assert_is_treasury(&to);
        let primary_store =
            primary_fungible_store::ensure_primary_store_exists(to, metadata());
        management.assert_not_frozen(to, false, true);
        let tokens = fungible_asset::mint(&management.mint_ref, amount);
        fungible_asset::deposit_with_ref(
            &management.transfer_ref, primary_store, tokens
        );
        event::emit(Mint { to, amount });
    }

    // Update the project and icon uri. Can only be called by the admin.
    entry fun mutate_project_and_icon_uri(
        admin: &signer, project_uri: String, icon_uri: String
    ) acquires KgenManagement {
        let management = get_kgen_management_ref();
        management.assert_is_admin(admin);
        fungible_asset::mutate_metadata(
            &management.mutate_metadata_ref,
            option::none(),
            option::none(),
            option::none(),
            option::some(icon_uri),
            option::some(project_uri)
        );
    }

    // Deposit function override to ensure that the account is not frozen.
    public fun deposit<T: key>(
        store: Object<T>, fa: FungibleAsset, transfer_ref: &TransferRef
    ) acquires KgenManagement {
        assert!(
            fungible_asset::transfer_ref_metadata(transfer_ref) == metadata(),
            EINVALID_ASSET
        );
        let management = get_kgen_management_ref();
        management.assert_not_paused();
        management.assert_not_frozen(object::owner(store), false, true);
        fungible_asset::deposit_with_ref(transfer_ref, store, fa);
    }

    // Withdraw function override to ensure that the account is not frozen.
    public fun withdraw<T: key>(
        store: Object<T>, amount: u64, transfer_ref: &TransferRef
    ): FungibleAsset acquires KgenManagement {
        assert!(
            fungible_asset::transfer_ref_metadata(transfer_ref) == metadata(),
            EINVALID_ASSET
        );
        let management = get_kgen_management_ref();
        management.assert_not_paused();
        management.assert_not_frozen(object::owner(store), true, false);
        fungible_asset::withdraw_with_ref(transfer_ref, store, amount)
    }

    // Transfer tokens from a frozen account. Can only be called by admin
    public entry fun transfer(
        admin: &signer,
        from: address,
        to: address,
        amount: u64
    ) acquires KgenManagement {
        transfer_store(
            admin,
            primary_fungible_store::ensure_primary_store_exists(from, metadata()),
            to,
            amount
        );
    }

    // Transfer tokens from a frozen account's specific store. Can only be called by admin
    public entry fun transfer_store(
        admin: &signer,
        from_store: Object<FungibleStore>,
        to: address,
        amount: u64
    ) acquires KgenManagement {
        let management = get_kgen_management_ref();
        management.assert_is_admin(admin);
        management.assert_is_frozen(object::owner(from_store));
        let to_store = primary_fungible_store::ensure_primary_store_exists(
            to, metadata()
        );
        fungible_asset::transfer_with_ref(&management.transfer_ref, from_store, to_store, amount);
    }

    // Burn tokens from the burn vault. Can only be called by admin
    public entry fun burn(admin: &signer, account: address, amount: u64) acquires KgenManagement {
        let store =
            primary_fungible_store::ensure_primary_store_exists(account, metadata());
        burn_store(admin, store, amount);
    }

    // Burn tokens from the burn vault's stores. Can only be called by admin
    public entry fun burn_store(
        admin: &signer, store: Object<FungibleStore>, amount: u64
    ) acquires KgenManagement {
        let management = get_kgen_management_ref();
        management.assert_is_admin(admin);
        assert!(object::owner(store) == management.burn_vault, ENOT_BURNVAULT);
        burn_internal(management, store, amount);
    }

    fun burn_internal(
        management: &KgenManagement, store: Object<FungibleStore>, amount: u64
    ) {
        let tokens =
            fungible_asset::withdraw_with_ref(&management.transfer_ref, store, amount);
        fungible_asset::burn(&management.burn_ref, tokens);
        event::emit(Burn { from: object::owner(store), store, amount });
    }

    // Freeze an account. Can only be called by the admin.
    public entry fun freeze_accounts(
        admin: &signer,
        accounts: vector<address>,
        sending_flags: vector<bool>,
        receiving_flags: vector<bool>
    ) acquires KgenManagement {
        assert!(
            accounts.length() == sending_flags.length(),
            EARGUMENT_VECTORS_LENGTH_MISMATCH
        );
        assert!(
            accounts.length() == receiving_flags.length(),
            EARGUMENT_VECTORS_LENGTH_MISMATCH
        );
        let management = get_kgen_management_mut_ref();
        management.assert_is_admin(admin);
        for (i in 0..accounts.length()) {
            let account = *accounts.borrow(i);
            let freeze_sending = *sending_flags.borrow(i);
            // Only set if the value is true to disallow unfreezing by passing false to this freeze function.
            if (freeze_sending && !management.freeze_sending.contains(&account)) {
                management.freeze_sending.add(account, true);
            };
            let freeze_receiving = *receiving_flags.borrow(i);
            if (freeze_receiving && !management.freeze_receiving.contains(&account)) {
                management.freeze_receiving.add(account, true);
            };
            event::emit(Freeze { account, freeze_sending, freeze_receiving });
        }
    }

    // Unfreeze an account. Can only be called by the admin.
    public entry fun unfreeze_accounts(
        admin: &signer,
        accounts: vector<address>,
        unfreeze_sending: vector<bool>,
        unfreeze_receiving: vector<bool>
    ) acquires KgenManagement {
        assert!(
            accounts.length() == unfreeze_sending.length(),
            EARGUMENT_VECTORS_LENGTH_MISMATCH
        );
        assert!(
            accounts.length() == unfreeze_receiving.length(),
            EARGUMENT_VECTORS_LENGTH_MISMATCH
        );
        let management = get_kgen_management_mut_ref();
        management.assert_is_admin(admin);
        for (i in 0..accounts.length()) {
            let account = *accounts.borrow(i);
            let unfreeze_sending = *unfreeze_sending.borrow(i);
            let unfreeze_receiving = *unfreeze_receiving.borrow(i);
            if (unfreeze_sending
                && management.freeze_sending.contains(&account)) {
                management.freeze_sending.remove(&account);
            };
            if (unfreeze_receiving
                && management.freeze_receiving.contains(&account)) {
                management.freeze_receiving.remove(&account);
            };
            event::emit(Unfreeze { account, unfreeze_sending, unfreeze_receiving });
        }
    }

    // Set the pending admin to the specified new admin. The new admin still needs to accept to become the admin.
    public entry fun transfer_admin(admin: &signer, new_admin: address) acquires KgenManagement {
        let management = get_kgen_management_mut_ref();
        management.assert_is_admin(admin);
        assert!(signer::address_of(admin) != new_admin, ESAME_ADMIN);
        management.pending_admin = new_admin;
        event::emit(TransferAdmin { admin: management.admin, pending_admin: new_admin });
    }

    // Accept the admin role. This can only be called by the pending admin.
    public entry fun accept_admin(pending_admin: &signer) acquires KgenManagement {
        let management = get_kgen_management_mut_ref();
        assert!(
            signer::address_of(pending_admin) == management.pending_admin,
            EUNAUTHORIZED
        );
        let old_admin = management.admin;
        management.admin = management.pending_admin;
        management.pending_admin = @0x0;
        event::emit(AcceptAdmin { old_admin, new_admin: management.admin });
    }

    // Add a new treasury address. Can only be called by the admin.
    public entry fun add_treasury_address(admin: &signer, new_treasury_addr: address) acquires KgenManagement {
        let management = get_kgen_management_mut_ref();
        management.assert_is_admin(admin);
        assert!(!management.treasury_vec.contains(&new_treasury_addr), EALREADY_EXIST);
        management.treasury_vec.push_back(new_treasury_addr);
        event::emit(AddTreasuryAddress { added_address: new_treasury_addr });
    }

    // Remove a treasury address. Can only be called by the admin.
    public entry fun remove_treasury_address(admin: &signer, treasury_addr: address) acquires KgenManagement {
        let management = get_kgen_management_mut_ref();
        management.assert_is_admin(admin);
        management.assert_is_treasury(&treasury_addr);
        // Find the index of the treausy address
        let (_, i) = management.treasury_vec.index_of(&treasury_addr);
        management.treasury_vec.remove(i);
        event::emit(RemoveTreasuryAddress { removed_address: treasury_addr });
    }

    // Add a new minter address. Can only be called by the admin.
    public entry fun add_minter(admin: &signer, new_minter_addr: address) acquires KgenManagement {
        let management = get_kgen_management_mut_ref();
        management.assert_is_admin(admin);
        assert!(!management.minter_vec.contains(&new_minter_addr), EALREADY_EXIST);
        management.minter_vec.push_back(new_minter_addr);
        event::emit(AddMinterAddress { added_address: new_minter_addr });
    }

    // Remove a minter address. Can only be called by the admin.
    public entry fun remove_minter_address(admin: &signer, minter_addr: address) acquires KgenManagement {
        let management = get_kgen_management_mut_ref();
        management.assert_is_admin(admin);
        management.assert_is_minter(&minter_addr);
        // Find the index of the treausy address
        let (_, i) = management.minter_vec.index_of(&minter_addr);
        management.minter_vec.remove(i);
        event::emit(RemoveMinterAddress { removed_address: minter_addr });
    }

    // Update the burn vault. Can only be called by the admin.
    public entry fun update_burn_vault(admin: &signer, new_burn_vault: address) acquires KgenManagement {
        let management = get_kgen_management_mut_ref();
        management.assert_is_admin(admin);
        let old_burn_vault = management.burn_vault;
        management.burn_vault = new_burn_vault;
        event::emit(UpdateBurnVault { old_burn_vault, new_burn_vault });
    }

    // Update the pause state. Can only be called by the admin.
    public entry fun set_pause(admin: &signer, is_paused: bool) acquires KgenManagement {
        let management = get_kgen_management_mut_ref();
        management.assert_is_admin(admin);
        management.paused = is_paused;
        event::emit(UpdatePause { is_paused });
    }

    // Internal utility functions
    inline fun get_kgen_management_ref(): &KgenManagement {
        &KgenManagement[kgen_address()]
    }

    inline fun get_kgen_management_mut_ref(): &mut KgenManagement {
        &mut KgenManagement[kgen_address()]
    }

    // Assert if the given signer is admin
    inline fun assert_is_admin(self: &KgenManagement, account: &signer) {
        assert!(signer::address_of(account) == self.admin, EUNAUTHORIZED);
    }

    // Assert if given address is treasury
    inline fun assert_is_treasury(self: &KgenManagement, treasury: &address) {
        assert!(self.treasury_vec.contains(treasury), ENOT_TREASURY_ADDRESS)
    }

    // Assert if given address is minter
    inline fun assert_is_minter(self: &KgenManagement, minter: &address) {
        assert!(self.minter_vec.contains(minter), ENOT_MINTER_ADDRESS)
    }

    // Checks if a store is frozen directly
    inline fun assert_is_frozen(self: &KgenManagement, account: address) {
        let (store_frozen_sending, store_frozen_receiving) =
            self.is_frozen_internal(account);
        let is_store_frozen = store_frozen_sending || store_frozen_receiving;
        assert!(is_store_frozen, ENOT_FROZEN);
    }

    // Chech if sending and receiving frozen for a given address
    inline fun is_frozen_internal(self: &KgenManagement, account: address): (bool, bool) {
        let freeze_sending =
            self.freeze_sending.contains(&account);
        let freeze_receiving =
            self.freeze_receiving.contains(&account);
        (freeze_sending, freeze_receiving)
    }

    // Assert if the the store is frozen for given address
    inline fun assert_not_frozen(
        self: &KgenManagement, account: address, check_sending: bool, check_receiving: bool
    ) {
        let frozen_sending =
            self.freeze_sending.contains(&account);
        assert!(!check_sending || !frozen_sending, EFROZEN_SENDING);
        let frozen_receiving =
            self.freeze_receiving.contains(&account);
        assert!(!check_receiving || !frozen_receiving, EFROZEN_RECEIVING);
    }

    // Assert if given address is minter
    inline fun assert_not_paused(self: &KgenManagement) {
        assert!(!self.paused, EPAUSED)
    }

    #[test_only]
    use aptos_framework::account;
    #[test_only]
    const KGEN_ADDR: address = @kgen;
    #[test_only]
    const ADMIN_ADDR: address = @admin;
    #[test_only]
    const BURN_VAULT_ADDR: address = @burn_vault;
    #[test_only]
    const TEST_TREASURY1: address = @0x100;
    #[test_only]
    const TEST_TREASURY2: address = @0x101;
    #[test_only]
    const TEST_USER1: address = @0x102;
    #[test_only]
    const TEST_USER2: address = @0x103;
    #[test_only]
    const TEST_PENDING_ADMIN: address = @0x104;
    #[test_only]
    const TEST_MINTER: address = @0x105;
    #[test_only]
    const TEST_NEW_BURN_VAULT: address = @0x106;
    #[test_only]
    const TEST_EXTRA_TREASURY: address = @0x107;

    #[test_only]
    public fun init_for_test() {
        init_module(&account::create_signer_for_test(@kgen));
    }

    #[test_only]
    // Get the metadata of the KGEN token
    public fun pending_admin(): address acquires KgenManagement {
        let kgen_management_ref = get_kgen_management_ref();
        kgen_management_ref.pending_admin
    }

    #[test]
    // Test the initialization of the module
    fun test_init() acquires KgenManagement {
        init_for_test();
        let management_addr = kgen_address();
        assert!(object::is_object(management_addr), 1000);
        let management = borrow_global<KgenManagement>(management_addr);
        assert!(management.admin == ADMIN_ADDR, 1001);
        assert!(management.pending_admin == @0x0, 1002);
        assert!(management.burn_vault == BURN_VAULT_ADDR, 1003);
        assert!(management.treasury_vec.is_empty(), 1004);
        assert!(management.minter_vec.length() == 1, 1005);
        assert!(management.minter_vec[0] == ADMIN_ADDR, 1006);
        let meta = metadata();
        assert!(fungible_asset::name(meta) == string::utf8(KGEN_NAME), 1007);
        assert!(fungible_asset::symbol(meta) == string::utf8(KGEN_SYMBOL), 1008);
        assert!(fungible_asset::decimals(meta) == KGEN_DECIMALS, 1009);
        assert!(fungible_asset::maximum(meta) == option::some(KGEN_MAX_SUPPLY), 1010);
        assert!(fungible_asset::supply(meta) == option::some(0u128), 1011);
    }

    #[test]
    // Test the addition of a treasury address
    fun test_add_treasury() acquires KgenManagement {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        add_treasury_address(&admin_signer, TEST_TREASURY1);
        let management = borrow_global<KgenManagement>(kgen_address());
        assert!(management.treasury_vec.contains(&TEST_TREASURY1), 2000);
    }

    #[test]
    #[expected_failure(abort_code = EALREADY_EXIST)]
    // Test the addition of a treasury address that already exists
    fun test_add_treasury_already_exists() acquires KgenManagement {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        add_treasury_address(&admin_signer, TEST_TREASURY1);
        add_treasury_address(&admin_signer, TEST_TREASURY1);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED)]
    // Test the addition of a treasury address by a non-admin
    fun test_add_treasury_non_admin() acquires KgenManagement {
        init_for_test();
        let bad_signer = account::create_signer_for_test(TEST_USER1);
        add_treasury_address(&bad_signer, TEST_TREASURY1);
    }

    #[test]
    // Test the removal of a treasury address
    fun test_remove_treasury() acquires KgenManagement {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        add_treasury_address(&admin_signer, TEST_TREASURY1);
        remove_treasury_address(&admin_signer, TEST_TREASURY1);
        let management = borrow_global<KgenManagement>(kgen_address());
        assert!(!management.treasury_vec.contains(&TEST_TREASURY1), 3000);
    }

    #[test]
    #[expected_failure(abort_code = ENOT_TREASURY_ADDRESS)]
    // Test the removal of a treasury address that does not exist
    fun test_remove_treasury_not_exists() acquires KgenManagement {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        remove_treasury_address(&admin_signer, TEST_TREASURY1);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED)]
    // Test the removal of a treasury address by a non-admin
    fun test_remove_treasury_non_admin() acquires KgenManagement {
        init_for_test();
        let bad_signer = account::create_signer_for_test(TEST_USER1);
        remove_treasury_address(&bad_signer, TEST_TREASURY1);
    }

    #[test]
    // Test the addition of a minter address
    fun test_add_minter() acquires KgenManagement {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        add_minter(&admin_signer, TEST_MINTER);
        let management = borrow_global<KgenManagement>(kgen_address());
        assert!(management.minter_vec.contains(&TEST_MINTER), 4000);
    }

    #[test]
    #[expected_failure(abort_code = EALREADY_EXIST)]
    // Test the addition of a minter address that already exists
    fun test_add_minter_already_exists() acquires KgenManagement {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        add_minter(&admin_signer, TEST_MINTER);
        add_minter(&admin_signer, TEST_MINTER);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED)]
    // Test the addition of a minter address by a non-admin
    fun test_add_minter_non_admin() acquires KgenManagement {
        init_for_test();
        let bad_signer = account::create_signer_for_test(TEST_USER1);
        add_minter(&bad_signer, TEST_MINTER);
    }

    #[test]
    // Test the removal of a minter address
    fun test_remove_minter() acquires KgenManagement {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        add_minter(&admin_signer, TEST_MINTER);
        remove_minter_address(&admin_signer, TEST_MINTER);
        let management = borrow_global<KgenManagement>(kgen_address());
        assert!(!management.minter_vec.contains(&TEST_MINTER), 5000);
    }

    #[test]
    #[expected_failure(abort_code = ENOT_MINTER_ADDRESS)]
    // Test the removal of a minter address that does not exist
    fun test_remove_minter_not_exists() acquires KgenManagement {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        remove_minter_address(&admin_signer, TEST_MINTER);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED)]
    // Test the removal of a minter address by a non-admin
    fun test_remove_minter_non_admin() acquires KgenManagement {
        init_for_test();
        let bad_signer = account::create_signer_for_test(TEST_USER1);
        remove_minter_address(&bad_signer, TEST_MINTER);
    }

    #[test]
    // Test the mutation of the project and icon URI
    fun test_mutate_project_and_icon_uri() acquires KgenManagement {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        let new_project_uri = string::utf8(b"https://newproject.com");
        let new_icon_uri = string::utf8(b"https://newicon.com");
        mutate_project_and_icon_uri(&admin_signer, new_project_uri, new_icon_uri);
        let meta = metadata();
        assert!(fungible_asset::project_uri(meta) == new_project_uri, 7000);
        assert!(fungible_asset::icon_uri(meta) == new_icon_uri, 7001);
    }

    #[test]
    #[expected_failure(abort_code = EUNAUTHORIZED)]
    // Test the mutation of the project and icon URI by a non-admin
    fun test_mutate_project_and_icon_uri_non_admin() acquires KgenManagement {
        init_for_test();
        let bad_signer = account::create_signer_for_test(TEST_USER1);
        mutate_project_and_icon_uri(&bad_signer, string::utf8(b""), string::utf8(b""));
    }

    #[test]
    // Test the pause state
    fun test_pause_state() acquires KgenManagement {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        set_pause(&admin_signer, true);
        assert!(is_paused(), 8000);
    }


    #[test]
    // Test the pause state by a non-admin
    #[expected_failure(abort_code = EUNAUTHORIZED)]
    fun test_pause_state_non_admin() acquires KgenManagement {
        init_for_test();
        let bad_signer = account::create_signer_for_test(TEST_USER1);
        set_pause(&bad_signer, true);
    }

    #[test]
    // Test the unpause state after pause
    fun test_unpause_state() acquires KgenManagement {
        init_for_test();
        let admin_signer = account::create_signer_for_test(ADMIN_ADDR);
        set_pause(&admin_signer, true);
        assert!(is_paused(), 9000);
        set_pause(&admin_signer, false);
        assert!(!is_paused(), 9001);
    }
}