// Proof Of Gamer NFT Contract
//
// This smart contract on the Aptos blockchain facilitates the minting and management of a "Proof Of Gamer" NFT.
// Each token represents a unique player profile, storing the following attributes:
// - Username
// - 6 badges
// - 6 encrypted score data entries
//
// Key Features:
// - Minting: Allows one token per wallet address, ensuring uniqueness.
// - Attribute Management: Functions to update the username, token avatar CID (for profile images), and other attributes.
// - Secure Data Storage: Ensures encrypted score data is securely stored on-chain.
// - Fetch Attributes: Enables fetching all on-chain attributes for a token.
// - Burn Mechanisms: Includes functions for token burning by the user or admin.
//
// This contract is designed with security and usability in mind, promoting fair and transparent interaction for players.
module KGeN::PoGNFT {
    // ======Import standard library modules and Aptos-specific functionality======
    use std::error;
    use std::option::{Self, Option};
    use std::string::{Self, String};
    use std::signer;
    use std::vector;
    use aptos_framework::object::{Self, ConstructorRef, Object, ExtendRef};
    use aptos_token_objects::collection;
    use aptos_token_objects::property_map;
    use aptos_token_objects::token;
    use aptos_framework::event;
    use aptos_std::string_utils::{to_string};
    use aptos_std::from_bcs;
    use KGeN::kgen_oracle_storage::{Self};

    //  ======Constants======

    // The collection does not exist
    const ECOLLECTION_DOES_NOT_EXIST: u64 = 1;
    // The token does not exist
    const ETOKEN_DOES_NOT_EXIST: u64 = 2;
    // The provided signer is not the creator
    const ENOT_CREATOR: u64 = 3;
    // The field being changed is not mutable
    const EFIELD_NOT_MUTABLE: u64 = 4;
    // The token being burned is not burnable
    const ETOKEN_NOT_BURNABLE: u64 = 5;
    // The property map being mutated is not mutable
    const EPROPERTIES_NOT_MUTABLE: u64 = 6;
    // If the Property Attribute is not per the constraints
    const EINVALID_ATTRIBUTE_VALUE: u64 = 7;
    // Caller of the function is not Admin.
    const ECALLER_NOT_ADMIN: u64 = 8;
    // Error while emitting the event.
    const EEMITTING_EVENT: u64 = 9;
    // Invalid Token name
    const EINVALID_TOKEN_NAME: u64 = 10;
    // Address is not token owner
    const ENOT_OWNER: u64 = 11;
    // Token data did't change
    const ENOT_CHANGE: u64 = 12;
    // User is not the owner of the token
    const EUSER_NOT_OWNER: u64 = 13;
    // Return value is not correct
    const EINVALID_RETURN_VALUE: u64 = 14;
    // Wallet holds Max number of token
    const EMAX_TOKEN_LIMIT: u64 = 15;
    // Token is not burned successfully
    const ETOKEN_NOT_BURNED: u64 = 16;
    /// Invalid vector length for arguments
    const EINVALID_VECTOR_LENGTH: u64 = 17;
    /// Method not called by Oracle
    const EINVOKER_NOT_ORACLE: u64 = 18;
    // The KGen token collection name
    const COLLECTION_NAME: vector<u8> = b"KGeN Proof Of Gamer";
    // The KGen token collection description
    const COLLECTION_DESCRIPTION: vector<u8> = b"The Proof Of Gamer (POG) NFT collection is built on Soulbound Tokens (SBTs) unique, non-transferable NFTs that evolve dynamically to reflect a gamer's identity. Each token features the P.O.G. Score, a comprehensive metric tracking cumulative performance across five dimensions: Proof of Human, Proof of Play, Proof of Skill, Proof of Commerce, and Proof of Social.";
    // The KGen token collection URI
    const COLLECTION_URI: vector<u8> = b"www.collection.uri.com/";
    // Core seed used to create the signer.
    const TOKEN_CORE_SEED: vector<u8> = b"kGeN.123!";
    // Max number of Token a wallet can have
    const MAX_ALLOCATED: u8 = 1;

    //  ======Global Storage======

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // Storage references/state for managing KGenToken.
    struct KGenPoACollection has key {
        // Used to mutate collection fields
        mutator_ref: Option<collection::MutatorRef>,
        // Determines if the creator can mutate the collection's description
        mutable_description: bool,
        // Determines if the creator can mutate the collection's uri
        mutable_uri: bool,
        // Determines if the creator can mutate token descriptions
        mutable_token_description: bool,
        // Determines if the creator can mutate token names
        mutable_token_name: bool,
        // Determines if the creator can mutate token properties
        mutable_token_properties: bool,
        // Determines if the creator can mutate token uris
        mutable_token_uri: bool,
        // Determines if the creator can burn tokens
        tokens_burnable_by_creator: bool,
        // Determines if the creator can freeze tokens
        tokens_freezable_by_creator: bool
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // Token Object to hold the mutator_refs
    struct KGenToken has key {
        // Used to burn.
        burn_ref: Option<token::BurnRef>,
        // Used to transer freeze.
        transfer_ref: Option<object::TransferRef>,
        // Used to mutate fields
        mutator_ref: Option<token::MutatorRef>,
        // Used to mutate properties
        property_mutator_ref: property_map::MutatorRef
    }

    // Struct to retrieve the Token Attributes for a player
    struct PlayerData has drop {
        player_username: String,
        kgen_community_member_badge: String,
        proof_of_human_badge: u8,
        proof_of_play_badge: u8,
        proof_of_skill_badge: u8,
        proof_of_commerce_badge: u8,
        proof_of_social_badge: u8,
        poh_score_data: String,
        pop_score_data: String,
        posk_score_data: String,
        poc_score_data: String,
        pos_score_data: String,
        pog_score_data: String
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // Admin: stores the module admin address.
    // TODO Add allow data by oracle
    struct Admin has key {
        // Stores the address of the module admin
        admin: address,
        allow_data_by_oracle: bool
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // base_uri: stores the base uri to be concatenated with cid to get token image.
    struct BaseURI has key {
        // Stores the address of the module admin
        uri: String
    }

