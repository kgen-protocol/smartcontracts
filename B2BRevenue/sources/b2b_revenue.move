module KGENB2B::B2BRevenue {
    use std::signer;
    use std::vector;
    use std::table;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::{Metadata};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::account::{Self};
    use aptos_framework::error;
    const E_NOT_WHITELISTED: u64 = 1001;
    const E_NOT_ADMIN: u64 = 1002;
    const E_INVALID_AMOUNT: u64 = 1003;
    const E_INSUFFICIENT_BALANCE: u64 = 1004;
    const E_ALREADY_WHITELISTED:u64 = 1005;
    const E_NOT_WHITELISTED_TOKEN:u64 = 1006;
    const E_TOKEN_ALREDY_WHITELISTED :u64 =1007;
    const SEED: vector<u8> = b"b2c-revenue_v1";
    const CORE_ADDRESS: address = @KGENB2B;
    struct Whitelist has key {
        accounts: vector<address>,
        admin: address,
        revenue_account_cap: account::SignerCapability,
    }

// wallet_addresse => token_address=>value
    struct Balances has key {
        tokenbalances: table::Table<address, u64>,
    }

    struct WhitelistToken has key, store, drop {
        isWhiteListed: bool,
    }

    struct WhitelistTokens has key, store {
        tokens: table::Table<address, WhitelistToken>,
    }
inline fun get_metadata_object(object: address): Object<Metadata> {
        object::address_to_object<Metadata>(object)
    }

public entry fun initialize(admin: &signer) {
        let caller_address = signer::address_of(admin);
        assert!(caller_address == CORE_ADDRESS,error::permission_denied( E_NOT_ADMIN));
        let (_, treasury_account_cap) = account::create_resource_account(admin, SEED);
        move_to(admin, Whitelist {
            revenue_account_cap:treasury_account_cap,
            admin: caller_address,
            accounts: vector[]
        });
    move_to(admin, Balances {tokenbalances : table::new<address, u64>()  });
    move_to(admin, WhitelistTokens { tokens: table::new<address, WhitelistToken>() });
    }

fun get_resource_account_sign(): signer acquires Whitelist {
        account::create_signer_with_capability(
            &borrow_global_mut<Whitelist>(@KGENB2B).revenue_account_cap
        )
    } 

public entry fun add_whitelist_token(admin: &signer, token: address) acquires WhitelistTokens,Whitelist {
    let caller_address = signer::address_of(admin);
    assert!(is_admin(caller_address),error::permission_denied(E_NOT_ADMIN));
    let whitelist_ref = borrow_global_mut<WhitelistTokens>(CORE_ADDRESS);
    assert!(!table::contains(&whitelist_ref.tokens, token),error::already_exists(E_TOKEN_ALREDY_WHITELISTED));
    table::upsert(
        &mut whitelist_ref.tokens,
        token,
        WhitelistToken { isWhiteListed: true }
    );
}

public fun is_token_whitelisted(token: address): bool acquires WhitelistTokens {
    let whitelist_ref = borrow_global<WhitelistTokens>(CORE_ADDRESS);
    if (!table::contains(&whitelist_ref.tokens, token)) {
        return false;
    };
    let token_data = table::borrow(&whitelist_ref.tokens, token);
    token_data.isWhiteListed
}

public entry fun add_whitelist_address(admin: &signer, account: address) acquires Whitelist {
        let caller_address = signer::address_of(admin);
        assert!(is_admin(caller_address),error::permission_denied(E_NOT_ADMIN) );
        let whitelist_ref = borrow_global_mut<Whitelist>(CORE_ADDRESS);
        assert!(!vector::contains(&whitelist_ref.accounts,&account),error::already_exists(E_ALREADY_WHITELISTED));
        whitelist_ref.accounts.push_back(account);
    }

public entry fun remove_from_admin_whitelist(admin: &signer, account: address) acquires Whitelist {
        let caller_address = signer::address_of(admin);
        assert!(is_admin(caller_address),error::permission_denied(E_NOT_ADMIN));
        let whitelist_ref = borrow_global_mut<Whitelist>(CORE_ADDRESS);
        assert!(vector::contains(&whitelist_ref.accounts,&account),error::not_found(E_NOT_WHITELISTED));
        let  index = 0;
        let length = vector::length(&whitelist_ref.accounts);

        let  i = index;
        while (i < length) {
            if (*vector::borrow(&whitelist_ref.accounts, i) == account) {
                break;
            };
            i = i + 1;
        };
        vector::swap_remove(&mut whitelist_ref.accounts, i);
    }

public entry fun deposit(user: &signer, token: address, amount: u64) acquires Balances , Whitelist,WhitelistTokens{
    assert!(amount > 0,error::invalid_argument(E_INVALID_AMOUNT));
    assert!(is_token_whitelisted(token),error::not_found(E_NOT_WHITELISTED_TOKEN));
    let balance_ref = borrow_global_mut<Balances>(CORE_ADDRESS);

    let token_balance =  if (table::contains(&balance_ref.tokenbalances, token)) {
        *table::borrow_mut(&mut balance_ref.tokenbalances, token)
    } else {
        0
    };
    let treasury = &get_resource_account_sign();
    primary_fungible_store::transfer(
        user,
        get_metadata_object(token),
        signer::address_of(treasury), 
        amount
    );
    let new_token_balance = token_balance + amount;
     if (table::contains(&balance_ref.tokenbalances, token)) {
        *table::borrow_mut(&mut balance_ref.tokenbalances, token) = new_token_balance;
    } else {
        table::add(&mut balance_ref.tokenbalances, token, new_token_balance);
    };

}

public entry fun withdraw(user: &signer, token: address, amount: u64,to:address) acquires Balances, Whitelist,WhitelistTokens {
    let caller_address = signer::address_of(user);
    assert!(amount > 0, error::invalid_argument( E_INVALID_AMOUNT));
    assert!(is_admin(caller_address),error::permission_denied(E_NOT_ADMIN));
    assert!(is_token_whitelisted(token),error::not_found(E_NOT_WHITELISTED_TOKEN));
    let balance_ref = borrow_global_mut<Balances>(CORE_ADDRESS);
    let current_token_balance = table::borrow_mut(&mut balance_ref.tokenbalances, token);
    assert!(*current_token_balance >= amount,error::invalid_argument( E_INSUFFICIENT_BALANCE));
    *current_token_balance = *current_token_balance - amount;
    let treasury = &get_resource_account_sign();
    primary_fungible_store::transfer(
        treasury,
        get_metadata_object(token),
        to,
        amount
    );
}

#[view]
public fun is_admin(account: address): bool acquires Whitelist {
        let whitelist_ref = borrow_global<Whitelist>(CORE_ADDRESS);
        //return true when it's the deployer address
        if(account == CORE_ADDRESS){return true};
        if(vector::contains(&whitelist_ref.accounts,&account))return true;
        false
    }

#[view]
public fun get_whitelist_admin(): vector<address> acquires Whitelist {
        let whitelist_ref = borrow_global<Whitelist>(CORE_ADDRESS);
        whitelist_ref.accounts
    }

#[view]
public fun get_token_balance_v1(token_address: address): u64 acquires Balances {
    let balances_ref = borrow_global<Balances>(CORE_ADDRESS);
    if (!table::contains(&balances_ref.tokenbalances, token_address)) {
        return 0;
    };
    let balance_ref = table::borrow(&balances_ref.tokenbalances, token_address);
    *balance_ref
}
}

