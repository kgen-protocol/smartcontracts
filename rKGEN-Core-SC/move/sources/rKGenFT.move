// rKGeN smart contract structure in accordance with the Aptos Fungible Asset (FA) Standard.
// rKGeN smart contract structure in accordance with the Aptos Fungible Asset (FA) Standard.
// 200M tokens with an initial circulating supply of 40M.
// rKGEN token will be non-transferable by default but allows staking from day 1.
module rKGenAdmin::rKGen {
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::event;
    use aptos_std::string_utils::{to_string};
    use std::error;
    use std::signer;
    use std::string::{String, utf8};
    use std::option;
    use std::vector;

    // Constants for error codes to simplify error handling and debugging
    const EALREADY_EXIST: u64 = 1;
    const ENOT_TREASURY_ADDRESS: u64 = 2;
    const ENOT_WHITELIST_SENDER: u64 = 3;
    const ENOT_WHITELIST_RECEIVER: u64 = 4;
    const EONLY_ADMIN: u64 = 5;
    const ENOT_ADMIN: u64 = 6;
    const ECANNOT_DELETE_TREASURY_ADDRESS: u64 = 7;
    const EINVALIDRECEIVERORSENDER: u64 = 8;
    const ENOT_BURNVAULT: u64 = 9;

    // Metadata values for the fungible asset
    const ASSET_SYMBOL: vector<u8> = b"rKGEN";
    const METADATA_NAME: vector<u8> = b"rKGEN";
    const ICON_URI: vector<u8> = b"https://prod-image-bucket.kgen.io/assets/rkgen-logo.png";
    const PROJECT_URI: vector<u8> = b"https://kgen.io";
    // const MULTISIG_ADDRESS: address =
    //     @0xcbcd4237032113566ef395a3f0dd0a2aad769ee130cce018193c17acbbed57b8;

    /* ----------- Resources (Global storage) ----------*/
    // Stores references for minting, transferring, and burning of rKGEN tokens.
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct ManagedRKGenAsset has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // Stores the multisig address used for minting purposes.
    struct Admin has key {
        admin: address,
        burnable: address
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // Stores the multisig address used for minting purposes.
    struct MintingManager has key {
        minter: address
    }

    // Stores treasury addresses allowed to mint and transfer tokens.
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct TreasuryAddresses has key {
        treasury_vec: vector<address>
    }

    // Stores treasury addresses allowed to mint and transfer tokens.
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct SenderWhiteList has key {
        sender_vec: vector<address>
    }

    // Stores treasury addresses allowed to mint and transfer tokens.
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct ReceiverWhiteList has key {
        receiver_vec: vector<address>
    }

    // Initialize metadata object and store the refs.
    fun init_module(admin: &signer) {
        // Initialize the rKGen

        /* Stores the global storage for the addresses of minter manager (Multisig wallet address) */
        move_to(admin, MintingManager { minter: signer::address_of(admin) });

        /* Stores the global storage for the addresses of Admin role */
        move_to(
            admin,
            Admin {
                admin: signer::address_of(admin),
                burnable: signer::address_of(admin)
            }
        );

        /* Stores the global storage for the addresses of  treasury address */
        let t_vec = vector::empty<address>();
        move_to(admin, TreasuryAddresses { treasury_vec: t_vec });

        /* Stores the global storage for the addresses of  whitelist sender */
        let s_vec = vector::empty<address>();
        move_to(admin, SenderWhiteList { sender_vec: s_vec });

        /* Stores the global storage for the addresses of  admin transfer role */
        let r_vec = vector::empty<address>();
        move_to(admin, ReceiverWhiteList { receiver_vec: r_vec });

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
        )

    }

    /* ----------- Functions For Admin Management ----------*/
    //Function to view the available admin address
    #[view]
    // Return the admin address.
    public fun get_admin(): address acquires Admin {
        borrow_global<Admin>(@rKGenAdmin).admin
    }

    //Function to view the available burnable address
    #[view]
    // Return the admin address.
    public fun get_burn_vault(): address acquires Admin {
        borrow_global<Admin>(@rKGenAdmin).burnable
    }

    // to check if the address is of admin
    inline fun is_admin(admin: &address): bool acquires Admin {
        let a = borrow_global<Admin>(@rKGenAdmin).admin;
        &a == admin
    }