    // TokenCore: stores the token_extended_ref
    // We need a contract signer as the creator of the token core
    // Otherwise we need admin to sign whenever a new token is created
    // and mutated which is inconvenient
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct TokenCore has key {
        // This is the extend_ref of the token core object,
        // token core object is the creator of token object
        // but owner of each token (i.e. user)
        // token_extended_ref
        token_ext_ref: ExtendRef
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // NFT-Counter: variables to store the NFT counter.
    struct Counter has key {
        // It stores the number of NFT Created and used to concatenate in the name of the NFT too
        count: u128
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    // Store the count of PoG token hold by wallet.
    struct PoGAllocated has key {
        // It stores the number of NFT Created and used to concatenate in the name of the NFT too
        count: u8
    }

    //  ======Events======
    #[event]
    // 1. NFTMintedToPlayer: Emitted when the NFT is minted for Player.
    struct NFTMintedToPlayerEvent has store, drop {
        token_name: String,
        to: address,
        counter: u128
    }

    #[event]
    // 2. PlayerScoreUpdated: Emitted when the Players Score is updated.
    struct PlayerScoreUpdatedEvent has store, drop {
        token_name: String,
        owner: address
    }

    #[event]
    // 3. TokenNameChanged: Emitted when the Name is mutated.
    struct NFTNameChangedEvent has store, drop {
        old_name: String,
        new_name: String,
        owner: address
    }

    #[event]
    // 4. TokenUriChanged: Emitted when the when is mutated by admin.
    struct TokenUriChangedEvent has store, drop {
        owner: address,
        token_name: String
    }

    #[event]
    // 5. CustodianChanged: Emmitted when the user changes the custodian.
    struct CustodianChangedEvent has store, drop {
        token_name: String,
        owner: address,
        by: address
    }

    #[event]
    // 6. CounterIncreased: Emitted whenever the counter is increased.
    struct CounterIncrementedEvent has store, drop {
        value: u128
    }

    #[event]
    // 7. CollectionCreatedEvent: Emitted when a new collection is created.
    struct CollectionCreatedEvent has store, drop {
        name: String,
        creator: address
    }

    #[event]
    // 8. UserBurnedEvent: Emitted when a user burns a token.
    struct UserBurnedEvent has store, drop {
        token_name: String
    }

    #[event]
    // 9. AdminBurnedEvent: Emitted when an admin burns a token
    struct AdminBurnedEvent has store, drop {
        token_name: String
    }

    //  ======View Functions======

    #[view]
    // 1. get_admin()
    public fun get_admin(): address acquires Admin {
        borrow_global<Admin>(@KGeN).admin
    }

    #[view]
    // 2. get_counter_value()
    public fun get_counter_value(): u128 acquires Counter {
        borrow_global<Counter>(@KGeN).count
    }

    #[view]
    // 3. get_player_score()
    public fun get_player_data(token_name: String): PlayerData {

        let token = get_token_object(token_name);

        let result = PlayerData {
            player_username: property_map::read_string(
                &token, &string::utf8(b"Username")
            ),
            kgen_community_member_badge: property_map::read_string(
                &token, &string::utf8(b"KGEN Community Badge")
            ),
            proof_of_human_badge: property_map::read_u8(
                &token, &string::utf8(b"Proof of Human Badge")
            ),
            proof_of_play_badge: property_map::read_u8(
                &token, &string::utf8(b"Proof of Play Badge")
            ),
            proof_of_skill_badge: property_map::read_u8(
                &token, &string::utf8(b"Proof of Skill Badge")
            ),
            proof_of_commerce_badge: property_map::read_u8(
                &token, &string::utf8(b"Proof of Commerce Badge")
            ),
            proof_of_social_badge: property_map::read_u8(
                &token, &string::utf8(b"Proof of Social Badge")
            ),
            poh_score_data: property_map::read_string(
                &token, &string::utf8(b"Proof of Human Score Data (Encrypted)")
            ),
            pop_score_data: property_map::read_string(
                &token, &string::utf8(b"Proof of Play Score Data (Encrypted)")
            ),
            posk_score_data: property_map::read_string(
                &token, &string::utf8(b"Proof of Skill Score Data (Encrypted)")
            ),
            poc_score_data: property_map::read_string(
                &token, &string::utf8(b"Proof of Commerce Score Data (Encrypted)")
            ),
            pos_score_data: property_map::read_string(
                &token, &string::utf8(b"Proof of Social Score Data (Encrypted)")
            ),
            pog_score_data: property_map::read_string(
                &token, &string::utf8(b"Proof of Gamer Score Data (Encrypted)")
            )
        };

        result
    }

    #[view]
    // Return whether wallet reached the limit for token count
    public fun is_pog_allocated(wallet_address: address): bool acquires PoGAllocated {
        if (exists<PoGAllocated>(wallet_address)) {
            return borrow_global<PoGAllocated>(wallet_address).count >= MAX_ALLOCATED
        };
        false
    }

    #[view]
    // Return whether wallet reached the limit for token count
    public fun get_collection_address(): address {
        let creator = get_token_signer_address();
        let collection_name = string::utf8(COLLECTION_NAME);
        let addr = collection::create_collection_address(&creator, &collection_name);
        addr
    }

    #[view]
    public fun get_token_object(token_name: String): Object<KGenToken> {
        let creator = get_token_signer_address();
        let collection_name = string::utf8(COLLECTION_NAME);

        let token_address =
            token::create_token_address(&creator, &collection_name, &token_name);
        object::address_to_object<KGenToken>(token_address)
    }

    #[view]
    public fun is_oracle_required(): bool acquires Admin {
        borrow_global<Admin>(@KGeN).allow_data_by_oracle
    }

    //  ====== Module Initialization Function======
    //init_module(): called once when the module is initialized/deployed.Initializes the module with required structures and objects.
    fun init_module(admin: &signer) {

        // Create a token constructor reference using the admin's signer
        let token_constructor_ref = &object::create_named_object(admin, TOKEN_CORE_SEED);

        // Generate extension reference and signer for future token store operations
        let token_ext_ref = object::generate_extend_ref(token_constructor_ref);
        let token_signer = object::generate_signer(token_constructor_ref);

        // Move the token core struct to the token signer address to initiate the token core object
        move_to(&token_signer, TokenCore { token_ext_ref });

        // Create a collection object for minting tokens
        create_collection_object(
            &token_signer,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true
        );

        // Store the admin address in the Admin resource
        let admin_address = signer::address_of(admin);
        move_to(admin, Admin { admin: admin_address, allow_data_by_oracle: false });

        // Store the base URI for the token
        let uri = string::utf8(
            b"https://teal-far-lemming-411.mypinata.cloud/ipfs/"
        );
        move_to(admin, BaseURI { uri: uri });

        // Initialize a counter resource
        let counter_value = 1;
        move_to(admin, Counter { count: counter_value });

        // Emit a counter incremented event
        let counter_event = CounterIncrementedEvent { value: counter_value };
        event::emit(counter_event);
    }

    //  ======Helper Functions======

    //Retrieves the base URI from the global storage, where the URI is stored.
    public fun get_base_uri(): String acquires BaseURI {
        borrow_global<BaseURI>(@KGeN).uri
    }

    // create_collections(): create a collection of objects from  where the tokens will be minted from .
    fun create_collection_object(
        creator: &signer,
        mutable_description: bool,
        mutable_uri: bool,
        mutable_token_description: bool,
        mutable_token_name: bool,
        mutable_token_properties: bool,
        mutable_token_uri: bool,
        tokens_burnable_by_creator: bool,
        tokens_freezable_by_creator: bool
    ): Object<KGenPoACollection> {

        let description = string::utf8(COLLECTION_DESCRIPTION);
        let name = string::utf8(COLLECTION_NAME);
        let uri = string::utf8(COLLECTION_URI);

        // Create the collection object using the creator's signer
        let _creator_addr = signer::address_of(creator);
        let constructor_ref =
            collection::create_unlimited_collection(
                creator, description, name, option::none(), uri
            );

        let object_signer = object::generate_signer(&constructor_ref);
        let mutator_ref =
            if (mutable_description || mutable_uri) {
                option::some(collection::generate_mutator_ref(&constructor_ref))
            } else {
                option::none()
            };

        let aptos_collection = KGenPoACollection {
            mutator_ref,
            // royalty_mutator_ref,
            mutable_description,
            mutable_uri,
            mutable_token_description,
            mutable_token_name,
            mutable_token_properties,
            mutable_token_uri,
            tokens_burnable_by_creator,
            tokens_freezable_by_creator
        };
        move_to(&object_signer, aptos_collection);

        let creator_address = signer::address_of(creator);

        let event = CollectionCreatedEvent { name, creator: creator_address };

        event::emit(event);
        // Return the constructed object from the constructor reference
        object::object_from_constructor_ref(&constructor_ref)
    }

    // mint_internal() Internal method to mint a token and return its constructor reference.
    fun mint_internal(
        creator: &signer,
        collection: String,
        description: String,
        token_name: String,
        avatar_cid: String,
        property_keys: vector<String>,
        property_types: vector<String>,
        property_values: vector<vector<u8>>
    ): ConstructorRef acquires KGenPoACollection, BaseURI {

        let uri = get_base_uri();
        string::append(&mut uri, avatar_cid);

        // Create a new token with the given properties
        let constructor_ref =
            token::create_named_token(
                creator,
                collection,
                description,
                token_name,
                option::none(),
                uri
            );

        // Generate object signer and mutator references for the token

        let object_signer = object::generate_signer(&constructor_ref);
        let collection_addr =
            collection::create_collection_address(
                &signer::address_of(creator), &collection
            );

        let collection_obj =
            object::address_to_object<KGenPoACollection>(collection_addr);
        let collection_address = object::object_address(&collection_obj);
        let collection = borrow_global<KGenPoACollection>(collection_address);

        // Generate mutator reference if token description, name, or URI are mutable
        let mutator_ref =
            if (
                collection.mutable_token_description
                    // 9. get_counter_value()
                    || collection.mutable_token_name
                    || collection.mutable_token_uri) {
                option::some(token::generate_mutator_ref(&constructor_ref))
            } else {
                option::none()
            };

        // Generate burn reference if the creator is allowed to burn tokens
        let burn_ref =
            if (collection.tokens_burnable_by_creator) {
                option::some(token::generate_burn_ref(&constructor_ref))
            } else {
                option::none()
            };

        // Prepare the properties and initialize them in the token
        let properties =
            property_map::prepare_input(property_keys, property_types, property_values);
        property_map::init(&constructor_ref, properties);

        // Create the token object and store it
        let aptos_token = KGenToken {
            burn_ref,
            transfer_ref: option::none(),
            mutator_ref,
            property_mutator_ref: property_map::generate_mutator_ref(&constructor_ref)
        };
        move_to(&object_signer, aptos_token);

        // Return the constructor reference for the minted token
        constructor_ref
    }

    // get_token_signer_address(): Retrieves the address of the token signer (e.g., the module address for the Token Core).
    fun get_token_signer_address(): address {
        object::create_object_address(&@KGeN, TOKEN_CORE_SEED)
    }

    // get_token_signer(): Retrieves the signer for the token core, using the provided signer address (e.g., for extending the Token Core).
    fun get_token_signer(token_signer_address: address): signer acquires TokenCore {
        object::generate_signer_for_extending(
            &borrow_global<TokenCore>(token_signer_address).token_ext_ref
        )
    }

    // ======Inline Methods======
    // 2. collection_object(): Returns the collection object from creater address and collection name.
    inline fun collection_object(creator: &signer, name: &String): Object<KGenPoACollection> {
        let collection_addr =
            collection::create_collection_address(&signer::address_of(creator), name);
        object::address_to_object<KGenPoACollection>(collection_addr)
    }

    // 3. borrow_collection(): Return the referenece to collection object from the token object
    inline fun borrow_collection<T: key>(token: &Object<T>): &KGenPoACollection {
        let collection_address = object::object_address(token);
        assert!(
            exists<KGenPoACollection>(collection_address),
            error::not_found(ECOLLECTION_DOES_NOT_EXIST)
        );
        borrow_global<KGenPoACollection>(collection_address)
    }

    fun merge_player_props(
        o_keys: vector<String>,
        o_values: vector<vector<u8>>,
        i_keys: vector<String>,
        i_values: vector<vector<u8>>
    ): (vector<String>, vector<vector<u8>>){
        let result_keys = vector::empty<String>();
        let result_values = vector::empty<vector<u8>>();

        vector::for_each(o_keys, |k| { vector::push_back(&mut result_keys, k); });
        vector::for_each(o_values, |v| { vector::push_back(&mut result_values, v); });

        vector::for_each(i_keys, |k| { 
            if(!vector::contains(&result_keys, &k)){
                vector::push_back(&mut result_keys, k);
                let (_bo, i) = vector::index_of(&i_keys, &k);
                vector::push_back(&mut result_values, *vector::borrow(&i_values, i));
            }
        });
        (result_keys, result_values)
    }

    //  ======Entry Functions======
    //  manage_admin(): Allows the current admin to change the admin address.
    // Ensures the caller is the current admin before updating the admin's address.
    public entry fun manage_admin(admin: &signer, new_admin: address) acquires Admin {
        assert!(
            signer::address_of(admin) == get_admin(),
            error::permission_denied(ECALLER_NOT_ADMIN)
        );

        let admin = borrow_global_mut<Admin>(@KGeN);

        admin.admin = new_admin;
    }

    public entry fun manage_oracle_approval(admin: &signer, status: bool) acquires Admin {
        assert!(
            signer::address_of(admin) == get_admin(),
            error::permission_denied(ECALLER_NOT_ADMIN)
        );

        let admin = borrow_global_mut<Admin>(@KGeN);

        admin.allow_data_by_oracle = status;
    }

    // Mint function only invoked after oracle
    public entry fun mint_player_nft_by_oracle(
        user: &signer,
        admin: &signer,
        player_username: String,
        avatar_cid: String,
        i_keys: vector<String>,
        i_values: vector<vector<u8>>
    ) acquires Counter, KGenPoACollection, TokenCore, Admin, KGenToken, BaseURI, PoGAllocated {
        assert!(
            signer::address_of(admin) == get_admin(),
            error::permission_denied(ECALLER_NOT_ADMIN)
        );

        assert!(
            !is_pog_allocated(signer::address_of(user)),
            error::permission_denied(EMAX_TOKEN_LIMIT)
        );

        // Collection name of the token.
        let collection_name = string::utf8(COLLECTION_NAME);

        // Storing the counter value in a variable.
        let counter_value = borrow_global_mut<Counter>(@KGeN);

        // Creating the Token name.
        let token_name = string::utf8(b"kgen.io-#");
        string::append(&mut token_name, to_string(&counter_value.count));

        let token_description =
            string::utf8(
                b"This Soulbound Token represents a unique gaming identity, evolving dynamically with badge levels and encrypted score data."
            );

        // fetching the signer Object
        let creator = get_token_signer(get_token_signer_address());

        let constructor_ref =
            mint_internal(
                &creator,
                collection_name,
                token_description,
                token_name,
                avatar_cid,
                vector[],
                vector[],
                vector[]
            );

        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        // Transfers the token to the `soul_bound_to` address
        let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref);
        object::transfer_with_ref(linear_transfer_ref, signer::address_of(user));
        // Disables ungated transfer, thus making the token soulbound and non-transferable
        object::disable_ungated_transfer(&transfer_ref);

        // Emmiting the mint event
        let mint_event = NFTMintedToPlayerEvent {
            token_name,
            to: signer::address_of(user),
            counter: counter_value.count
        };

        event::emit(mint_event);

        if (!exists<PoGAllocated>(signer::address_of(user))) {
            move_to(user, PoGAllocated { count: 1 });
        } else {
            let count = borrow_global_mut<PoGAllocated>(signer::address_of(user));
            count.count = count.count + 1;
        };

        let token_address =
            token::create_token_address(
                &get_token_signer_address(),
                &collection_name,
                &token_name
            );
        let aptos_token = borrow_global<KGenToken>(token_address);

        let (okeys, ovalues) =
            kgen_oracle_storage::get_player_props(signer::address_of(user));

        // TODO Match keys and values from oracle and input
        let (keys, values) = merge_player_props(okeys, ovalues, i_keys, i_values);

        let mutator_ref = &aptos_token.property_mutator_ref;

        property_map::add_typed(
            mutator_ref,
            string::utf8(b"Username"),
            player_username
        );

        let keys_len = vector::length(&keys);
        // let values_len = vector::length(&values);
        assert!(
            keys_len == vector::length(&values),
            error::invalid_argument(EINVALID_VECTOR_LENGTH)
        );

        let tp = string::utf8(b"0x1::string::String");

        let i = 0;
        while (i < keys_len) {
            let key = *vector::borrow(&keys, i);
            let value = *vector::borrow(&values, i);

            // Validate badge values
            if (key == string::utf8(b"Proof of Human Badge")) {
                assert!(
                    from_bcs::to_u8(value) <= 2,
                    error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
                );
                tp = string::utf8(b"u8");
            } else if (key == string::utf8(b"Proof of Play Badge")
                || key == string::utf8(b"Proof of Skill Badge")
                || key == string::utf8(b"Proof of Commerce Badge")
                || key == string::utf8(b"Proof of Social Badge")) {
                assert!(
                    from_bcs::to_u8(value) <= 10,
                    error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
                );
                tp = string::utf8(b"u8");
            };
            property_map::add(mutator_ref, key, tp, value);
            tp = string::utf8(b"0x1::string::String");
            i = i + 1;
        };

        // Emit player score update event
        let score_event = PlayerScoreUpdatedEvent {
            token_name,
            owner: signer::address_of(user)
        };
        event::emit(score_event);

        // Emit counter increment event
        counter_value.count = counter_value.count + 1;
        let counter_event = CounterIncrementedEvent { value: counter_value.count };
        event::emit(counter_event);

    }

    // mint_player_nft(): Mints a soulbound NFT for a player with detailed attributes.
    public entry fun mint_player_nft(
        user: &signer,
        admin: &signer,
        player_username: String,
        avatar_cid: String,
        kgen_community_member_badge: String,
        proof_of_human_badge: u8,
        proof_of_play_badge: u8,
        proof_of_skill_badge: u8,
        proof_of_commerce_badge: u8,
        proof_of_social_badge: u8,
        poh_score_data: String,
        pop_score_data: String,
        posk_score_data: String,
        poc_score_data: String,
        pos_score_data: String,
        pog_score_data: String
    ) acquires Counter, KGenPoACollection, TokenCore, KGenToken, Admin, BaseURI, PoGAllocated {
        assert!(!is_oracle_required(), error::permission_denied(EINVOKER_NOT_ORACLE));

        assert!(
            signer::address_of(admin) == get_admin(),
            error::permission_denied(ECALLER_NOT_ADMIN)
        );

        assert!(
            !is_pog_allocated(signer::address_of(user)),
            error::permission_denied(EMAX_TOKEN_LIMIT)
        );

        // Collection name of the token.
        let collection_name = string::utf8(COLLECTION_NAME);

        // Storing the counter value in a variable.
        let counter_value = borrow_global_mut<Counter>(@KGeN);

        // Creating the Token name.
        let token_name = string::utf8(b"kgen.io-#");
        string::append(&mut token_name, to_string(&counter_value.count));

        let token_description =
            string::utf8(
                b"This Soulbound Token represents a unique gaming identity, evolving dynamically with badge levels and encrypted score data."
            );

        // fetching the signer Object
        let creator = get_token_signer(get_token_signer_address());

        let constructor_ref =
            mint_internal(
                &creator,
                collection_name,
                token_description,
                token_name,
                avatar_cid,
                vector[],
                vector[],
                vector[]
            );

        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        // Transfers the token to the `soul_bound_to` address
        let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref);
        object::transfer_with_ref(linear_transfer_ref, signer::address_of(user));
        // Disables ungated transfer, thus making the token soulbound and non-transferable
        object::disable_ungated_transfer(&transfer_ref);

        // Emmiting the mint event
        let mint_event = NFTMintedToPlayerEvent {
            token_name,
            to: signer::address_of(user),
            counter: counter_value.count
        };

        event::emit(mint_event);

        if (!exists<PoGAllocated>(signer::address_of(user))) {
            move_to(user, PoGAllocated { count: 1 });
        } else {
            let count = borrow_global_mut<PoGAllocated>(signer::address_of(user));
            count.count = count.count + 1;
        };

        let token_address =
            token::create_token_address(
                &get_token_signer_address(),
                &collection_name,
                &token_name
            );
        let aptos_token = borrow_global<KGenToken>(token_address);

        // Adding the UserName
        property_map::add_typed(
            &aptos_token.property_mutator_ref,
            string::utf8(b"Username"),
            player_username
        );

        // Adding KGen Community Badge
        property_map::add_typed(
            &aptos_token.property_mutator_ref,
            string::utf8(b"KGEN Community Badge"),
            kgen_community_member_badge
        );

        // Level Verification and Adding Badges
        // Proof of Human Badge
        assert!(
            proof_of_human_badge <= 2,
            error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
        );
        property_map::add_typed(
            &aptos_token.property_mutator_ref,
            string::utf8(b"Proof of Human Badge"),
            proof_of_human_badge
        );

        // Proof of Play Badge
        assert!(
            proof_of_play_badge <= 10,
            error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
        );
        property_map::add_typed(
            &aptos_token.property_mutator_ref,
            string::utf8(b"Proof of Play Badge"),
            proof_of_play_badge
        );

        // Proof of Skill Badge
        assert!(
            proof_of_skill_badge <= 10,
            error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
        );
        property_map::add_typed(
            &aptos_token.property_mutator_ref,
            string::utf8(b"Proof of Skill Badge"),
            proof_of_skill_badge
        );

        // Proof of Commerce Badge
        assert!(
            proof_of_commerce_badge <= 10,
            error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
        );
        property_map::add_typed(
            &aptos_token.property_mutator_ref,
            string::utf8(b"Proof of Commerce Badge"),
            proof_of_commerce_badge
        );

        // Proof of Social Badge
        assert!(
            proof_of_social_badge <= 10,
            error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
        );
        property_map::add_typed(
            &aptos_token.property_mutator_ref,
            string::utf8(b"Proof of Social Badge"),
            proof_of_social_badge
        );

        // Adding encrypted data
        property_map::add_typed(
            &aptos_token.property_mutator_ref,
            string::utf8(b"Proof of Human Score Data (Encrypted)"),
            poh_score_data
        );
        property_map::add_typed(
            &aptos_token.property_mutator_ref,
            string::utf8(b"Proof of Play Score Data (Encrypted)"),
            pop_score_data
        );
        property_map::add_typed(
            &aptos_token.property_mutator_ref,
            string::utf8(b"Proof of Skill Score Data (Encrypted)"),
            posk_score_data
        );
        property_map::add_typed(
            &aptos_token.property_mutator_ref,
            string::utf8(b"Proof of Commerce Score Data (Encrypted)"),
            poc_score_data
        );
        property_map::add_typed(
            &aptos_token.property_mutator_ref,
            string::utf8(b"Proof of Social Score Data (Encrypted)"),
            pos_score_data
        );
        property_map::add_typed(
            &aptos_token.property_mutator_ref,
            string::utf8(b"Proof of Gamer Score Data (Encrypted)"),
            pog_score_data
        );

        // Emit player score update event
        let score_event = PlayerScoreUpdatedEvent {
            token_name,
            owner: signer::address_of(user)
        };
        event::emit(score_event);

        // Emit counter increment event
        counter_value.count = counter_value.count + 1;
        let counter_event = CounterIncrementedEvent { value: counter_value.count };
        event::emit(counter_event);
    }

