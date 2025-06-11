module KGeN::oracle_aggregator {
    // === Dependencies ===
    use std::signer;
    use std::vector;
    use std::ed25519;
    use std::bcs;
    use std::error;
    use std::string::{Self, String};
    use aptos_std::hash;
    use aptos_std::smart_table;
    use aptos_std::simple_map;
    use aptos_std::from_bcs;
    use aptos_framework::timestamp;
    use aptos_framework::event;

    use KGeN::oracle_storage;

    // === Constants ===

    /// Caller is not Module Admin.
    const ENOT_ADMIN: u64 = 1; // Error code: Caller lacks admin privileges
    /// Signature threshold not met.
    const ETHRESHOLD_NOT_MET: u64 = 2; // Error code: Insufficient valid signatures for consensus
    /// Invalid length of vector arguments.
    const EINVALID_VECTOR_LENGTH: u64 = 3; // Error code: Vector arguments have incorrect lengths
    /// Primary Leader is not active and no Secondary Leader is active.
    const ENO_SECONDARY_LEADER_ACTIVE: u64 = 4; // Error code: No active leader available
    /// Invoker is not the active Leader Node (corrected comment from original).
    const ENOT_ACTIVE_LEADER: u64 = 5; // Error code: Caller is not the active leader node
    /// Round is already in progress (corrected typo from 'progess').
    const EROUND_ALREADY_IN_PROGRESS: u64 = 6; // Error code: A round is currently active
    /// Given Leader Node Address is already chosen (corrected typo from 'choosen').
    const EALREADY_LEADER: u64 = 7; // Error code: Leader node address is already set
    /// Address trying to add already exists.
    const EALREADY_EXISTS: u64 = 8; // Error code: Address already exists in the registry
    /// Address trying to remove does not exist (corrected typo from 'exists').
    const ENOT_EXISTS: u64 = 9; // Error code: Address not found in the registry
    /// Invalid Status for Secondary Leader.
    const EINVALID_STATUS: u64 = 10; // Error code: Invalid status change requested
    /// Round is already in progress, cannot start another (corrected typo from 'inprogess').
    const EROUND_ALREADY_INPROGRESS: u64 = 11; // Error code: Cannot start a new round while one is active
    /// Round trying to mark complete is already completed.
    const EROUND_ALREADY_COMPLETED: u64 = 12; // Error code: Round is already marked as completed
    /// Public Key not found.
    const EKEY_NOT_FOUND: u64 = 13; // Error code: Public key not found in registry
    /// Status is already applied for the Oracle Node.
    const ESTATUS_ALREADY_APPLIED: u64 = 14; // Error code: Requested status is already set
    /// Public Key trying to add as Secondary Lead is Leader Node.
    const EIS_LEADER: u64 = 15;
    /// On Chain Batch Submission and Consensus is not Applicable for current round.
    const EBATCH_SUBMISSION_IS_NOT_APPLICABLE: u64 = 16;
    /// Denotes the consensus required for score submission.
    const CONSENSUS_PERCENTAGE: u64 = 67; // Consensus threshold: 67% of oracles must agree
    /// Chain ID for Aptos Mainnet (corrected typo from 'CHAIN_ID').
    /// For Testnet Node ID is set to 2.
    const TESTNET_CHAIN_ID: u64 = 2; // Chain identifier for Aptos Testnet to prevent replays
    const MAINNET_CHAIN_ID: u64 = 1; // Chain identifier for Aptos Mainnet to prevent replays

    // === Structs ===

    // Represents a single round's data.
    struct RoundInfo has store, drop, copy {
        round_id: u64, // Unique identifier for the round
        is_onchain_consensus_applicable: bool, // Tells whether consensus will happen onchain or offchain
        start_time: u64, // Timestamp when the round began
        round_initiated_at: u64, // Timestamp when the round was initiated
        round_end_time: u64, // Timestamp when the round ended
        round_interval: u64, // Duration of the round in seconds
        batch_size: u64, // Number of entries per batch
        page_size: u64, // Number of items per page in a batch
        total_batch_submitted: u64, // Total batches submitted in the round
        successful_batch: u64, // Number of successfully processed batches
        total_processed_records: u64, // Number of successfully processed batches
        is_all_records_processed: bool, // Number of successfully processed batches
        is_force_round_stop: bool, // Tells whether Admin has stopped current round execution forcefully.
        is_force_round_start: bool, // Tells whether leader should Start next forcefully round or not.
        is_successful: bool, // Indicates if the round completed successfully
        leader_node: address // Address of the leader node managing the round
    }

    // Stores all round records in a table.
    struct RoundTable has key {
        last_round_id: u64,
        round_table: smart_table::SmartTable<u64, RoundInfo> // Maps round IDs to their records
    }

    struct LeadNode has store, drop, copy {
        public_key: vector<u8>,
        is_online: bool,
        is_active_lead: bool
    }

    // Stores aggregator configuration and state.
    struct AggregatorStore has key {
        deployed_at: u64, // Timestamp at which the contract was deployed
        last_round_start_time: u64, // Timestamp of the last successful round
        batch_size: u64, // Default batch size for submissions
        round_interval: u64, // Default interval between rounds
        page_size: u64, // Default page size for batches
        num_offchain_round: u64, // Number of offchain round after which onchain consensus will happen.
        offchain_round_counter: u64, // Stores the value for offchain consensus
        leader_node: LeadNode, // Primary leader node and its active status
        secondary_leaders: vector<LeadNode>, // Secondary leaders and their active statuses
        registry: smart_table::SmartTable<vector<u8>, bool> // Oracle addresses mapped to their public keys
    }

    // Message format for oracle-signed score submissions.
    struct SignedMessage has store, drop {
        players: vector<address>, // List of player addresses
        keys_vec: vector<vector<String>>, // Keys associated with scores
        values_vec: vector<vector<vector<u8>>>, // Score values
        chain_id: u64 // Chain ID to ensure message uniqueness
    }

    // === Events ===

    // Event emitted when a new round starts.
    #[event]
    struct RoundInitiatedEvent has drop, store, copy {
        round_id: u64, // Unique identifier of the round
        start_time: u64, // Round start timestamp
        round_initiated_at: u64, // Timestamp when the round was initiated
        round_end_time: u64,
        round_interval: u64, // Duration of the round
        batch_size: u64, // Batch size for the round
        page_size: u64, // Page size for batches
        total_processed_records: u64,
        is_all_records_processed: bool,
        is_onchain_consensus_applicable: bool, // Tells whether consensus will happen onchain or offchain
        is_force_round_stop: bool, // Tells whether Admin has stopped current round execution forcefully.
        is_force_round_start: bool, // Tells whether leader should Start next forcefully round or not.
        is_leader_online: bool,
        leader_node: address // Address of the leader initiating the round
    }

    // Event emitted when invalid public keys are detected.
    #[event]
    struct ScoreSubmission has store, drop {
        round_id: u64,
        batch_id: u64,
        batch_number: u64,
        leader: address,
        invalid_public_keys: vector<vector<u8>>,
        invalid_signature_pub_key: vector<vector<u8>>,
        valid_signature_pub_key: vector<vector<u8>>,
        submited_to_storage: bool
    }

    // Event emitted when a round completes successfully.
    #[event]
    struct RoundCompletedEvent has drop, store, copy {
        round_id: u64, // Unique identifier of the completed round
        start_time: u64, // Round start timestamp
        round_initiated_at: u64, // Timestamp when the round was initiated
        round_end_time: u64,
        round_interval: u64, // Duration of the round
        batch_size: u64, // Batch size used
        page_size: u64, // Page size used
        total_batch_submitted: u64, // Total batches submitted
        successful_batch: u64, // Number of successful batches
        total_processed_records: u64,
        is_all_records_processed: bool,
        is_onchain_consensus_applicable: bool, // Tells whether consensus will happen onchain or offchain
        is_force_round_stop: bool, // Tells whether Admin has stopped current round execution forcefully.
        is_force_round_start: bool, // Tells whether leader should Start next forcefully round or not.
        is_leader_online: bool,
        leader_node: address // Leader node completing the round
    }

    #[event]
    struct LeaderNodeUpdatedEvent has drop, store, copy {
        leader_node: vector<u8> // Leader node
    }

    #[event]
    struct LeaderNodeMarkedOnlineEvent has drop, store, copy {
        public_key: vector<u8>
    }

    #[event]
    struct LeaderNodeMarkedOfflineEvent has drop, store, copy {
        public_key: vector<u8>
    }

    #[event]
    struct SecondaryLeadBecameLeaderNodeEvent has drop, store, copy {
        public_key: vector<u8>
    }

    #[event]
    struct PrimaryLeadBecameLeaderNodeEvent has drop, store, copy {
        public_key: vector<u8>
    }

    #[event]
    struct GeneralNodeMarkedOnlineEvent has drop, store, copy {
        public_key: vector<u8>
    }

    #[event]
    struct GeneralNodeMarkedOfflineEvent has drop, store, copy {
        public_key: vector<u8>
    }

    #[event]
    struct SecondaryNodeMarkedOnlineEvent has drop, store, copy {
        public_key: vector<u8>
    }

    #[event]
    struct SecondaryNodeMarkedOfflineEvent has drop, store, copy {
        public_key: vector<u8>
    }

    #[event]
    struct SecondaryLeaderSwitchedEvent has drop, store, copy {
        previous_leader_public_key: vector<u8>,
        new_leader_public_key: vector<u8>
    }

    #[event]
    struct InsufficientSecondaryLeaderEvent has drop, store, copy {
        msg: String
    }

    // === View Functions ===

    // Returns the default round interval.
    #[view]
    public fun get_round_interval(): u64 acquires AggregatorStore {
        let store = borrow_global<AggregatorStore>(@KGeN); // Fetch aggregator state
        store.round_interval // Return the round interval
    }

    // Returns the default batch size.
    #[view]
    public fun get_batch_size(): u64 acquires AggregatorStore {
        let store = borrow_global<AggregatorStore>(@KGeN); // Fetch aggregator state
        store.batch_size // Return the batch size
    }

    #[view]
    public fun get_contract_deployed_time(): u64 acquires AggregatorStore {
        let store = borrow_global<AggregatorStore>(@KGeN); // Fetch aggregator state
        store.deployed_at // Return the batch size
    }

    #[view]
    public fun get_page_size(): u64 acquires AggregatorStore {
        let store = borrow_global<AggregatorStore>(@KGeN); // Fetch aggregator state
        store.page_size // Return the page size
    }

    #[view]
    public fun get_num_offchain_round_value(): u64 acquires AggregatorStore {
        let store = borrow_global<AggregatorStore>(@KGeN); // Fetch aggregator state
        store.num_offchain_round // Return the page size
    }

    #[view]
    public fun get_offchain_round_counter(): u64 acquires AggregatorStore {
        let store = borrow_global<AggregatorStore>(@KGeN); // Fetch aggregator state
        store.offchain_round_counter // Return the page size
    }

    #[view]
    public fun get_total_oracle_count(): u64 acquires AggregatorStore {
        let store = borrow_global<AggregatorStore>(@KGeN); // Fetch aggregator state
        let count = 0;

        if (!vector::is_empty(&store.leader_node.public_key)) {
            count = count + 1;
        };

        let secondary_leaders = vector::length(&store.secondary_leaders);
        let general_nodes = smart_table::length(&store.registry);

        count = count + secondary_leaders + general_nodes;
        return count
    }

    #[view]
    public fun get_registered_public_keys(): vector<vector<u8>> acquires AggregatorStore {
        let store = borrow_global<AggregatorStore>(@KGeN); // Fetch aggregator state
        let result = vector::empty<vector<u8>>();

        if (!vector::is_empty(&store.leader_node.public_key)) {
            vector::push_back(&mut result, store.leader_node.public_key);
        };

        if (!vector::is_empty(&store.secondary_leaders)) {
            vector::for_each(
                store.secondary_leaders,
                |ele| vector::push_back(&mut result, ele.public_key)
            )
        };
        let i = 0;
        let general_nodes = smart_table::keys(&store.registry);
        while (i < vector::length(&general_nodes)) {
            vector::push_back(&mut result, *vector::borrow(&general_nodes, i));
            i = i + 1;
        };

        return result
    }

    // Returns the current round end time.
    #[view]
    public fun get_last_round_info(): RoundInfo acquires RoundTable {
        let store = borrow_global<RoundTable>(@KGeN);
        let last_round_id = store.last_round_id;
        if (last_round_id == 0) {
            return RoundInfo {
                round_id: 0, // Unique identifier for the round
                start_time: 0, // Timestamp when the round began
                round_initiated_at: 0, // Timestamp when the round was initiated
                round_end_time: 0, // Timestamp when the round ended
                round_interval: 0, // Duration of the round in seconds
                batch_size: 0, // Number of entries per batch
                page_size: 0, // Number of items per page in a batch
                total_batch_submitted: 0, // Total batches submitted in the round
                successful_batch: 0, // Number of successfully processed batches
                is_successful: false, // Indicates if the round completed successfully
                total_processed_records: 0,
                is_onchain_consensus_applicable: false, // Tells whether consensus will happen onchain or offchain
                is_all_records_processed: false, // Indicates if the round completed successfully
                is_force_round_stop: false,
                is_force_round_start: false,
                leader_node: @0x0 // Address of the leader node managing the round
            }
        };

        *smart_table::borrow(&store.round_table, last_round_id)
    }

    #[view]
    public fun get_round_by_round_id(round_id: u64): RoundInfo acquires RoundTable {
        let store = borrow_global<RoundTable>(@KGeN);
        if (!smart_table::contains(&store.round_table, round_id)) {
            return RoundInfo {
                round_id: 0, // Unique identifier for the round
                start_time: 0, // Timestamp when the round began
                round_initiated_at: 0, // Timestamp when the round was initiated
                round_end_time: 0, // Timestamp when the round ended
                round_interval: 0, // Duration of the round in seconds
                batch_size: 0, // Number of entries per batch
                page_size: 0, // Number of items per page in a batch
                total_batch_submitted: 0, // Total batches submitted in the round
                successful_batch: 0, // Number of successfully processed batches
                is_successful: false, // Indicates if the round completed successfully
                total_processed_records: 0,
                is_onchain_consensus_applicable: false, // Tells whether consensus will happen onchain or offchain
                is_all_records_processed: false, // Indicates if the round completed successfully
                is_force_round_stop: false,
                is_force_round_start: false,
                leader_node: @0x0 // Address of the leader node managing the round
            }
        };

        *smart_table::borrow(&store.round_table, round_id)
    }

    // Checks if a public key is registered and its online status.
    #[view]
    public fun has_public_key(pub_key: vector<u8>): (bool, bool) acquires AggregatorStore {
        let store = borrow_global<AggregatorStore>(@KGeN); // Fetch oracle registry

        let lead = store.leader_node;

        if (&lead.public_key == &pub_key) {
            return (true, lead.is_online)
        };

        if (smart_table::contains(&store.registry, pub_key)) {
            let general = *smart_table::borrow(&store.registry, pub_key);
            return (true, general)
        };

        let (found, index) = vector::find(
            &store.secondary_leaders, |node| { &node.public_key == &pub_key }
        );

        if (!found) {
            return (false, false)
        };

        let second_lead = vector::borrow(&store.secondary_leaders, index);
        (found, second_lead.is_online) // Return existence and status
    }

    // Converts a public key to its corresponding address.
    #[view]
    public fun public_key_to_address(public_key: vector<u8>): address {
        let unvalidated_key = ed25519::new_unvalidated_public_key_from_bytes(public_key); // Create unvalidated key
        let auth_key =
            ed25519::unvalidated_public_key_to_authentication_key(&unvalidated_key); // Derive auth key
        from_bcs::to_address(auth_key) // Convert to address
    }

    // Determines the role of a public key (Leader, Secondary Leader, or General Oracle).
    #[view]
    public fun get_public_key_role(pub_key: vector<u8>): (String, bool, bool) acquires AggregatorStore {

        let store = borrow_global<AggregatorStore>(@KGeN); // Fetch oracle registry

        let lead = store.leader_node;

        if (&lead.public_key == &pub_key) {
            return (string::utf8(b"Leader Node"), lead.is_online, lead.is_active_lead)
        };

        if (smart_table::contains(&store.registry, pub_key)) {
            let is_online = *smart_table::borrow(&store.registry, pub_key);
            return (string::utf8(b"General Node"), is_online, false)
        };

        let (found, index) = vector::find(
            &store.secondary_leaders, |node| { &node.public_key == &pub_key }
        );

        let second_lead = *vector::borrow(&store.secondary_leaders, index);

        if (found) {
            return (
                string::utf8(b"Secondary Lead"),
                second_lead.is_online,
                second_lead.is_active_lead
            )
        };

        (string::utf8(b"Invalid Public Key"), false, false)
    }

    // Returns the address of the primary leader node.
    #[view]
    public fun get_leader_node(): LeadNode acquires AggregatorStore {
        borrow_global<AggregatorStore>(@KGeN).leader_node // Fetch leader map
    }

    #[view]
    public fun get_active_leader(): vector<u8> acquires AggregatorStore {
        let store = borrow_global<AggregatorStore>(@KGeN);

        if (store.leader_node.is_active_lead) {
            return store.leader_node.public_key
        };

        if (vector::length(&store.secondary_leaders) > 0) {
            let (found, index) = vector::find(
                &store.secondary_leaders, |node| { &node.is_active_lead == &true }
            );
            if (found) {
                let key = *vector::borrow(&store.secondary_leaders, index);
                return key.public_key
            };
        };

        return vector::empty<u8>()
    }

    #[view]
    public fun get_secondary_leaders(): vector<LeadNode> acquires AggregatorStore {
        borrow_global<AggregatorStore>(@KGeN).secondary_leaders
    }

    // Retrieves the list of oracle addresses and their public keys.
    #[view]
    public fun get_oracle_registry(): simple_map::SimpleMap<vector<u8>, bool> acquires AggregatorStore {
        let pub_key_map = borrow_global<AggregatorStore>(@KGeN); // Access aggregator state
        smart_table::to_simple_map(&pub_key_map.registry) // Convert registry to SimpleMap
    }

    // === Initialization ===

    // Initializes the module with default aggregator and round table state.
    fun init_module(admin: &signer) {

        let lead = LeadNode {
            public_key: vector::empty<u8>(),
            is_online: false,
            is_active_lead: false
        };

        let store = AggregatorStore {
            leader_node: lead, // Initialize empty leader map
            secondary_leaders: vector::empty<LeadNode>(), // Initialize empty secondary leaders map
            registry: smart_table::new<vector<u8>, bool>(), // Initialize empty oracle registry
            deployed_at: timestamp::now_seconds(), // Set deployment timestamp
            last_round_start_time: 0, // Set initial round start time to 0
            offchain_round_counter: 0,
            num_offchain_round: 0,
            round_interval: 25200, // Default: 2 hours
            batch_size: 50, // Default batch size
            page_size: 2000 // Default page size
        };
        move_to(admin, store); // Store aggregator state under admin's address

        move_to(
            admin,
            RoundTable {
                last_round_id: 0,
                round_table: smart_table::new<u64, RoundInfo>() // Initialize empty round table
            }
        );
    }

    // === Round Management ===

    // Initiates a new round, ensuring no overlap with previous rounds and filling gaps if necessary.
    public entry fun initiate_round(leader: &signer) acquires AggregatorStore, RoundTable {
        assert!(verify_leader_node(signer::address_of(leader)), ENOT_ACTIVE_LEADER); // Verify caller is active leader

        let is_onchain_consensus_applicable = false;
        let now = timestamp::now_seconds();

        let round_table = borrow_global_mut<RoundTable>(@KGeN); // Access round table

        let round_id = get_round_id(); // Calculate current round ID
        let store = borrow_global_mut<AggregatorStore>(@KGeN); // Access aggregator state

        let round_end_time = store.deployed_at + (round_id * store.round_interval); // Calculate end time
        let last_round_id = round_table.last_round_id; // Get the last completed round ID

        if (last_round_id != 0) { // If not the first round
            let round_info =
                smart_table::borrow_mut(
                    &mut round_table.round_table,
                    last_round_id // Fetch last round info
                );

            if (now > round_info.round_end_time || round_info.is_force_round_start) {
                round_info.is_successful = true;
            } else {
                assert!(false, error::already_exists(EROUND_ALREADY_INPROGRESS));
            }
        };

        if (last_round_id >= round_id) {
            round_id = last_round_id + 1;
        };

        if (store.offchain_round_counter >= store.num_offchain_round) {
            is_onchain_consensus_applicable = true;
            store.offchain_round_counter = 0;
        } else {
            store.offchain_round_counter = store.offchain_round_counter + 1;
        };

        if ((round_id - last_round_id) > 1) { // Check for missed rounds

            if (last_round_id != 0) {

                let l = smart_table::borrow(&round_table.round_table, last_round_id);

                let round_info = RoundInfo {
                    round_id: last_round_id + 1, // Placeholder for skipped rounds
                    start_time: l.round_end_time, // Use last round start time
                    round_initiated_at: now,
                    round_end_time: now,
                    round_interval: store.round_interval,
                    batch_size: store.batch_size,
                    page_size: store.page_size,
                    total_batch_submitted: 0,
                    successful_batch: 0,
                    is_successful: false, // Mark as incomplete
                    total_processed_records: 0,
                    is_onchain_consensus_applicable: false,
                    is_all_records_processed: false, // Mark as incomplete
                    is_force_round_stop: false,
                    is_force_round_start: false,
                    leader_node: signer::address_of(leader) // Set leader address
                };

                // let table = borrow_global_mut<RoundTable>(@KGeN); // Access mutable round table
                smart_table::add(
                    &mut round_table.round_table, last_round_id + 1, round_info
                ); // Add new roundleader

            };
        };

        let round_info = RoundInfo {
            round_id: round_id,
            start_time: store.last_round_start_time, // Use last round start time
            round_initiated_at: now, //timestamp::now_seconds(), // Set initiation time
            round_end_time: round_end_time,
            round_interval: store.round_interval,
            batch_size: store.batch_size,
            page_size: store.page_size,
            total_batch_submitted: 0, // Initialize batch count
            successful_batch: 0, // Initialize successful batch count
            is_successful: false, // Mark as incomplete
            total_processed_records: 0,
            is_onchain_consensus_applicable,
            is_all_records_processed: false, // Mark as incomplete
            is_force_round_stop: false,
            is_force_round_start: false,
            leader_node: signer::address_of(leader) // Set leader address
        };

        // let table = borrow_global_mut<RoundTable>(@KGeN); // Access mutable round table
        smart_table::add(&mut round_table.round_table, round_id, round_info); // Add new roundleader

        let lead = store.leader_node;
        let is_leader_online = lead.is_active_lead;
        if (!lead.is_active_lead && lead.is_online) {
            let leader = LeadNode {
                is_online: true,
                is_active_lead: true,
                public_key: lead.public_key
            };
            store.leader_node = leader;
            set_secondary_false(&mut store.secondary_leaders); // Set all secondary leaders to inactive

            event::emit(PrimaryLeadBecameLeaderNodeEvent { public_key: lead.public_key });
            is_leader_online = true;
        };

        event::emit(
            RoundInitiatedEvent {
                round_id,
                is_leader_online,
                start_time: store.last_round_start_time,
                round_initiated_at: now, //timestamp::now_seconds(),
                round_end_time,
                round_interval: store.round_interval,
                batch_size: store.batch_size,
                page_size: store.page_size,
                total_processed_records: 0,
                is_onchain_consensus_applicable: is_onchain_consensus_applicable,
                is_all_records_processed: false,
                is_force_round_stop: false,
                is_force_round_start: false,
                leader_node: signer::address_of(leader)
            }
        ); // Emit round start event
        round_table.last_round_id = round_id;

    }

    // Submits a batch of scores with oracle signatures for verification.
    public entry fun submit_scores_in_batch(
        leader: &signer,
        batch_id: u64,
        batch_number: u64,
        oracle_pubkeys: vector<vector<u8>>, // Public keys of signing oracles
        signatures: vector<vector<u8>>, // Signatures from oracles
        players: vector<address>, // Player addresses
        keys_vec: vector<vector<String>>, // Score keys
        values_vec: vector<vector<vector<u8>>> // Score values
    ) acquires AggregatorStore, RoundTable {
        assert!(verify_leader_node(signer::address_of(leader)), ENOT_ACTIVE_LEADER); // Verify caller is active leader

        assert!(
            vector::length(&oracle_pubkeys) == vector::length(&signatures),
            error::invalid_argument(EINVALID_VECTOR_LENGTH)
        );
        let playersInBatch = vector::length(&players);
        assert!(
            playersInBatch == vector::length(&keys_vec)
                && playersInBatch == vector::length(&values_vec),
            error::invalid_argument(EINVALID_VECTOR_LENGTH)
        );

        let round_table = borrow_global_mut<RoundTable>(@KGeN); // Access mutable round table
        let round_id = round_table.last_round_id; // Get current round ID
        let round_record = smart_table::borrow_mut(
            &mut round_table.round_table, round_id
        ); // Get round record

        assert!(
            round_record.is_onchain_consensus_applicable,
            error::permission_denied(EBATCH_SUBMISSION_IS_NOT_APPLICABLE)
        );

        round_record.total_batch_submitted = round_record.total_batch_submitted + 1; // Increment batch count

        let msg = SignedMessage {
            players,
            keys_vec,
            values_vec,
            chain_id: MAINNET_CHAIN_ID
        }; // Create signed message
        let message_bytes = bcs::to_bytes<SignedMessage>(&msg); // Serialize message (typo 'messag_bytes' preserved)
        let message_hash = hash::sha2_256(message_bytes); // Hash message for signing

        let invalid_signature = vector::empty<vector<u8>>(); // Track invalid signatures
        let invalid_pub_key = vector::empty<vector<u8>>(); // Track invalid public keys
        let valid_signature = vector::empty<vector<u8>>(); //
        let submited_to_storage = false;

        let len = vector::length(&oracle_pubkeys); // Number of signatures to check
        let verified_sign = 0; // Count of valid signatures
        for (i in 0..len) {
            let signature = *vector::borrow(&signatures, i); // Get signature
            let pub_key = *vector::borrow(&oracle_pubkeys, i); // Get public key
            let (contains_key, is_online) = has_public_key(pub_key); // Check key status
            if (contains_key && is_online) { // If key is valid and online
                if (verify_signature(message_hash, signature, pub_key)) { // Verify signature (typo preserved)
                    verified_sign = verified_sign + 1; // Increment valid signature count
                    vector::push_back(&mut valid_signature, pub_key); // Record invalid signature
                } else {
                    vector::push_back(&mut invalid_signature, pub_key); // Record invalid signature
                }
            } else {
                vector::push_back(&mut invalid_pub_key, pub_key); // Record invalid key
            }
        };

        if (check_threshold(verified_sign)) { // Check if consensus threshold is met
            oracle_storage::update_scores(round_id, players, keys_vec, values_vec); // Update scores
            round_record.successful_batch = round_record.successful_batch + 1; // Increment successful batches
            round_record.total_processed_records =
                round_record.total_processed_records + playersInBatch;
            submited_to_storage = true;
        };

        event::emit(
            ScoreSubmission {
                round_id,
                batch_id,
                batch_number,
                leader: signer::address_of(leader),
                invalid_public_keys: invalid_pub_key,
                invalid_signature_pub_key: invalid_signature,
                valid_signature_pub_key: valid_signature,
                submited_to_storage
            }
        );
    }

    // Completes the current round and updates the aggregator state.
    public entry fun complete_round(
        leader: &signer, totalRecords: u64
    ) acquires AggregatorStore, RoundTable {
        assert!(verify_leader_node(signer::address_of(leader)), ENOT_ACTIVE_LEADER); // Verify caller is active leader
        let store = borrow_global_mut<AggregatorStore>(@KGeN);
        let lead = store.leader_node;

        let is_leader_online = lead.is_active_lead;

        if (!lead.is_active_lead && lead.is_online) {
            let leader = LeadNode {
                is_online: true,
                is_active_lead: true,
                public_key: lead.public_key
            };
            store.leader_node = leader;
            set_secondary_false(&mut store.secondary_leaders); // Set all secondary leaders to inactive

            event::emit(PrimaryLeadBecameLeaderNodeEvent { public_key: lead.public_key });
            is_leader_online = true;
        };

        let table = borrow_global_mut<RoundTable>(@KGeN); // Access mutable round table
        let round_id = table.last_round_id; // Get the last round ID
        let round_info = smart_table::borrow_mut(&mut table.round_table, round_id); // Get round record
        assert!(!round_info.is_successful, EROUND_ALREADY_COMPLETED); // Ensure round isn't already completed
        if (round_info.total_processed_records >= totalRecords && totalRecords > 0) {
            store.last_round_start_time = round_info.round_initiated_at; // Update last round start time
            round_info.is_all_records_processed = true;
        };
        round_info.is_successful = true; // Mark round as successful
        event::emit(
            RoundCompletedEvent {
                round_id,
                start_time: round_info.start_time,
                round_initiated_at: round_info.round_initiated_at,
                round_end_time: round_info.round_end_time,
                round_interval: store.round_interval,
                batch_size: store.batch_size,
                page_size: store.page_size,
                total_batch_submitted: round_info.total_batch_submitted,
                successful_batch: round_info.successful_batch,
                total_processed_records: round_info.total_processed_records,
                is_all_records_processed: round_info.is_all_records_processed,
                is_leader_online,
                is_onchain_consensus_applicable: round_info.is_onchain_consensus_applicable,
                is_force_round_stop: round_info.is_force_round_stop,
                is_force_round_start: round_info.is_force_round_start,
                leader_node: round_info.leader_node
            }
        ); // Emit round completion event
    }

    // === Admin Functions ===

    // Sets the default batch size for rounds.
    package fun manage_batch_size(batch_size: u64) acquires AggregatorStore {
        let store = borrow_global_mut<AggregatorStore>(@KGeN); // Access mutable aggregator state
        store.batch_size = batch_size; // Update batch size
    }

    // Sets the default round interval.
    package fun manage_round_interval(round_interval: u64) acquires AggregatorStore {
        let store = borrow_global_mut<AggregatorStore>(@KGeN); // Access mutable aggregator state
        store.round_interval = round_interval; // Update round interval
    }

    // Sets the default page size for batches.
    package fun manage_page_size(page_size: u64) acquires AggregatorStore {
        let store = borrow_global_mut<AggregatorStore>(@KGeN); // Access mutable aggregator state
        store.page_size = page_size; // Update page size
    }

    // Sets the default page size for batches.
    package fun manage_num_offchain_round(round_count: u64) acquires AggregatorStore {
        let store = borrow_global_mut<AggregatorStore>(@KGeN); // Access mutable aggregator state
        store.num_offchain_round = round_count; // Update page size
    }

    // Updates or adds an oracle's public key in the registry.
    package fun update_pub_key(old_key: vector<u8>, new_key: vector<u8>) acquires AggregatorStore {
        let store = borrow_global_mut<AggregatorStore>(@KGeN); // Access mutable aggregator state

        if (&store.leader_node.public_key == &old_key) {
            let lead =
                LeadNode {
                    is_online: store.leader_node.is_online,
                    is_active_lead: store.leader_node.is_active_lead,
                    public_key: new_key
                };

            store.leader_node = lead;

            return
        };

        let (found, index) = vector::find(
            &store.secondary_leaders, |node| { &node.public_key == &old_key }
        );

        if (found) {
            let second_lead = vector::borrow_mut(&mut store.secondary_leaders, index);
            second_lead.public_key = new_key;
        } else {
            let x = smart_table::remove(&mut store.registry, old_key);
            smart_table::add(&mut store.registry, new_key, x);
        }
    }

    // Manages the online status of an oracle's public key.
    package fun manage_online_status(
        pub_key: vector<u8>, status: bool
    ) acquires AggregatorStore, RoundTable {
        if (status) {
            set_true(pub_key);
            return;
        };

        let store = borrow_global_mut<AggregatorStore>(@KGeN);

        if (smart_table::contains(&store.registry, pub_key)) {
            smart_table::upsert(&mut store.registry, pub_key, false);

            event::emit(GeneralNodeMarkedOfflineEvent { public_key: pub_key });
            return;
        };

        let lead = store.leader_node;
        if (&lead.public_key == &pub_key) {
            let leader = LeadNode {
                is_online: false,
                is_active_lead: false,
                public_key: lead.public_key
            };

            store.leader_node = leader;

            event::emit(LeaderNodeMarkedOfflineEvent { public_key: leader.public_key });

            let (found, index) = vector::find(
                &store.secondary_leaders, |node| { &node.is_online == &true }
            );

            if (!found) {

                let leader = LeadNode {
                    is_online: false,
                    is_active_lead: true,
                    public_key: lead.public_key
                };
                store.leader_node = leader;

                event::emit(
                    InsufficientSecondaryLeaderEvent {
                        msg: string::utf8(
                            b"No More Active Secondary Leader Available, Please Add More in the List"
                        )
                    }
                );
                return
            };

            let second_lead = vector::borrow_mut(&mut store.secondary_leaders, index);
            second_lead.is_active_lead = true;

            event::emit(
                SecondaryLeadBecameLeaderNodeEvent { public_key: second_lead.public_key }
            );
            return
        };

        let (found, index) = vector::find(
            &store.secondary_leaders, |node| { &node.public_key == &pub_key }
        );

        assert!(found, error::not_found(EKEY_NOT_FOUND));

        let length = vector::length(&store.secondary_leaders);
        let second_lead = vector::borrow_mut(&mut store.secondary_leaders, index);
        second_lead.is_online = false;

        event::emit(
            SecondaryNodeMarkedOfflineEvent { public_key: second_lead.public_key }
        );
        if (!second_lead.is_active_lead) { return };

        let prev_second_lead = second_lead.public_key;
        second_lead.is_active_lead = false;
        if (length > 1) {

            let (found, new_index) = vector::find(
                &store.secondary_leaders, |node| { &node.is_online == &true }
            );

            if (!found) {
                let prev = vector::borrow_mut(&mut store.secondary_leaders, index);
                prev.is_active_lead = true;

                event::emit(
                    SecondaryLeadBecameLeaderNodeEvent { public_key: prev.public_key }
                );
                event::emit(
                    InsufficientSecondaryLeaderEvent {
                        msg: string::utf8(
                            b"No More Active Secondary Leader Available, Please Add More in the List"
                        )
                    }
                );
                return
            };
            let new = vector::borrow_mut(&mut store.secondary_leaders, new_index);
            new.is_active_lead = true;
            event::emit(
                SecondaryLeaderSwitchedEvent {
                    previous_leader_public_key: prev_second_lead,
                    new_leader_public_key: new.public_key
                }
            );
        } else {
            // second_lead.is_active_lead = true;
            event::emit(
                InsufficientSecondaryLeaderEvent {
                    msg: string::utf8(
                        b"No More Secondary Leader Available, Please Add More in the List"
                    )
                }
            );
        };
    }

    // Sets the primary leader node.
    package fun manage_leader(leader_node: vector<u8>) acquires AggregatorStore {
        let store = borrow_global_mut<AggregatorStore>(@KGeN); // Access mutable aggregator state
        let lead_struct = store.leader_node;

        if (smart_table::contains(&store.registry, leader_node)) {
            let is_online = smart_table::remove(&mut store.registry, leader_node);

            let lead = LeadNode { public_key: leader_node, is_online, is_active_lead: true };

            store.leader_node = lead;
        } else {
            let (_, index) = vector::find(
                &store.secondary_leaders, |node| { &node.public_key == &leader_node }
            );

            let second_lead = vector::remove<LeadNode>(
                &mut store.secondary_leaders, index
            );

            let lead = LeadNode {
                public_key: second_lead.public_key,
                is_online: second_lead.is_online,
                is_active_lead: second_lead.is_online
            };
            store.leader_node = lead;

        };

        if (!vector::is_empty(&lead_struct.public_key)) {
            smart_table::add(
                &mut store.registry, lead_struct.public_key, lead_struct.is_online
            );
        };

        event::emit(LeaderNodeUpdatedEvent { leader_node })
    }

    // Adds secondary leader nodes with inactive status.
    package fun add_secondary_leader(node_pub_keys: vector<vector<u8>>) acquires AggregatorStore {
        let store = borrow_global_mut<AggregatorStore>(@KGeN); // Access mutable aggregator state
        let length = vector::length(&node_pub_keys); // Get number of nodes to add
        for (i in 0..length) {

            let lead = store.leader_node.public_key;
            let key = *vector::borrow(&node_pub_keys, i); // Get node address
            assert!(
                &lead != &key,
                error::invalid_argument(EIS_LEADER)
            );

            let general = smart_table::remove(&mut store.registry, key); // Check for duplicates
            let second_lead = LeadNode {
                public_key: key,
                is_online: general,
                is_active_lead: false
            };
            vector::push_back(&mut store.secondary_leaders, second_lead); // Add as inactive
        }
    }

    // Removes secondary leader nodes.
    package fun revoke_secondary_leader(
        node_pub_keys: vector<vector<u8>>
    ) acquires AggregatorStore {
        let store = borrow_global_mut<AggregatorStore>(@KGeN); // Access mutable aggregator state
        let length = vector::length(&node_pub_keys); // Get number of nodes to remove
        for (i in 0..length) {

            let key = *vector::borrow(&node_pub_keys, i);

            let (found, index) = vector::find(
                &store.secondary_leaders, |node| { &node.public_key == &key }
            );

            assert!(found, error::not_found(EKEY_NOT_FOUND));

            let second_lead = vector::remove(&mut store.secondary_leaders, index);
            smart_table::add(
                &mut store.registry, second_lead.public_key, second_lead.is_online
            );

        }
    }

    // Removes a public key from the registry.
    package fun remove_pub_key(pub_key: vector<u8>) acquires AggregatorStore {
        let store = borrow_global_mut<AggregatorStore>(@KGeN); // Access mutable aggregator state

        if (&store.leader_node.public_key == &pub_key) {
            let lead = LeadNode {
                is_online: false,
                is_active_lead: false,
                public_key: vector::empty<u8>()
            };

            store.leader_node = lead;
            return
        };

        let (found, index) = vector::find(
            &store.secondary_leaders, |node| { &node.public_key == &pub_key }
        );

        if (found) {
            vector::remove(&mut store.secondary_leaders, index);
        } else {
            smart_table::remove(&mut store.registry, pub_key); // Remove public key
        }
    }

    package fun add_pub_key(pub_key: vector<u8>) acquires AggregatorStore {
        let store = borrow_global_mut<AggregatorStore>(@KGeN); // Access mutable aggregator state
        smart_table::add(&mut store.registry, pub_key, true); // Remove public key
    }

    package fun admin_force_round_stop() acquires RoundTable {
        let round_table = borrow_global_mut<RoundTable>(@KGeN);
        let round_id = round_table.last_round_id;
        let round_info = smart_table::borrow_mut(&mut round_table.round_table, round_id);
        round_info.is_force_round_stop = true;
    }

    package fun admin_force_round_start() acquires RoundTable {
        let round_table = borrow_global_mut<RoundTable>(@KGeN);
        let round_id = round_table.last_round_id;
        let round_info = smart_table::borrow_mut(&mut round_table.round_table, round_id);
        round_info.is_force_round_start = true;
    }

    package fun admin_force_round_stop_and_start() acquires RoundTable {
        let round_table = borrow_global_mut<RoundTable>(@KGeN);
        let round_id = round_table.last_round_id;
        let round_info = smart_table::borrow_mut(&mut round_table.round_table, round_id);
        round_info.is_force_round_start = true;
        round_info.is_force_round_stop = true;
    }

    // === Helper Functions ===

    // Verifies if the caller is the active leader (primary or secondary).
    fun verify_leader_node(leader_node: address): bool acquires AggregatorStore {
        if (vector::is_empty(&get_active_leader())) {
            return false
        };

        (public_key_to_address(get_active_leader()) == leader_node)
    }

    // Checks if the number of valid signatures meets the consensus threshold.
    fun check_threshold(count: u64): bool acquires AggregatorStore {
        let pub_key_map = borrow_global<AggregatorStore>(@KGeN); // Access aggregator state
        let pub_key_length = smart_table::length(&pub_key_map.registry); // Get oracle count
        pub_key_length = pub_key_length
            + vector::length(&pub_key_map.secondary_leaders) + 1;
        (count * 100) / pub_key_length >= CONSENSUS_PERCENTAGE // Return true if threshold met
    }

    // Verifies an Ed25519 signature against a message hash (typo 'signatute' preserved).
    fun verify_signature(
        message_hash: vector<u8>, signature: vector<u8>, pub_key: vector<u8>
    ): bool {
        let signature_ed = ed25519::new_signature_from_bytes(signature); // Create signature object
        let public_key_ed = ed25519::new_unvalidated_public_key_from_bytes(pub_key); // Create public key object
        let is_valid =
            ed25519::signature_verify_strict(&signature_ed, &public_key_ed, message_hash); // Verify
        return is_valid // Return verification result
    }

    // Sets all secondary leaders to inactive (unused in contract).
    fun set_secondary_false(leads: &mut vector<LeadNode>) {
        vector::for_each_mut(
            leads,
            |val| { // Set all to false
                val.is_active_lead = false;
            }
        );
    }

    // Calculates the current round ID based on elapsed time.
    fun get_round_id(): u64 acquires AggregatorStore {
        let current_time = timestamp::now_seconds(); // Get current timestamp
        let store = borrow_global<AggregatorStore>(@KGeN); // Access aggregator state
        let deployed_time = store.deployed_at; // Get deployment time
        let interval = store.round_interval; // Get round interval
        let round_id = (current_time - deployed_time) / interval; // Calculate round ID
        (round_id + 1) // Return next round ID
    }

    fun set_true(key: vector<u8>) acquires AggregatorStore, RoundTable {
        let store = borrow_global_mut<AggregatorStore>(@KGeN);

        let lead = store.leader_node;
        if (&lead.public_key == &key) {

            let leader = LeadNode {
                is_online: true,
                is_active_lead: lead.is_active_lead,
                public_key: lead.public_key
            };

            let round_store = borrow_global<RoundTable>(@KGeN);

            if (smart_table::length(&round_store.round_table) > 0) {

                let round_info =
                    *smart_table::borrow(
                        &round_store.round_table, round_store.last_round_id
                    );

                if (round_info.is_successful
                    || timestamp::now_seconds() > round_info.round_end_time
                    || lead.is_active_lead) {
                    leader.is_active_lead = true;
                    set_secondary_false(&mut store.secondary_leaders); // Set all secondary leaders to inactive

                    event::emit(
                        PrimaryLeadBecameLeaderNodeEvent { public_key: leader.public_key }
                    );
                }
            } else {
                leader.is_active_lead = true;
                set_secondary_false(&mut store.secondary_leaders); // Set all secondary leaders to inactive

                event::emit(
                    PrimaryLeadBecameLeaderNodeEvent { public_key: leader.public_key }
                );
            };

            store.leader_node = leader;

            event::emit(LeaderNodeMarkedOnlineEvent { public_key: key });
            return
        };

        if (smart_table::contains(&store.registry, key)) {
            smart_table::upsert(&mut store.registry, key, true);

            event::emit(GeneralNodeMarkedOnlineEvent { public_key: key });

            return;
        };

        let (found, index) = vector::find(
            &store.secondary_leaders, |node| { &node.public_key == &key }
        );

        assert!(found, error::not_found(EKEY_NOT_FOUND));
        let second_lead = vector::borrow_mut(&mut store.secondary_leaders, index);
        second_lead.is_online = true;

        event::emit(SecondaryNodeMarkedOnlineEvent { public_key: key });
    }
}
