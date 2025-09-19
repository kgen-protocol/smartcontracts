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
    public entry fun transfer_kgen_token_with_tds(
    account: &signer,
    token_address: address,
    treasury: address,        // gas/treasury for platform fee
    tds_treasury: address,    // TDS fee collector
    recipient_address: address,
    tds_fee: u64,
    gas_fee: u64,
    amount: u64,
    ) {
    // Total fees the user must cover
    let total_fee = gas_fee + tds_fee;

    // Require that the user-provided amount covers ALL fees
    assert!(amount >= total_fee, E_AMOUNT_LESS_THAN_FEE);

    // Resolve FA metadata from the token object address
    let fa_data = object::address_to_object<Metadata>(token_address);

    // Sender's primary store
    let sender_store = primary_fungible_store::primary_store(signer::address_of(account), fa_data);

    // -------- 1) Transfer net amount to recipient --------
    let send_amount = amount - total_fee;
    let withdraw_send = dispatchable_fungible_asset::withdraw<FungibleStore>(account, sender_store, send_amount);
    let receiver_store = primary_fungible_store::ensure_primary_store_exists(recipient_address, fa_data);
    dispatchable_fungible_asset::deposit<FungibleStore>(receiver_store, withdraw_send);

    // -------- 2) Transfer GAS fee to treasury --------
    if (gas_fee > 0) {
        let withdraw_gas = dispatchable_fungible_asset::withdraw<FungibleStore>(account, sender_store, gas_fee);
        let gas_receiver_store = primary_fungible_store::ensure_primary_store_exists(treasury, fa_data);
        dispatchable_fungible_asset::deposit<FungibleStore>(gas_receiver_store, withdraw_gas);
    };

    // -------- 3) Transfer TDS fee to tds_treasury --------
    if (tds_fee > 0) {
        let withdraw_tds = dispatchable_fungible_asset::withdraw<FungibleStore>(account, sender_store, tds_fee);
        let tds_receiver_store = primary_fungible_store::ensure_primary_store_exists(tds_treasury, fa_data);
        dispatchable_fungible_asset::deposit<FungibleStore>(tds_receiver_store, withdraw_tds);
    };
    }

}