    // change_username_attribute(): Updates the name of the token, ensuring the caller is the token owner.
    public entry fun change_username_attribute(
        user: &signer,
        admin: &signer,
        token_name: String,
        username: String
    ) acquires KGenToken, Admin, {
        assert!(
            signer::address_of(admin) == get_admin(),
            error::permission_denied(ECALLER_NOT_ADMIN)
        );

        let collection = string::utf8(COLLECTION_NAME);
        let object_signer = get_token_signer_address();
        let token_address =
            token::create_token_address(&object_signer, &collection, &token_name);
        let token = object::address_to_object<KGenToken>(token_address);
        let aptos_token = borrow_global<KGenToken>(token_address);

        assert!(
            object::owner(token) == signer::address_of(user),
            error::permission_denied(EUSER_NOT_OWNER)
        );

        let old_name = property_map::read_string(&token, &string::utf8(b"Username"));

        property_map::update_typed(
            &aptos_token.property_mutator_ref, &string::utf8(b"Username"), username
        );
        let event = NFTNameChangedEvent {
            old_name,
            new_name: username,
            owner: object::owner(token)
        };

        event::emit(event);
    }

    // change_avatar_cid(): Updates the avatar URI for the token, ensuring the caller is the token owner.
    public entry fun change_avatar_cid(
        user: &signer,
        admin: &signer,
        token_name: String,
        avatar_cid: String
    ) acquires BaseURI, Admin, KGenToken {
        assert!(
            signer::address_of(admin) == get_admin(),
            error::permission_denied(ECALLER_NOT_ADMIN)
        );

        let collection_name = string::utf8(COLLECTION_NAME);
        let token_address =
            token::create_token_address(
                &get_token_signer_address(),
                &collection_name,
                &token_name
            );

        let token = object::address_to_object<KGenToken>(token_address);
        let aptos_token = borrow_global<KGenToken>(token_address);

        assert!(
            object::owner(token) == signer::address_of(user),
            error::permission_denied(EUSER_NOT_OWNER)
        );

        let uri = get_base_uri();
        string::append(&mut uri, avatar_cid);

        token::set_uri(option::borrow(&aptos_token.mutator_ref), uri);

        let event = TokenUriChangedEvent { owner: signer::address_of(user), token_name };

        event::emit(event);
    }

