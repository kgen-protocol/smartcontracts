module KGeN::kgen_oracle_storage {
    use std::signer;
    use std::string::{String};
    use std::vector;
    use std::error;
    use aptos_std::smart_table;
    use aptos_std::simple_map;

    // Caller of the function is not Admin.
    const ENOT_ADMIN: u64 = 1;
    const EINVALID_ARGUMENTS_LENGTH: u64 = 2;
    const EPLAYER_NOT_EXIST: u64 = 3;

    // Storage references/state for managing player props.
    struct PlayersRecords has key {
        players: smart_table::SmartTable<address, simple_map::SimpleMap<String, vector<u8>>>
    }

    // Admin: stores the module admin address.
    struct Admin has key {
        // Stores the address of the module admin
        admin_vec: vector<address>
    }

    fun init_module(admin: &signer) {
        /* Stores the global storage for the addresses of admin */
        let a_vec = vector::empty<address>();
        vector::push_back<address>(&mut a_vec, signer::address_of(admin));
        move_to(admin, Admin{admin_vec: a_vec});

        let records = smart_table::new<address, simple_map::SimpleMap<String, vector<u8>>>();

        move_to(admin, PlayersRecords{ players: records});
    }

    // Add records for the user
    public entry fun set_player_props(admin: &signer, player: address, keys: vector<String>, values: vector<vector<u8>>)
     acquires PlayersRecords, Admin {
       assert!(verify_admin(&signer::address_of(admin)), error::invalid_argument(ENOT_ADMIN));

       // Add keys, values into the simple map
       let s = simple_map::new<String, vector<u8>>();
       simple_map::add_all<String, vector<u8>>(&mut s, keys, values);

       let records = borrow_global_mut<PlayersRecords>(@KGeN);
       smart_table::add(&mut records.players, player, s);
    }

    // Add records for the user
    public entry fun set_player_props_by_aggregator(players: vector<address>,
        keys_vec: vector<vector<String>>,
        values_vec: vector<vector<vector<u8>>>)
     acquires PlayersRecords {

        let len = vector::length(&players);
        for (i in 0..len){
            // Add keys, values into the simple map
            let s = simple_map::new<String, vector<u8>>();
            simple_map::add_all<String, vector<u8>>(&mut s, *vector::borrow(&keys_vec, i), *vector::borrow(&values_vec, i));

            let records = borrow_global_mut<PlayersRecords>(@KGeN);
            smart_table::add(&mut records.players, *vector::borrow(&players, i), s);
        }

    }

    #[view]
    public fun get_player_props(player: address): (vector<String>, vector<vector<u8>>) acquires PlayersRecords{
        let records = borrow_global_mut<PlayersRecords>(@KGeN);
        assert!(smart_table::contains(&mut records.players, player), error::invalid_argument(EPLAYER_NOT_EXIST));

        let player_props = smart_table::borrow<address, simple_map::SimpleMap<String, vector<u8>>>(&records.players, player);

        (simple_map::keys(player_props), 
        simple_map::values(player_props))
    }

    /* Verifies that admin is eligible or not*/
    inline fun verify_admin(addr: &address): bool acquires Admin{
        let a_vec = borrow_global<Admin>(@KGeN).admin_vec;
        assert!(!vector::is_empty(&a_vec), error::invalid_argument(EINVALID_ARGUMENTS_LENGTH));
        vector::contains(&a_vec, addr)
    }

    #[test(admin = @KGeN, acc1 = @0x1)]
    public fun t2(admin: &signer, acc1: &signer) acquires PlayersRecords, Admin{
        init_module(admin);
        let key = vector::empty<String>(); 
        vector::push_back<String>(&mut key, string::utf8(b"KGen Community Badge"));
        let f = vector::empty<u8>();
        vector::push_back<u8>(&mut f, 1);
        let val = vector::empty<vector<u8>>();
        vector::push_back<vector<u8>>(&mut val, f);

        add_player_props(admin, signer::address_of(acc1), key, val );

        let (a, b, c) = get_player_props(signer::address_of(acc1));

        std::debug::print(&string::utf8(b"A: "));
        std::debug::print(&a);
        std::debug::print(&string::utf8(b"B: "));
        std::debug::print(&b);
        std::debug::print(&string::utf8(b"C: "));
        std::debug::print(&c);
    }
}
