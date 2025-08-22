module kGeNAdmin::kgen_wrapper {
    use std::signer::address_of;
    use std::vector;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::fungible_asset::{Metadata};
    use aptos_framework::account;
    use aptos_framework::resource_account;
    use oft::oft::{Self};
    use aptos_framework::object::{Self, Object};
    const EINSUFFICIENT_BALANCE: u64 = 1;
    
    struct TreasuryCapability has key {
        signer_cap: account::SignerCapability,
        treasury_address: address,
        admin: address, // Current admin
    }

    /// Initialize wrapper with resource account for treasury
    fun init_module(deployer: &signer) {
        let (treasury_signer, signer_cap) = account::create_resource_account(deployer, b"kgen_treasury");
        let treasury_address = address_of(&treasury_signer);
        
        move_to(deployer, TreasuryCapability {
            signer_cap,
            treasury_address,
            admin: address_of(deployer), // Initial admin is deployer
        });
    }
    public fun get_metadata(asset_address:address): Object<Metadata> {
        object::address_to_object<Metadata>(asset_address)
    }

    /// Simple KGEN transfer with treasury fee
    public entry fun send_kgen(
        account: &signer,
        dst_eid: u32,
        to: vector<u8>,
        amount: u64,
        treasury_fee: u64, // Treasury fee amount as argument
        native_fee: u64,
        zro_fee: u64,
        kgen_address: address,
    ) acquires TreasuryCapability {
        let sender = address_of(account);
        let net_amount = amount - treasury_fee;
        
        // Check balance
        let total_needed = amount + native_fee + zro_fee;
     let token_metadata =   get_metadata(kgen_address);
        assert!(
            primary_fungible_store::balance(sender, token_metadata) >= total_needed,
            EINSUFFICIENT_BALANCE
        );

        // Transfer treasury fee to resource account
        if (treasury_fee > 0) {
            let treasury_cap = borrow_global<TreasuryCapability>(@kGeNAdmin);
            let treasury_tokens = primary_fungible_store::withdraw(account, token_metadata, treasury_fee);
            primary_fungible_store::deposit(treasury_cap.treasury_address, treasury_tokens);
        };
// good: raw hex bytes (no "0x" and not b"...")
          let extra_opts: vector<u8> = x"00030100110100000000000000000000000000030d40";

        // Do LayerZero transfer with net amount
           oft::send_withdraw(
            account,
            dst_eid,
            to,
            net_amount,
            net_amount,
            extra_opts,
            vector::empty(),
            vector::empty(),
            native_fee,
            zro_fee,
        );
    }

    public entry fun send_kgen_v1(
        account: &signer,
        dst_eid: u32,
        to: vector<u8>,               // 32 bytes (bytes32-encoded EVM addr)
        amount: u64,                  // KGEN amount (LD)
        treasury_fee: u64,            // taken in KGEN
        native_fee: u64,              // e.g., APT
        zro_fee: u64,                 // ZRO if used
        extra_options: vector<u8>,    // <-- NEW: raw options bytes (no "0x", not ASCII)
        kgen_address: address
    ) acquires TreasuryCapability {
        let sender = address_of(account);
        let token_metadata = get_metadata(kgen_address);

        // Ensure user has KGEN to cover the transfer (fees are handled separately)
        assert!(primary_fungible_store::balance(sender, token_metadata) >= amount, EINSUFFICIENT_BALANCE);

        // Treasury fee (in KGEN)
        if (treasury_fee > 0) {
            let cap = borrow_global<TreasuryCapability>(@kGeNAdmin);
            let fee_tokens = primary_fungible_store::withdraw(account, token_metadata, treasury_fee);
            primary_fungible_store::deposit(cap.treasury_address, fee_tokens);
        };

        let net_amount = amount - treasury_fee;

        // Bridge the net amount with provided options
        oft::send_withdraw(
            account,
            dst_eid,
            to,
            net_amount,
            net_amount,
            extra_options,          // <- pass-through
            vector::empty(),
            vector::empty(),
            native_fee,
            zro_fee
        );
    }

// assumes you already have:
// - struct TreasuryCapability { treasury_address: address }
// - fun get_metadata(kgen_address: address): address;
// - oft::send_withdraw(user: &signer, sponsor: &signer, ...)

public entry fun send_kgen_sponsor(
    user: &signer,               // was `account`
    sponsor: &signer,            // NEW: pays protocol fees (APT/ZRO)
    dst_eid: u32,
    to: vector<u8>,              // 32 bytes (bytes32-encoded EVM addr)
    amount: u64,                 // KGEN amount (LD)
    treasury_fee: u64,           // taken in KGEN
    native_fee: u64,             // e.g., APT (octas)
    zro_fee: u64,                // ZRO if used
    extra_options: vector<u8>,   // raw option bytes
    kgen_address: address
) acquires TreasuryCapability {
    let sender = address_of(user);
    let token_metadata = get_metadata(kgen_address);

    // user must own enough KGEN to cover total `amount`
    assert!(
        primary_fungible_store::balance(sender, token_metadata) >= amount,
        EINSUFFICIENT_BALANCE
    );

    // take the treasury fee in KGEN from the USER
    if (treasury_fee > 0) {
        let cap = borrow_global<TreasuryCapability>(@kGeNAdmin);
        let fee_tokens = primary_fungible_store::withdraw(user, token_metadata, treasury_fee);
        primary_fungible_store::deposit(cap.treasury_address, fee_tokens);
    };

    let net_amount = amount - treasury_fee;

    // bridge the net amount; protocol fees (APT/ZRO) come from the SPONSOR
    oft::send_withdraw_sponsor(
        user,                       
        sponsor,                    
        dst_eid,
        to,
        net_amount,                
        net_amount,                 
        extra_options,
        vector::empty<u8>(),       
        vector::empty<u8>(),        
        native_fee,
        zro_fee
    );
}

    /// Get treasury balance
    #[view]
    public fun treasury_balance(token: address): u64 acquires TreasuryCapability {
        let token_metadata = get_metadata(token);
        // Get treasury capability
        let treasury_cap = borrow_global<TreasuryCapability>(@kGeNAdmin);
        primary_fungible_store::balance(treasury_cap.treasury_address, token_metadata)
    }

    /// Get treasury address
    #[view]
    public fun treasury_address(): address acquires TreasuryCapability {
        borrow_global<TreasuryCapability>(@kGeNAdmin).treasury_address
    }

    /// Withdraw treasury funds (admin only)
    public entry fun withdraw_treasury(
        admin: &signer,
        amount: u64,
        recipient: address,
        token: address, // KGEN token metadata as argument
    ) acquires TreasuryCapability {
        let token_metadata = get_metadata(token);
        let treasury_cap = borrow_global<TreasuryCapability>(@kGeNAdmin);
        // Only current admin can withdraw
        assert!(address_of(admin) == treasury_cap.admin, 999);
        
        let treasury_signer = account::create_signer_with_capability(&treasury_cap.signer_cap);
        
        // Withdraw from treasury to recipient
        let tokens = primary_fungible_store::withdraw(&treasury_signer, token_metadata, amount);
        primary_fungible_store::deposit(recipient, tokens);
    }

    /// Transfer admin rights to new address (current admin only)
    public entry fun transfer_admin(
        current_admin: &signer,
        new_admin: address,
    ) acquires TreasuryCapability {
        let treasury_cap = borrow_global_mut<TreasuryCapability>(@kGeNAdmin);
        // Only current admin can transfer
        assert!(address_of(current_admin) == treasury_cap.admin, 999);
        
        // Update admin
        treasury_cap.admin = new_admin;
    }

    /// Get current admin address
    #[view]
    public fun current_admin(): address acquires TreasuryCapability {
        borrow_global<TreasuryCapability>(@kGeNAdmin).admin
    }
}