    // burn_by_user(): Allows a user to burn their token, ensuring the caller is the token owner.
    public entry fun burn_by_user(
        user: &signer, admin: &signer, token_name: String
    ) acquires KGenToken, Admin, PoGAllocated {
        assert!(
            signer::address_of(admin) == get_admin(),
            error::permission_denied(ECALLER_NOT_ADMIN)
        );

        let collection = string::utf8(COLLECTION_NAME);
        let object_signer = get_token_signer_address();
        let token_address =
            token::create_token_address(&object_signer, &collection, &token_name);
        let token = object::address_to_object<KGenToken>(token_address);
        assert!(
            object::owner(token) == signer::address_of(user),
            error::permission_denied(EUSER_NOT_OWNER)
        );

        let player_token = borrow_global<KGenToken>(token_address);
        assert!(
            option::is_some(&player_token.burn_ref),
            error::permission_denied(ETOKEN_NOT_BURNABLE)
        );
        move player_token;
        let aptos_token = move_from<KGenToken>(token_address);
        let KGenToken { burn_ref, transfer_ref: _, mutator_ref: _, property_mutator_ref } =
            aptos_token;
        property_map::burn(property_mutator_ref);
        token::burn(option::extract(&mut burn_ref));

        let count = borrow_global_mut<PoGAllocated>(signer::address_of(user));
        count.count = count.count - 1;

        event::emit(UserBurnedEvent { token_name });
    }

