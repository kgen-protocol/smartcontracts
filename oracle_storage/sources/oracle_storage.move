module Admin::oracle_storage {
    use std::signer;
    use std::string::{Self, String, utf8};
    use std::option;
    use std::vector;

    // To get player info, like scores and badges
    #[view]
    public fun get_player_scores(player: address): (vector<String>, vector<vector<u8>>) {
        let key = vector::empty<String>();
        let f = vector::empty<u8>();
        let val = vector::empty<vector<u8>>();

        vector::push_back<String>(&mut key, string::utf8(b""));
        vector::push_back<String>(&mut key, string::utf8(b""));
        vector::push_back<u8>(&mut f, 0);
        vector::push_back<u8>(&mut f, 0);
        vector::push_back<String>(&mut key, string::utf8(b""));
        vector::push_back<String>(&mut key, string::utf8(b""));
        vector::push_back<u8>(&mut f, 0);
        vector::push_back<u8>(&mut f, 0);
        vector::push_back<String>(&mut key, string::utf8(b""));
        vector::push_back<String>(&mut key, string::utf8(b""));
        vector::push_back<u8>(&mut f, 0);
        vector::push_back<u8>(&mut f, 0);
        vector::push_back<String>(&mut key, string::utf8(b""));
        vector::push_back<String>(&mut key, string::utf8(b""));
        vector::push_back<u8>(&mut f, 0);
        vector::push_back<u8>(&mut f, 0);
        vector::push_back<String>(&mut key, string::utf8(b""));
        vector::push_back<String>(&mut key, string::utf8(b""));
        vector::push_back<u8>(&mut f, 0);
        vector::push_back<u8>(&mut f, 0);
        vector::push_back<String>(&mut key, string::utf8(b""));
        vector::push_back<String>(&mut key, string::utf8(b""));
        vector::push_back<u8>(&mut f, 0);
        vector::push_back<u8>(&mut f, 0);

        vector::push_back<vector<u8>>(&mut val, f);

        (key, val)
    }
}
