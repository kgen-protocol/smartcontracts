module RevenueContractV2::RevenueContractV2 {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::account;
    use aptos_framework::table::{Self, Table};
    use aptos_framework::fungible_asset::{Self, FungibleStore, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::dispatchable_fungible_asset;
    use std::signer;
    use std::vector; 
    use aptos_framework::event;
    const EONLY_OWNER: u64 = 100;
    const EUNAUTHORIZED_WITHDRAWER: u64 = 101;
    const ETOKEN_NOT_WHITELISTED: u64 = 102;
    const EINSUFFICIENT_BALANCE: u64 = 103;
    const EVAULT_ALREADY_CREATED:u64 = 104;
    const EVAULT_NOT_CREATED:u64 = 105;
    const EZERO_TOKEN_DEPOSIT:u64 = 106;
    const EADMIN_NOT_FOUND:u64 = 107;
    const ETOKEN_HAS_BALANCE:u64 = 108;
    const EADMIN_ALREADY_PRESENT:u64 = 109;
    const ETOKEN_ALREADY_WHITELISTED:u64 = 110;
    const ENOT_DEPLOYER:u64 = 111;
    const DEPLOYER_ADDRESS:address = @deployer;
    #[event]
    /// Emitted when deposit fungible asset to contract 
    struct DepositFungibleAsset has drop ,store {
        sender:address,
        token:address,
        amount:u64
    }
    #[event]
    /// Emitted when deposit fungible asset to contract 
    struct DepositNativeAsset has drop ,store {
        sender:address,
        amount:u64
    }
   struct RevenueEventHolder has key {
        deposit_fungible: event::EventHandle<DepositFungibleAsset>,
    }
   struct RevenueEventHolderV1 has key {
        deposit_native: event::EventHandle<DepositNativeAsset>,
    }
    struct Vault has key {
        admins_list: vector<address>,
        signer_cap: account::SignerCapability,
        allowed_withdrawers: vector<address>,
        nativeCoins: Coin<aptos_coin::AptosCoin>, // Holds APT instead of storing it directly in the account balance
        faCoins: Table<address, Object<FungibleStore>>, // Store multiple token types
        whiteListedTokens:vector<address>
    }
  public entry fun initializeV1(account: &signer)  {
         move_to(account, RevenueEventHolder {
            deposit_fungible: account::new_event_handle<DepositFungibleAsset>(account),
        });
    }
  public entry fun initializeV2(account: &signer)  {
         move_to(account, RevenueEventHolderV1 {
            deposit_native: account::new_event_handle<DepositNativeAsset>(account),
        });
    }

    public entry fun initialize(account: &signer){
        assert!(signer::address_of(account) == DEPLOYER_ADDRESS, ENOT_DEPLOYER);
        let (resource_address, signer_capability) = account::create_resource_account(account, b"vault");
        assert!(!exists<Vault>(signer::address_of(&resource_address)), EVAULT_ALREADY_CREATED);
        let admins = vector::empty<address>();
        vector::push_back(&mut admins, signer::address_of(account)); 
        move_to(&resource_address, Vault {
            admins_list: admins,
            allowed_withdrawers: vector::empty(),
            nativeCoins: coin::zero<aptos_coin::AptosCoin>(), // Start with 0 APT
            faCoins: table::new<address, Object<FungibleStore>>(), // Table to store multiple tokens
            whiteListedTokens: vector::empty(),
            signer_cap : signer_capability
        });
    }
    public entry fun deposit_native(account: &signer, amount: u64) acquires Vault,RevenueEventHolderV1 {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
        assert!(amount > 0, EZERO_TOKEN_DEPOSIT);
        let vault = borrow_global_mut<Vault>(vault_address);
        let coins = coin::withdraw(account, amount);
        coin::merge(&mut vault.nativeCoins, coins); // Store APT inside Vault struct
        let revenue_event_holder = borrow_global_mut<RevenueEventHolderV1>(@RevenueContractV2);
        event::emit_event<DepositNativeAsset>(
            &mut revenue_event_holder.deposit_native,
            DepositNativeAsset{
                sender : signer::address_of(account),
                amount
            }
        )
    }

    public entry fun add_allowed_withdrawer(account: &signer,withdrawer: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vector::contains(&vault.admins_list, &signer::address_of(account)), EADMIN_NOT_FOUND); // Only owner can add withdrawers
        assert!(!vector::contains(&vault.allowed_withdrawers, &withdrawer), EUNAUTHORIZED_WITHDRAWER);
        vector::push_back(&mut vault.allowed_withdrawers, withdrawer);
        
    }

    public entry fun withdraw_native(account: &signer, recipient: address, amount: u64) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
        assert!(amount > 0, EZERO_TOKEN_DEPOSIT);
        let vault = borrow_global_mut<Vault>(vault_address);
        
        assert!(vector::contains(&vault.allowed_withdrawers, &signer::address_of(account)), EUNAUTHORIZED_WITHDRAWER);
        assert!(coin::value(&vault.nativeCoins) >= amount, EINSUFFICIENT_BALANCE);
        let coins = coin::extract(&mut vault.nativeCoins, amount);
        coin::deposit(recipient, coins);
    }

    public entry fun add_address_to_adminlist(account: &signer, addr: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vector::contains(&vault.admins_list, &signer::address_of(account)), EONLY_OWNER);
        assert!(!vector::contains(&vault.admins_list, &addr), EADMIN_ALREADY_PRESENT);
        vector::push_back(&mut vault.admins_list, addr);
        
    }

    public entry fun remove_address_from_adminlist(account: &signer,addr: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vector::contains(&vault.admins_list, &signer::address_of(account)), EONLY_OWNER);
        assert!(vector::contains(&vault.admins_list, &addr), EADMIN_NOT_FOUND);
        let (found, i) = vector::index_of(&vault.admins_list, &addr);
        assert!(found, EADMIN_NOT_FOUND);
        vector::remove(&mut vault.admins_list, i);
      
        
    }

    public entry fun whitelist_token(account: &signer, addr: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vector::contains(&vault.admins_list, &signer::address_of(account)), EONLY_OWNER);
        assert!(!vector::contains(&vault.whiteListedTokens, &addr), ETOKEN_ALREADY_WHITELISTED);
        vector::push_back(&mut vault.whiteListedTokens, addr);
        create_vault_fa_store(addr);
        
    }

    public entry fun remove_whitelisted_token(account: &signer,addr: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vector::contains(&vault.admins_list, &signer::address_of(account)), EONLY_OWNER);
        assert!(vector::contains(&vault.whiteListedTokens, &addr), ETOKEN_NOT_WHITELISTED);
        let token_store_obj = *table::borrow(&vault.faCoins, addr);
        let balance = fungible_asset::balance(token_store_obj);
        assert!(!(balance > 0), ETOKEN_HAS_BALANCE); 
        let (found, i) = vector::index_of(&vault.whiteListedTokens, &addr);
        assert!(found,ETOKEN_NOT_WHITELISTED);
        table::remove(&mut vault.faCoins, addr);
        vector::remove(&mut vault.whiteListedTokens, i);
    
        
    }

    public fun is_token_whitelisted(token_address: address):bool acquires Vault{
        let vault_address = get_vault_address();
        if (!exists<Vault>(vault_address)) {
            return false
        }
        else {
            let vault = borrow_global<Vault>(vault_address);
            return vector::contains(&vault.whiteListedTokens, &token_address)
        }         
    }
 
    public entry fun deposit_fungible(
        account: &signer, 
        token_address: address, 
        amount: u64,
    ) acquires Vault ,RevenueEventHolder {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
        assert!(amount > 0, EZERO_TOKEN_DEPOSIT);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(table::contains(&vault.faCoins, token_address), ETOKEN_NOT_WHITELISTED);
        assert!(vector::contains(&vault.whiteListedTokens, &token_address), ETOKEN_NOT_WHITELISTED);
        let fa_data = object::address_to_object<Metadata>(token_address); 
        let sender_store = primary_fungible_store::primary_store(signer::address_of(account), fa_data);
        let store_ref = table::borrow_mut(&mut vault.faCoins, token_address);
        let store = *store_ref;
        let withdraw = dispatchable_fungible_asset::withdraw<FungibleStore>(account, sender_store, amount);
        dispatchable_fungible_asset::deposit<FungibleStore>(store,withdraw);
        let sender = signer::address_of(account);
        let revenue_event_holder = borrow_global_mut<RevenueEventHolder>(@RevenueContractV2);
        event::emit_event<DepositFungibleAsset>(
            &mut revenue_event_holder.deposit_fungible,
            DepositFungibleAsset{
                sender,
                token: token_address,
                amount,
            }
        );}

    fun create_vault_fa_store(
        token_address:address,
    ) acquires Vault{
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);     
        let vault = borrow_global_mut<Vault>(vault_address);
        let metadata = object::address_to_object<Metadata>(token_address);
        let fungible_store = primary_fungible_store::ensure_primary_store_exists(vault_address, metadata);
        if (!table::contains(&vault.faCoins, token_address)) {
            table::add(&mut vault.faCoins, token_address, fungible_store);
        } else {
            // Optional: Handle already existing case
            assert!(false, ETOKEN_ALREADY_WHITELISTED);
        }
    }

    fun get_vault_address():address{
        account::create_resource_address(&DEPLOYER_ADDRESS, b"vault")
    }

    fun u64_pow(base: u64, exp: u8): u64 {
        let result = 1;
        let i = 0;
        while (i < exp) {
            result = result * base;
            i = i + 1;
        };
        result
    }

    public entry fun withdraw_fungible(
        account: &signer, 
        token_address: address, 
        receipient_address:address,
        amount: u64,
    ) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
        assert!(amount > 0, EZERO_TOKEN_DEPOSIT);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vector::contains(&vault.whiteListedTokens, &token_address), ETOKEN_NOT_WHITELISTED); // Token must be whitelisted
        assert!(vector::contains(&vault.allowed_withdrawers, &signer::address_of(account)), EUNAUTHORIZED_WITHDRAWER);
        let fa_data = object::address_to_object<Metadata>(token_address);
        let receiver_store = primary_fungible_store::ensure_primary_store_exists(receipient_address, fa_data);
        let store_ref = table::borrow_mut(&mut vault.faCoins, token_address);
        let store = *store_ref;
        assert!(fungible_asset::balance<FungibleStore>(store) >= amount, EINSUFFICIENT_BALANCE);
        let vault_signer = account::create_signer_with_capability(&vault.signer_cap);
        let withdraw = dispatchable_fungible_asset::withdraw<FungibleStore>(&vault_signer, store, amount);
        dispatchable_fungible_asset::deposit<FungibleStore>(receiver_store,withdraw);
    }

     #[view]
    public fun get_whitelisted_tokens(): vector<address> acquires Vault
     {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
        let vault = borrow_global<Vault>(vault_address);
        return vault.whiteListedTokens
    }

     #[view]
    public fun get_allowed_withdrawers(): vector<address> acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
        let vault = borrow_global<Vault>(vault_address);
        return vault.allowed_withdrawers
    }
   
    #[view]
    public fun is_admin(user: address): bool acquires Vault {
        let vault_address = get_vault_address();
        if (!exists<Vault>(vault_address)) {
            return false
        };
        let vault = borrow_global<Vault>(vault_address);
        if(vector::contains(&vault.admins_list, &user)){
            return true
        }
        else{
            return false
        }
        
    }

    #[view]
    public fun get_token_balance(token_address: address): u64 acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
        let vault = borrow_global<Vault>(vault_address);
        
        if (!vector::contains(&vault.whiteListedTokens, &token_address)) {
            return 0 // Return 0 if the token is not whitelisted
        };

        let store_ref = table::borrow(&vault.faCoins, token_address);
        let store = *store_ref;

        return fungible_asset::balance<FungibleStore>(store)
    }


    #[test(account = @0x5)]
    fun test_initialize(account: signer) {
        initialize(&account);
    }

    #[test(framework = @0x1,owner=@0x1234, user = @0x2)]
    fun test_deposit_withdraw_native(framework:signer,owner: signer, user: signer) acquires Vault {
        initialize(&owner);
        let vault_address = account::create_resource_address(&signer::address_of(&owner), b"vault");
        let owner_addr = signer::address_of(&owner);
        let (burn, mint) = aptos_framework::aptos_coin::initialize_for_test(&framework);
        aptos_framework::aptos_account::create_account(copy owner_addr);

        let coin = coin::mint<AptosCoin>(1000, &mint);
        coin::deposit(copy owner_addr, coin);

        deposit_native(&owner, 500);
        let vault = borrow_global<Vault>(vault_address);
        assert!(coin::value(&vault.nativeCoins) == 500, EINSUFFICIENT_BALANCE);

        let user_addr = signer::address_of(&user);
        aptos_framework::aptos_account::create_account(copy user_addr);
        let coin = coin::mint<AptosCoin>(100, &mint);
        coin::deposit(copy user_addr, coin);

        add_allowed_withdrawer(&owner, signer::address_of(&user));
        withdraw_native(&user, signer::address_of(&user), 200);
        let updated_vault = borrow_global<Vault>(vault_address);
        assert!(coin::value(&updated_vault.nativeCoins) == 300, EINSUFFICIENT_BALANCE);
        coin::destroy_burn_cap(burn);
        coin::destroy_mint_cap(mint);
    }
    
    #[test(owner = @0xcafe, user = @0xface)]
    fun test_deposit_and_withdraw_fungible(owner: &signer, user: &signer) acquires Vault{
        initialize(owner);
        let vault_address = account::create_resource_address(&signer::address_of(owner), b"vault");
        let (creator_ref, metadata) = fungible_asset::create_test_token(owner);
        let (mintRef,_,_) = primary_fungible_store::init_test_metadata_with_primary_store_enabled(&creator_ref);
        let creator_address = signer::address_of(owner);
        let token_address = object::object_address(&metadata);
        whitelist_token(owner,token_address);
        primary_fungible_store::mint(&mintRef, creator_address,100);
        deposit_fungible(owner, token_address,100);
        add_allowed_withdrawer(owner, signer::address_of(owner));
        withdraw_fungible(owner, token_address,signer::address_of(user),100);
    }


    #[test(framework=@0x1,owner = @0x1234, user = @0x5677)]
    fun test_unauthorized_withdrawal(framework:signer,owner: signer, user: signer) acquires Vault{
        initialize(&owner);
        let vault_address = account::create_resource_address(&signer::address_of(&owner), b"vault");
        let owner_addr = signer::address_of(&owner);
        let (burn, mint) = aptos_framework::aptos_coin::initialize_for_test(&framework);
        aptos_framework::aptos_account::create_account(copy owner_addr);

        let coin = coin::mint<AptosCoin>(1000, &mint);
        coin::deposit(copy owner_addr, coin);
        deposit_native(&owner, 500);
        withdraw_native(&user, signer::address_of(&user), 100);
        coin::destroy_burn_cap(burn);
        coin::destroy_mint_cap(mint);
        
    }

    #[test(owner = @0x1)]
    fun test_zero_deposit(owner: signer) acquires Vault{
        initialize(&owner);
        deposit_native(&owner, 0);
    
    }

    }

