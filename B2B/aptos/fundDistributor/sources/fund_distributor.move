module fundDistributor::fundDistributor {
   use std::signer;
   use std::error;
   use aptos_framework::account;
   use std::vector; 
   use std::object::{Self};
   use aptos_framework::fungible_asset::{Self, FungibleStore, Metadata};
   use aptos_framework::primary_fungible_store;
   use aptos_framework::dispatchable_fungible_asset;
   const Deployer_address:address = @fundDistributor;
    const ENOT_ADMIN: u64 = 100;
    const EUNAUTHORIZED_WITHDRAWER: u64 = 101;
    const EVAULT_NOT_CREATED:u64 = 104;
    const EADMIN_NOT_FOUND:u64 = 105;
    const EADMIN_ALREADY_PRESENT:u64 = 106;
    const VAULT_SEED:vector<u8> =  b"FundDistributor_Vault";
    
   // purchase nft from cp to kgenWallet
     struct Vault has key {
        admins_list: vector<address>,
        signer_cap: account::SignerCapability,
        allowed_withdrawers: vector<address>,
    }
    public entry fun initialize(account: &signer){
        let (resource_address, signer_capability) = account::create_resource_account(account,VAULT_SEED );
        let admins = vector::empty<address>();
        vector::push_back(&mut admins, signer::address_of(account)); 
        move_to(&resource_address, Vault {
            admins_list: admins,
            allowed_withdrawers: vector::empty(),
            signer_cap : signer_capability,
        });
    }
    #[view]
     public fun get_vault_address():address{
        account::create_resource_address(&Deployer_address, VAULT_SEED)
    }
 public entry fun transfer(
    admin: &signer,
    receipient_address:address,
    token_address:address,
    amount:u64
) acquires Vault { 
    let vault_address = get_vault_address();
    assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
    let vault = borrow_global_mut<Vault>(vault_address);
    assert!(vector::contains(&vault.admins_list, &signer::address_of(admin)), ENOT_ADMIN);
    let fa_data = object::address_to_object<Metadata>(token_address);
    let receiver_store = primary_fungible_store::ensure_primary_store_exists(receipient_address, fa_data);
    let store = primary_fungible_store::ensure_primary_store_exists(vault_address, fa_data);
    let vault_signer = account::create_signer_with_capability(&vault.signer_cap);
    let withdraw = dispatchable_fungible_asset::withdraw<FungibleStore>(&vault_signer, store, amount);
    dispatchable_fungible_asset::deposit<FungibleStore>(receiver_store,withdraw);

}
public entry fun withdraw_fungible(
        account: &signer, 
        token_address: address, 
        receipient_address:address,
        amount: u64,
    ) acquires Vault {
        let vault_address = get_vault_address();
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vector::contains(&vault.allowed_withdrawers, &signer::address_of(account)), EUNAUTHORIZED_WITHDRAWER);
        let fa_data = object::address_to_object<Metadata>(token_address);
        let receiver_store = primary_fungible_store::ensure_primary_store_exists(receipient_address, fa_data);
        let store = primary_fungible_store::ensure_primary_store_exists(vault_address, fa_data);
        let vault_signer = account::create_signer_with_capability(&vault.signer_cap);
        let withdraw = dispatchable_fungible_asset::withdraw<FungibleStore>(&vault_signer, store, amount);
        dispatchable_fungible_asset::deposit<FungibleStore>(receiver_store,withdraw);
    }
    #[view]
    public fun get_allowed_withdrawers(): vector<address> acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
        let vault = borrow_global<Vault>(vault_address);
        return vault.allowed_withdrawers
    }
     public entry fun add_allowed_withdrawer(account: &signer,withdrawer: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vector::contains(&vault.admins_list, &signer::address_of(account)), EADMIN_NOT_FOUND); // Only owner can add withdrawers
        assert!(!vector::contains(&vault.allowed_withdrawers, &withdrawer), EUNAUTHORIZED_WITHDRAWER);
        vector::push_back(&mut vault.allowed_withdrawers, withdrawer);
        
    }
        public entry fun add_address_to_adminlist(account: &signer, addr: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vector::contains(&vault.admins_list, &signer::address_of(account)), ENOT_ADMIN);
        assert!(!vector::contains(&vault.admins_list, &addr), EADMIN_ALREADY_PRESENT);
        vector::push_back(&mut vault.admins_list, addr);
        
    }

    public entry fun remove_address_from_adminlist(account: &signer,addr: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vector::contains(&vault.admins_list, &signer::address_of(account)), ENOT_ADMIN);
        assert!(vector::contains(&vault.admins_list, &addr), EADMIN_NOT_FOUND);
        let (found, i) = vector::index_of(&vault.admins_list, &addr);
        assert!(found, EADMIN_NOT_FOUND);
        vector::remove(&mut vault.admins_list, i);
    }

      #[view]
    /// Check if an address is an admin
    public fun is_admin(admin_address: address): bool acquires Vault {
        let vault_address = get_vault_address();
        if (!exists<Vault>(vault_address)) {
            return false
        };
        let vault = borrow_global<Vault>(vault_address);
        vector::contains(&vault.admins_list, &admin_address)
    }

        public entry fun add_admin(account: &signer, new_admin: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), error::not_found(EVAULT_NOT_CREATED));
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vector::contains(&vault.admins_list, &signer::address_of(account)), EADMIN_NOT_FOUND);
        assert!(!vector::contains(&vault.admins_list, &new_admin), error::already_exists(EADMIN_ALREADY_PRESENT));
        vector::push_back(&mut vault.admins_list, new_admin);
    }
 public entry fun remove_admin(account: &signer, admin_to_remove: address) acquires Vault {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), error::not_found(EVAULT_NOT_CREATED));
        let vault = borrow_global_mut<Vault>(vault_address);
          assert!(vector::contains(&vault.admins_list, &signer::address_of(account)), EADMIN_NOT_FOUND);
        assert!(vector::contains(&vault.admins_list, &admin_to_remove), error::not_found(EADMIN_NOT_FOUND));
        let (found, i) = vector::index_of(&vault.admins_list, &admin_to_remove);
        assert!(found, error::not_found(EADMIN_NOT_FOUND));
        vector::remove(&mut vault.admins_list, i);
    }
    public entry fun deposit_fungible(
        account: &signer, 
        token_address: address, 
        amount: u64
    )  {
        let vault_address = get_vault_address();
        assert!(exists<Vault>(vault_address), EVAULT_NOT_CREATED);
        let fa_data = object::address_to_object<Metadata>(token_address); 
        let sender_store = primary_fungible_store::primary_store(signer::address_of(account), fa_data);
        let store = primary_fungible_store::ensure_primary_store_exists(vault_address, fa_data);
        let withdraw = dispatchable_fungible_asset::withdraw<FungibleStore>(account, sender_store, amount);
        dispatchable_fungible_asset::deposit<FungibleStore>(store,withdraw);
    }
}