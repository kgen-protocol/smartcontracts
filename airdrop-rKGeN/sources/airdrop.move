module KGeNAdmin::airdrop {
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::{Metadata};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::account;
    use std::signer;
    use aptos_framework::system_addresses;
    use aptos_std::string_utils::{to_string};
    use std::error;
    use std::vector;
    use std::option;
    use aptos_std::ed25519;
    use aptos_std::hash;
    use std::bcs;
    use std::event;
    use std::string::{String};
    use aptos_std::simple_map;

    // Constants for error codes to simplify error handling and debugging
    /// Only Admin can invoke this
    const ENOT_ADMIN: u64 = 1;
    /// Invalid signature provided
    const EINVALID_SIGNATURE: u64 = 2;
    /// Invalid address provided
    const ENOT_VALID_ADDRESS: u64 = 3;
    /// Provided argument is already present
    const EALREADY_EXIST: u64 = 4;
    /// No address is nominated
    const ENO_NOMINATED: u64 = 5;
    /// ChainID
    const CHAIN_ID: u64 = 1;  //For mainnet

    /// Seed for creating a resource account
    const LAUNCHPAD_SEED: vector<u8> = b"rKGeN Launchpad";

    /// Stores administrative details, including the admin address, reward signer key,
    /// resource account, and its capability.
    struct AdminStore has key {
        admin: address,
        reward_signer_key: vector<u8>, // Public key of the reward signer
        resource_account: address, // Resource account address
        resource_account_cap: account::SignerCapability, // Capability for the resource account
        nominated_admin: option::Option<address>
    }

    /// Manages user-specific counters (nonces) to prevent duplication
    struct ManagedNonce has key {
        nonce: simple_map::SimpleMap<address, u64> // A mapping of contract addresses to nonces
    }

    /// Holds the message details for creating and verifying signatures
    struct SignedMessage has drop, store {
        user: address, // Address of the user
        metadata: address, // Metadata address (e.g., token address)
        amount: u64, // Amount for the reward
        nonce: u64, // User-specific nonce
        chain_id: u64
    }

    // Event structure to log signature verification results
    #[event]
    struct SignVerify has drop, store {
        signatureEd: ed25519::Signature, // Verified signature
        result: bool // Verification result (true/false)
    }

    // Event emitted when rewards are transferred
    #[event]
    struct Transfer has drop, store {
        user: address, // Recipient of the reward
        amount: u64 // Amount transferred
    }

    // Event emitted when the reward signer key is updated
    #[event]
    struct UpdatedSigner has drop, store {
        new_signer: vector<u8> // New reward signer key
    }

    // Event emitted when the admin role is updated
    #[event]
    struct NominatedAdminEvent has drop, store {
        role: String, // Description of the role change
        nominated_admin: address // Address of the new admin
    }

    // Event emitted when the admin role is updated
    #[event]
    struct UpdatedAdmin has drop, store {
        role: String, // Description of the role change
        added_admin: address // Address of the new admin
    }

    #[event]
    struct AdminWithdrawal has drop, store {
        admin : address,
        amount : u64,
        token : address
    }
    #[event]
    struct AdminWithdrwal has drop, store {
        admin : address,
        amount : u64,
        token : address
    }
    #[view]
    // Return the resource _account address.
    public fun get_resource_account(): address acquires AdminStore {
        borrow_global<AdminStore>(@KGeNAdmin).resource_account
    }

    #[view]
    // Return the admin address.
    public fun get_admin(): address acquires AdminStore {
        borrow_global<AdminStore>(@KGeNAdmin).admin
    }

    #[view]
    // Return the nominated admin address.
    public fun get_nominated_admin(): option::Option<address> acquires AdminStore {
        borrow_global<AdminStore>(@KGeNAdmin).nominated_admin
    }

    #[view]
    // Return the signer address.
    public fun get_signer_key(): vector<u8> acquires AdminStore {
        let pubkey = borrow_global<AdminStore>(@KGeNAdmin).reward_signer_key;
        pubkey
    }

    #[view]
    public fun get_nonce(user: address, metadata_address: address): u64 acquires ManagedNonce {
        let n = 0;
        if (exists<ManagedNonce>(user)) {
            let s = borrow_global<ManagedNonce>(user).nonce;
            if (simple_map::contains_key(&s, &metadata_address)) {
                n = *simple_map::borrow(&s, &metadata_address);
            };
        };
        n
    }

    // :!:>initialize
    fun init_module(admin: &signer) {
        let (resource_account, resource_account_cap) =
            account::create_resource_account(admin, LAUNCHPAD_SEED);
        move_to(
            admin,
            AdminStore {
                admin: signer::address_of(admin),
                reward_signer_key: vector::empty<u8>(),
                resource_account: signer::address_of(&resource_account),
                resource_account_cap,
                nominated_admin: option::none()
            }
        );
    }

    public entry fun update_signer_key(
        admin_addr: &signer, new_key: vector<u8>
    ) acquires AdminStore {
        // Ensure that only admin can add a new admin
        assert_admin(admin_addr);

        let admin_struct = borrow_global_mut<AdminStore>(@KGeNAdmin);
        assert!(
            &admin_struct.reward_signer_key != &new_key,
            error::already_exists(EALREADY_EXIST)
        );

        // Add the new key
        admin_struct.reward_signer_key = new_key;

        event::emit(UpdatedSigner { new_signer: new_key });
    }

    public entry fun nominate_admin(
        admin_addr: &signer, new_admin: address
    ) acquires AdminStore {
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
        let admin_struct = borrow_global_mut<AdminStore>(@KGeNAdmin);
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

    public entry fun accept_admin_role(new_admin: &signer) acquires AdminStore {
        let admin_struct = borrow_global_mut<AdminStore>(@KGeNAdmin);
        // Ensure that nominated address exist
        let pending_admin = option::borrow(&admin_struct.nominated_admin);
        assert!(
            !option::is_none(&admin_struct.nominated_admin),
            error::unauthenticated(ENO_NOMINATED)
        );
        assert!(
            *pending_admin == signer::address_of(new_admin),
            error::unauthenticated(ENOT_VALID_ADDRESS)
        );
        // Add the new admin
        admin_struct.admin = signer::address_of(new_admin);
        admin_struct.nominated_admin = option::none();

        event::emit(
            UpdatedAdmin {
                role: to_string(&std::string::utf8(b"New Admin Added")),
                added_admin: signer::address_of(new_admin)
            }
        );
    }

    public entry fun claim_reward(
        claimer: &signer,
        object: address, // Assets (fund, token, coin, rKGen) address, metadata address
        amount: u64,
        signature: vector<u8>
    ) acquires AdminStore, ManagedNonce {
        let nonce = ensure_nonce(claimer, &object);
        let message = SignedMessage {
            user: signer::address_of(claimer),
            metadata: object,
            amount,
            nonce,
            chain_id: CHAIN_ID
        };
        let messag_bytes = bcs::to_bytes<SignedMessage>(&message);
        let message_hash = hash::sha2_256(messag_bytes);

        // Verify designated signer with signature
        let is_signature_valid = signature_verification(message_hash, signature);
        assert!(is_signature_valid, error::permission_denied(EINVALID_SIGNATURE));

        let sender = &get_resource_account_sign(); // Ensure this address should be in whitelist at rKGeN
        primary_fungible_store::transfer(
            sender,
            get_metadata_object(object),
            signer::address_of(claimer),
            amount
        );
        event::emit<Transfer>(Transfer { user: signer::address_of(claimer), amount });
        update_nonce(&signer::address_of(claimer), &object);
    }

    // Method to verify the signature of the user
    fun signature_verification(
        messageHash: vector<u8>, signature: vector<u8>
    ): bool acquires AdminStore {
        let pubkey = borrow_global<AdminStore>(@KGeNAdmin).reward_signer_key;
        let signatureEd = ed25519::new_signature_from_bytes(signature);

        // Converting Public Key Bytes into UnValidated Public Key
        let unValidatedPublickkey =
            ed25519::new_unvalidated_public_key_from_bytes(pubkey);

        // Verifying Signature using Message Hash and public key
        let res =
            ed25519::signature_verify_strict(
                &signatureEd, &unValidatedPublickkey, messageHash
            );

        event::emit<SignVerify>(SignVerify { signatureEd, result: res });
        res
    }

    inline fun get_metadata_object(object: address): Object<Metadata> {
        object::address_to_object<Metadata>(object)
    }

    // initialize the nonce for the user if it doesnot has
    inline fun ensure_nonce(user: &signer, metadata_address: &address): u64 acquires ManagedNonce {
        let n = 0;

        // Check if the ManagedNonce object exists for the user
        if (!exists<ManagedNonce>(signer::address_of(user))) {
            // Create a new simple map to store the nonce for each metadata_address
            let managed_nonce_map = simple_map::new<address, u64>();
            move_to(user, ManagedNonce { nonce: managed_nonce_map });
        };

        // Borrow the ManagedNonce object for modifying
        let managed_nonce = borrow_global_mut<ManagedNonce>(signer::address_of(user));

        // Check if the metadata_address is already in the simple map
        if (simple_map::contains_key(&managed_nonce.nonce, metadata_address)) {
            n = *simple_map::borrow(&managed_nonce.nonce, metadata_address);
        };

        // If the nonce does not exist, initialize it to 0
        if (n == 0) {
            simple_map::add(&mut managed_nonce.nonce, *metadata_address, 0);
        };

        n
    }

    inline fun assert_admin(deployer: &signer) {
        assert!(
            borrow_global<AdminStore>(@KGeNAdmin).admin == signer::address_of(deployer),
            error::unauthenticated(ENOT_ADMIN)
        );
    }

    // Private function to update the nonce of the passed address
    inline fun update_nonce(user: &address, metadata_address: &address) acquires ManagedNonce {
        // Borrow the ManagedNonce object for the user
        let managed_nonce = borrow_global_mut<ManagedNonce>(*user);

        // Check if the metadata_address is already in the simple map
        if (simple_map::contains_key(&managed_nonce.nonce, metadata_address)) {
            // If it exists, increment the current nonce value by 1
            let count_ref =
                simple_map::borrow_mut(&mut managed_nonce.nonce, metadata_address);
            *count_ref = *count_ref + 1;
        } else {
            // If not, initialize the nonce for this address to 1
            simple_map::add(&mut managed_nonce.nonce, *metadata_address, 1);
        }
    }

    // To get signer sign e.g. module is a signer now for the bucket core
    fun get_resource_account_sign(): signer acquires AdminStore {
        account::create_signer_with_capability(
            &borrow_global<AdminStore>(@KGeNAdmin).resource_account_cap
        )
    }
   public entry fun transfer_from_resource_account_to_admin (admin:&signer,object:address,amount: u64) acquires AdminStore {
       let admin_address = signer::address_of(admin);
       assert!(
            admin_address == get_admin(),
            error::permission_denied(ENOT_ADMIN)
        );
       let sender = &get_resource_account_sign();
       primary_fungible_store::transfer(
           sender,
           get_metadata_object(object),
           admin_address ,
           amount
       );
        event::emit<AdminWithdrawal>(AdminWithdrawal {admin:admin_address,amount,token:object });
   }
   public entry fun transfer_from_resource_account_to_treasury (admin:&signer,treasury:address,object:address,amount: u64) acquires AdminStore {
       let admin_address = signer::address_of(admin);
       assert!(
            admin_address == get_admin(),
            error::permission_denied(ENOT_ADMIN)
        );
       let sender = &get_resource_account_sign();
       primary_fungible_store::transfer(
           sender,
           get_metadata_object(object),
           treasury ,
           amount
       );
        event::emit<AdminWithdrawal>(AdminWithdrawal {admin:treasury,amount,token:object });
   }

}

