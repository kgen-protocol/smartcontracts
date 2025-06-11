module KGeN::oracle_storage {
    use std::string::{String};
    use std::vector;
    use std::error;
    use std::event;
    use std::option::{Option};
    use aptos_std::smart_table;
    use aptos_std::simple_map;
    use aptos_framework::timestamp;

    // === Constants ===

    // Error codes for common failure conditions
    // Indicates arguments provided have invalid lengths
    const EINVALID_ARGUMENTS_LENGTH: u64 = 1;

    // === Structs ===

    // Represents a player's data with round ID, scores, and timestamps
    struct Player has store, drop, copy {
        round_id: u64, // The round ID associated with the player
        scores: simple_map::SimpleMap<String, vector<u8>>, // Key-value pairs of scores
        created_at: u64, // Timestamp when the record was created
        updated_at: u64 // Timestamp when the record was last updated
    }

    // Stores player properties in a smart table
    struct PlayersRecords has key {
        // A smart table mapping player addresses to their properties (key-value pairs)
        players: smart_table::SmartTable<address, Player>
    }

    #[event]
    struct ScoreSubmittedSuccessEvent has store, drop, copy {
        round_id: u64
    }

    // === View Functions ===

    // Retrieves a player's properties (keys and values)
    #[view]
    public fun get_player_data(
        player: address // Address of the player to query
    ): Player acquires PlayersRecords {
        // Access the global PlayersRecords resource
        let records = borrow_global<PlayersRecords>(@KGeN);

        if (smart_table::contains(&records.players, player)) {
            return *smart_table::borrow<address, Player>(&records.players, player) // Return existing player data
        };

        // Return a default empty player if not found (note: this is unreachable due to missing return)
        Player {
            round_id: 0,
            scores: simple_map::new<String, vector<u8>>(),
            created_at: 0,
            updated_at: 0
        }
    }

    #[view]
    public fun get_total_player_count(): u64 acquires PlayersRecords {
        // Access the global PlayersRecords resource
        let records = borrow_global<PlayersRecords>(@KGeN);
        smart_table::length(&records.players)
    }

    // Retrieves paginated player addresses (note: typo in 'kes' instead of 'keys')
    #[view]
    public fun get_paginated_keys(
        num_keys: u64, starting_bucket_index: u64, starting_vector_index: u64
    ): (vector<address>, Option<u64>, Option<u64>) acquires PlayersRecords {
        let store = borrow_global<PlayersRecords>(@KGeN);
        smart_table::keys_paginated(
            &store.players,
            starting_bucket_index,
            starting_vector_index,
            num_keys
        )
        // Return paginated list of player addresses
    }

    // Retrieves scores for a list of player addresses
    #[view]
    public fun get_scores_by_address(
        players: vector<address>
    ): simple_map::SimpleMap<address, Player> acquires PlayersRecords {
        let result = simple_map::new<address, Player>(); // Initialize result map
        let store = borrow_global<PlayersRecords>(@KGeN); // Access global storage

        let length = vector::length(&players); // Number of players to process

        for (i in 0..length) {
            let addr = *vector::borrow(&players, i); // Get player address
            let map = *smart_table::borrow(&store.players, addr); // Get player data
            simple_map::add(&mut result, addr, map); // Add to result map
        };

        result // Return map of player addresses to their data
    }

    // Retrieves a player's scores as separate vectors of keys and values
    public fun get_player_scores(
        player: address
    ): (vector<String>, vector<vector<u8>>) acquires PlayersRecords {
        let records = borrow_global<PlayersRecords>(@KGeN); // Access global storage

        if (smart_table::contains(&records.players, player)) {
            let player_data =
                smart_table::borrow<address, Player>(&records.players, player); // Get player data
            let keys = simple_map::keys(&player_data.scores); // Extract score keys
            let values = simple_map::values(&player_data.scores); // Extract score values
            return (keys, values) // Return keys and values
        };

        // Return empty vectors if player not found
        (vector::empty<String>(), vector::empty<vector<u8>>())
    }

    // === Initialization ===

    // Initializes the module by setting up admin and player records
    fun init_module(admin: &signer) {
        // Create a new smart table to store player properties
        let records = smart_table::new<address, Player>();
        // Store the PlayersRecords struct under the admin's address
        move_to(admin, PlayersRecords { players: records });
    }

    // === Score Management ===

    // Updates player scores/properties in bulk
    package fun update_scores(
        round_id: u64,
        players: vector<address>, // List of player addresses to update
        keys: vector<vector<String>>, // Keys for each player's properties
        values: vector<vector<vector<u8>>> // Values corresponding to each player's keys
    ) acquires PlayersRecords {
        // Access the global mutable PlayersRecords resource
        let records = borrow_global_mut<PlayersRecords>(@KGeN);

        // Ensure input vectors have matching lengths
        assert!(
            vector::length(&players) == vector::length(&keys)
                && vector::length(&keys) == vector::length(&values),
            error::invalid_argument(EINVALID_ARGUMENTS_LENGTH)
        );

        let i = 0;
        // Iterate over all players in the input vector
        while (i < vector::length(&players)) {
            // Extract the current player's address, keys, and values
            let player = *vector::borrow(&players, i);
            let key = *vector::borrow(&keys, i);
            let value = *vector::borrow(&values, i);

            if (!smart_table::contains(&records.players, player)) {
                // Create a new SimpleMap with the new properties
                let s = simple_map::new<String, vector<u8>>();
                simple_map::add_all<String, vector<u8>>(&mut s, key, value);

                let strct = Player {
                    round_id,
                    scores: s,
                    created_at: timestamp::now_seconds(), // Preserve original creation time
                    updated_at: timestamp::now_seconds() // Update timestamp
                };

                // Update existing player data
                smart_table::add(&mut records.players, player, strct);
            } else {

                let player_props =
                    smart_table::borrow<address, Player>(&records.players, player);

                // Get the current keys and values for this player
                let stored_keys = simple_map::keys(&player_props.scores);
                let stored_values = simple_map::values(&player_props.scores);

                // Merge new properties with existing ones
                let (o_keys, o_values) =
                    merge_player_props(key, value, stored_keys, stored_values);

                // Create a new SimpleMap with the merged properties
                let s = simple_map::new<String, vector<u8>>();
                simple_map::add_all<String, vector<u8>>(&mut s, o_keys, o_values);
                let strct = Player {
                    round_id,
                    scores: s,
                    created_at: timestamp::now_seconds(), // Set creation time
                    updated_at: timestamp::now_seconds() // Set update time
                };

                // Insert new player data
                smart_table::upsert(&mut records.players, player, strct);
            };
            i = i + 1; // Move to the next player
        };

        event::emit(ScoreSubmittedSuccessEvent { round_id });
    }

    // === Helper Functions ===

    // Merges new player properties with existing ones, avoiding duplicates
    fun merge_player_props(
        o_keys: vector<String>, // New keys to merge
        o_values: vector<vector<u8>>, // New values to merge
        i_keys: vector<String>, // Existing keys
        i_values: vector<vector<u8>> // Existing values
    ): (vector<String>, vector<vector<u8>>) {
        // Initialize empty vectors for the merged results
        let result_keys = vector::empty<String>();
        let result_values = vector::empty<vector<u8>>();

        // Add all new keys to the result
        vector::for_each(
            o_keys,
            |k| {
                vector::push_back(&mut result_keys, k);
            }
        );
        // Add all new values to the result
        vector::for_each(
            o_values,
            |v| {
                vector::push_back(&mut result_values, v);
            }
        );

        // Add existing keys and values only if they aren't already present
        vector::for_each(
            i_keys,
            |k| {
                if (!vector::contains(&result_keys, &k)) {
                    vector::push_back(&mut result_keys, k);
                    // Find the index of the key in i_keys to get the corresponding value
                    let (_bo, i) = vector::index_of(&i_keys, &k);
                    vector::push_back(&mut result_values, *vector::borrow(&i_values, i));
                }
            }
        );
        // Return the merged keys and values
        (result_keys, result_values)
    }
}
