module oapp::oapp {
    use std::fungible_asset::{FungibleAsset};
    use std::option;
    use std::option::Option;
    use std::primary_fungible_store;
    use std::signer::address_of;
    use endpoint_v2_common::native_token;
    use oapp::oapp_core::{combine_options, lz_quote, lz_send, refund_fees};
    use oapp::oapp_store::OAPP_ADDRESS;
    use aptos_framework::event;
    friend oapp::oapp_receive;
    friend oapp::oapp_compose;
    use endpoint_v2_common::bytes32::{Self, Bytes32};
    use aptos_framework::account::{Self};
    use std::signer;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::{Metadata};
    use std::string;
    use std::vector;
    use std::error;
    use aptos_std::from_bcs;
    use oapp::utils::{bytes_to_string, hex_string_to_bytes};
    use aptos_framework::system_addresses;
    const SEED: vector<u8> = b"KGEN_LAZYER_ZERO_SEED";
    use std::string::{String};
    use aptos_std::string_utils::{to_string};
    struct Admin has key {
        treasury_account: address,
        treasury_account_cap: account::SignerCapability,
        admin: address,
        nominated_admin: option::Option<address>
    }

    #[event]
    struct AdminWithdrawal has drop, store {
        admin: address,
        amount: u64,
        token: address
    }

    #[event]
    struct BridgeSuccessfulEvent has drop, store {
        token: address,
        to: address,
        amount: u64,
    }

    #[event]
    struct BridgeInitiatedEvent has drop, store {
        from: address,
        token: address,
        amount: u64
    }
    #[event]
    struct NominatedAdminEvent has drop, store {
        role: String, // Description of the role change
        nominated_admin: address // Address of the new admin
    }
        // Event emitted when the admin role is updated
    #[event]
    struct UpdatedAdmin has drop, store {
        role: String, // Description of the role change
        added_admin: address // Address of the new admin
    }
    #[view]

    fun init_module(account: &signer) {
        let (resource_account, treasury_account_cap) = account::create_resource_account(account, SEED);
        let treasury_account_address = signer::address_of(&resource_account);
        let admin_address = signer::address_of(account);
        move_to(account, Admin {
            admin: admin_address,
            treasury_account: treasury_account_address,
            treasury_account_cap: treasury_account_cap,
            nominated_admin: option::none()
        });
    }
    // Return the nominated admin address.
    public fun get_nominated_admin(): option::Option<address> acquires Admin {
        borrow_global<Admin>(@oapp).nominated_admin
    }
        public entry fun nominate_admin(
        admin_addr: &signer, new_admin: address
    ) acquires Admin {
        // Ensure that only admin can add a new admin
        assert_admin(admin_addr);

        // Ensure that new_admin should be a valid address
        assert!(
            new_admin != @0x0
                && !system_addresses::is_framework_reserved_address(new_admin),
            error::unauthenticated(ENOT_VALID_ADDRESS)
        );
        assert!(
            signer::address_of(admin_addr) != new_admin,
            error::already_exists(EALREADY_EXIST)
        );

        // Get the Nominated Admin Role storage reference
        let admin_struct = borrow_global_mut<Admin>(@oapp);
        // Nominate the new admin
        admin_struct.nominated_admin = option::some(new_admin);

        event::emit(
            NominatedAdminEvent {
                role: to_string(
                    &std::string::utf8(
                        b"New Admin Nominated, Now new admin need to accept the role"
                    )
                ),
                nominated_admin: new_admin
            }
        );
    }
     public entry fun accept_admin_role(new_admin: &signer) acquires Admin {
        let admin_struct = borrow_global_mut<Admin>(@oapp);
        // Ensure that nominated address exist
        let pending_admin = option::borrow(&admin_struct.nominated_admin);
        assert!(
            !option::is_none(&admin_struct.nominated_admin),
            error::unauthenticated(ENO_NOMINATED)
        );
        assert!(
            *pending_admin == signer::address_of(new_admin),
            error::unauthenticated(ENOT_VALID_ADDRESS)
        );
        // Add the new admin
        admin_struct.admin = signer::address_of(new_admin);
        admin_struct.nominated_admin = option::none();

        event::emit(
            UpdatedAdmin {
                role: to_string(&std::string::utf8(b"New Admin Added")),
                added_admin: signer::address_of(new_admin)
            }
        );
    }
    inline fun assert_admin(deployer: &signer) {
        assert!(
            borrow_global<Admin>(@oapp).admin == signer::address_of(deployer),
            error::unauthenticated(ENOT_ADMIN)
        );
    }

    #[view]
    public fun get_admin(): address acquires Admin {
        borrow_global<Admin>(@oapp).admin
    }

    fun get_resource_account_sign(): signer acquires Admin {
        account::create_signer_with_capability(
            &borrow_global<Admin>(@oapp).treasury_account_cap
        )
    }

    public entry fun transfer_from_resource_account_to_admin(admin: &signer, object: address, amount: u64) acquires Admin {
        let admin_address = signer::address_of(admin);
        assert!(
            admin_address == get_admin(),
            error::permission_denied(ENOT_ADMIN)
        );
        let sender = &get_resource_account_sign();
        primary_fungible_store::transfer(
            sender,
            get_metadata_object(object),
            admin_address,
            amount
        );
        event::emit(AdminWithdrawal {
            admin: admin_address,
            amount,
            token: object
        });
    }