    // to check if the address is of burn_vault
    inline fun is_burn_vault(burn: &address): bool acquires Admin {
        let b = borrow_global<Admin>(@rKGenAdmin).burnable;
        &b == burn
    }

    // Only invoked by the admin
    public entry fun update_admin(admin_addr: &signer, new_admin: address) acquires Admin {
        // Ensure that only admin can add a new admin
        assert!(
            is_admin(&signer::address_of(admin_addr)),
            error::permission_denied(ENOT_ADMIN)
        );
        // Check if the new admin already exists in the list
        assert!(!is_admin(&new_admin), error::already_exists(EALREADY_EXIST));

        // Get the Admin Role storage reference
        let admin_struct = borrow_global_mut<Admin>(@rKGenAdmin);
        // Add the new admin
        admin_struct.admin = new_admin;

        event::emit(
            UpdatedAdmin {
                role: to_string(&std::string::utf8(b"New Admin Added")),
                added_admin: new_admin
            }
        );
    }

    // Only invoked by the admin
    public entry fun update_burn_vault(
        admin_addr: &signer, new_address: address
    ) acquires Admin {
        // Ensure that only admin can add a new admin
        assert!(
            is_admin(&signer::address_of(admin_addr)),
            error::permission_denied(ENOT_ADMIN)
        );
        // Check if the new address already exists
        assert!(!is_burn_vault(&new_address), error::already_exists(EALREADY_EXIST));

        // Get the Admin Role storage reference
        let admin_struct = borrow_global_mut<Admin>(@rKGenAdmin);
        // Add the new admin
        admin_struct.burnable = new_address;

        event::emit(
            UpdatedBurnVault {
                role: to_string(&std::string::utf8(b"New Admin Added")),
                updated_address: new_address
            }
        );
    }

    /* ----------- Functions For Minter Management ----------*/
    //Function to view the address of minter
    #[view]
    // Return the treasury addresses.
    public fun get_minter(): address acquires MintingManager {
        borrow_global<MintingManager>(@rKGenAdmin).minter
    }

    // Function to verify_sender is multisig address
    inline fun verifyMinter(minter: &address): bool acquires MintingManager {
        let m = borrow_global<MintingManager>(@rKGenAdmin).minter;
        &m == minter
    }

    /* To assign minter role to an address (multisig address) */
    // Only invoked by the admin
    public entry fun update_minter(admin: &signer, new_minter: address) acquires MintingManager, Admin {
        // Ensure that only admin can add a new minter
        assert!(
            is_admin(&signer::address_of(admin)),
            error::permission_denied(ENOT_ADMIN)
        );
        // Check if the  minter already exists in the minter struct
        assert!(!verifyMinter(&new_minter), error::already_exists(EALREADY_EXIST));

        // Get the AdminMinterRole storage reference
        let mint_struct = borrow_global_mut<MintingManager>(@rKGenAdmin);
        // Add the new minter to the minter list
        mint_struct.minter = new_minter;
        event::emit(
            UpdatedMinter {
                role: to_string(&std::string::utf8(b"NewMinter")),
                added_user: new_minter
            }
        );
    }

    /* ----------- Functions For Treasury Management ----------*/
    //Function to view the available addresses in treasury
    #[view]
    // Return the treasury addresses.
    public fun get_treasury_address(): vector<address> acquires TreasuryAddresses {
        borrow_global<TreasuryAddresses>(@rKGenAdmin).treasury_vec
    }

    //function to verify address is in treasusy_vec
    inline fun verifyTreasuryAddress(treasury_addr: &address): bool acquires TreasuryAddresses {
        let t_vec = borrow_global<TreasuryAddresses>(@rKGenAdmin).treasury_vec;
        vector::contains(&t_vec, treasury_addr)
    }

