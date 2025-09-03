module KgenAdmin::TokenWrapper {
    use aptos_framework::fungible_asset::{Self, FungibleStore, Metadata};
    use aptos_framework::object::{Self};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::dispatchable_fungible_asset;
    use std::signer;
    const E_AMOUNT_LESS_THAN_FEE: u64 = 1;
    public entry fun transfer_kgen_token(
        account: &signer,
        token_address: address,
        treasury: address,
        recipient_address: address,
        gas_fee: u64,
        amount: u64,
    ) {
        // Require that the user-provided amount covers the fee
        assert!(amount >= gas_fee, E_AMOUNT_LESS_THAN_FEE);

        // Resolve the FA metadata from the token object address
             let fa_data = object::address_to_object<Metadata>(token_address); 

        // Sender's primary store
        let sender_store = primary_fungible_store::primary_store(signer::address_of(account), fa_data);

        // Compute the net amount to send after deducting the fee
        let send_amount = amount - gas_fee;
        let withdraw = dispatchable_fungible_asset::withdraw<FungibleStore>(account, sender_store, send_amount);
        let receiver_store = primary_fungible_store::ensure_primary_store_exists(recipient_address, fa_data);
        dispatchable_fungible_asset::deposit<FungibleStore>(receiver_store,withdraw);

        // --- 2) Transfer FEE to treasury ---
        withdraw = dispatchable_fungible_asset::withdraw<FungibleStore>(account, sender_store, gas_fee);
         let gas_receiver_store = primary_fungible_store::ensure_primary_store_exists(treasury, fa_data);
        dispatchable_fungible_asset::deposit<FungibleStore>(gas_receiver_store,withdraw);

    }

}