    // burn_by_admin(): Allows admin to burn token.
    public entry fun burn_by_admin(
        admin: &signer, token_name: String
    ) acquires KGenToken, Admin, PoGAllocated {
        assert!(
            signer::address_of(admin) == get_admin(),
            error::permission_denied(ECALLER_NOT_ADMIN)
        );

        let collection = string::utf8(COLLECTION_NAME);
        let object_signer = get_token_signer_address();
        let token_address =
            token::create_token_address(&object_signer, &collection, &token_name);
        let token = object::address_to_object<KGenToken>(token_address);

        let user = object::owner(token);

        let player_token = borrow_global<KGenToken>(token_address);
        assert!(
            option::is_some(&player_token.burn_ref),
            error::permission_denied(ETOKEN_NOT_BURNABLE)
        );
        move player_token;
        let aptos_token = move_from<KGenToken>(token_address);
        let KGenToken { burn_ref, transfer_ref: _, mutator_ref: _, property_mutator_ref } =
            aptos_token;
        property_map::burn(property_mutator_ref);
        token::burn(option::extract(&mut burn_ref));

        let count = borrow_global_mut<PoGAllocated>(user);
        count.count = count.count - 1;

        event::emit(AdminBurnedEvent { token_name });
    }

    // Update method only callable by oracle
    public entry fun update_player_score_by_oracle(
        user: &signer,
        admin: &signer,
        token_name: String,
        i_keys: vector<String>,
        i_values: vector<vector<u8>>
    ) acquires KGenToken, Admin {
        let (okeys, ovalues) =
            kgen_oracle_storage::get_player_props(signer::address_of(user));
        // TODO Match keys and values from oracle and input
        let (keys, values) = merge_player_props(okeys, ovalues, i_keys, i_values);
        update_player_score(user, admin, token_name, keys, values);
    }

