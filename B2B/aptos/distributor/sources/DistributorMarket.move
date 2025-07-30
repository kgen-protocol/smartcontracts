    module distributor_addr::distributor_V2_market {
   use std::signer;
   use std::option;
   use std::error;
   use std::string::{Self, String};
   use std::object::{Self, Object, TransferRef};
   use std::timestamp;
   use aptos_token_objects::royalty::{Royalty};
   use aptos_token_objects::token::{Self, Token};
   use aptos_token_objects::collection;
   use aptos_std::big_ordered_map::{Self, BigOrderedMap};
   use aptos_framework::fungible_asset::{Self, FungibleStore, Metadata};
   use aptos_framework::primary_fungible_store;
    use aptos_framework::event;
   use aptos_framework::dispatchable_fungible_asset;
   #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
   
   /// The owner of the token has not owned it for long enough
   const ETOKEN_IN_LOCKUP: u64 = 0;
   /// The owner must own the token to transfer it
   const ENOT_TOKEN_OWNER: u64 = 1;

   const COLLECTION_NAME: vector<u8> = b"Rickety Raccoons";
   const COLLECTION_DESCRIPTION: vector<u8> = b"A collection of rickety raccoons!";
   const COLLECTION_URI: vector<u8> = b"https://ricketyracoonswebsite.com/collection/rickety-raccoon.png";
   const TOKEN_URI: vector<u8> = b"https://ricketyracoonswebsite.com/tokens/raccoon.png";
   const MAXIMUM_SUPPLY: u64 = 1000;
      const EINSUFFICIENT_BALANCE: u64 = 1;
   /// Invalid quantity (must be > 0)
   const EINVALID_QUANTITY: u64 = 2;
   /// Not authorized
   const ENOT_AUTHORIZED: u64 = 3;
   // 24 hours in one day * 60 minutes in one hour * 60 seconds in one minute * 7 days
   #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
   struct SemiFungibleToken has key {
      // How many copies each address owns
      balances: BigOrderedMap<address, u64>,
      // Total supply of this token
      total_supply: u64,
      // Token metadata
      name: String,
      uri: String,
      // Transfer controls
      transfer_ref: TransferRef,
      last_transfer: u64,
   }
   const storageContract: address = @0xecf431e33e96c6f3769e181713f59c758d669b9a5b0e1856cd9f94850202af02;
      #[event]
    struct PurcheseNftEvent   has drop, store {
        cp: address,
        kgenWallet: address,
        amount: u64,
        token: Object<Token>,
        quantity: u64,
        utr: String,

    }

   public fun initialize_collection(creator: &signer) {
      collection::create_fixed_collection(
         creator,
         string::utf8(COLLECTION_DESCRIPTION),
         MAXIMUM_SUPPLY,
         string::utf8(COLLECTION_NAME),
         option::none<Royalty>(),
         string::utf8(COLLECTION_URI),
      );
   }
public entry fun transfer(
      from: &signer,
      token: Object<Token>,
      to: address,
      quantity: u64,
   )   {
   }

   public entry fun transfer_v1(
      from: address,
      token: Object<Token>,
      to: address,
      quantity: u64,
   ) acquires SemiFungibleToken {
      // redundant error checking for clear error message
      assert!(object::is_owner(token, from), error::permission_denied(ENOT_TOKEN_OWNER));
      assert!(quantity > 0, error::invalid_argument(EINVALID_QUANTITY));


      let from_addr = from;
      let token_data = borrow_global_mut<SemiFungibleToken>(object::object_address(&token));

      // Check sender has enough
      assert!(big_ordered_map::contains(&token_data.balances, &from_addr), error::invalid_argument(EINSUFFICIENT_BALANCE));
      let from_balance = big_ordered_map::borrow_mut(&mut token_data.balances, &from_addr);
      assert!(*from_balance >= quantity, error::invalid_argument(EINSUFFICIENT_BALANCE));

      // Update sender balance
      *from_balance = *from_balance - quantity;
      // Update recipient balance
      if (big_ordered_map::contains(&token_data.balances, &to)) {
         let to_balance = big_ordered_map::borrow_mut(&mut token_data.balances, &to);
         *to_balance = *to_balance + quantity;
      } else {
         big_ordered_map::add(&mut token_data.balances, to, quantity);
      };
      // generate linear transfer ref and transfer the token object
      let linear_transfer_ref = object::generate_linear_transfer_ref(&token_data.transfer_ref);
      object::transfer_with_ref(linear_transfer_ref, to);

   }
   public entry  fun initialize_collection_v1(creator: &signer) {
      collection::create_fixed_collection(
         creator,
         string::utf8(COLLECTION_DESCRIPTION),
         MAXIMUM_SUPPLY,
         string::utf8(COLLECTION_NAME),
         option::none<Royalty>(),
         string::utf8(COLLECTION_URI),
      );
   }

   public  entry fun create_semi_fungible_token(
      creator: &signer,
      token_name: String,
   ) {
      let token_constructor_ref = token::create_named_token(
         creator,
         string::utf8(COLLECTION_NAME),
         string::utf8(COLLECTION_DESCRIPTION),
         token_name,
         option::none(),
         string::utf8(TOKEN_URI),
      );

      let transfer_ref = object::generate_transfer_ref(&token_constructor_ref);
      let token_signer = object::generate_signer(&token_constructor_ref);

      // disable the ability to transfer the token through any means other than the `transfer` function we define
    //   object::disable_ungated_transfer(&transfer_ref);

      move_to(
         &token_signer,
         SemiFungibleToken {
            balances: big_ordered_map::new<address, u64>(),
            total_supply: 0,
            name: token_name,
            uri: string::utf8(TOKEN_URI),
            transfer_ref,
            last_transfer: timestamp::now_seconds(),
         }
      );

        
   }
   // purchase nft from cp to kgenWallet
   public entry fun purchaseNft(
      buyer: &signer,
      token: Object<Token>,
      cp: address,
      quantity: u64,
      amount: u64,
      paytoken:address,
      utr:String,
   ) acquires SemiFungibleToken { 
      let to = signer::address_of(buyer);
      transfer_v1(cp, token, storageContract, quantity);
      let fa_data = object::address_to_object<Metadata>(paytoken); 
      let sender_store = primary_fungible_store::primary_store(signer::address_of(buyer), fa_data);
      let withdraw = dispatchable_fungible_asset::withdraw<FungibleStore>(buyer, sender_store, amount);
      let receiver_store = primary_fungible_store::ensure_primary_store_exists(cp, fa_data);
      dispatchable_fungible_asset::deposit<FungibleStore>(receiver_store,withdraw);
     event::emit<PurcheseNftEvent>(PurcheseNftEvent{
        cp: cp,
        kgenWallet: to,
        amount: amount,
        token: token,
        quantity: quantity,
        utr: utr,
     });
      // object::transfer(creator, token, to);
   }
   public entry fun mint_to(
      creator: &signer,
      token: Object<Token>,
      to: address,
      quantity: u64,
   ) acquires SemiFungibleToken {
      let token_data = borrow_global_mut<SemiFungibleToken>(object::object_address(&token));
      token_data.total_supply = token_data.total_supply + quantity;
      if (big_ordered_map::contains(&token_data.balances, &to)) {
         let balance = big_ordered_map::borrow_mut(&mut token_data.balances, &to);
         *balance = *balance + quantity;
      } else {
         big_ordered_map::add(&mut token_data.balances, to, quantity);
      };
     
      object::transfer(creator, token, to);
   }  
   //    // Get total supply
   #[view]
   public fun total_supply(token: Object<Token>): u64 acquires SemiFungibleToken {
      let token_data = borrow_global<SemiFungibleToken>(object::object_address(&token));
      token_data.total_supply
   }

   // Get token name
   #[view]
   public fun name(token: Object<Token>): String acquires SemiFungibleToken {
      let token_data = borrow_global<SemiFungibleToken>(object::object_address(&token));
      token_data.name
   }

   // Get token URI
   #[view]
   public fun uri(token: Object<Token>): String acquires SemiFungibleToken {
      let token_data = borrow_global<SemiFungibleToken>(object::object_address(&token));
      token_data.uri
   }
   //    // Check balance
   #[view]
   public fun balance_of(token: Object<Token>, owner: address): u64 acquires SemiFungibleToken {
      let token_data = borrow_global<SemiFungibleToken>(object::object_address(&token));
      if (big_ordered_map::contains(&token_data.balances, &owner)) {
         *big_ordered_map::borrow(&token_data.balances, &owner)
      } else {
         0
      }
   }
   }