    // Function to add new address to the treausry Only invoked by the admin
    public entry fun add_treasury_address(
        admin: &signer, new_address: address
    ) acquires TreasuryAddresses, Admin, SenderWhiteList {
        // Ensure that only admin can add a new treausry
        assert!(
            is_admin(&signer::address_of(admin)),
            error::permission_denied(ENOT_ADMIN)
        );
        // Check if the new treasury address already exists in the treasury list
        assert!(
            !verifyTreasuryAddress(&new_address),
            error::already_exists(EALREADY_EXIST)
        );

        if (!verifySenderAddress(&new_address)) {
            // Get the AdminMinterRole storage reference
            let s_struct = borrow_global_mut<SenderWhiteList>(@rKGenAdmin);

            // Add the new minter to the minter list
            vector::push_back<address>(&mut s_struct.sender_vec, new_address);
        };

        // Get the Treasury storage reference
        let t_struct = borrow_global_mut<TreasuryAddresses>(@rKGenAdmin);

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
    ) acquires TreasuryAddresses, Admin {
        // Ensure that only admin can remove a treausry address
        assert!(
            is_admin(&signer::address_of(admin)),
            error::permission_denied(ENOT_ADMIN)
        );
        // Check if the treasury address exists in the treasury list or not
        assert!(
            verifyTreasuryAddress(&treasury_address),
            error::unauthenticated(ENOT_TREASURY_ADDRESS)
        );

        // Get the Treasury storage reference
        let t_struct = borrow_global_mut<TreasuryAddresses>(@rKGenAdmin);

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

    /* ----------- Functions For Whitelist Sender Management ----------*/
    //Function to view the available addresses in SenderWhiteList
    #[view]
    public fun get_whitelisted_sender(): vector<address> acquires SenderWhiteList {
        borrow_global<SenderWhiteList>(@rKGenAdmin).sender_vec
    }

    //function to verify address is in sender_vec
    inline fun verifySenderAddress(sender_addr: &address): bool acquires SenderWhiteList {
        let s_vec = borrow_global<SenderWhiteList>(@rKGenAdmin).sender_vec;
        vector::contains(&s_vec, sender_addr)
    }

    // Function to add new address to the whitelist of sender Only invoked by the admin
    public entry fun add_whitelist_sender(
        admin: &signer, new_address: address
    ) acquires SenderWhiteList, Admin {
        // Ensure that only admin can add a new whitelist sender
        assert!(
            is_admin(&signer::address_of(admin)),
            error::permission_denied(ENOT_ADMIN)
        );
        // Check if the new address already exists in the whitelist
        assert!(
            !verifySenderAddress(&new_address),
            error::already_exists(EALREADY_EXIST)
        );

        // Get the AdminMinterRole storage reference
        let s_struct = borrow_global_mut<SenderWhiteList>(@rKGenAdmin);

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
    ) acquires SenderWhiteList, Admin, TreasuryAddresses {
        // Ensure that admin can remove a whitelist address
        assert!(
            is_admin(&signer::address_of(admin)),
            error::permission_denied(ENOT_ADMIN)
        );

        // Check if the whitelist address exists in the whitelist
        assert!(
            verifySenderAddress(&sender_address),
            error::invalid_argument(ENOT_WHITELIST_SENDER)
        );

        // Check if the new treasury address already exists in the treasury list
        assert!(
            !verifyTreasuryAddress(&sender_address),
            error::invalid_argument(ECANNOT_DELETE_TREASURY_ADDRESS)
        );

        // Get the SenderWhiteList storage reference
        let s_struct = borrow_global_mut<SenderWhiteList>(@rKGenAdmin);

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

    /* ----------- Functions For Whitelist Receiver Management ----------*/
    //Function to view the available in reciever whitelisted
    #[view]
    // Return the whitelisted receiver addresses.
    public fun get_whitelisted_receiver(): vector<address> acquires ReceiverWhiteList {
        borrow_global<ReceiverWhiteList>(@rKGenAdmin).receiver_vec
    }

    //function to verify address is in receiver_vec
    inline fun verifyReceiverAddress(receiver_addr: &address): bool acquires ReceiverWhiteList {
        let r_vec = borrow_global<ReceiverWhiteList>(@rKGenAdmin).receiver_vec;
        vector::contains(&r_vec, receiver_addr)
    }

    // Function to add new address to the whitelist of receiver Only invoked by the admin
    public entry fun add_whitelist_receiver(
        admin: &signer, new_address: address
    ) acquires ReceiverWhiteList, Admin {
        // Ensure that only admin can add a new address
        assert!(
            is_admin(&signer::address_of(admin)),
            error::permission_denied(ENOT_ADMIN)
        );
        // Check if the new receiver address exists in the whitelist
        assert!(
            !verifyReceiverAddress(&new_address),
            error::already_exists(EALREADY_EXIST)
        );

        // Get the ReceiverWhiteList storage reference
        let r_struct = borrow_global_mut<ReceiverWhiteList>(@rKGenAdmin);

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
    ) acquires ReceiverWhiteList, Admin {
        // Ensure that only admin can remove a receiver
        assert!(
            is_admin(&signer::address_of(admin)),
            error::permission_denied(ENOT_ADMIN)
        );
        // Check if the address exists in the list
        assert!(
            verifyReceiverAddress(&receiver_address),
            error::invalid_argument(ENOT_WHITELIST_RECEIVER)
        );

        // Get the ReceiverWhiteList storage reference
        let r_struct = borrow_global_mut<ReceiverWhiteList>(@rKGenAdmin);

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

    /* ----------- Events and View Functions ----------*/
    // Event triggered when tokens are minted to a treasury address.
    #[event]
    struct MintedToTreasury has drop, store {
        treasury: address,
        amount: u64
    }

    // Event triggered when tokens are transferred from whitelist address.
    #[event]
    struct TransferFromWhitelistSender has drop, store {
        from: address,
        receiver: address,
        amount: u64
    }

    // Event triggered when tokens are transferred from whitelist address.
    #[event]
    struct Transfer has drop, store {
        from: address,
        receiver: address,
        amount: u64
    }

    // Event triggered when tokens are transferred from whitelist address.
    #[event]
    struct TransferToWhitelistReceiver has drop, store {
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

    // Triggered when owner unfreezed an address so it can perform transfer
    #[event]
    struct UnfreezedAddress has drop, store {
        msg: String,
        user: address
    }

    //VIEW FUNCTIONS
    #[view]
    // Return the address of the managed fungible asset that's created when this module is deployed.
    public fun get_metadata(): Object<Metadata> {
        let asset_address = object::create_object_address(&@rKGenAdmin, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }

    /* ----------- Inline Functions ----------*/
    // to check if the address is of admin
    inline fun is_owner(owner: address): bool {
        owner == @rKGenAdmin
    }

    // Inline Functions to get ref
    // Function to get ref for minting rKGen
    inline fun authorized_borrow_mint_refs(
        asset: Object<Metadata>
    ): &MintRef acquires ManagedRKGenAsset, TreasuryAddresses {
        let ref = borrow_global<ManagedRKGenAsset>(object::object_address(&asset));
        &ref.mint_ref
    }

    // Function to get ref for transfer rKGen
    inline fun authorized_borrow_transfer_refs(
        asset: Object<Metadata>
    ): &TransferRef acquires ManagedRKGenAsset, TreasuryAddresses {
        let ref = borrow_global<ManagedRKGenAsset>(object::object_address(&asset));
        &ref.transfer_ref
    }

    // This validates that the signer is the metadata object's owner.
    inline fun authorized_borrow_burn_refs(
        asset: Object<Metadata>
    ): &BurnRef acquires ManagedRKGenAsset {
        let ref = borrow_global<ManagedRKGenAsset>(object::object_address(&asset));
        &ref.burn_ref
    }

    /* ----------- Private Functions ----------*/
    // Transfer private function which works with rKGen
    fun transfer_internal(from: &signer, to: &address, amount: u64) acquires ManagedRKGenAsset {
        let asset = get_metadata();
        let transfer_ref = authorized_borrow_transfer_refs(asset);
        let from_wallet =
            primary_fungible_store::primary_store(signer::address_of(from), asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(*to, asset);

        fungible_asset::transfer_with_ref(transfer_ref, from_wallet, to_wallet, amount);

        // Freeeze the account so that native trnsfer would not work
        fungible_asset::set_frozen_flag(transfer_ref, to_wallet, true);
    }

    /* -----  Entry functions that can be called from outside ----- */
    // Freeze an account so it cannot transfer or receive fungible assets. Only invoked by the admin
    public entry fun freeze_account(admin: &signer, account: address) acquires ManagedRKGenAsset, Admin {
        // Ensure that only admin can freeze account
        assert!(
            is_admin(&signer::address_of(admin)),
            error::permission_denied(ENOT_ADMIN)
        );
        let asset = get_metadata();
        let transfer_ref = authorized_borrow_transfer_refs(asset);
        let wallet = primary_fungible_store::ensure_primary_store_exists(account, asset);
        fungible_asset::set_frozen_flag(transfer_ref, wallet, true);
    }

    // Unfreeze an account so it can transfer or receive fungible assets. Only invoked by the admin
    public entry fun unfreeze_account(
        admin: &signer, account: address
    ) acquires ManagedRKGenAsset, Admin {
        // Ensure that only admin can unfreeze account
        assert!(
            is_admin(&signer::address_of(admin)),
            error::permission_denied(ENOT_ADMIN)
        );
        let asset = get_metadata();
        let transfer_ref = authorized_borrow_transfer_refs(asset);
        let wallet = primary_fungible_store::ensure_primary_store_exists(account, asset);
        fungible_asset::set_frozen_flag(transfer_ref, wallet, false);
        event::emit(
            UnfreezedAddress {
                msg: to_string(
                    &utf8(b"User Address Unfreezed Now It can perform transfer")
                ),
                user: account
            }
        );
    }

    // :!:>mint
    // Mint as the minter role and deposit to a specific account.
    // Only multisig wallet can invoke the mint capability
    public entry fun mint(
        admin: &signer, to: address, amount: u64
    ) acquires ManagedRKGenAsset, MintingManager, TreasuryAddresses {
        assert!(
            verifyMinter(&signer::address_of(admin)),
            error::permission_denied(ENOT_ADMIN)
        );
        assert!(
            verifyTreasuryAddress(&to),
            error::permission_denied(ENOT_TREASURY_ADDRESS)
        );

        let asset = get_metadata();

        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);

        let mint_ref_borrow = authorized_borrow_mint_refs(asset);
        let fa = fungible_asset::mint(mint_ref_borrow, amount);

        let transfer_ref_borrow = authorized_borrow_transfer_refs(asset);

        fungible_asset::deposit_with_ref(transfer_ref_borrow, to_wallet, fa);
        // Freeeze the account so that native trnsfer would not work
        fungible_asset::set_frozen_flag(transfer_ref_borrow, to_wallet, true);

        event::emit(MintedToTreasury { treasury: to, amount: amount });

    } // <:!:mint_to

    // Burn fungible assets as the owner of metadata object. Only invoked by the admin
    public entry fun burn(admin: &signer, from: address, amount: u64) acquires ManagedRKGenAsset, Admin {
        // Ensure that only admin can burn token
        assert!(
            is_admin(&signer::address_of(admin)),
            error::permission_denied(ENOT_ADMIN)
        );
        // Ensure that only admin can burn from burn_vault
        assert!(
            is_burn_vault(&from),
            error::permission_denied(ENOT_BURNVAULT)
        );
        let asset = get_metadata();
        let burn_ref = authorized_borrow_burn_refs(asset);
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        fungible_asset::burn_from(burn_ref, from_wallet, amount);
    }

    // Implement function to transfer rKGen from whitelist sender
    // Only whitelist sender can transfer
    public entry fun transfer_from_whitelist_sender(
        sender_address: &signer, receiver: address, amount: u64
    ) acquires ManagedRKGenAsset, SenderWhiteList {
        assert!(
            verifySenderAddress(&signer::address_of(sender_address)),
            error::permission_denied(ENOT_WHITELIST_SENDER)
        );
        transfer_internal(sender_address, &receiver, amount);
        event::emit(
            TransferFromWhitelistSender {
                from: signer::address_of(sender_address),
                receiver,
                amount
            }
        );
    }

    // transfer function
    public entry fun transfer(
        sender: &signer, receiver: address, amount: u64
    ) acquires ManagedRKGenAsset, ReceiverWhiteList, SenderWhiteList {
        assert!(
            verifySenderAddress(&signer::address_of(sender))
                || verifyReceiverAddress(&receiver),
            error::unauthenticated(EINVALIDRECEIVERORSENDER)
        );
        transfer_internal(sender, &receiver, amount);

        event::emit(Transfer { from: signer::address_of(sender), receiver, amount });
    }

    // Implement function to transfer rKGen to whitelist receiver
    // Anyone can invoke this function but receiver should be in whitelist
    public entry fun transfer_to_whitelist_receiver(
        sender_address: &signer, receiver: address, amount: u64
    ) acquires ManagedRKGenAsset, ReceiverWhiteList {
        assert!(
            verifyReceiverAddress(&receiver),
            error::unauthenticated(ENOT_WHITELIST_RECEIVER)
        );
        transfer_internal(sender_address, &receiver, amount);
        event::emit(
            TransferToWhitelistReceiver {
                from: signer::address_of(sender_address),
                receiver,
                amount
            }
        );
    }
}