    public entry fun update_player_score(
        user: &signer,
        admin: &signer,
        token_name: String,
        keys: vector<String>,
        values: vector<vector<u8>>
    ) acquires KGenToken, Admin {
        assert!(!is_oracle_required(), error::permission_denied(EINVOKER_NOT_ORACLE));

        assert!(
            signer::address_of(admin) == get_admin(),
            error::permission_denied(ECALLER_NOT_ADMIN)
        );

        let creator = get_token_signer_address();
        let collection = string::utf8(COLLECTION_NAME);

        let token_address = token::create_token_address(
            &creator, &collection, &token_name
        );

        let token = object::address_to_object<KGenToken>(token_address);

        assert!(
            object::owner(token) == signer::address_of(user),
            error::permission_denied(EUSER_NOT_OWNER)
        );

        let aptos_token = borrow_global<KGenToken>(token_address);
        let mutator_ref = &aptos_token.property_mutator_ref;
        let keys_len = vector::length(&keys);
        // let values_len = vector::length(&values);
        assert!(
            keys_len == vector::length(&values),
            error::invalid_argument(EINVALID_VECTOR_LENGTH)
        );

        let tp = string::utf8(b"0x1::string::String");

        let i = 0;
        while (i < keys_len) {
            let key = *vector::borrow(&keys, i);
            let value = *vector::borrow(&values, i);

            // Validate badge values
            if (key == string::utf8(b"Proof of Human Badge")) {
                assert!(
                    from_bcs::to_u8(value) <= 2,
                    error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
                );
                tp = string::utf8(b"u8");
            } else if (key == string::utf8(b"Proof of Play Badge")
                || key == string::utf8(b"Proof of Skill Badge")
                || key == string::utf8(b"Proof of Commerce Badge")
                || key == string::utf8(b"Proof of Social Badge")) {
                assert!(
                    from_bcs::to_u8(value) <= 10,
                    error::invalid_argument(EINVALID_ATTRIBUTE_VALUE)
                );
                tp = string::utf8(b"u8");
            };
            property_map::update(mutator_ref, &key, tp, value);
            tp = string::utf8(b"0x1::string::String");
            i = i + 1;
        };
        let event = PlayerScoreUpdatedEvent { token_name, owner: object::owner(token) };

        event::emit(event);
    }

    // ======Test Cases======

