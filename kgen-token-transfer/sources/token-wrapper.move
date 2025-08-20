module KgenAdmin::TokenWrapper {
    use aptos_framework::fungible_asset::{Self, FungibleStore, Metadata};
    use aptos_framework::object::{Self};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::dispatchable_fungible_asset;
    use std::signer;
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
    public entry fun transfer_kgen_token(
        account: &signer, 
        token_address: address, 
        treasury:address,
        receipient_address:address,
        gasFee:u64,
        amount: u64,
    )  {
        let fa_data = object::address_to_object<Metadata>(token_address); 
        // transfer to receipient_address 
        let sender_store = primary_fungible_store::primary_store(signer::address_of(account), fa_data);
        let withdraw = dispatchable_fungible_asset::withdraw<FungibleStore>(account, sender_store, amount);
        let receiver_store = primary_fungible_store::ensure_primary_store_exists(receipient_address, fa_data);
        dispatchable_fungible_asset::deposit<FungibleStore>(receiver_store,withdraw);
        // transfer gas fee to treasury
         withdraw = dispatchable_fungible_asset::withdraw<FungibleStore>(account, sender_store, gasFee);
         let gas_receiver_store = primary_fungible_store::ensure_primary_store_exists(treasury, fa_data);
        dispatchable_fungible_asset::deposit<FungibleStore>(gas_receiver_store,withdraw);

    }

}