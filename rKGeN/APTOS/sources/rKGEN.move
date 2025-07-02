module rKGenAdmin::rKGEN {
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::{
        Self,
        MintRef,
        TransferRef,
        BurnRef,
        Metadata,
        FungibleAsset
    };
    use aptos_framework::function_info;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::system_addresses;
    use std::signer;
    use std::option;
    use aptos_std::string_utils::{to_string};
    use std::error;
    use std::vector;
    use std::event;
    use std::string::{Self, String, utf8};

    // Constants for error codes to simplify error handling and debugging 0x4368a9b21de66ed31a5cf95c9cab30b062f0f0724d0aa291b1ace2d812c46605
    /// It is already exist
    const EALREADY_EXIST: u64 = 1;
    /// Provided address is not a treasury address
    const ENOT_TREASURY_ADDRESS: u64 = 2;
    /// Provided address is not a whitelist sender address
    const ENOT_WHITELIST_SENDER: u64 = 3;
    /// Provided address is not a whitelist receiver address
    const ENOT_WHITELIST_RECEIVER: u64 = 4;
    /// Only admin can invoke this
    const EONLY_ADMIN: u64 = 5;
    /// Provided address is not Admin
    const ENOT_ADMIN: u64 = 6;
    /// Here treasury address cannot be deleted
    const ECANNOT_DELETE_TREASURY_ADDRESS: u64 = 7;
    /// Provided address is neither a whitelist sender nor receiver address
    const EINVALIDRECEIVERORSENDER: u64 = 8;
    /// Provided address is not a burnable address
    const ENOT_BURNVAULT: u64 = 9;
    /// Provided address is not a valid address
    const ENOT_VALID_ADDRESS: u64 = 10;
    /// Only owner of the module can invoke this
    const ENOT_OWNER: u64 = 11;
    /// No nominated address here
    const ENO_PENDING: u64 = 12;
    /// Please enter amount more than 0
    const EINVALID_AMOUNT: u64 = 13;

    // Metadata values for the fungible asset
    const ASSET_SYMBOL: vector<u8> = b"rKGEN";
    const METADATA_NAME: vector<u8> = b"rKGEN";
    const ICON_URI: vector<u8> = b"https://prod-image-bucket.kgen.io/assets/rkgen-logo.png";
    const PROJECT_URI: vector<u8> = b"https://kgen.io";

    /* ----------- Resources (Global storage) ----------*/
    // Stores references for minting, transferring, and burning of rKGEN tokens.
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct ManagedRKGenAsset has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Admin has key {
        admin: address
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct NominatedAdmin has key {
        nominated_admin: option::Option<address>
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // Stores the multisig address used for minting purposes and a burnvault address.
    struct MintingManager has key {
        minter: address,
        burnable: address
    }

    // Stores treasury addresses allowed to mint and transfer tokens.
    // Stores whitelist sender addresses allowed to send tokens to anyone.
    // Stores whitelist receiver addresses allowed to receive tokens from anyone.
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct WhiteListed has key {
        treasury_vec: vector<address>,
        sender_vec: vector<address>,
        receiver_vec: vector<address>
    }

    /* Events */
    // Event triggered when tokens are minted to a treasury address.
    #[event]
    struct MintedToTreasury has drop, store {
        treasury: address,
        amount: u64
    }

    // Event triggered when tokens are transferred from whitelist address.
    #[event]
    struct Transfer has drop, store {
        from: address,
        receiver: address,
        amount: u64
    }

    // Triggered when onwer updated the admin
    #[event]
    struct UpdatedBurnVault has drop, store {
        role: String,
        updated_address: address
    }

    // Triggered when onwer updated the admin
    #[event]
    struct UpdatedAdmin has drop, store {
        role: String,
        added_admin: address
    }

    // Triggered when onwer nominate the new admin
    #[event]
    struct NominatedAdminEvent has drop, store {
        role: String,
        nominated_admin: address
    }

    // Triggered when onwer updated the minter (multisig account)
    #[event]
    struct UpdatedMinter has drop, store {
        role: String,
        added_user: address
    }

    // Triggered when rKGen owner added a new address to treasury
    #[event]
    struct AddedTreasuryAddress has drop, store {
        msg: String,
        added_address: address
    }

    // Triggered when owner removed a address from treasury
    #[event]
    struct RemovedTreasuryAddress has drop, store {
        msg: String,
        removed_address: address
    }

    // Event triggered when address added to sender whitelist.
    #[event]
    struct AddedSenderAddress has drop, store {
        msg: String,
        added_address: address
    }

    // Event triggered when address removed from sender whitelist.
    #[event]
    struct RemovedSenderAddress has drop, store {
        msg: String,
        removed_address: address
    }

    // Event triggered when address added to receiver whitelist.
    #[event]
    struct AddedReceiverAddress has drop, store {
        msg: String,
        added_address: address
    }

    // Event triggered when address removed from receiver whitelist.
    #[event]
    struct RemovedReceiverAddress has drop, store {
        msg: String,
        removed_address: address
    }

    /*Views*/
    #[view]
    // Return the address of the managed fungible asset that's created when this module is deployed.
    public fun get_metadata_addr(): address {
        object::create_object_address(&@rKGenAdmin, ASSET_SYMBOL)
    }

    #[view]
    // Return the address of the managed fungible asset that's created when this module is deployed.
    public fun get_metadata(): Object<Metadata> {
        let asset_address = object::create_object_address(&@rKGenAdmin, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }

    //Function to view the available admin address
    #[view]
    // Return the admin address.
    public fun get_admin(): address acquires Admin {
        borrow_global<Admin>(@rKGenAdmin).admin
    }

    //Function to view the available admin address
    #[view]
    // Return the admin address.
    public fun get_nominated_admin(): option::Option<address> acquires NominatedAdmin {
        borrow_global<NominatedAdmin>(@rKGenAdmin).nominated_admin
    }

    //Function to view the available burnable address
    #[view]
    public fun get_burn_vault(): address acquires MintingManager {
        borrow_global<MintingManager>(@rKGenAdmin).burnable
    }

    //Function to view the address of minter
    #[view]
    public fun get_minter(): address acquires MintingManager {
        borrow_global<MintingManager>(@rKGenAdmin).minter
    }

    //Function to view the available addresses in treasury
    #[view]
    public fun get_treasury_address(): vector<address> acquires WhiteListed {
        borrow_global<WhiteListed>(@rKGenAdmin).treasury_vec
    }

    //Function to view the available addresses in SenderWhiteList
    #[view]
    public fun get_whitelisted_sender(): vector<address> acquires WhiteListed {
        borrow_global<WhiteListed>(@rKGenAdmin).sender_vec
    }

    //Function to view the available in reciever whitelisted
    #[view]
    public fun get_whitelisted_receiver(): vector<address> acquires WhiteListed {
        borrow_global<WhiteListed>(@rKGenAdmin).receiver_vec
    }

    /* Initialization - Asset Creation, Register Dispatch Functions and initialize resources */
    fun init_module(admin: &signer) {
        // Initialize the rKGen

        /* Stores the global storage for the addresses of minter manager (Multisig wallet address) */
        move_to(
            admin,
            MintingManager {
                minter: signer::address_of(admin),
                burnable: signer::address_of(admin)
            }
        );

        /* Stores the global storage for the addresses of Admin role */
        move_to(
            admin,
            Admin { admin: signer::address_of(admin) }
        );

        // Stores the global storage for the addresses of  treasury address
        // Stores the global storage for the addresses of  whitelist sender
        // Stores the global storage for the addresses of  admin transfer role
        let t_vec = vector::empty<address>();
        let s_vec = vector::empty<address>();
        let r_vec = vector::empty<address>();
        move_to(
            admin,
            WhiteListed { treasury_vec: t_vec, sender_vec: s_vec, receiver_vec: r_vec }
        );

        /*
         Here we're initializing the metadata for rKGen fungible asset,
        */
        let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::some(200_000_000_00000000), /* Supply 200* 10^8 (8 decimals)*/
            utf8(METADATA_NAME), /* name */
            utf8(ASSET_SYMBOL), /* symbol */
            8, /* decimals */
            utf8(ICON_URI), /* icon */
            utf8(PROJECT_URI) /* project */
        );

        // Create mint/burn/transfer refs to allow creator to manage the fungible asset.
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        let metadata_object_signer = object::generate_signer(constructor_ref);

        move_to(
            &metadata_object_signer,
            ManagedRKGenAsset { mint_ref, transfer_ref, burn_ref }
        );

        // Override the deposit function.
        // This ensures all transfer will call the deposit function in this module which checks if the receiver is whitelisted.
        let deposit =
            function_info::new_function_info(
                admin,
                string::utf8(b"rKGEN"),
                string::utf8(b"deposit")
            );

        // Override the withdraw function.
        // This ensures all transfer will call the withdraw function in this module which checks if the sender is whitelisted.
        let withdraw =
            function_info::new_function_info(
                admin,
                string::utf8(b"rKGEN"),
                string::utf8(b"withdraw")
            );
        dispatchable_fungible_asset::register_dispatch_functions(
            constructor_ref,
            option::some(withdraw),
            option::some(deposit),
            option::none()
        );
    }

    /* Dispatchable Hooks */
    /// Deposit function override to impose only whitlisted receiver can transfer through native method.
    public fun deposit<T: key>(
        store: Object<T>, fa: FungibleAsset, _transfer_ref: &TransferRef
    ) {
        fungible_asset::deposit_with_ref(_transfer_ref, store, fa);
    }

    /* Dispatchable Hooks */
    /// Withdraw function override to impose onlu whitlisted sender can transfer through native method.
    public fun withdraw<T: key>(
        store: Object<T>, amount: u64, transfer_ref: &TransferRef
    ): FungibleAsset acquires WhiteListed {
        let owner = object::owner(store);
        assert!(verify_sender(&owner), error::unauthenticated(ENOT_WHITELIST_SENDER));
        assert_amount(amount);

        // Withdraw the remaining amount from the input store and return it.
        fungible_asset::withdraw_with_ref(transfer_ref, store, amount)
    }

    /* -----  Entry functions that can be called from outside ----- */
    // :!:>mint
    // Mint as the minter role and deposit to a specific account.
    // Only multisig wallet can invoke the mint capability
    public entry fun mint(
        admin: &signer, to: address, amount: u64
    ) acquires ManagedRKGenAsset, MintingManager, WhiteListed {
        assert_minter(&signer::address_of(admin));
        assert_amount(amount);

        assert!(
            verify_treasury(&to),
            error::unauthenticated(ENOT_TREASURY_ADDRESS)
        );

        let asset = get_metadata();

        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);

        let mint_ref_borrow = &authorized_borrow_refs(asset).mint_ref;
        let fa = fungible_asset::mint(mint_ref_borrow, amount);

        let transfer_ref_borrow = &authorized_borrow_refs(asset).transfer_ref;

        fungible_asset::deposit_with_ref(transfer_ref_borrow, to_wallet, fa);

        event::emit(MintedToTreasury { treasury: to, amount: amount });

    } // <:!:mint_to

    /* Transfer */
    // transfer function
    public entry fun transfer(
        sender: &signer, to: address, amount: u64
    ) acquires ManagedRKGenAsset, WhiteListed {
        assert_amount(amount);
        assert!(
            verify_sender(&signer::address_of(sender)) || verify_receiver(&to),
            error::invalid_argument(EINVALIDRECEIVERORSENDER)
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

    /* -----  Entry functions that can be called from outside by Admin Only ----- */
    // Upgraded code to store nominated admin
    public entry fun init_nominated_resource(owner: &signer){
        assert!(
            signer::address_of(owner) == @rKGenAdmin,
            error::permission_denied(ENOT_OWNER)
        );
        assert!(
            !exists<NominatedAdmin>(@rKGenAdmin),
            error::already_exists(EALREADY_EXIST)
        );
        move_to(owner, NominatedAdmin { nominated_admin: option::none() });
    }

    public entry fun update_admin(
        admin_addr: &signer, new_admin: address
    ) acquires Admin, NominatedAdmin {
        // Ensure that only admin can add a new admin
        assert_admin(admin_addr);

        // Ensure that new_admin should be a valid address
        assert!(
            new_admin != @0x0
                && !system_addresses::is_framework_reserved_address(new_admin),
            error::unauthenticated(ENOT_VALID_ADDRESS)
        );
        assert!(
            signer::address_of(admin_addr) != new_admin,
            error::already_exists(EALREADY_EXIST)
        );

        // Get the Nominated Admin Role storage reference
        let admin_struct = borrow_global_mut<NominatedAdmin>(@rKGenAdmin);
        // Nominate the new admin
        admin_struct.nominated_admin = option::some(new_admin);

        event::emit(
            NominatedAdminEvent {
                role: to_string(
                    &std::string::utf8(
                        b"New Admin Nominated, Now new admin need to accept the role"
                    )
                ),
                nominated_admin: new_admin
            }
        );
    }

    public entry fun accept_admin_role(new_admin: &signer) acquires NominatedAdmin, Admin {
        let n_admin_struct = borrow_global_mut<NominatedAdmin>(@rKGenAdmin);
        // Ensure that nominated address exist
        let pending_admin = option::borrow(&n_admin_struct.nominated_admin);
        assert!(
            !option::is_none(&n_admin_struct.nominated_admin),
            error::unauthenticated(ENO_PENDING)
        );
        assert!(
            *pending_admin == signer::address_of(new_admin),
            error::unauthenticated(ENOT_VALID_ADDRESS)
        );

        // Get the Admin Role storage reference
        let admin_struct = borrow_global_mut<Admin>(@rKGenAdmin);
        // Add the new admin
        admin_struct.admin = signer::address_of(new_admin);
        n_admin_struct.nominated_admin = option::none();

        event::emit(
            UpdatedAdmin {
                role: to_string(&std::string::utf8(b"New Admin Added")),
                added_admin: signer::address_of(new_admin)
            }
        );
    }

    // Updating minting and burning manager
    public entry fun update_minter(
        admin_addr: &signer, new_address: address
    ) acquires Admin, MintingManager {
        // Ensure that only admin can add a new admin
        assert_admin(admin_addr);
        // Ensure that new_address should be a valid address
        assert!(
            new_address != @0x0
                && !system_addresses::is_framework_reserved_address(new_address),
            error::unauthenticated(ENOT_VALID_ADDRESS)
        );

        // Get the Admin Role storage reference
        let admin_struct = borrow_global_mut<MintingManager>(@rKGenAdmin);

        // Check if the new address already exists
        assert!(
            admin_struct.minter != new_address, error::already_exists(EALREADY_EXIST)
        );

        // Add the new admin
        admin_struct.minter = new_address;

        event::emit(
            UpdatedMinter {
                role: to_string(&std::string::utf8(b"NewMinter")),
                added_user: new_address
            }
        );
    }

    public entry fun update_burn_vault(
        admin_addr: &signer, new_address: address
    ) acquires Admin, MintingManager {
        // Ensure that only admin can add a new admin
        assert_admin(admin_addr);
        // Ensure that new_address should be a valid address
        assert!(
            new_address != @0x0
                && !system_addresses::is_framework_reserved_address(new_address),
            error::unauthenticated(ENOT_VALID_ADDRESS)
        );

        // Get the Admin Role storage reference
        let admin_struct = borrow_global_mut<MintingManager>(@rKGenAdmin);

        // Check if the new address already exists
        assert!(
            admin_struct.burnable != new_address, error::already_exists(EALREADY_EXIST)
        );

        // Add the new admin
        admin_struct.burnable = new_address;

        event::emit(
            UpdatedBurnVault {
                role: to_string(&std::string::utf8(b"Burnable Address Updated")),
                updated_address: new_address
            }
        );
    }

    /* ----------- Functions For Treasury Management ----------*/
    // Function to add new address to the treausry Only invoked by the admin
    public entry fun add_treasury_address(
        admin: &signer, new_address: address
    ) acquires Admin, WhiteListed {
        // Ensure that only admin can add a new treausry
        assert_admin(admin);

        // Check if the new treasury address already exists in the treasury list
        assert!(
            !verify_treasury(&new_address),
            error::already_exists(EALREADY_EXIST)
        );

        if (!verify_sender(&new_address)) {
            // Get the AdminMinterRole storage reference
            let s_struct = borrow_global_mut<WhiteListed>(@rKGenAdmin);

            // Add the new minter to the minter list
            vector::push_back<address>(&mut s_struct.sender_vec, new_address);
            event::emit(
            AddedSenderAddress {
                msg: to_string(&std::string::utf8(b"New Sender Address Whitelisted")),
                added_address: new_address
            }
        );
        };

        // Get the Treasury storage reference
        let t_struct = borrow_global_mut<WhiteListed>(@rKGenAdmin);

        // Add the new address to the treasury list
        vector::push_back<address>(&mut t_struct.treasury_vec, new_address);
        event::emit(
            AddedTreasuryAddress {
                msg: to_string(&std::string::utf8(b"New Treasury Address Added")),
                added_address: new_address
            }
        );
    }

    // Function to remove existing address from the treausry Only invoked by the admin
    public entry fun remove_treasury_address(
        admin: &signer, treasury_address: address
    ) acquires Admin, WhiteListed {
        // Ensure that only admin can remove a treausry address
        assert_admin(admin);
        // Check if the treasury address exists in the treasury list or not
        assert!(
            verify_treasury(&treasury_address),
            error::unauthenticated(ENOT_TREASURY_ADDRESS)
        );

        // Get the Treasury storage reference
        let t_struct = borrow_global_mut<WhiteListed>(@rKGenAdmin);

        // Find the index of the treausy address in list
        let (_, j) = vector::index_of(&t_struct.treasury_vec, &treasury_address);
        vector::remove(&mut t_struct.treasury_vec, j);
        event::emit(
            RemovedTreasuryAddress {
                msg: to_string(&std::string::utf8(b"Treasury Address Removed")),
                removed_address: treasury_address
            }
        );
    }

    /* ----------- Functions For Whitelisted Sender Management ----------*/
    // Function to add new address to the whitelist of sender Only invoked by the admin
    public entry fun add_whitelist_sender(
        admin: &signer, new_address: address
    ) acquires Admin, WhiteListed {
        // Ensure that only admin can add a new whitelist sender
        assert_admin(admin);

        // Check if the new address already exists in the whitelist
        assert!(
            !verify_sender(&new_address),
            error::already_exists(EALREADY_EXIST)
        );

        // Get the AdminMinterRole storage reference
        let s_struct = borrow_global_mut<WhiteListed>(@rKGenAdmin);

        // Add the new minter to the minter list
        vector::push_back<address>(&mut s_struct.sender_vec, new_address);
        event::emit(
            AddedSenderAddress {
                msg: to_string(&std::string::utf8(b"New Sender Address Whitelisted")),
                added_address: new_address
            }
        );
    }

    // Function to remove existing address from the whitelist of sender Only invoked by the admin
    public entry fun remove_whitelist_sender(
        admin: &signer, sender_address: address
    ) acquires WhiteListed, Admin {
        // Ensure that admin can remove a whitelist address
        assert_admin(admin);

        // Check if the whitelist address exists in the whitelist
        assert!(
            verify_sender(&sender_address),
            error::invalid_argument(ENOT_WHITELIST_SENDER)
        );

        // Check if the new treasury address already exists in the treasury list
        assert!(
            !verify_treasury(&sender_address),
            error::invalid_argument(ECANNOT_DELETE_TREASURY_ADDRESS)
        );

        // Get the SenderWhiteList storage reference
        let s_struct = borrow_global_mut<WhiteListed>(@rKGenAdmin);

        // Find the index of the whitelist address in list
        let (_, j) = vector::index_of(&s_struct.sender_vec, &sender_address);
        vector::remove(&mut s_struct.sender_vec, j);
        event::emit(
            RemovedSenderAddress {
                msg: to_string(
                    &std::string::utf8(b"Sender Address Removed From Whitelist")
                ),
                removed_address: sender_address
            }
        );
    }

    /* ----------- Functions For Whitelisted Receiver Management ----------*/
    // Function to add new address to the whitelist of receiver Only invoked by the admin
    public entry fun add_whitelist_receiver(
        admin: &signer, new_address: address
    ) acquires WhiteListed, Admin {
        // Ensure that only admin can add a new address
        assert_admin(admin);
        // Check if the new receiver address exists in the whitelist
        assert!(
            !verify_receiver(&new_address),
            error::already_exists(EALREADY_EXIST)
        );

        // Get the ReceiverWhiteList storage reference
        let r_struct = borrow_global_mut<WhiteListed>(@rKGenAdmin);

        // Add the address to the whitelist
        vector::push_back<address>(&mut r_struct.receiver_vec, new_address);
        event::emit(
            AddedReceiverAddress {
                msg: to_string(&std::string::utf8(b"New Receiver Address Whitelisted")),
                added_address: new_address
            }
        );
    }

    // Function to remove existing address from the whitelist of receiver Only invoked by the admin
    public entry fun remove_whitelist_receiver(
        admin: &signer, receiver_address: address
    ) acquires WhiteListed, Admin {
        // Ensure that only admin can remove a receiver
        assert_admin(admin);
        // Check if the address exists in the list
        assert!(
            verify_receiver(&receiver_address),
            error::invalid_argument(ENOT_WHITELIST_RECEIVER)
        );

        // Get the ReceiverWhiteList storage reference
        let r_struct = borrow_global_mut<WhiteListed>(@rKGenAdmin);

        // Find the index of the receiver address in list
        let (_, j) = vector::index_of(&r_struct.receiver_vec, &receiver_address);
        vector::remove(&mut r_struct.receiver_vec, j);
        event::emit(
            RemovedReceiverAddress {
                msg: to_string(
                    &std::string::utf8(b"Receiver Address Removed From Whitelist")
                ),
                removed_address: receiver_address
            }
        );
    }

    /// Burn fungible assets as the owner of metadata object. Only invoked by the admin
    public entry fun burn(
        admin: &signer, from: address, amount: u64
    ) acquires ManagedRKGenAsset, Admin, MintingManager {
        assert_admin(admin);
        assert_amount(amount);

        // Get the Admin Role storage reference
        let admin_struct = borrow_global_mut<MintingManager>(@rKGenAdmin);

        // Check if the from is burnable vault
        assert!(
            admin_struct.burnable == from, error::unauthenticated(ENOT_VALID_ADDRESS)
        );
        let asset = get_metadata();
        let burn_ref = &authorized_borrow_refs(asset).burn_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        fungible_asset::burn_from(burn_ref, from_wallet, amount);
    }

    // Freeze an account so it cannot transfer or receive fungible assets. Only invoked by the admin
    public entry fun freeze_account(admin: &signer, account: address) acquires ManagedRKGenAsset, Admin {
        // Ensure that only admin can freeze account
        assert_admin(admin);
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(asset).transfer_ref;
        let wallet = primary_fungible_store::ensure_primary_store_exists(account, asset);
        fungible_asset::set_frozen_flag(transfer_ref, wallet, true);
    }

    // Unfreeze an account so it can transfer or receive fungible assets. Only invoked by the admin
    public entry fun unfreeze_account(
        admin: &signer, account: address
    ) acquires ManagedRKGenAsset, Admin {
        // Ensure that only admin can unfreeze account
        assert_admin(admin);

        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(asset).transfer_ref;
        let wallet = primary_fungible_store::ensure_primary_store_exists(account, asset);
        fungible_asset::set_frozen_flag(transfer_ref, wallet, false);
    }

    /* Assert verifiers, Checks if the addresses have capabilities of operations */
    // Inline Functions to get ref
    // Function to get ref for managing rKGen
    inline fun authorized_borrow_refs(
        asset: Object<Metadata>
    ): &ManagedRKGenAsset acquires ManagedRKGenAsset {
        borrow_global<ManagedRKGenAsset>(object::object_address(&asset))
    }

    inline fun assert_admin(deployer: &signer) {
        assert!(
            borrow_global<Admin>(@rKGenAdmin).admin == signer::address_of(deployer),
            error::unauthenticated(EONLY_ADMIN)
        );
    }

    inline fun assert_amount(amount: u64) {
        assert!(
            amount > 0,
            error::invalid_argument(EINVALID_AMOUNT)
        );
    }

    inline fun assert_minter(deployer: &address) {
        assert!(
            borrow_global<MintingManager>(@rKGenAdmin).minter == *deployer,
            error::unauthenticated(ENOT_VALID_ADDRESS)
        );
    }

    inline fun verify_treasury(invoker: &address): bool {
        let t_vec = borrow_global<WhiteListed>(@rKGenAdmin).treasury_vec;
        vector::contains(&t_vec, invoker)
    }

    inline fun verify_sender(sender: &address): bool acquires WhiteListed {
        let l = borrow_global<WhiteListed>(@rKGenAdmin).sender_vec;
        vector::contains(&l, sender)
    }

    inline fun verify_receiver(receiver: &address): bool acquires WhiteListed {
        let l = borrow_global<WhiteListed>(@rKGenAdmin).receiver_vec;
        vector::contains(&l, receiver)
    }
}
