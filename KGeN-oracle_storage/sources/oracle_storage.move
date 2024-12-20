module Admin::kgen_oracle_storage {
    use std::signer;
    use std::string::{Self, String, utf8};
    use std::option;
    use std::vector;
    use std::bcs;
    use aptos_std::from_bcs;


    // To get player info, like scores and badges
    #[view]
    public fun get_player_scores(player: address): (vector<String>, vector<vector<u8>>) {
        let key = vector::empty<String>(); // vector of string
        let f = vector::empty<u8>(); // vector of u8
        vector::push_back<u8>(&mut f, 1);
        let s = bcs::to_bytes(&string::utf8(b"jasdbfj")); // vector of u8
        let val = vector::empty<vector<u8>>();


        vector::push_back<String>(&mut key, string::utf8(b"KGen Community Badge"));
        vector::push_back<vector<u8>>(&mut val, s);

        vector::push_back<String>(&mut key, string::utf8(b"Proof of Human Badge"));
        vector::push_back<vector<u8>>(&mut val, f);

        vector::push_back<String>(&mut key, string::utf8(b"Proof of Play Badge"));
        vector::push_back<vector<u8>>(&mut val, f);

        vector::push_back<String>(&mut key, string::utf8(b"Proof of Skill Badge"));
        vector::push_back<vector<u8>>(&mut val, f);

        vector::push_back<String>(&mut key, string::utf8(b"Proof of Commerce Badge"));
        vector::push_back<vector<u8>>(&mut val, f);

        vector::push_back<String>(&mut key, string::utf8(b"Proof of Social Badge"));
        vector::push_back<vector<u8>>(&mut val, f);

        vector::push_back<String>(&mut key, string::utf8(b"Proof of Human Score Data (Encrypted)"));
        vector::push_back<vector<u8>>(&mut val, s);
        
        vector::push_back<String>(&mut key, string::utf8(b"Proof of Play Score Data (Encrypted)"));
        vector::push_back<vector<u8>>(&mut val, s);
        
        vector::push_back<String>(&mut key, string::utf8(b"Proof of Skill Score Data (Encrypted)"));
        vector::push_back<vector<u8>>(&mut val, s);
        
        vector::push_back<String>(&mut key, string::utf8(b"Proof of Commerce Score Data (Encrypted)"));
        vector::push_back<vector<u8>>(&mut val, s);
        
        vector::push_back<String>(&mut key, string::utf8(b"Proof of Social Score Data (Encrypted)"));
        vector::push_back<vector<u8>>(&mut val, s);
        
        vector::push_back<String>(&mut key, string::utf8(b"Proof of Gamer Score Data (Encrypted)"));
        vector::push_back<vector<u8>>(&mut val, s);

        (key, val)
    }


    #[test]
    public fun test(){
        let s = bcs::to_bytes(&string::utf8(b"a"));
        std::debug::print(&s);
        std::debug::print(&from_bcs::to_string(s));
    }
}
