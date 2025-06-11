module KGeN::oracle_poa_nft {
    use std::option::{Self, Option};
    use std::string::{Self, String};
    use std::signer;
    use aptos_std::smart_table;
    use aptos_std::from_bcs;
    use aptos_framework::object::{Self, ConstructorRef, Object, ExtendRef};
    use aptos_framework::timestamp;
    use aptos_framework::event;
    use aptos_token_objects::collection;
    use aptos_token_objects::property_map;
    use aptos_token_objects::token;

    // === Constants ===

    /// The KGeN token collection name
    const COLLECTION_NAME: vector<u8> = b"KGeN Proof of Authority Collection";
    /// The KGeN token collection description
    const COLLECTION_DESCRIPTION: vector<u8> = b"The KGeN Proof of Authority (PoA) NFT is a unique digital credential that verifies an operator's identity and authority within the oracle network. It signifies that the holder is a trusted and verified participant, authorized to contribute data and services securely and reliably in the decentralized environment.";
    /// The KGeN token collection URI
    const COLLECTION_URI: vector<u8> = b"https://kgen.io";
    /// Core seed used to create the token signer
    const TOKEN_CORE_SEED: vector<u8> = b"03fe1a9c07398efdbf10e138e3d07585e155873f330c9554c088c5f7e7cb05f9";
    /// Maximum number of tokens a wallet can hold
    const MAX_ALLOCATED: u8 = 1;

    // === Structs ===

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Stores references and state for managing the KGeN PoA collection
    struct KGenPoACollection has key {
        /// Reference to mutate collection fields
        mutator_ref: Option<collection::MutatorRef>
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Represents a PoA token with mutator and burn references
    struct KGeNPoAToken has key {
        /// Reference to burn the token
        burn_ref: Option<token::BurnRef>,
        /// Reference to control token transfers
        transfer_ref: Option<object::TransferRef>,
        /// Reference to mutate token fields
        mutator_ref: Option<token::MutatorRef>,
        /// Reference to mutate token properties
        property_mutator_ref: property_map::MutatorRef
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Stores the base URI for token images
    struct BaseURI has key {
        uri: String
    }

    /// Holds a transfer reference for a token
    struct Referrence has store, drop {
        ref: object::TransferRef
    }

    /// Registry to manage transfer references for tokens
    struct TransferRefRegistry has key, store {
        ref_table: smart_table::SmartTable<address, Referrence>
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Holds the extend reference for the token core
    struct TokenCore has key {
        /// Extend reference for the token core object, which creates token objects
        token_ext_ref: ExtendRef
    }

    // === Events ===

    #[event]
    /// Emitted when an NFT is minted for an oracle operator
    struct NFTMintedToValidatorEvent has store, drop {
        token_name: String,
        to: address,
        pub_key: address,
        timestamp: u64
    }

    #[event]
    /// Emitted when a counter is incremented (not used in this code)
    struct CounterIncrementedEvent has store, drop {
        value: u128
    }

    #[event]
    /// Emitted when a new collection is created
    struct CollectionCreatedEvent has store, drop {
        name: String,
        creator: address
    }

    #[event]
    /// Emitted when an oracle's public key is updated
    struct PublicKeyUpdatedEvent has store, drop {
        token_name: String,
        old_key: address,
        new_key: address
    }

    #[event]
    /// Emitted when a token is burned
    struct BurnedEvent has store, drop {
        token_name: String
    }

    #[event]
    /// Emitted when an oracle's status is updated
    struct OracleStatusUpdatedEvent has store, drop {
        token_name: String,
        status: String
    }

    #[event]
    /// Emitted when a proxy address is added (not directly used; see update_proxy_address)
    struct ProxyAddressAddedEvent has store, drop {
        token_name: String,
        proxy_address: address,
        status: String
    }

    #[event]
    /// Emitted when a proxy address is updated
    struct ProxyAddressUpdatedEvent has store, drop {
        token_name: String,
        proxy_address: address,
        status: String
    }

    #[event]
    /// Emitted when a proxy address is removed
    struct ProxyAddressRemovedEvent has store, drop {
        token_name: String,
        status: String
    }

    // === View Functions ===

    #[view]
    /// Returns the address of the PoA NFT collection
    public fun get_collection_address(): address {
        let creator = get_token_signer_address();
        let collection_name = string::utf8(COLLECTION_NAME);
        let addr = collection::create_collection_address(&creator, &collection_name);
        addr
    }

    #[view]
    /// Returns the public key associated with a token
    public fun get_oracle_public_key(token_name: String): address {
        let creator = get_token_signer_address();
        let collection_name = string::utf8(COLLECTION_NAME);
        let token_address =
            token::create_token_address(&creator, &collection_name, &token_name);
        let token = object::address_to_object<KGeNPoAToken>(token_address);
        let (_x, y) = property_map::read(&token, &string::utf8(b"Oracle's Public Key"));
        from_bcs::to_address(y)
    }

    #[view]
    /// Returns the activity status of a token
    public fun get_oracle_active_status(token_name: String): String {
        let creator = get_token_signer_address();
        let collection_name = string::utf8(COLLECTION_NAME);
        let token_address =
            token::create_token_address(&creator, &collection_name, &token_name);
        let token = object::address_to_object<KGeNPoAToken>(token_address);
        let (_x, y) = property_map::read(&token, &string::utf8(b"Active Status"));
        from_bcs::to_string(y)
    }

    #[view]
    /// Returns the proxy address of a token, if it exists
    public fun get_oracle_proxy_address(token_name: String): Option<address> {
        let creator = get_token_signer_address();
        let collection_name = string::utf8(COLLECTION_NAME);
        let token_address =
            token::create_token_address(&creator, &collection_name, &token_name);
        let token = object::address_to_object<KGeNPoAToken>(token_address);
        if (property_map::contains_key(&token, &string::utf8(b"Proxy Address"))) {
            let (_x, y) = property_map::read(&token, &string::utf8(b"Proxy Address"));
            let addr = from_bcs::to_address(y);
            return option::some(addr)
        };
        return option::none<address>()
    }

    #[view]
    /// Returns the token object for a given token name
    public fun get_token_object(token_name: String): Object<KGeNPoAToken> {
        let creator = get_token_signer_address();
        let collection_name = string::utf8(COLLECTION_NAME);
        let token_address =
            token::create_token_address(&creator, &collection_name, &token_name);
        object::address_to_object<KGeNPoAToken>(token_address)
    }

    // === Initialization ===

    /// Initializes the module with required structures and objects
    fun init_module(admin: &signer) {
        // Create a token constructor reference using the admin's signer
        let token_constructor_ref = &object::create_named_object(admin, TOKEN_CORE_SEED);

        // Generate extension reference and signer for future token operations
        let token_ext_ref = object::generate_extend_ref(token_constructor_ref);
        let token_signer = object::generate_signer(token_constructor_ref);

        // Move the TokenCore struct to the token signer's address
        move_to(&token_signer, TokenCore { token_ext_ref });

        // Create a collection object for minting tokens
        create_collection_object(&token_signer);

        // Store the base URI for token images
        let uri = string::utf8(
            b"https://teal-far-lemming-411.mypinata.cloud/ipfs/"
        );
        move_to(admin, BaseURI { uri });

        // Initialize the TransferRefRegistry for managing transfer references
        move_to(
            admin,
            TransferRefRegistry {
                ref_table: smart_table::new<address, Referrence>()
            }
        );
    }

    // === Helper Functions ===

    /// Retrieves the base URI from global storage
    public fun get_base_uri(): String acquires BaseURI {
        borrow_global<BaseURI>(@KGeN).uri
    }

    /// Creates a collection object for minting tokens
    fun create_collection_object(creator: &signer): Object<KGenPoACollection> {
        let description = string::utf8(COLLECTION_DESCRIPTION);
        let name = string::utf8(COLLECTION_NAME);
        let uri = string::utf8(COLLECTION_URI);

        // Create an unlimited collection using the creator's signer
        let constructor_ref =
            collection::create_unlimited_collection(
                creator, description, name, option::none(), uri
            );

        let object_signer = object::generate_signer(&constructor_ref);
        let mutator_ref =
            option::some(collection::generate_mutator_ref(&constructor_ref));

        let aptos_collection = KGenPoACollection { mutator_ref };
        move_to(&object_signer, aptos_collection);

        let creator_address = signer::address_of(creator);
        let event = CollectionCreatedEvent { name, creator: creator_address };
        event::emit(event);

        // Return the constructed collection object
        object::object_from_constructor_ref(&constructor_ref)
    }

    /// Internal method to mint a token and return its constructor reference
    fun mint_internal(
        creator: &signer,
        collection: String,
        description: String,
        token_name: String,
        property_keys: vector<String>,
        property_types: vector<String>,
        property_values: vector<vector<u8>>
    ): ConstructorRef acquires BaseURI {
        let uri = get_base_uri();

        // Create a new token with the specified properties
        let constructor_ref =
            token::create_named_token(
                creator,
                collection,
                description,
                token_name,
                option::none(),
                uri
            );

        // Generate object signer and references for the token
        let object_signer = object::generate_signer(&constructor_ref);
        let mutator_ref = option::some(token::generate_mutator_ref(&constructor_ref));
        let burn_ref = option::some(token::generate_burn_ref(&constructor_ref));

        // Initialize token properties
        let properties =
            property_map::prepare_input(property_keys, property_types, property_values);
        property_map::init(&constructor_ref, properties);

        // Store the token object
        let aptos_token = KGeNPoAToken {
            burn_ref,
            transfer_ref: option::none(),
            mutator_ref,
            property_mutator_ref: property_map::generate_mutator_ref(&constructor_ref)
        };
        move_to(&object_signer, aptos_token);

        constructor_ref
    }

    /// Retrieves the address of the token signer
    fun get_token_signer_address(): address {
        object::create_object_address(&@KGeN, TOKEN_CORE_SEED)
    }

    /// Retrieves the signer for the token core
    fun get_token_signer(token_signer_address: address): signer acquires TokenCore {
        object::generate_signer_for_extending(
            &borrow_global<TokenCore>(token_signer_address).token_ext_ref
        )
    }

    // === Entry Functions ===

    /// Mints a PoA NFT for an oracle operator
    package fun mint_poa_nft(
        oracle_operator: address, token_name: String, public_key: vector<u8>
    ) acquires TokenCore, KGeNPoAToken, BaseURI, TransferRefRegistry {
        let collection_name = string::utf8(COLLECTION_NAME);
        string::append(&mut token_name, string::utf8(b".kgen.io"));

        let token_description =
            string::utf8(
                b"The PoA NFT confirms an operator's verification and eligibility to participate in the oracle network."
            );

        let creator = get_token_signer(get_token_signer_address());
        let constructor_ref =
            mint_internal(
                &creator,
                collection_name,
                token_description,
                token_name,
                vector[],
                vector[],
                vector[]
            );

        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref);
        object::transfer_with_ref(linear_transfer_ref, oracle_operator);
        object::disable_ungated_transfer(&transfer_ref); // Makes the token soulbound

        let ref_registry = &mut borrow_global_mut<TransferRefRegistry>(@KGeN).ref_table;
        smart_table::add(ref_registry, oracle_operator, Referrence { ref: transfer_ref });

        let token_address =
            token::create_token_address(
                &get_token_signer_address(), &collection_name, &token_name
            );
        let aptos_token = borrow_global<KGeNPoAToken>(token_address);

        // Add initial properties
        property_map::add_typed(
            &aptos_token.property_mutator_ref,
            string::utf8(b"Active Status"),
            string::utf8(b"Active")
        );
        let pub_key = from_bcs::to_address(public_key);
        property_map::add_typed(
            &aptos_token.property_mutator_ref,
            string::utf8(b"Oracle's Public Key"),
            pub_key
        );

        // Emit mint event
        event::emit(
            NFTMintedToValidatorEvent {
                token_name,
                to: oracle_operator,
                pub_key,
                timestamp: timestamp::now_seconds()
            }
        );
    }

    /// Updates the public key of a token
    package fun manage_pub_key(
        token_name: String, public_key: vector<u8>
    ) acquires KGeNPoAToken {
        let collection = string::utf8(COLLECTION_NAME);
        let object_signer = get_token_signer_address();
        string::append(&mut token_name, string::utf8(b".kgen.io"));

        let token_address =
            token::create_token_address(&object_signer, &collection, &token_name);
        let aptos_token = borrow_global<KGeNPoAToken>(token_address);

        let old_key = get_oracle_public_key(token_name);
        let pub_key = from_bcs::to_address(public_key);
        property_map::update_typed(
            &aptos_token.property_mutator_ref,
            &string::utf8(b"Oracle's Public Key"),
            pub_key
        );

        event::emit(PublicKeyUpdatedEvent { token_name, old_key, new_key: pub_key });
    }

    /// Updates the activity status of a token
    package fun manage_activity_status(
        token_name: String, status: String
    ) acquires KGeNPoAToken {
        let collection = string::utf8(COLLECTION_NAME);
        let object_signer = get_token_signer_address();
        string::append(&mut token_name, string::utf8(b".kgen.io"));

        let token_address =
            token::create_token_address(&object_signer, &collection, &token_name);
        let aptos_token = borrow_global<KGeNPoAToken>(token_address);

        property_map::update_typed(
            &aptos_token.property_mutator_ref, &string::utf8(b"Active Status"), status
        );
        event::emit(OracleStatusUpdatedEvent { token_name, status });
    }

    /// Adds or updates a proxy address for a token
    package fun update_proxy_address(
        token_name: String, proxy_address: address
    ) acquires KGeNPoAToken {
        let collection = string::utf8(COLLECTION_NAME);
        let object_signer = get_token_signer_address();
        string::append(&mut token_name, string::utf8(b".kgen.io"));
        let token_address =
            token::create_token_address(&object_signer, &collection, &token_name);
        let token = object::address_to_object<KGeNPoAToken>(token_address);
        let aptos_token = borrow_global<KGeNPoAToken>(token_address);

        if (property_map::contains_key(&token, &string::utf8(b"Proxy Address"))) {
            property_map::update_typed(
                &aptos_token.property_mutator_ref,
                &string::utf8(b"Proxy Address"),
                proxy_address
            );
        } else {
            property_map::add_typed(
                &aptos_token.property_mutator_ref,
                string::utf8(b"Proxy Address"),
                proxy_address
            );
        };

        event::emit(
            ProxyAddressUpdatedEvent {
                token_name,
                proxy_address,
                status: get_oracle_active_status(token_name)
            }
        );
    }

    /// Removes the proxy address from a token
    package fun remove_proxy_address(token_name: String) acquires KGeNPoAToken {
        let collection = string::utf8(COLLECTION_NAME);
        let object_signer = get_token_signer_address();
        string::append(&mut token_name, string::utf8(b".kgen.io"));

        let token_address =
            token::create_token_address(&object_signer, &collection, &token_name);

        let token = object::address_to_object<KGeNPoAToken>(token_address);
        let aptos_token = borrow_global<KGeNPoAToken>(token_address);

        if (property_map::contains_key(&token, &string::utf8(b"Proxy Address"))) {
            property_map::remove(
                &aptos_token.property_mutator_ref, &string::utf8(b"Proxy Address")
            );
        };

        event::emit(
            ProxyAddressRemovedEvent {
                token_name,
                status: get_oracle_active_status(token_name)
            }
        );
    }

    /// Burns a token, removing it from circulation
    package fun burn(token_name: String, owner: address) acquires KGeNPoAToken, TransferRefRegistry {
        let collection = string::utf8(COLLECTION_NAME);
        let object_signer = get_token_signer_address();
        string::append(&mut token_name, string::utf8(b".kgen.io"));
        let token_address =
            token::create_token_address(&object_signer, &collection, &token_name);

        let player_token = borrow_global<KGeNPoAToken>(token_address);
        move player_token;

        let aptos_token = move_from<KGeNPoAToken>(token_address);
        let KGeNPoAToken { burn_ref, transfer_ref: _, mutator_ref: _, property_mutator_ref } =
            aptos_token;

        property_map::burn(property_mutator_ref);
        token::burn(option::extract(&mut burn_ref));

        let ref_registry = borrow_global_mut<TransferRefRegistry>(@KGeN);
        smart_table::remove(&mut ref_registry.ref_table, owner);

        event::emit(BurnedEvent { token_name });
    }

    /// Transfers a token between addresses (admin function)
    package fun transfer_nft(from: address, to: address) acquires TransferRefRegistry {
        let ref_registry = borrow_global_mut<TransferRefRegistry>(@KGeN);
        let transfer_ref = smart_table::remove(&mut ref_registry.ref_table, from);

        object::enable_ungated_transfer(&transfer_ref.ref);
        let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref.ref);
        object::transfer_with_ref(linear_transfer_ref, to);
        object::disable_ungated_transfer(&transfer_ref.ref); // Keeps the token soulbound

        smart_table::add(&mut ref_registry.ref_table, to, transfer_ref);
    }
}
