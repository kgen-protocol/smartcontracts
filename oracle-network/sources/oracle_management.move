module KGeN::oracle_management {
    // === Dependencies ===
    use std::error;
    use std::event;
    use std::signer;
    use std::vector;
    use std::option::{Self, Option};
    use std::string::{Self, String};
    use aptos_std::smart_table;
    use aptos_std::from_bcs;

    use KGeN::oracle_poa_nft;
    use KGeN::oracle_keys;
    use KGeN::oracle_aggregator;
    use KGeN::oracle_reward;

    // === Constants ===

    /// Caller is not the admin.
    const ENOT_ADMIN: u64 = 1;
    /// Oracle node is not yet registered.
    const EORACLE_NOT_REGISTERED: u64 = 2;
    /// Proxy address is not assigned to be updated.
    const EPROXY_NOT_ASSIGNED: u64 = 3;
    /// PoA-NFT is already minted for the oracle node.
    const ENFT_ALREADY_MINTED: u64 = 4;
    /// PoA-NFT is not minted for the oracle node.
    const ENFT_NOT_MINTED: u64 = 5;
    /// A wallet is already nominated for the oracle node.
    const EALREADY_NOMINATED: u64 = 6;
    /// No wallet is nominated for the oracle node.
    const ENOT_NOMINATED: u64 = 7;
    /// Nomination not approved by the admin.
    const ENOT_APPROVED_BY_ADMIN: u64 = 8;
    /// Signer wallet is not nominated.
    const EINVALID_WALLET: u64 = 9;
    /// Method is invoked by a non-assigned oracle proxy.
    const ESIGNER_NOT_PROXY: u64 = 10;
    /// No admin is currently nominated.
    const ENO_NOMINATED_ADMIN: u64 = 11;
    /// Oracle node is already registered.
    const EORACLE_ALREADY_REGISTERED: u64 = 12;
    /// Invalid Status for Oracle Node.
    const EINVALID_STATUS: u64 = 13;
    /// Platform trying to add is already added.
    const EPLATFORM_ALREADY_EXISTS: u64 = 14;
    /// Platform trying to remove not already added.
    const EPLATFORM_NOT_EXISTS: u64 = 15;
    /// Signer is not Node Monitor.
    const EINVALID_NODE_MONITOR: u64 = 16;
    /// Secondary Signer is not valid Admin Web Platform.
    const EINVALID_ADMIN_PLATFORM: u64 = 17;
    /// Secondary Signer is not valid Operator Web Platform.
    const EINVALID_OPERATOR_PLATFORM: u64 = 18;
    /// Secondary Signer is not valid Proxy Automation Platform.
    const EINVALID_PROXY_PLATFROM: u64 = 19;
    /// Proxy address being updated is same as previous.
    const EPROXY_ADD_IS_SAME: u64 = 20;
    /// Proxy is already assigned for the operator.
    const EPROXY_ALREADY_ASSIGNED: u64 = 21;
    /// Address trying to add is already present.
    const EALREADY_ADDED: u64 = 22;
    /// Address trying to remove is not present.
    const ENOT_PRESENT: u64 = 23;
    /// Value trying to update is same.
    const EVALUE_ALREADY_PRESENT: u64 = 24;
    /// Given Leader Node Address is already chosen.
    const EALREADY_LEADER: u64 = 25; // Error code: Leader node address is already set

    // === Structs ===

    // Represents the configuration and state of an oracle node.
    struct OracleNodeStruct has store, drop, copy {
        is_registered: bool, // Indicates if the node is registered
        candidate_name: String, // Name of the oracle operator
        reward_wallet: address, // Wallet address for receiving rewards
        is_stablecoin_applicable: bool, // Whether the node supports stablecoin rewards
        amount_of_keys: u64, // Number of key tokens allocated
        is_proxy_assigned: bool, // Whether a proxy is assigned
        current_proxy_add: Option<address>, // Current proxy address (if assigned)
        is_poa_minted: bool, // Whether the PoA-NFT is minted
        node_public_key: vector<u8>, // Current public key (unused in this version)
        nominated_wallet: Option<address>, // Wallet nominated to replace primary wallet
        nomination_approved: bool, // Whether the nomination is admin-approved
        is_reward_applicable: bool // Whether the node is eligible for rewards
    }

    // Stores admin-related data and the oracle node registry.
    struct AdminStore has key {
        admin_address: address, // Address of the current admin
        node_monitors: vector<address>, // List of node monitor addresses
        nominated_admin: Option<address>, // Address of the nominated admin (if any)
        node_registry: smart_table::SmartTable<address, OracleNodeStruct>, // Registry of oracle nodes
        kgen_pub_key: String, // KGeN public key (initialized as @0x0)
        admin_web_platform: vector<address>, // Authorized admin web platforms
        operator_web_platform: vector<address>, // Authorized operator web platforms
        proxy_automation_platform: vector<address> // Authorized proxy automation platforms
    }

    // === Events ===

    // Emitted when a new oracle node is registered.
    #[event]
    struct OracleRegisteredEvent has key, store, drop {
        candidate_address: address // Address of the registered oracle node
    }

    // Emitted when a proxy is assigned to an oracle node.
    #[event]
    struct ProxyAssignedToOracleNodeEvent has key, store, drop {
        oracle_address: address, // Oracle node address
        proxy_address: address // Assigned proxy address
    }

    // Emitted when a proxy address is updated for an oracle node.
    #[event]
    struct OracleNodeProxyUpdatedEvent has key, store, drop {
        oracle_address: address, // Oracle node address
        previous_proxy_address: address, // Previous proxy address
        updated_proxy_address: address // New proxy address
    }

    // Emitted when a proxy is revoked and public key is updated for an oracle node.
    #[event]
    struct OracleNodeProxyAndUpdatePublicKeyEvent has key, store, drop {
        oracle_address: address, // Oracle node address
        revoked_proxy_address: address, // Revoked proxy address
        public_key: address // New public key
    }

    // Emitted when a proxy is revoked from an oracle node.
    #[event]
    struct OracleNodeProxyRevokedEvent has key, store, drop {
        oracle_address: address // Oracle node address
    }

    // Emitted when an operator mints a PoA-NFT and key tokens.
    #[event]
    struct MintByOperatorEvent has key, store, drop {
        oracle_operator: address, // Operator address
        oracle_node_pubkey: address // Public key address
    }

    // Emitted when a proxy mints a PoA-NFT and key tokens for an oracle node.
    #[event]
    struct MintByOracleProxyEvent has key, store, drop {
        proxy_address: address, // Proxy address
        oracle_operator: address, // Operator address
        oracle_node_pubkey: address // Public key address
    }

    // Emitted when the leader node is updated.
    #[event]
    struct LeaderNodeUpdatedEvent has key, store, drop {
        // previous_leader_address: address, // Previous leader address
        new_leader_address: address // New leader address
    }

    // Emitted when an admin nominates a new admin.
    #[event]
    struct AdminNominatedEvent has key, store, drop {
        admin: address, // Current admin address
        nominated_admin: address // Nominated admin address
    }

    // Emitted when the admin role is transferred.
    #[event]
    struct AdminUpdatedEvent has key, store, drop {
        prev_admin: address, // Previous admin address
        updated_admin: address // New admin address
    }

    // Emitted when a node monitor is added.
    #[event]
    struct NodeMonitorAddedEvent has key, store, drop {
        node_monitor: address // Added node monitor address
    }

    // Emitted when a node monitor is revoked.
    #[event]
    struct NodeMonitorRevokedEvent has key, store, drop {
        node_monitor: address // Revoked node monitor address
    }

    // Emitted when secondary leaders are added.
    #[event]
    struct SecondaryLeaderAddedEvent has key, store, drop {
        secondary_leader_address: vector<address> // Added secondary leader addresses
    }

    // Emitted when an oracle's status is updated.
    #[event]
    struct OperatorActivityStatusUpdatedEvent has key, store, drop {
        oracle_address: address, // Oracle node address
        status: String // New status
    }

    // Emitted when an operator updates an oracle's public key.
    #[event]
    struct PublicKeyUpdatedByOperatorEvent has key, store, drop {
        oracle_address: address, // Oracle node address
        new_public_key: address // New public key address
    }

    // Emitted when a proxy updates an oracle's public key.
    #[event]
    struct PublicKeyUpdatedByProxyEvent has key, store, drop {
        oracle_proxy: address, // Proxy address
        oracle_address: address, // Oracle node address
        new_public_key: address // New public key address
    }

    // Emitted when an oracle's PoA-NFT is revoked (not implemented).
    #[event]
    struct OraclePoANFTRevokedEvent has key, store, drop {
        operator: address // Operator address
    }

    // Emitted when a wallet is nominated for an oracle node.
    #[event]
    struct WalletNominatedEvent has key, store, drop {
        oracle_address: address, // Oracle node address
        nominated_wallet: address // Nominated wallet address
    }

    // Emitted when the admin approves a wallet nomination.
    #[event]
    struct AdminApprovesNominationEvent has key, store, drop {
        oracle_address: address // Oracle node address
    }

    // Emitted when an oracle node's primary wallet is updated.
    #[event]
    struct PrimaryWalletUpdatedEvent has key, store, drop {
        oracle_address: address, // Previous primary wallet address
        new_primary_wallet: address // New primary wallet address
    }

    // Emitted when a wallet nomination is revoked.
    #[event]
    struct NominationRevokedEvent has key, store, drop {
        oracle_address: address // Oracle node address
    }

    // Emitted when the admin nominates a wallet for an oracle node.
    #[event]
    struct WalletNominatedByAdminEvent has key, store, drop {
        oracle_address: address, // Oracle node address
        nominated_wallet: address // Nominated wallet address
    }

    // Emitted when a secondary leader's status is updated.
    #[event]
    struct OracleNodeStatusUpdatedEvent has key, store, drop {
        node_monitor: address, // Node monitor address
        node: vector<u8>, // Secondary leader address
        status: bool // New status
    }

    // Emitted when an admin web platform is added.
    #[event]
    struct AdminWebPlatformAddedEvent has key, store, drop {
        admin: address, // Admin address
        platform: vector<address> // Added platform addresses
    }

    // Emitted when an admin web platform is revoked.
    #[event]
    struct AdminWebPlatformRevokedEvent has key, store, drop {
        admin: address, // Admin address
        platform: vector<address> // Revoked platform addresses
    }

    // Emitted when an operator web platform is added.
    #[event]
    struct OperatorWebPlatformAddedEvent has key, store, drop {
        admin: address, // Admin address
        platform: vector<address> // Added platform addresses
    }

    // Emitted when an operator web platform is revoked.
    #[event]
    struct OperatorWebPlatformRevokedEvent has key, store, drop {
        admin: address, // Admin address
        platform: vector<address> // Revoked platform addresses
    }

    // Emitted when a proxy automation platform is added.
    #[event]
    struct ProxyAutomationPlatformAddedEvent has key, store, drop {
        admin: address, // Admin address
        platform: vector<address> // Added platform addresses
    }

    // Emitted when a proxy automation platform is revoked.
    #[event]
    struct ProxyAutomationPlatformRevokedEvent has key, store, drop {
        admin: address, // Admin address
        platform: vector<address> // Revoked platform addresses
    }

    // Emitted when the batch size is updated.
    #[event]
    struct BatchSizeUpdatedEvent has key, store, drop {
        batch_size: u64, // New batch size
        admin: address // Admin who updated it
    }

    // Emitted when the page size is updated.
    #[event]
    struct PageSizeUpdatedEvent has key, store, drop {
        page_size: u64, // New page size
        admin: address // Admin who updated it
    }

    #[event]
    struct NumOffChainRoundCountUpdated has key, store, drop {
        round_count: u64, // New page size
        admin: address // Admin who updated it
    }

    // Emitted when the round interval is updated.
    #[event]
    struct RoundIntervalUpdatedEvent has key, store, drop {
        round_interval: u64, // New round interval
        admin: address // Admin who updated it
    }

    // Emitted when upfront rKGeN is transferred by an operator.
    #[event]
    struct UpfrontTransferredByOperatorEvent has key, store, drop {
        operator: address // Operator address
    }

    // Emitted when a reward wallet is updated by an operator.
    #[event]
    struct RewardWalletUpdatedByOperatorEvent has key, store, drop {
        operator: address, // Operator address
        reward_wallet: address // New reward wallet address
    }

    // Emitted when a reward is claimed by an operator.
    #[event]
    struct RewardClaimedByOperatorEvent has key, store, drop {
        operator: address // Operator address
    }

    // Emitted when a new tier is added for rewards.
    #[event]
    struct NewTierAddedEvent has key, store, drop {
        admin: address, // Admin address
        min_keys: vector<u64>, // Minimum keys for each tier
        max_keys: vector<u64>, // Maximum keys for each tier
        stablecoin_yield: vector<u64>, // Stablecoin yield for each tier
        bonus_rKGeN_yield: vector<u64>, // Bonus rKGeN yield for each tier
        rKGeN_per_key: vector<u64> // rKGeN per key for each tier
    }

    // Emitted when the key price is updated.
    #[event]
    struct KeyPriceUpdatedEvent has key, store, drop {
        admin: address, // Admin address
        key_price: u64 // New key price
    }

    // Emitted when the days for upfront rewards are updated.
    #[event]
    struct DaysUpfrontUpdatedEvent has key, store, drop {
        admin: address, // Admin address
        days_for_upfront: u64 // New days for upfront rewards
    }

    // Emitted when the stablecoin metadata is updated.
    #[event]
    struct StablecoinMetadataUpdatedEvent has key, store, drop {
        admin: address, // Admin address
        stablecoin_metadata: address // New stablecoin metadata address
    }

    // Emitted when the rKGeN metadata is updated.
    #[event]
    struct RKGeNMetadataUpdatedEvent has key, store, drop {
        admin: address, // Admin address
        rKGeN_metadata: address // New rKGeN metadata address
    }

    // === View Functions ===

    // Returns the current admin address.
    #[view]
    public fun get_admin_address(): address acquires AdminStore {
        borrow_global<AdminStore>(@KGeN).admin_address
    }

    // Returns whether the primary wallet is registered.
    #[view]
    public fun is_registered(primary_wallet: address): bool acquires AdminStore {
        let oracle_registry = borrow_global<AdminStore>(@KGeN);
        smart_table::contains(&oracle_registry.node_registry, primary_wallet)
    }

    // Returns the OracleNodeStruct for a primary wallet or a default struct if not registered.
    #[view]
    public fun get_oralce_info(primary_wallet: address): OracleNodeStruct acquires AdminStore {
        let oracle_registry = borrow_global<AdminStore>(@KGeN);
        if (smart_table::contains(&oracle_registry.node_registry, primary_wallet)) {
            return *smart_table::borrow(&oracle_registry.node_registry, primary_wallet)
        };
        // Return a default struct if the wallet is not registered
        return OracleNodeStruct {
            is_registered: false,
            candidate_name: std::string::utf8(b"None"),
            reward_wallet: @0x0,
            is_stablecoin_applicable: false,
            amount_of_keys: 0,
            is_proxy_assigned: false,
            current_proxy_add: option::none(),
            is_poa_minted: false,
            node_public_key: vector::empty<u8>(),
            nominated_wallet: option::none(),
            nomination_approved: false,
            is_reward_applicable: false
        }
    }

    // Returns the activity status of an oracle node.
    #[view]
    public fun get_activity_status(primary_wallet: address): String acquires AdminStore {
        let oracle_registry = borrow_global<AdminStore>(@KGeN);
        if (!smart_table::contains(&oracle_registry.node_registry, primary_wallet)) {
            return string::utf8(b"")
        };

        let operator =
            *smart_table::borrow(&oracle_registry.node_registry, primary_wallet);

        if (operator.is_poa_minted) {
            let token_name = operator.candidate_name;
            string::append(&mut token_name, string::utf8(b".kgen.io"));
            return oracle_poa_nft::get_oracle_active_status(token_name)
        };

        return string::utf8(b"")
    }

    #[view]
    public fun get_kgen_public_key(): String acquires AdminStore {
        borrow_global<AdminStore>(@KGeN).kgen_pub_key
    }

    // === Initialization ===

    // Initializes the module by setting up the AdminStore resource under the admin's account.
    fun init_module(admin: &signer) {
        // Create and initialize the AdminStore resource
        let node_monitors = vector::empty<address>();
        vector::push_back(
            &mut node_monitors,
            @0x0a01df134b9c874d19c147d3a541984341591372e3939eb411c158b31c9405f0
        );
        let operator_web_platform = vector::empty<address>();
        vector::push_back(
            &mut operator_web_platform,
            @0xe48415b8202f110a6ae22663bf3cbfb23af56ac675803c59519d3f0350767d44
        );
        let proxy_automation_platform = vector::empty<address>();
        vector::push_back(
            &mut proxy_automation_platform,
            @0xa09f4a7e8f73fa5b4986a841b4ac4d8c35ed8d6687b723ab04c9573ea2bd2782
        );
        let admin_resource = AdminStore {
            admin_address: signer::address_of(admin),
            node_monitors,
            nominated_admin: option::none(),
            node_registry: smart_table::new<address, OracleNodeStruct>(),
            kgen_pub_key: string::utf8(
                b"03c3036fd066c9467472b5374c3665349dd735c01f58c6983ffb19ae799d759734"
            ),
            admin_web_platform: vector::empty<address>(),
            operator_web_platform,
            proxy_automation_platform
        };
        // Store the resource under the admin's address
        move_to(admin, admin_resource);
    }

    // === Oracle Registration ===

    // Registers a new oracle node with the provided details.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun register_oracle(
        admin: &signer,
        admin_web_platform: &signer,
        primary_wallet: address,
        reward_wallet: address,
        operator_name: String,
        amount_of_keys: u64,
        is_stablecoin_applicable: bool,
        is_reward_applicable: bool
    ) acquires AdminStore {
        // Verify the caller is the admin
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));

        // Add the node to the registry
        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure the primary wallet isn't already registered
        assert!(
            !smart_table::contains(&oracle_registry.node_registry, primary_wallet),
            error::already_exists(EORACLE_ALREADY_REGISTERED)
        );

        // Create a new oracle node struct
        let candidate_oracle_node = OracleNodeStruct {
            is_registered: true,
            candidate_name: operator_name,
            reward_wallet: reward_wallet,
            is_stablecoin_applicable: is_stablecoin_applicable,
            amount_of_keys: amount_of_keys,
            is_proxy_assigned: false,
            current_proxy_add: option::none(),
            is_poa_minted: false,
            node_public_key: vector::empty<u8>(),
            nominated_wallet: option::none(),
            nomination_approved: false,
            is_reward_applicable: is_reward_applicable
        };

        smart_table::add(
            &mut oracle_registry.node_registry,
            primary_wallet,
            candidate_oracle_node
        );

        // Emit registration event
        event::emit(OracleRegisteredEvent { candidate_address: primary_wallet });
    }

    // === Proxy Management ===

    // Assigns a proxy address to an oracle node.
    // Only callable by the operator and an authorized operator web platform.
    public entry fun assign_proxy(
        oracle_operator: &signer, operator_web_platform: &signer, proxy_address: address
    ) acquires AdminStore {
        assert_operator_web_platform(signer::address_of(operator_web_platform));
        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure the oracle node is registered
        assert!(
            smart_table::contains(
                &oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            ),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        let operator =
            smart_table::borrow_mut(
                &mut oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            );

        assert!(
            !operator.is_proxy_assigned,
            error::already_exists(EPROXY_ALREADY_ASSIGNED)
        );

        // Assign the proxy
        operator.is_proxy_assigned = true;
        operator.current_proxy_add = option::some(proxy_address);

        // Update proxy in PoA-NFT if minted
        if (operator.is_poa_minted) {
            oracle_poa_nft::update_proxy_address(operator.candidate_name, proxy_address);
        };

        // Emit proxy assignment event
        event::emit(
            ProxyAssignedToOracleNodeEvent {
                oracle_address: signer::address_of(oracle_operator),
                proxy_address: proxy_address
            }
        );
    }

    // Updates the proxy address for an oracle node.
    // Only callable by the operator and an authorized operator web platform.
    public entry fun update_proxy(
        oracle_operator: &signer, operator_web_platform: &signer, proxy_address: address
    ) acquires AdminStore {
        assert_operator_web_platform(signer::address_of(operator_web_platform));
        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure the oracle node is registered
        assert!(
            smart_table::contains(
                &oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            ),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        let operator =
            smart_table::borrow_mut(
                &mut oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            );

        // Ensure a proxy is already assigned
        assert!(
            operator.is_proxy_assigned,
            error::not_found(EPROXY_NOT_ASSIGNED)
        );

        let prev_proxy_add = *option::borrow<address>(&operator.current_proxy_add);

        assert!(
            prev_proxy_add != proxy_address, error::already_exists(EPROXY_ADD_IS_SAME)
        );

        operator.current_proxy_add = option::some(proxy_address);

        // Update proxy in PoA-NFT if minted
        if (operator.is_poa_minted) {
            oracle_poa_nft::update_proxy_address(operator.candidate_name, proxy_address);
        };

        // Emit proxy update event
        event::emit(
            OracleNodeProxyUpdatedEvent {
                oracle_address: signer::address_of(oracle_operator),
                previous_proxy_address: prev_proxy_add,
                updated_proxy_address: proxy_address
            }
        );
    }

    // Revokes the proxy address and updates the public key for an oracle node.
    // Only callable by the operator and an authorized operator web platform.
    public entry fun revoke_proxy_and_update_public_key(
        oracle_operator: &signer, operator_web_platform: &signer, public_key: vector<u8>
    ) acquires AdminStore {
        assert_operator_web_platform(signer::address_of(operator_web_platform));
        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure the oracle node is registered
        assert!(
            smart_table::contains(
                &oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            ),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        let operator =
            smart_table::borrow_mut(
                &mut oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            );

        // Ensure a proxy is already assigned
        assert!(
            operator.is_proxy_assigned,
            error::not_found(EPROXY_NOT_ASSIGNED)
        );

        let prev_public_key = operator.node_public_key;
        operator.node_public_key = public_key;

        let prev_proxy_add = *option::borrow<address>(&operator.current_proxy_add);
        operator.current_proxy_add = option::none();
        operator.is_proxy_assigned = false;

        // Update proxy in PoA-NFT if minted
        if (operator.is_poa_minted) {
            oracle_poa_nft::remove_proxy_address(operator.candidate_name);
            oracle_poa_nft::manage_pub_key(operator.candidate_name, public_key);
            oracle_aggregator::update_pub_key(prev_public_key, public_key);
        };

        // Emit proxy update event
        event::emit(
            OracleNodeProxyAndUpdatePublicKeyEvent {
                oracle_address: signer::address_of(oracle_operator),
                revoked_proxy_address: prev_proxy_add,
                public_key: from_bcs::to_address(public_key)
            }
        );
    }

    // Revokes the proxy from an oracle node.
    // Only callable by the operator and an authorized operator web platform.
    public entry fun revoke_proxy(
        oracle_operator: &signer, operator_web_platform: &signer
    ) acquires AdminStore {
        assert_operator_web_platform(signer::address_of(operator_web_platform));
        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure the oracle node is registered
        assert!(
            smart_table::contains(
                &oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            ),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        let operator =
            smart_table::borrow_mut(
                &mut oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            );

        // Ensure a proxy is assigned
        assert!(
            operator.is_proxy_assigned,
            error::not_found(EPROXY_NOT_ASSIGNED)
        );

        // Revoke the proxy
        operator.is_proxy_assigned = false;
        operator.current_proxy_add = option::none();

        // Remove proxy from PoA-NFT if minted
        if (operator.is_poa_minted) {
            oracle_poa_nft::remove_proxy_address(operator.candidate_name);
        };

        // Emit proxy revocation event
        event::emit(
            OracleNodeProxyRevokedEvent {
                oracle_address: signer::address_of(oracle_operator)
            }
        );
    }

    // === Minting Functions ===

    // Mints PoA-NFT and key tokens for an oracle node.
    // Only callable by the operator and an authorized operator web platform.
    public entry fun mint_by_operator(
        oracle_operator: &signer,
        operator_web_platform: &signer,
        oracle_node_pubkey: vector<u8>
    ) acquires AdminStore {
        assert_operator_web_platform(signer::address_of(operator_web_platform));
        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure the oracle node is registered
        assert!(
            smart_table::contains(
                &oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            ),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        let operator =
            smart_table::borrow_mut(
                &mut oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            );

        // Ensure PoA-NFT is not already minted
        assert!(
            !operator.is_poa_minted,
            error::already_exists(ENFT_ALREADY_MINTED)
        );

        operator.node_public_key = oracle_node_pubkey;

        // Mint the PoA-NFT
        oracle_poa_nft::mint_poa_nft(
            signer::address_of(oracle_operator),
            operator.candidate_name,
            oracle_node_pubkey
        );

        // Mint key tokens
        oracle_keys::mint_for_oracle(
            signer::address_of(oracle_operator),
            operator.amount_of_keys
        );

        // Register public key in the aggregator
        oracle_aggregator::add_pub_key(oracle_node_pubkey);

        // Integrate reward logic
        oracle_reward::add_reward_wallet(
            signer::address_of(oracle_operator),
            operator.reward_wallet,
            operator.is_stablecoin_applicable,
            operator.is_reward_applicable
        );

        operator.is_poa_minted = true;

        // Emit minting event
        event::emit(
            MintByOperatorEvent {
                oracle_operator: signer::address_of(oracle_operator),
                oracle_node_pubkey: from_bcs::to_address(oracle_node_pubkey)
            }
        );
    }

    // Mints PoA-NFT and key tokens on behalf of an oracle node.
    // Only callable by the assigned proxy and an authorized proxy automation platform.
    public entry fun mint_by_proxy(
        oracle_proxy: &signer,
        proxy_automation_platform: &signer,
        primary_wallet: address,
        oracle_node_pubkey: vector<u8>
    ) acquires AdminStore {
        assert_proxy_automation_platform(signer::address_of(proxy_automation_platform));
        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure the oracle node is registered
        assert!(
            smart_table::contains(&oracle_registry.node_registry, primary_wallet),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        let operator =
            smart_table::borrow_mut(
                &mut oracle_registry.node_registry,
                primary_wallet
            );

        // Ensure a proxy is assigned
        assert!(
            operator.is_proxy_assigned,
            error::not_found(EPROXY_NOT_ASSIGNED)
        );

        operator.node_public_key = oracle_node_pubkey;

        // Verify the caller is the assigned proxy
        let proxy_add = *option::borrow<address>(&operator.current_proxy_add);
        assert!(
            signer::address_of(oracle_proxy) == proxy_add,
            error::unauthenticated(ESIGNER_NOT_PROXY)
        );

        // Ensure PoA-NFT is not already minted
        assert!(
            !operator.is_poa_minted,
            error::already_exists(ENFT_ALREADY_MINTED)
        );

        // Mint the PoA-NFT
        oracle_poa_nft::mint_poa_nft(
            primary_wallet,
            operator.candidate_name,
            oracle_node_pubkey
        );

        // Mint key tokens
        oracle_keys::mint_for_oracle(primary_wallet, operator.amount_of_keys);

        // Register public key in the aggregator
        oracle_aggregator::add_pub_key(oracle_node_pubkey);

        // Integrate reward logic
        oracle_reward::add_reward_wallet(
            primary_wallet,
            operator.reward_wallet,
            operator.is_stablecoin_applicable,
            operator.is_reward_applicable
        );

        operator.is_poa_minted = true;

        // Emit minting event
        event::emit(
            MintByOracleProxyEvent {
                proxy_address: signer::address_of(oracle_proxy),
                oracle_operator: primary_wallet,
                oracle_node_pubkey: from_bcs::to_address(oracle_node_pubkey)
            }
        );
    }

    // === Admin Management ===

    // Nominates a new admin.
    // Only callable by the current admin and an authorized admin web platform.
    public entry fun nominate_admin(
        admin: &signer, admin_web_platform: &signer, nominated_admin: address
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));

        let admin_resource = borrow_global_mut<AdminStore>(@KGeN);

        assert!(
            !option::is_some<address>(&admin_resource.nominated_admin),
            error::not_found(EALREADY_NOMINATED)
        );

        admin_resource.nominated_admin = option::some(nominated_admin);

        // Emit nomination event
        event::emit(AdminNominatedEvent { admin: get_admin_address(), nominated_admin });
    }

    // Accepts the admin nomination.
    // Only callable by the nominated admin and an authorized admin web platform.
    public entry fun accept_admin_nomination(
        nominated_admin: &signer, proxy_automation_platform: &signer
    ) acquires AdminStore {
        assert_admin_web_platform(signer::address_of(proxy_automation_platform));
        let admin_resource = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure an admin is nominated
        assert!(
            option::is_some<address>(&admin_resource.nominated_admin),
            error::not_found(ENO_NOMINATED_ADMIN)
        );

        // Verify the caller is the nominated admin
        let nominated_admin_address =
            *option::borrow<address>(&admin_resource.nominated_admin);
        assert!(
            signer::address_of(nominated_admin) == nominated_admin_address,
            error::unauthenticated(EINVALID_WALLET)
        );

        let prev_admin = admin_resource.admin_address;
        admin_resource.admin_address = nominated_admin_address;
        admin_resource.nominated_admin = option::none();

        // Emit admin update event
        event::emit(
            AdminUpdatedEvent { prev_admin, updated_admin: nominated_admin_address }
        );
    }

    //For custom timestamp for the reward
    public entry fun toggle_custom_time(
        admin: &signer, admin_web_platform: &signer, state: bool
    ) acquires AdminStore {
        assert_admin_web_platform(signer::address_of(admin_web_platform));
        assert_admin(admin);
        oracle_reward::toggle_custom_time(state);
    }

    public entry fun set_manual_timestamp(
        admin: &signer, admin_web_platform: &signer, new_time: u64
    ) acquires AdminStore {
        assert_admin_web_platform(signer::address_of(admin_web_platform));
        assert_admin(admin);
        oracle_reward::set_manual_timestamp(new_time);
    }

    // Adds a node monitor.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun add_node_monitor(
        admin: &signer, admin_web_platform: &signer, node_monitor: address
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));

        let store = borrow_global_mut<AdminStore>(@KGeN);
        assert!(
            !vector::contains(&store.node_monitors, &node_monitor),
            error::already_exists(EALREADY_ADDED)
        );
        vector::push_back(&mut store.node_monitors, node_monitor);

        // Emit monitor addition event
        event::emit(NodeMonitorAddedEvent { node_monitor });
    }

    // Revokes a node monitor.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun remove_node_monitor(
        admin: &signer, admin_web_platform: &signer, node_monitor: address
    ) acquires AdminStore {
        assert_admin_web_platform(signer::address_of(admin_web_platform));
        assert_admin(admin);

        let monitor_vector = borrow_global_mut<AdminStore>(@KGeN);
        assert!(
            vector::contains(&monitor_vector.node_monitors, &node_monitor),
            error::not_found(ENOT_PRESENT)
        );
        vector::remove_value(&mut monitor_vector.node_monitors, &node_monitor);

        // Emit monitor revocation event
        event::emit(NodeMonitorRevokedEvent { node_monitor });
    }

    // === Leader Node Management ===

    // Updates the leader node in the oracle aggregator.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun update_leader_node(
        admin: &signer, admin_web_platform: &signer, new_leader_address: address
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));

        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure the oracle node is registered
        assert!(
            smart_table::contains(
                &oracle_registry.node_registry,
                new_leader_address
            ),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        let operator =
            smart_table::borrow_mut(
                &mut oracle_registry.node_registry,
                new_leader_address
            );

        assert!(operator.is_poa_minted, error::not_found(ENFT_NOT_MINTED));

        let current_leader_address = oracle_aggregator::get_active_leader();

        assert!(
            !(&operator.node_public_key == &current_leader_address),
            error::already_exists(EALREADY_LEADER)
        );

        oracle_aggregator::manage_leader(operator.node_public_key);

        // Emit leader update event
        event::emit(
            LeaderNodeUpdatedEvent {
                // previous_leader_address: signer::address_of(admin),
                new_leader_address
            }
        );
    }

    // Adds secondary leaders to the oracle aggregator.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun add_secondary_leaders(
        admin: &signer,
        admin_web_platform: &signer,
        secondary_leader_addresses: vector<address>
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));

        let addresses = vector::empty<vector<u8>>();
        let oracle_registry = borrow_global<AdminStore>(@KGeN);

        for (i in 0..vector::length(&secondary_leader_addresses)) {
            // Ensure the oracle node is registered

            let p_add = *vector::borrow(&secondary_leader_addresses, i);
            assert!(
                smart_table::contains(&oracle_registry.node_registry, p_add),
                error::not_found(EORACLE_NOT_REGISTERED)
            );

            let operator = smart_table::borrow(&oracle_registry.node_registry, p_add);

            assert!(operator.is_poa_minted, error::not_found(ENFT_NOT_MINTED));

            let pub_key = operator.node_public_key;

            vector::push_back(&mut addresses, pub_key);

        };

        oracle_aggregator::add_secondary_leader(addresses);

        // Emit secondary leader addition event
        event::emit(
            SecondaryLeaderAddedEvent {
                secondary_leader_address: secondary_leader_addresses
            }
        );
    }

    // Revokes secondary leaders from the oracle aggregator.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun remove_secondary_leaders(
        admin: &signer,
        admin_web_platform: &signer,
        secondary_leader_addresses: vector<address>
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));

        let addresses = vector::empty<vector<u8>>();
        let oracle_registry = borrow_global<AdminStore>(@KGeN);

        for (i in 0..vector::length(&secondary_leader_addresses)) {
            // Ensure the oracle node is registered

            let p_add = *vector::borrow(&secondary_leader_addresses, i);
            assert!(
                smart_table::contains(&oracle_registry.node_registry, p_add),
                error::not_found(EORACLE_NOT_REGISTERED)
            );

            let operator = smart_table::borrow(&oracle_registry.node_registry, p_add);

            assert!(operator.is_poa_minted, error::not_found(ENFT_NOT_MINTED));

            let pub_key = operator.node_public_key;

            vector::push_back(&mut addresses, pub_key);

        };

        oracle_aggregator::revoke_secondary_leader(addresses);

        // Emit secondary leader revocation event
        event::emit(
            SecondaryLeaderAddedEvent {
                secondary_leader_address: secondary_leader_addresses
            }
        );
    }

    // Manages the online status of an oracle node.
    // Only callable by a node monitor.
    public entry fun set_is_online_status(
        monitor_node: &signer, public_key: vector<u8>, online_status: bool
    ) acquires AdminStore {
        assert_node_monitors(signer::address_of(monitor_node));
        oracle_aggregator::manage_online_status(public_key, online_status);
        event::emit(
            OracleNodeStatusUpdatedEvent {
                node_monitor: signer::address_of(monitor_node), // Node monitor address
                node: public_key, // Secondary leader address
                status: online_status // New status
            }
        )
    }

    public entry fun admin_force_round_stop(
        admin: &signer, admin_web_platform: &signer
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));
        oracle_aggregator::admin_force_round_stop()
    }

    public entry fun admin_force_round_start(
        admin: &signer, admin_web_platform: &signer
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));
        oracle_aggregator::admin_force_round_start()
    }

    public entry fun admin_force_round_stop_and_start(
        admin: &signer, admin_web_platform: &signer
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));
        oracle_aggregator::admin_force_round_stop_and_start()
    }

    // === Platform Management ===

    // Adds an admin web platform.
    // Only callable by the admin.
    public entry fun add_admin_web_platform(
        admin: &signer, platform_address: vector<address>
    ) acquires AdminStore {
        assert_admin(admin);

        let store = borrow_global_mut<AdminStore>(@KGeN);
        let length = vector::length(&platform_address);

        for (i in 0..length) {
            let add = *vector::borrow(&platform_address, i);
            assert!(
                !vector::contains(&store.admin_web_platform, &add),
                error::already_exists(EPLATFORM_ALREADY_EXISTS)
            );
            vector::push_back(&mut store.admin_web_platform, add);
        };

        // Emit platform addition event
        event::emit(
            AdminWebPlatformAddedEvent {
                admin: signer::address_of(admin),
                platform: platform_address
            }
        );
    }

    // Revokes an admin web platform.
    // Only callable by the admin.
    public entry fun revoke_admin_web_platform(
        admin: &signer, platform_address: vector<address>
    ) acquires AdminStore {
        assert_admin(admin);

        let store = borrow_global_mut<AdminStore>(@KGeN);
        let length = vector::length(&platform_address);

        for (i in 0..length) {
            let add = *vector::borrow(&platform_address, i);
            assert!(
                vector::contains(&store.admin_web_platform, &add),
                error::already_exists(EPLATFORM_NOT_EXISTS)
            );
            vector::remove_value(&mut store.admin_web_platform, &add);
        };

        // Emit platform revocation event
        event::emit(
            AdminWebPlatformRevokedEvent {
                admin: signer::address_of(admin),
                platform: platform_address
            }
        );
    }

    // Adds an operator web platform.
    // Only callable by the admin.
    public entry fun add_operator_web_platform(
        admin: &signer, platform_address: vector<address>
    ) acquires AdminStore {
        assert_admin(admin);

        let store = borrow_global_mut<AdminStore>(@KGeN);
        let length = vector::length(&platform_address);

        for (i in 0..length) {
            let add = *vector::borrow(&platform_address, i);
            assert!(
                !vector::contains(&store.operator_web_platform, &add),
                error::already_exists(EPLATFORM_ALREADY_EXISTS)
            );
            vector::push_back(&mut store.operator_web_platform, add);
        };

        // Emit platform addition event
        event::emit(
            OperatorWebPlatformAddedEvent {
                admin: signer::address_of(admin),
                platform: platform_address
            }
        );
    }

    // Revokes an operator web platform.
    // Only callable by the admin.
    public entry fun revoke_operator_web_platform(
        admin: &signer, platform_address: vector<address>
    ) acquires AdminStore {
        assert_admin(admin);

        let store = borrow_global_mut<AdminStore>(@KGeN);
        let length = vector::length(&platform_address);

        for (i in 0..length) {
            let add = *vector::borrow(&platform_address, i);
            assert!(
                vector::contains(&store.operator_web_platform, &add),
                error::already_exists(EPLATFORM_NOT_EXISTS)
            );
            vector::remove_value(&mut store.operator_web_platform, &add);
        };

        // Emit platform revocation event
        event::emit(
            OperatorWebPlatformRevokedEvent {
                admin: signer::address_of(admin),
                platform: platform_address
            }
        );
    }

    // Adds a proxy automation platform.
    // Only callable by the admin.
    public entry fun add_proxy_automation_platform(
        admin: &signer, platform_address: vector<address>
    ) acquires AdminStore {
        assert_admin(admin);

        let store = borrow_global_mut<AdminStore>(@KGeN);
        let length = vector::length(&platform_address);

        for (i in 0..length) {
            let add = *vector::borrow(&platform_address, i);
            assert!(
                !vector::contains(&store.proxy_automation_platform, &add),
                error::already_exists(EPLATFORM_ALREADY_EXISTS)
            );
            vector::push_back(&mut store.proxy_automation_platform, add);
        };

        // Emit platform addition event
        event::emit(
            ProxyAutomationPlatformAddedEvent {
                admin: signer::address_of(admin),
                platform: platform_address
            }
        );
    }

    // Revokes a proxy automation platform.
    // Only callable by the admin.
    public entry fun revoke_proxy_automation_platform(
        admin: &signer, platform_address: vector<address>
    ) acquires AdminStore {
        assert_admin(admin);

        let store = borrow_global_mut<AdminStore>(@KGeN);
        let length = vector::length(&platform_address);

        for (i in 0..length) {
            let add = *vector::borrow(&platform_address, i);
            assert!(
                vector::contains(&store.proxy_automation_platform, &add),
                error::already_exists(EPLATFORM_NOT_EXISTS)
            );
            vector::remove_value(&mut store.proxy_automation_platform, &add);
        };

        // Emit platform revocation event
        event::emit(
            ProxyAutomationPlatformRevokedEvent {
                admin: signer::address_of(admin),
                platform: platform_address
            }
        );
    }

    // === Oracle Status and Public Key Management ===

    // Updates the activity status of an oracle node.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun manage_activity_status(
        admin: &signer,
        admin_web_platform: &signer,
        primary_wallet: address,
        status: String
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));

        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);
        assert!(
            smart_table::contains(&oracle_registry.node_registry, primary_wallet),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        let operator =
            smart_table::borrow_mut(
                &mut oracle_registry.node_registry,
                primary_wallet
            );
        assert!(operator.is_poa_minted, error::not_found(ENFT_NOT_MINTED));

        let token_name = operator.candidate_name;
        string::append(&mut token_name, string::utf8(b".kgen.io"));
        let activity_status = oracle_poa_nft::get_oracle_active_status(token_name);

        assert!(&activity_status != &status, error::aborted(EINVALID_STATUS));

        // Update activity status in PoA-NFT
        oracle_poa_nft::manage_activity_status(operator.candidate_name, status);

        if (status == string::utf8(b"Active")) {
            oracle_aggregator::add_pub_key(operator.node_public_key);
        } else {
            oracle_aggregator::remove_pub_key(operator.node_public_key);
        };

        // Emit status update event
        event::emit(
            OperatorActivityStatusUpdatedEvent { oracle_address: primary_wallet, status }
        );
    }

    // Updates the public key of an oracle node.
    // Only callable by the operator and an authorized operator web platform.
    public entry fun manage_public_key_by_operator(
        oracle_operator: &signer,
        operator_web_platform: &signer,
        new_oracle_node_pubkey: vector<u8>
    ) acquires AdminStore {
        assert_operator_web_platform(signer::address_of(operator_web_platform));
        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure the oracle node is registered
        assert!(
            smart_table::contains(
                &oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            ),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        let operator =
            smart_table::borrow_mut(
                &mut oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            );

        // Ensure PoA-NFT is minted
        assert!(operator.is_poa_minted, error::not_found(ENFT_NOT_MINTED));

        let pub_key = operator.node_public_key;
        operator.node_public_key = new_oracle_node_pubkey;

        // Update public key in aggregator and PoA-NFT
        oracle_aggregator::update_pub_key(pub_key, new_oracle_node_pubkey);
        oracle_poa_nft::manage_pub_key(operator.candidate_name, new_oracle_node_pubkey);

        // Emit public key update event
        event::emit(
            PublicKeyUpdatedByOperatorEvent {
                oracle_address: signer::address_of(oracle_operator),
                new_public_key: from_bcs::to_address(new_oracle_node_pubkey)
            }
        );
    }

    // Updates the public key on behalf of an oracle node.
    // Only callable by the assigned proxy and an authorized proxy automation platform.
    public entry fun manage_public_key_by_proxy(
        proxy: &signer,
        proxy_automation_platform: &signer,
        primary_wallet: address,
        new_oracle_node_pubkey: vector<u8>
    ) acquires AdminStore {
        assert_proxy_automation_platform(signer::address_of(proxy_automation_platform));
        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure the oracle node is registered
        assert!(
            smart_table::contains(&oracle_registry.node_registry, primary_wallet),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        let operator =
            smart_table::borrow_mut(
                &mut oracle_registry.node_registry,
                primary_wallet
            );

        // Verify the caller is the assigned proxy
        let proxy_add = *option::borrow<address>(&operator.current_proxy_add);
        assert!(
            signer::address_of(proxy) == proxy_add,
            error::unauthenticated(ESIGNER_NOT_PROXY)
        );

        // Ensure PoA-NFT is minted
        assert!(operator.is_poa_minted, error::not_found(ENFT_NOT_MINTED));

        let key = operator.node_public_key;
        operator.node_public_key = new_oracle_node_pubkey;

        // Update public key in aggregator and PoA-NFT
        oracle_aggregator::update_pub_key(key, new_oracle_node_pubkey);
        oracle_poa_nft::manage_pub_key(operator.candidate_name, new_oracle_node_pubkey);

        // Emit public key update event
        event::emit(
            PublicKeyUpdatedByProxyEvent {
                oracle_proxy: signer::address_of(proxy),
                oracle_address: primary_wallet,
                new_public_key: from_bcs::to_address(new_oracle_node_pubkey)
            }
        );
    }

    // === Wallet Nomination and Transfer ===

    // Nominates a wallet to replace the primary wallet.
    // Only callable by the operator and an authorized operator web platform.
    public entry fun nominate_primary_wallet(
        oracle_operator: &signer, operator_web_platform: &signer, nominated_wallet: address
    ) acquires AdminStore {
        assert_operator_web_platform(signer::address_of(operator_web_platform));
        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure the oracle node is registered
        assert!(
            smart_table::contains(
                &oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            ),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        // Ensure the nominated wallet isn't already registered
        assert!(
            !smart_table::contains(&oracle_registry.node_registry, nominated_wallet),
            error::already_exists(EORACLE_ALREADY_REGISTERED)
        );

        let operator =
            smart_table::borrow_mut(
                &mut oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            );

        // Ensure no wallet is already nominated
        assert!(
            option::is_none<address>(&operator.nominated_wallet),
            error::already_exists(EALREADY_NOMINATED)
        );

        operator.nominated_wallet = option::some(nominated_wallet);

        // Emit nomination event
        event::emit(
            WalletNominatedEvent {
                oracle_address: signer::address_of(oracle_operator),
                nominated_wallet
            }
        );
    }

    // Approves a wallet nomination.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun approve_nomination_by_admin(
        admin: &signer, admin_web_platform: &signer, oracle_operator: address
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));
        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure the oracle node is registered
        assert!(
            smart_table::contains(&oracle_registry.node_registry, oracle_operator),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        let operator =
            smart_table::borrow_mut(
                &mut oracle_registry.node_registry,
                oracle_operator
            );

        // Ensure a wallet is nominated
        assert!(
            option::is_some<address>(&operator.nominated_wallet),
            error::not_found(ENOT_NOMINATED)
        );

        operator.nomination_approved = true;

        // Emit approval event
        event::emit(AdminApprovesNominationEvent { oracle_address: oracle_operator });
    }

    // Transfers the primary wallet to the nominated wallet.
    // Only callable by the nominated wallet and an authorized operator web platform.
    public entry fun accept_nomination(
        nominated_wallet: &signer, operator_web_platform: &signer, primary_wallet: address
    ) acquires AdminStore {
        assert_operator_web_platform(signer::address_of(operator_web_platform));
        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure the oracle node is registered
        assert!(
            smart_table::contains(&oracle_registry.node_registry, primary_wallet),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        let operator =
            smart_table::borrow_mut(
                &mut oracle_registry.node_registry,
                primary_wallet
            );

        // Ensure a wallet is nominated
        assert!(
            option::is_some<address>(&operator.nominated_wallet),
            error::not_found(ENOT_NOMINATED)
        );

        // Verify the caller is the nominated wallet
        let nominated_address = *option::borrow<address>(&operator.nominated_wallet);
        assert!(
            signer::address_of(nominated_wallet) == nominated_address,
            error::unauthenticated(EINVALID_WALLET)
        );

        // Ensure the nomination is approved
        assert!(
            operator.nomination_approved,
            error::permission_denied(ENOT_APPROVED_BY_ADMIN)
        );

        // Transfer NFT and keys
        oracle_poa_nft::transfer_nft(
            primary_wallet,
            signer::address_of(nominated_wallet)
        );
        oracle_keys::transfer_keys(
            primary_wallet,
            signer::address_of(nominated_wallet)
        );

        oracle_reward::update_oracle_primary_wallet(
            primary_wallet,
            signer::address_of(nominated_wallet)
        );

        // Update registry with new primary wallet
        smart_table::add(
            &mut oracle_registry.node_registry,
            signer::address_of(nominated_wallet),
            OracleNodeStruct {
                is_registered: true,
                candidate_name: operator.candidate_name,
                reward_wallet: operator.reward_wallet,
                is_stablecoin_applicable: operator.is_stablecoin_applicable,
                amount_of_keys: operator.amount_of_keys,
                is_proxy_assigned: operator.is_proxy_assigned,
                current_proxy_add: operator.current_proxy_add,
                is_poa_minted: operator.is_poa_minted,
                node_public_key: operator.node_public_key,
                nominated_wallet: option::none(),
                nomination_approved: false,
                is_reward_applicable: operator.is_reward_applicable
            }
        );

        // Remove old primary wallet
        smart_table::remove(&mut oracle_registry.node_registry, primary_wallet);

        // Emit wallet update event
        event::emit(
            PrimaryWalletUpdatedEvent {
                oracle_address: primary_wallet,
                new_primary_wallet: signer::address_of(nominated_wallet)
            }
        );
    }

    // Revokes a wallet nomination.
    // Only callable by the operator and an authorized operator web platform.
    public entry fun revoke_nomination(
        oracle_operator: &signer, operator_web_platform: &signer
    ) acquires AdminStore {
        assert_operator_web_platform(signer::address_of(operator_web_platform));
        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure the oracle node is registered
        assert!(
            smart_table::contains(
                &oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            ),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        let operator =
            smart_table::borrow_mut(
                &mut oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            );

        // Ensure a wallet is nominated
        assert!(
            option::is_some<address>(&operator.nominated_wallet),
            error::not_found(ENOT_NOMINATED)
        );

        // Revoke the nomination
        operator.nominated_wallet = option::none<address>();
        operator.nomination_approved = false;

        // Emit revocation event
        event::emit(
            NominationRevokedEvent { oracle_address: signer::address_of(oracle_operator) }
        );
    }

    // Nominates and approves a wallet for an oracle node.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun nominat_wallet_by_admin(
        admin: &signer,
        admin_web_platform: &signer,
        primary_wallet: address,
        nominated_wallet: address
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));
        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure the oracle node is registered
        assert!(
            smart_table::contains(&oracle_registry.node_registry, primary_wallet),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        let operator =
            smart_table::borrow_mut(
                &mut oracle_registry.node_registry,
                primary_wallet
            );

        // Set and approve the nominated wallet
        operator.nominated_wallet = option::some(nominated_wallet);
        operator.nomination_approved = true;

        // Emit nomination event
        event::emit(
            WalletNominatedByAdminEvent { oracle_address: primary_wallet, nominated_wallet }
        );
    }

    // Updates the KGeN public key.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun manage_kgen_public_key(
        admin: &signer, admin_web_platform: &signer, public_key: String
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));

        let admin_resource = borrow_global_mut<AdminStore>(@KGeN);
        admin_resource.kgen_pub_key = public_key;
    }

    // === Admin Config Management ===

    // Manages the batch size for the oracle aggregator.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun manage_batch_size(
        admin: &signer, admin_web_platform: &signer, batch_size: u64
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));

        assert!(
            batch_size != oracle_aggregator::get_batch_size(),
            error::already_exists(EVALUE_ALREADY_PRESENT)
        );

        oracle_aggregator::manage_batch_size(batch_size);

        event::emit(
            BatchSizeUpdatedEvent { batch_size, admin: signer::address_of(admin) }
        );
    }

    // Manages the round interval for the oracle aggregator.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun manage_round_interval(
        admin: &signer, admin_web_platform: &signer, round_interval: u64
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));

        assert!(
            round_interval != oracle_aggregator::get_round_interval(),
            error::already_exists(EVALUE_ALREADY_PRESENT)
        );

        oracle_aggregator::manage_round_interval(round_interval);

        event::emit(
            RoundIntervalUpdatedEvent { round_interval, admin: signer::address_of(admin) }
        );
    }

    // Manages the page size for the oracle aggregator.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun manage_page_size(
        admin: &signer, admin_web_platform: &signer, page_size: u64
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));

        assert!(
            page_size != oracle_aggregator::get_page_size(),
            error::already_exists(EVALUE_ALREADY_PRESENT)
        );

        oracle_aggregator::manage_page_size(page_size);

        event::emit(PageSizeUpdatedEvent { page_size, admin: signer::address_of(admin) });
    }

    // public entry fun manage_num_offchain_round(
    //     admin: &signer, admin_web_platform: &signer, round_count: u64
    // ) acquires AdminStore {
    //     assert_admin(admin);
    //     assert_admin_web_platform(signer::address_of(admin_web_platform));

    //     oracle_aggregator::manage_num_offchain_round(round_count);

    //     event::emit(
    //         NumOffChainRoundCountUpdated { round_count, admin: signer::address_of(admin) }
    //     );
    // }

    // === Node Deregistration ===

    // Deregisters an oracle node.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun deregister_oracle_node(
        admin: &signer, admin_web_platform: &signer, primary_wallet: address
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));

        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure the primary wallet is registered
        assert!(
            smart_table::contains(&oracle_registry.node_registry, primary_wallet),
            error::already_exists(EORACLE_NOT_REGISTERED)
        );

        let operator =
            smart_table::borrow_mut(
                &mut oracle_registry.node_registry,
                primary_wallet
            );

        if (operator.is_poa_minted) {
            // Burn the PoA-NFT
            oracle_poa_nft::burn(operator.candidate_name, primary_wallet);

            // Remove the primary wallet to public key mapping in aggregator
            oracle_aggregator::remove_pub_key(operator.node_public_key);

            // Remove entry from the node registry
            oracle_reward::remove_primary_wallet(primary_wallet);
            // Burn the PoA Keys
            oracle_keys::burn(primary_wallet, operator.amount_of_keys);

        };
        smart_table::remove(&mut oracle_registry.node_registry, primary_wallet);
    }

    public entry fun deregister_node(primary_wallet: address) {}

    // === Reward Contract Methods ===

    // Adds a new tier for rewards.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun add_new_tier(
        admin: &signer,
        admin_web_platform: &signer,
        min_keys: vector<u64>,
        max_keys: vector<u64>,
        stablecoin_yield: vector<u64>,
        bonus_rKGeN_yield: vector<u64>,
        rKGeN_per_key: vector<u64>
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));

        oracle_reward::add_new_tier(
            min_keys,
            max_keys,
            stablecoin_yield,
            bonus_rKGeN_yield,
            rKGeN_per_key
        );

        event::emit(
            NewTierAddedEvent {
                admin: signer::address_of(admin),
                min_keys,
                max_keys,
                stablecoin_yield,
                bonus_rKGeN_yield,
                rKGeN_per_key
            }
        );
    }

    // Manages the key price for rewards.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun manage_key_price(
        admin: &signer, admin_web_platform: &signer, key_price: u64
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));
        oracle_reward::manage_key_price(key_price);
        event::emit(KeyPriceUpdatedEvent { admin: signer::address_of(admin), key_price });
    }

    // Manages the days for upfront rewards.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun manage_days_for_upfront(
        admin: &signer, admin_web_platform: &signer, days_for_upfront: u64
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));
        oracle_reward::manage_days_for_upfront(days_for_upfront);

        event::emit(
            DaysUpfrontUpdatedEvent { admin: signer::address_of(admin), days_for_upfront }
        );
    }

    // Manages the stablecoin metadata for rewards.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun manage_stablecoin_metadata(
        admin: &signer, admin_web_platform: &signer, stablecoin_metadata: address
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));
        oracle_reward::manage_stablecoin_metadata(stablecoin_metadata);

        event::emit(
            StablecoinMetadataUpdatedEvent {
                admin: signer::address_of(admin),
                stablecoin_metadata
            }
        );
    }

    // Manages the rKGeN metadata for rewards.
    // Only callable by the admin and an authorized admin web platform.
    public entry fun manage_rKGeN_metadata(
        admin: &signer, admin_web_platform: &signer, rKGeN_metadata: address
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(admin_web_platform));
        oracle_reward::manage_rKGeN_metadata(rKGeN_metadata);

        event::emit(
            RKGeNMetadataUpdatedEvent { admin: signer::address_of(admin), rKGeN_metadata }
        );
    }

    // Updates the reward wallet for an oracle node.
    // Only callable by the operator and an authorized operator web platform.
    public entry fun update_reward_wallet(
        oracle_operator: &signer, operator_web_platform: &signer, reward_wallet: address
    ) acquires AdminStore {
        assert_operator_web_platform(signer::address_of(operator_web_platform));
        let oracle_registry = borrow_global_mut<AdminStore>(@KGeN);

        // Ensure the oracle node is registered
        assert!(
            smart_table::contains(
                &oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            ),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        let operator =
            smart_table::borrow_mut(
                &mut oracle_registry.node_registry,
                signer::address_of(oracle_operator)
            );

        operator.reward_wallet = reward_wallet;

        oracle_reward::update_reward_wallet(
            signer::address_of(oracle_operator),
            reward_wallet
        );

        event::emit(
            RewardWalletUpdatedByOperatorEvent {
                operator: signer::address_of(oracle_operator),
                reward_wallet
            }
        );
    }

    // Transfers upfront rKGeN to the operator.
    // Only callable by the operator and an authorized operator web platform.
    public entry fun transfer_upfront_rKGeN(
        operator: &signer, operator_web_platform: &signer
    ) acquires AdminStore {
        assert_operator_web_platform(signer::address_of(operator_web_platform));

        let oracle_registry = borrow_global<AdminStore>(@KGeN);

        // Ensure the oracle node is registered
        assert!(
            smart_table::contains(
                &oracle_registry.node_registry,
                signer::address_of(operator)
            ),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        oracle_reward::transfer_upfront_rKGeN(operator);

        event::emit(
            UpfrontTransferredByOperatorEvent { operator: signer::address_of(operator) }
        );
    }

    // Claims the reward for the operator.
    // Only callable by the operator and an authorized operator web platform.
    public entry fun claim_reward(
        operator: &signer, operator_web_platform: &signer
    ) acquires AdminStore {
        assert_operator_web_platform(signer::address_of(operator_web_platform));
        let oracle_registry = borrow_global<AdminStore>(@KGeN);

        // Ensure the oracle node is registered
        assert!(
            smart_table::contains(
                &oracle_registry.node_registry,
                signer::address_of(operator)
            ),
            error::not_found(EORACLE_NOT_REGISTERED)
        );

        oracle_reward::claim_oracle_reward(operator);

        event::emit(
            RewardClaimedByOperatorEvent { operator: signer::address_of(operator) }
        );
    }

    public entry fun transfer_rewards_from_resource(
        admin: &signer,
        web_platform: &signer,
        receiver: address,
        token_address: address,
        amount: u64
    ) acquires AdminStore {
        assert_admin(admin);
        assert_admin_web_platform(signer::address_of(web_platform));
        oracle_reward::transfer_rewards_from_resource(receiver, token_address, amount)
    }

    // === Helper Functions ===

    // Asserts that the signer is the admin.
    // Aborts with ENOT_ADMIN if the signer is not the admin.
    fun assert_admin(admin: &signer) acquires AdminStore {
        let admin_address = get_admin_address();
        assert!(
            signer::address_of(admin) == admin_address,
            error::unauthenticated(ENOT_ADMIN)
        );
    }

    // Validates that the address is a node monitor.
    // Aborts with EINVALID_NODE_MONITOR if the address is not a node monitor.
    fun assert_node_monitors(monitor: address) acquires AdminStore {
        let platform_list = &borrow_global<AdminStore>(@KGeN).node_monitors;
        assert!(
            vector::contains<address>(platform_list, &monitor),
            error::unauthenticated(EINVALID_NODE_MONITOR)
        );
    }

    // Validates that the address is an authorized admin web platform.
    // Aborts with EINVALID_ADMIN_PLATFORM if the address is not authorized.
    fun assert_admin_web_platform(platform: address) acquires AdminStore {
        let platform_list = &borrow_global<AdminStore>(@KGeN).admin_web_platform;
        assert!(
            vector::contains<address>(platform_list, &platform),
            error::unauthenticated(EINVALID_ADMIN_PLATFORM)
        );
    }

    // Validates that the address is an authorized operator web platform.
    // Aborts with EINVALID_OPERATOR_PLATFORM if the address is not authorized.
    fun assert_operator_web_platform(platform: address) acquires AdminStore {
        let platform_list = &borrow_global<AdminStore>(@KGeN).operator_web_platform;
        assert!(
            vector::contains<address>(platform_list, &platform),
            error::unauthenticated(EINVALID_OPERATOR_PLATFORM)
        );
    }

    // Validates that the address is an authorized proxy automation platform.
    // Aborts with EINVALID_PROXY_PLATFROM if the address is not authorized.
    fun assert_proxy_automation_platform(platform: address) acquires AdminStore {
        let platform_list = &borrow_global<AdminStore>(@KGeN).proxy_automation_platform;
        assert!(
            vector::contains<address>(platform_list, &platform),
            error::unauthenticated(EINVALID_PROXY_PLATFROM)
        );
    }
}