    public(friend) fun lz_receive_impl(
        _src_eid: u32,
        _sender: Bytes32,
        _nonce: u64,
        _guid: Bytes32,
        _message: vector<u8>,
        _extra_data: vector<u8>,
        receive_value: Option<FungibleAsset>,
    ) acquires Admin {
        option::destroy(receive_value, |value| primary_fungible_store::deposit(OAPP_ADDRESS(), value));

        let string_length = (
            (*vector::borrow(&_message, 60) as u64) << 24 |
            (*vector::borrow(&_message, 61) as u64) << 16 |
            (*vector::borrow(&_message, 62) as u64) << 8 |
            (*vector::borrow(&_message, 63) as u64)
        );

        let string_start = 64;
        let string_end = string_start + string_length;
        let string_bytes = vector::slice(&_message, string_start, string_end);
        let decoded_string = bytes_to_string(string_bytes);

        let string_content_bytes = *string::bytes(&decoded_string);
        let hex_part_bytes = vector::slice(&string_content_bytes, 2, vector::length(&string_content_bytes));
        let hex_part_string = bytes_to_string(hex_part_bytes);
        let hex_content = hex_string_to_bytes(hex_part_string);

        let addr1_bytes = vector::slice(&hex_content, 0, 32);
        let userAddress = from_bcs::to_address(addr1_bytes);

        let addr2_bytes = vector::slice(&hex_content, 32, 64);
        let fa_token_address = from_bcs::to_address(addr2_bytes);

        let hex_content_len = vector::length(&hex_content);
        let number_bytes = if (hex_content_len >= 96) {
            vector::slice(&hex_content, 64, 96)
        } else {
            vector::slice(&hex_content, 64, hex_content_len)
        };

        let number_u256 = 0u256;
        let j = 0;
        let num_bytes_len = vector::length(&number_bytes);
        while (j < num_bytes_len) {
            let byte_val = *vector::borrow(&number_bytes, j);
            number_u256 = (number_u256 << 8) + (byte_val as u256);
            j = j + 1;
        };

        let resource_signer = &get_resource_account_sign();
        let asset = get_metadata_object(fa_token_address);
        primary_fungible_store::ensure_primary_store_exists(userAddress, asset);
        primary_fungible_store::transfer(
            resource_signer,
            asset,
            userAddress,
            number_u256 as u64
        );
        event::emit(BridgeSuccessfulEvent {
            token: fa_token_address,
            to: userAddress,
            amount: number_u256 as u64
        })
    }

    #[view]
    public fun get_treasury_adddress(): address acquires Admin {
        borrow_global<Admin>(@oapp).treasury_account
    }

    inline fun get_metadata_object(object: address): Object<Metadata> {
        object::address_to_object<Metadata>(object)
    }

    public fun decode_message_payload(message: &vector<u8>): (address, address, u256) {
        let addr1_bytes = vector::slice(message, 0, 32);
        let addr1 = from_bcs::to_address(addr1_bytes);

        let addr2_bytes = vector::slice(message, 32, 64);
        let addr2 = from_bcs::to_address(addr2_bytes);

        let amount_bytes = vector::slice(message, 64, vector::length(message));

        let amount = 0u256;
        let i = 0;
        let len = vector::length(&amount_bytes);
        while (i < len) {
            let b = vector::borrow(&amount_bytes, i);
            amount = (amount << 8) + (*b as u256);
            i = i + 1;
        };

        (addr1, addr2, amount)
    }

    public entry fun bridge_token(
        account: &signer,
        dst_eid: u32,
        message: vector<u8>,
        extra_options: vector<u8>,
        native_fee: u64,
        fa_token_address: address,
    ) acquires Admin {
        let bal = native_token::balance(address_of(account));
        assert!(bal >= native_fee, EINSUFFICIENT_BALANCE);
        assert!(signer::address_of(account) == get_admin(), ENOT_ADMIN);
        let native_fee_fa = native_token::withdraw(account, native_fee);

        let zro_fee_fa = option::none();
        let treasury_account = get_treasury_adddress();
        let asset = get_metadata_object(fa_token_address);
        let (_, _, amount) = decode_message_payload(&message);
        primary_fungible_store::ensure_primary_store_exists(treasury_account, asset);
        primary_fungible_store::transfer(
            account,
            asset,
            treasury_account,
            amount as u64
        );
        lz_send(
            dst_eid,
            message,
            combine_options(dst_eid, STANDARD_MESSAGE_TYPE, extra_options),
            &mut native_fee_fa,
            &mut zro_fee_fa,
        );
        refund_fees(address_of(account), native_fee_fa, zro_fee_fa);
        event::emit(BridgeInitiatedEvent {
            from: signer::address_of(account),
            token: fa_token_address,
            amount: amount as u64
        })
    }

    #[view]
    public fun quote_bridge_fee(
        dst_eid: u32,
        message: vector<u8>,
        extra_options: vector<u8>,
    ): (u64, u64) {
        let options = combine_options(dst_eid, STANDARD_MESSAGE_TYPE, extra_options);

        lz_quote(
            dst_eid,
            message,
            options,
            false,
        )
    }

    public(friend) fun lz_compose_impl(
        _from: address,
        _guid: Bytes32,
        _index: u16,
        _message: vector<u8>,
        _extra_data: vector<u8>,
        _value: Option<FungibleAsset>,
    ) {
        abort ECOMPOSE_NOT_IMPLEMENTED
    }

    public(friend) fun next_nonce_impl(_src_eid: u32, _sender: Bytes32): u64 {
        0
    }

    const ECOMPOSE_NOT_IMPLEMENTED: u64 = 1;
    const EINSUFFICIENT_BALANCE: u64 = 2;
    const STANDARD_MESSAGE_TYPE: u16 = 1;
    const ENOT_ADMIN: u64 = 2;
    /// Invalid address provided
    const ENOT_VALID_ADDRESS: u64 = 3;
    /// Provided argument is already present
    const EALREADY_EXIST: u64 = 4;
        /// No address is nominated
    const ENO_NOMINATED: u64 = 5;
}