    #[test(admin = @KGeN, acc1 = @0x1)]
    public fun test_mint_and_burn_by_user(
        admin: &signer, acc1: &signer
    ) acquires TokenCore, KGenToken, Counter, KGenPoACollection, Admin, BaseURI, PoGAllocated {
        init_module(admin);

        assert!(get_counter_value() == 1, 89898);

        mint_player_nft(
            acc1,
            admin,
            string::utf8(b"Rkoranne0755"),
            string::utf8(b"QmesLTdEB5qEXeu8MQiBFWgYcqs2FgbVEgUuFCHs6M4B1B"),
            string::utf8(b"Yes"),
            1,
            2,
            3,
            4,
            5,
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes")
        );
        let collection_name = string::utf8(COLLECTION_NAME);
        let token_name = string::utf8(b"kgen.io-#1");

        let token_address =
            token::create_token_address(
                &get_token_signer_address(),
                &collection_name,
                &token_name
            );

        assert!(exists<KGenToken>(token_address), 5);

        burn_by_user(acc1, admin, token_name);

        assert!(!exists<KGenToken>(token_address), 7);
    }

    #[test(admin = @KGeN, acc1 = @0x1)]
    public fun test_mint_and_burn_by_admin(
        admin: &signer, acc1: &signer
    ) acquires TokenCore, KGenToken, Counter, KGenPoACollection, Admin, BaseURI, PoGAllocated {
        init_module(admin);

        mint_player_nft(
            acc1,
            admin,
            string::utf8(b"Rkoranne0755"),
            string::utf8(b"QmesLTdEB5qEXeu8MQiBFWgYcqs2FgbVEgUuFCHs6M4B1B"),
            string::utf8(b"Yes"),
            1,
            2,
            3,
            4,
            5,
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes")
        );
        let collection_name = string::utf8(COLLECTION_NAME);
        let token_name = string::utf8(b"kgen.io-#1");

        let token_address =
            token::create_token_address(
                &get_token_signer_address(),
                &collection_name,
                &token_name
            );

        assert!(exists<KGenToken>(token_address), 5);

        burn_by_admin(admin, token_name);

        assert!(
            !exists<KGenToken>(token_address),
            error::not_implemented(ETOKEN_NOT_BURNED)
        );
    }

    #[test(admin = @KGeN, acc1 = @0x1)]
    public fun test_fetch_and_update(
        admin: &signer, acc1: &signer
    ) acquires TokenCore, KGenToken, Counter, KGenPoACollection, Admin, BaseURI, PoGAllocated {
        init_module(admin);

        mint_player_nft(
            acc1,
            admin,
            string::utf8(b"Rkoranne0755"),
            string::utf8(b"QmesLTdEB5qEXeu8MQiBFWgYcqs2FgbVEgUuFCHs6M4B1B"),
            string::utf8(b"Yes"),
            1,
            2,
            3,
            4,
            5,
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes")
        );
        let collection_name = string::utf8(COLLECTION_NAME);
        let token_name = string::utf8(b"kgen.io-#1");

        let token_address =
            token::create_token_address(
                &get_token_signer_address(),
                &collection_name,
                &token_name
            );

        assert!(exists<KGenToken>(token_address), 5);

        let result = get_player_data(token_name);

        assert!(
            result.player_username == string::utf8(b"Rkoranne0755"),
            error::invalid_state(EINVALID_RETURN_VALUE)
        );
        assert!(
            result.kgen_community_member_badge == string::utf8(b"Yes"),
            error::invalid_state(EINVALID_RETURN_VALUE)
        );
        assert!(
            result.proof_of_human_badge == 1,
            error::invalid_state(EINVALID_RETURN_VALUE)
        );
        assert!(
            result.proof_of_play_badge == 2,
            error::invalid_state(EINVALID_RETURN_VALUE)
        );
        assert!(
            result.proof_of_skill_badge == 3,
            error::invalid_state(EINVALID_RETURN_VALUE)
        );
        assert!(
            result.proof_of_commerce_badge == 4,
            error::invalid_state(EINVALID_RETURN_VALUE)
        );
        assert!(
            result.proof_of_social_badge == 5,
            error::invalid_state(EINVALID_RETURN_VALUE)
        );
        // Encrypted Data
        assert!(
            result.poh_score_data == string::utf8(b"Yes"),
            error::invalid_state(EINVALID_RETURN_VALUE)
        );
        assert!(
            result.pop_score_data == string::utf8(b"Yes"),
            error::invalid_state(EINVALID_RETURN_VALUE)
        );
        assert!(
            result.posk_score_data == string::utf8(b"Yes"),
            error::invalid_state(EINVALID_RETURN_VALUE)
        );
        assert!(
            result.poc_score_data == string::utf8(b"Yes"),
            error::invalid_state(EINVALID_RETURN_VALUE)
        );
        assert!(
            result.pos_score_data == string::utf8(b"Yes"),
            error::invalid_state(EINVALID_RETURN_VALUE)
        );
        assert!(
            result.pog_score_data == string::utf8(b"Yes"),
            error::invalid_state(EINVALID_RETURN_VALUE)
        );

        let badges = vector::empty<String>();

        let levels = vector::empty<vector<u8>>();

        update_player_score(acc1, admin, token_name, badges, levels);

    }

    #[test(admin = @KGeN, acc1 = @0x1)]
    public fun test_change_token_name_and_avatar_uri(
        admin: &signer, acc1: &signer
    ) acquires TokenCore, KGenToken, Counter, KGenPoACollection, Admin, BaseURI, PoGAllocated {
        init_module(admin);

        mint_player_nft(
            acc1,
            admin,
            string::utf8(b"Rkoranne0755"),
            string::utf8(b"QmesLTdEB5qEXeu8MQiBFWgYcqs2FgbVEgUuFCHs6M4B1B"),
            string::utf8(b"Yes"),
            1,
            2,
            3,
            4,
            5,
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes")
        );
        let collection_name = string::utf8(COLLECTION_NAME);
        let token_name = string::utf8(b"kgen.io-#1");

        let token_address =
            token::create_token_address(
                &get_token_signer_address(),
                &collection_name,
                &token_name
            );

        let token = object::address_to_object<KGenToken>(token_address);
        assert!(exists<KGenToken>(token_address), 5);

        assert!(
            property_map::read_string(&token, &string::utf8(b"Username"))
                == string::utf8(b"Rkoranne0755"),
            error::invalid_state(EINVALID_RETURN_VALUE)
        );

        change_username_attribute(
            acc1,
            admin,
            token_name,
            string::utf8(b"iMentus")
        );

        assert!(
            property_map::read_string(&token, &string::utf8(b"Username"))
                == string::utf8(b"iMentus"),
            error::invalid_state(EINVALID_RETURN_VALUE)
        );

        assert!(
            token::uri(token)
                == string::utf8(
                    b"https://teal-far-lemming-411.mypinata.cloud/ipfs/QmesLTdEB5qEXeu8MQiBFWgYcqs2FgbVEgUuFCHs6M4B1B"
                ),
            error::invalid_state(EINVALID_RETURN_VALUE)
        );

        change_avatar_cid(
            acc1,
            admin,
            token_name,
            string::utf8(b"Rkoranne0755")
        );

        assert!(
            token::uri(token)
                == string::utf8(
                    b"https://teal-far-lemming-411.mypinata.cloud/ipfs/Rkoranne0755"
                ),
            error::invalid_state(EINVALID_RETURN_VALUE)
        );
    }

