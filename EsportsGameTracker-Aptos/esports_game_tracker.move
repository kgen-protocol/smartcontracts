
//     ______                      __          ______                        ______                __            
//    / ____/________  ____  _____/ /______   / ____/___ _____ ___  ___     /_  __/________ ______/ /_____  _____
//   / __/ / ___/ __ \/ __ \/ ___/ __/ ___/  / / __/ __ `/ __ `__ \/ _ \     / / / ___/ __ `/ ___/ //_/ _ \/ ___/
//  / /___(__  ) /_/ / /_/ / /  / /_(__  )  / /_/ / /_/ / / / / / /  __/    / / / /  / /_/ / /__/ ,< /  __/ /    
// /_____/____/ .___/\____/_/   \__/____/   \____/\__,_/_/ /_/ /_/\___/    /_/ /_/   \__,_/\___/_/|_|\___/_/     
//           /_/                                                                                                 


module EsportsGameTracker::esports_game_tracker {
    use std::signer;
    use std::error;
    use std::vector;
    use std::string::String;
    use aptos_framework::event;
    use KCashAdmin::kcash;

  
    // Error code when module is not initialized
    const ENOT_INITIALIZED: u64 = 1;
    // Error code when argument lengths do not match expected values
    const EINVALID_ARGUMENTS_LENGTH: u64 = 2;
    // Error code when game is not in whitelist
    const ENOT_WHITELISTED: u64 = 3;
    // Error code when caller is not the owner
    const ENOT_OWNER: u64 = 4;

    // Stores the list of whitelisted games that are allowed to use the reward system
    // The games vector contains String identifiers for each approved game
    struct WhitelistedGames has key {
        games: vector<String>
    }

    // Event emitted when a game-related transaction occurs
    // Contains details about the game, sender, receiver and amount transferred
    #[event]
    struct GameTransactionEvent has drop, store {
        // Identifier of the game where the transaction occurred
        game_id: String,
        // Address of the account receiving the transfer
        receiver: address,
        // Address of the account sending the transfer
        sender: address,
        // Amount of tokens/rewards transferred
        transfer_amount: u64,
    }

    // Checks if the provided signer account is the owner of this module
    // @param account - The signer account to check ownership for
    // @return bool - Returns true if the signer's address matches the module's address
    public fun is_owner(account: &signer): bool {
        signer::address_of(account) == @EsportsGameTracker
    }

   
    // Initializes the module by creating and storing the WhitelistedGames resource
    // This can only be called by the module owner during module deployment
    // @param admin - The signer account that must be the module owner
    fun init_module(admin: &signer) {
        // Verify the caller is the module owner
        assert!(is_owner(admin), error::permission_denied(ENOT_INITIALIZED));
        
        // Create new WhitelistedGames resource with empty games vector
        let whitelisted_games = WhitelistedGames {
            games: vector[]
        };
        
        // Store the WhitelistedGames resource in the admin's account
        move_to(admin, whitelisted_games);
    }

    // Adds a new game to the whitelist of approved games
    // @param admin - The signer account that must be the module owner
    // @param game_id - String identifier for the game to be whitelisted
    public entry fun add_whitelisted_game(admin: &signer, game_id: String) acquires WhitelistedGames {
        // Verify the caller is the module owner
        assert!(is_owner(admin), error::permission_denied(ENOT_OWNER));
        // Verify the WhitelistedGames resource exists
        assert!(exists<WhitelistedGames>(@EsportsGameTracker), error::not_found(ENOT_INITIALIZED));
        // Get mutable reference to WhitelistedGames resource
        let whitelisted_games = borrow_global_mut<WhitelistedGames>(@EsportsGameTracker);
        // Add the new game_id to the list of whitelisted games
        vector::push_back(&mut whitelisted_games.games, game_id);
    }

    // Removes a game from the whitelist of approved games
    // @param admin - The signer account that must be the module owner
    // @param game_id - String identifier for the game to be removed from whitelist
    public entry fun remove_whitelisted_game(admin: &signer, game_id: String) acquires WhitelistedGames {
        // Verify the caller is the module owner
        assert!(is_owner(admin), error::permission_denied(ENOT_OWNER));
        // Get mutable reference to WhitelistedGames resource
        let whitelisted_games = borrow_global_mut<WhitelistedGames>(@EsportsGameTracker);
        // Check if game exists in whitelist and get its index
        let (found, index) = vector::index_of(&whitelisted_games.games, &game_id);
        // If game is found, remove it from the whitelist
        if (found) {
            vector::swap_remove(&mut whitelisted_games.games, index);
        }
    }

    // Returns the vector of all whitelisted game IDs
    // This is a view function that can be called without modifying state
    // @return vector<String> - Vector containing all whitelisted game IDs
    #[view]
    public fun get_whitelisted_games(): vector<String> acquires WhitelistedGames {
        borrow_global<WhitelistedGames>(@EsportsGameTracker).games
    }

    // Checks if a given game ID is in the whitelist of approved games
    // @param game_id - String identifier of the game to check
    // @return bool - True if the game is whitelisted, false otherwise
    #[view]
    public fun is_whitelisted(game_id: String): bool acquires WhitelistedGames {
        vector::contains(&borrow_global<WhitelistedGames>(@EsportsGameTracker).games, &game_id)
    }

    // Transfers reward3 tokens from one account to another, with optional game tracking
    // @param from - The signer account sending the tokens
    // @param to - The recipient address 
    // @param amount - The amount of reward3 tokens to transfer
    // @param game_id - Optional game identifier for tracking. If empty string, no game tracking occurs
    public entry fun transfer_reward3_to_reward3_game_tracker(from: &signer, to: address, amount: u64, game_id: String) acquires WhitelistedGames {
       // If game_id is empty, just do a regular transfer without game tracking
       if (game_id == std::string::utf8(b"")) {
        kcash::transfer_reward3_to_reward3(from, to, amount);
       } 
       // If game is whitelisted, do transfer and emit game tracking event
       else if (is_whitelisted(game_id)) {
        kcash::transfer_reward3_to_reward3(from, to, amount);
        // Emit event to track the game-related transfer
        event::emit(
            GameTransactionEvent {
                game_id,
                receiver: to,
                sender: signer::address_of(from),
                transfer_amount: amount
            }
        )
       }
       // If game is not whitelisted, throw error
       else {
        error::invalid_argument(ENOT_WHITELISTED);
       }
    }


    // Performs bulk transfers of reward3 tokens with game tracking
    // @param from - The signer account sending the tokens
    // @param to_vec - Vector of recipient addresses
    // @param amount_vec - Vector of amounts to transfer to each recipient
    // @param game_id_vec - Vector of game IDs for tracking each transfer
    // All input vectors must be the same length
    public entry fun transfer_reward3_to_reward3_game_tracker_bulk(
        from: &signer,
        to_vec: vector<address>,
        amount_vec: vector<u64>, 
        game_id_vec: vector<String>
    ) acquires WhitelistedGames {
        // Get length of first vector and verify all vectors are same length
        let len = vector::length(&to_vec);
        assert!(len == vector::length(&amount_vec) && len == vector::length(&game_id_vec), 
            error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));

        // Iterate through vectors and process each transfer
        let i = 0;
        while (i < len) {
            let to = vector::borrow(&to_vec, i);
            let amount = vector::borrow(&amount_vec, i);
            let game_id = vector::borrow(&game_id_vec, i);
            transfer_reward3_to_reward3_game_tracker(from, *to, *amount, *game_id);
            i = i + 1;
        }
    }

}