    #[test(admin = @KGeN, acc1 = @0x1)]
    public fun test_manage_admin(admin: &signer, acc1: &signer) acquires Admin {
        init_module(admin);
        assert!(
            get_admin() == signer::address_of(admin),
            error::invalid_state(ECALLER_NOT_ADMIN)
        );

        manage_admin(admin, signer::address_of(acc1));
        assert!(
            get_admin() == signer::address_of(acc1),
            error::invalid_state(ECALLER_NOT_ADMIN)
        );

    }

    #[test(admin = @KGeN, acc1 = @0x1)]
    // #[expected_failure()]
    public fun test_max_limit(
        admin: &signer, acc1: &signer
    ) acquires TokenCore, KGenToken, Counter, KGenPoACollection, Admin, BaseURI, PoGAllocated {
        init_module(admin);
        mint_player_nft(
            acc1,
            admin,
            string::utf8(b"Rkoranne0755"),
            string::utf8(b"QmesLTdEB5qEXeu8MQiBFWgYcqs2FgbVEgUuFCHs6M4B1B"),
            string::utf8(b"Yes"),
            1,
            2,
            3,
            4,
            5,
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes")
        );
        let token_name = string::utf8(b"kgen.io-#1");
        burn_by_user(acc1, admin, token_name);
        mint_player_nft(
            acc1,
            admin,
            string::utf8(b"Rkoranne0755"),
            string::utf8(b"QmesLTdEB5qEXeu8MQiBFWgYcqs2FgbVEgUuFCHs6M4B1B"),
            string::utf8(b"Yes"),
            1,
            2,
            3,
            4,
            5,
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes")
        );
        token_name = string::utf8(b"kgen.io-#2");
        burn_by_admin(admin, token_name);
        mint_player_nft(
            acc1,
            admin,
            string::utf8(b"Rkoranne0755"),
            string::utf8(b"QmesLTdEB5qEXeu8MQiBFWgYcqs2FgbVEgUuFCHs6M4B1B"),
            string::utf8(b"Yes"),
            1,
            2,
            3,
            4,
            5,
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes")
        );
        token_name = string::utf8(b"kgen.io-#3");
        let collection_name = string::utf8(COLLECTION_NAME);
        let creator = get_token_signer(get_token_signer_address());
        let token_address =
            token::create_token_address(
                &signer::address_of(&creator),
                &collection_name,
                &token_name
            );

        assert!(exists<KGenToken>(token_address), 16);
    }

    #[test(admin = @KGeN)]
    public fun test_collection_address(admin: &signer) {
        init_module(admin);
        // std::debug::print(&get_collection_address());
        // std::debug::print(&get_collection_address());
        // std::debug::print(&get_collection_address());
        // std::debug::print(&get_collection_address());
    }

    #[test(admin = @KGeN, acc1 = @0x1)]
    #[expected_failure]
    public fun test_oracle_approvale(
        admin: &signer, acc1: &signer
    ) acquires TokenCore, KGenToken, Counter, KGenPoACollection, Admin, BaseURI, PoGAllocated {
        init_module(admin);

        assert!(
            !is_oracle_required(),
            error::invalid_state(EINVALID_RETURN_VALUE)
        );

        manage_oracle_approval(admin, true);

        assert!(
            is_oracle_required(),
            error::invalid_state(EINVALID_RETURN_VALUE)
        );

        mint_player_nft(
            acc1,
            admin,
            string::utf8(b"Rkoranne0755"),
            string::utf8(b"QmesLTdEB5qEXeu8MQiBFWgYcqs2FgbVEgUuFCHs6M4B1B"),
            string::utf8(b"Yes"),
            1,
            2,
            3,
            4,
            5,
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes"),
            string::utf8(b"Yes")
        );
    }

    #[test(admin = @KGeN, acc1 = @0x1)]
    // #[expected_failure()]
    public fun test_mint_oracle(
        admin: &signer, acc1: &signer
    ) acquires TokenCore, KGenToken, Counter, KGenPoACollection, Admin, BaseURI, PoGAllocated {
        init_module(admin);

        let keys = vector::empty<String>();
        let values = vector::empty<vector<u8>>();

        mint_player_nft_by_oracle(
            acc1,
            admin,
            string::utf8(b"player1"),
            string::utf8(b"player1"),
            keys,
            values
        );
    }

    #[test]
    public fun test_merge_vector() {
        let keys = vector::empty<String>();
        let i_keys = vector::empty<String>();
        let values = vector::empty<vector<u8>>();
        let i_values = vector::empty<vector<u8>>();

        vector::push_back(&mut keys, string::utf8(b"kgen_community_member_badge"));
        vector::push_back(&mut keys, string::utf8(b"Proof of Human Badge"));

        vector::push_back(&mut values, vector<u8>[0x01, 0x02, 0x03]);
        vector::push_back(&mut values, vector<u8>[0x04, 0x05, 0x06]);

        vector::push_back(&mut i_keys, string::utf8(b"Proof of Human Badge"));
        vector::push_back(&mut i_keys, string::utf8(b"Proof of Play Badge"));

        vector::push_back(&mut i_values, vector<u8>[0x07, 0x08, 0x08]);
        vector::push_back(&mut i_values, vector<u8>[0x05, 0x04, 0x04]);

        // std::debug::print(&keys);
        // std::debug::print(&values);
        // std::debug::print(&i_keys);
        // std::debug::print(&i_values);

        (keys, values) = merge_player_props(keys, values, i_keys, i_values);
        std::debug::print(&keys);
        std::debug::print(&values);

    }
}
