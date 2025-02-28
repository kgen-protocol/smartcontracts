module KGeNAdmin::rKGeN_staking {
    use aptos_framework::timestamp;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_std::smart_table;
    use aptos_std::simple_map;
    use std::error;
    use std::signer;
    use std::string::{String};
    use std::vector;
    use std::event;
    use std::option::{Self};
    use aptos_std::smart_vector;
    use rKGenAdmin::rKGEN::{Self};
    use aptos_framework::system_addresses;
    use aptos_std::string_utils::{to_string};

    // Error codes
    /// Only Admin can invoke this
    const ENOT_ADMIN: u64 = 1;
    /// This is an invalid range
    const ERANGE_NOT_FOUND: u64 = 2;
    /// Minimum amount should less than maximum
    const EMIN_AMOUNT_GREATER_THAN_MAX: u64 = 3;
    /// This platform not exisit
    const EPLATFORM_NOT_FOUND: u64 = 4;
    /// Amount does not exist for this duration
    const EAMOUNT_NOT_FOUND_FOR_DURATION: u64 = 5;
    /// Not a nominated address
    const ENO_NOMINATED: u64 = 6;
    /// Duration is over
    const EHARVEST_DURATION_OVER: u64 = 7;
    /// Already exists
    const EALREADY_EXIST: u64 = 8;
    /// Invalid stake id
    const ESTAKE_NOT_EXIST: u64 = 9;
    /// You can only harvest once in 24 hrs
    const EHARVEST_TOO_SOON: u64 = 10;
    /// Invalid arguments provided
    const EINVALID_ARGUMENT: u64 = 11;
    /// Staking period is not over yet
    const ECLAIM_TOO_SOON: u64 = 12;
    /// Only invoke this function
    const EINVALID_PLATFORM: u64 = 13;
    /// This platform is already exist
    const EPLATFORM_ALREADY_EXISTS: u64 = 14;
    /// Invalid lenght in ranges
    const EAPY_ROWS_MISMATCH: u64 = 15;
    /// Invalid address provided
    const ENOT_VALID_ADDRESS: u64 = 16;

    const HARVEST_TIME: u64 = 1440;  // For mainnet, in minutes
    const SECONDS_IN_DAY: u64 = 86400; // In seconds

    // Resources
    // Represents the admin's information and configuration.
    struct Admin has key {
        admin: address,
        range_id: u64,
        platform_list: smart_vector::SmartVector<address>,
        signer_cap: SignerCapability,
        resource_address: address,
        nominated_admin: option::Option<address>
    }

    // Represents a specific APY range configuration for staking.
    struct APYRange has store, drop, copy {
        min_amount: u64,
        max_amount: u64,
        apy: u64,
        duration: u64
    }

    // Stores and manages all APY ranges for staking in a smart table.
    struct StakingAPYRange has key {
        ranges: smart_table::SmartTable<u64, APYRange>
    }

    // Represents the details of an individual stake made by a user.
    struct StakeDetails has store, drop, copy {
        amount: u64,
        apy: u64,
        duration: u64,
        start_time: u64,
        last_harvest_time: u64,
        total_claimed: u64
    }

    struct UserStakes has key {
        stake_id: u64,
        stakes: simple_map::SimpleMap<u64, StakeDetails>
    }

    #[view]
    public fun get_admin(): address acquires Admin {
        borrow_global<Admin>(@KGeNAdmin).admin
    }

    // Fetches the appropriate APY range based on the input amount.
    #[view]
    public fun get_apy_range(input_amount: u64, input_duration: u64): APYRange acquires StakingAPYRange {
        let read_apy_table = borrow_global<StakingAPYRange>(@KGeNAdmin);
        let apy_range_row = option::none<APYRange>();
        let found = false;

        smart_table::for_each_ref<u64, APYRange>(
            &read_apy_table.ranges,
            |_key, value| {

                let APYRange { min_amount, max_amount, apy: _, duration } = *value;

                if (input_amount >= min_amount && input_amount < max_amount) {
                    if (input_duration == duration) {
                        apy_range_row = option::some<APYRange>(*value);
                        found = true // Mark as found
                    }
                };
            }
        );
        assert!(found, error::out_of_range(EAMOUNT_NOT_FOUND_FOR_DURATION));

        option::extract(&mut apy_range_row)
    }

    // Check if stake is exists for the user
    #[view]
    public fun is_stake_exists(stake_holder: address, stake_id: u64): bool acquires UserStakes{
        if (exists<UserStakes>(stake_holder)){
            let st = borrow_global<UserStakes>(stake_holder);
            if(simple_map::contains_key(&st.stakes, &stake_id)){
                true
            }else{
                false
            }
        }else{
            false
        }
    }

    // Get all available staking ranges
    #[view]
    public fun get_staking_ranges(): simple_map::SimpleMap<u64, APYRange> acquires StakingAPYRange {
        let apy_table = borrow_global<StakingAPYRange>(@KGeNAdmin);
        smart_table::to_simple_map(&apy_table.ranges)
    }

    // Get a specific staking range by its range_id.
    #[view]
    public fun get_staking_range_by_range_id(range_id: u64): APYRange acquires StakingAPYRange {
        let apy_table = borrow_global<StakingAPYRange>(@KGeNAdmin);
        assert!(
            smart_table::contains(&apy_table.ranges, range_id),
            error::not_found(ERANGE_NOT_FOUND)
        );
        *smart_table::borrow(&apy_table.ranges, range_id)
    }

    // Active stakes
    #[view]
    public fun get_user_stake_records(user_address: address): simple_map::SimpleMap<u64, StakeDetails> acquires UserStakes{
        if (exists<UserStakes>(user_address)){
            let st = borrow_global<UserStakes>(user_address);
            st.stakes
        }else{
            simple_map::new<u64, StakeDetails>()
        }
    }

    // Get the resource account address associated with the admin
    #[view]
    public fun get_resource_acc_address(): address acquires Admin {
        borrow_global<Admin>(@KGeNAdmin).resource_address
    }

    // Get the list of authorized platforms.
    #[view]
    public fun get_authorised_platforms(): vector<address> acquires Admin {
        let platform = borrow_global<Admin>(@KGeNAdmin);
        smart_vector::to_vector(&platform.platform_list)
    }

    #[view]
    public fun is_duration_over(
        user_address: address, input_stake_id: u64
    ): bool acquires UserStakes {
        assert!(
            is_stake_exists(user_address, input_stake_id),
            error::not_found(ESTAKE_NOT_EXIST)
        );
        let st = borrow_global<UserStakes>(user_address);
        let stake = *simple_map::borrow(&st.stakes, &input_stake_id);
        timestamp::now_seconds() >= stake.start_time + (stake.duration * SECONDS_IN_DAY)
    }

    #[view]
    public fun get_stake_by_stake_id(
        user_address: address, input_stake_id: u64
    ): StakeDetails acquires UserStakes {
        assert!(
            is_stake_exists(user_address, input_stake_id),
            error::not_found(ESTAKE_NOT_EXIST)
        );
        let st = borrow_global<UserStakes>(user_address);
        *simple_map::borrow(&st.stakes, &input_stake_id)
    }

    // Get the current reward to harvest
    #[view]
    public fun get_current_reward(user_address: address, stake_id: u64): u64 acquires UserStakes {
        let stake = get_stake_by_stake_id(user_address, stake_id);

        let current_time = timestamp::now_seconds();

        if (current_time > stake.start_time + (stake.duration * SECONDS_IN_DAY)) {
            current_time = stake.start_time + (stake.duration * SECONDS_IN_DAY)
        };

        let total_rewards_earned =
            get_available_rewards(
                stake.start_time,
                stake.apy,
                stake.amount,
                current_time
            );

        let total_rewards_claimed = stake.total_claimed;

        // Calculate the current reward to be harvested
        let current_reward = total_rewards_earned - total_rewards_claimed;
        current_reward
    }

    // get total staked balance of a user
    #[view]
    public fun total_active_stakes(user_address: address): u64 acquires UserStakes{
        if(exists<UserStakes>(user_address)){
            let st = borrow_global<UserStakes>(user_address);
            simple_map::length(&st.stakes)
        }else { 0 }
    }

    // get total staked balance of a user
    #[view]
    public fun get_staked_balance(user_address: address): u64 acquires UserStakes{
        let staked_amount = 0;
        if(exists<UserStakes>(user_address)){
            let st = borrow_global<UserStakes>(user_address);
            
            let stake_list = simple_map::values(&st.stakes);
            let i=0;
            while(i < vector::length(&stake_list)){
                let stake_details = vector::borrow(&stake_list, i);
                staked_amount = staked_amount + stake_details.amount;
                i = i + 1;
            }
        };
        staked_amount
    }

    // Get claimable reward for a specific stake
    #[view]
    public fun get_total_claimable_reward(
        user_address: address, stake_id: u64
    ): u64 acquires UserStakes {
        let stake = get_stake_by_stake_id(user_address, stake_id);

        let total_rewards_earned =
            get_available_rewards(
                stake.start_time,
                stake.apy,
                stake.amount,
                stake.start_time + (stake.duration * SECONDS_IN_DAY)
            ); 
        total_rewards_earned - stake.total_claimed + stake.amount
    }

    #[event]
    struct AddStakeEvent has drop, store {
        amount: u64,
        timestamp: u64,
        stake_id: u64
    }

    // Event emitted when a platform is added by an admin.
    #[event]
    struct PlatformAddedEvent has drop, store {
        admin_address: address,
        platform_address: address
    }

    // Event emitted when a platform is removed by an admin.
    #[event]
    struct PlatformRemovedEvent has drop, store {
        admin_address: address,
        platform_address: address
    }

    // Event emitted when a apy is removed by an admin.
    #[event]
    struct APYUpdated has drop, store {
        range_id: u64,
        admin_address: address,
        updated_apy: u64
    }

    // Event emitted when the admin role is updated
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

    // Event emitted when rewards are harvested from a stake.
    #[event]
    struct HarvestEvent has drop, store {
        reward: u64,
        timestamp: u64,
        apy: u64,
        stake_id: u64
    }

    // Event emitted when a stake is claimed (unstaked).
    #[event]
    struct ClaimEvent has drop, store {
        unstake_amount: u64,
        timestamp: u64,
        apy: u64,
        stake_id: u64
    }


    // Event emitted when the entire APY table is updated.
    #[event]
    struct TransferFromResource has drop, store {
        receiver: address,
        amount: u64
    }

    // Event emitted when the entire APY table is updated.
    #[event]
    struct APYTableUpdated has drop, store {
        admin_address: address,
        timestamp: u64
    }

    fun init_module(admin: &signer) {
        let admin_address = signer::address_of(admin);
        let seed = b"rKGeN_staking";
        let (resource_signer, resource_signer_cap) =
            account::create_resource_account(admin, seed);
        let resource_account_address = signer::address_of(&resource_signer);

        let initial_range_id = 1;
        move_to(
            admin,
            Admin {
                admin: admin_address,
                range_id: initial_range_id,
                platform_list: smart_vector::new<address>(),
                signer_cap: resource_signer_cap,
                resource_address: resource_account_address,
                nominated_admin: option::none()
            }
        );
        move_to(
            admin,
            StakingAPYRange {
                ranges: smart_table::new<u64, APYRange>()
            }
        );
    }

    // Remove rKGeN from contract
    public entry fun transfer_from_resource(admin: &signer, receiver: address, amount: u64) acquires Admin{
        // Ensure the caller is the admin
        assert!(
            signer::address_of(admin) == get_admin(),
            error::permission_denied(ENOT_ADMIN)
        );

        // Transfer the current reward to the user
        let res_config = borrow_global<Admin>(@KGeNAdmin);
        let resource_signer =
            account::create_signer_with_capability(&res_config.signer_cap);
        rKGEN::transfer(&resource_signer, receiver, amount);
        event::emit(
            TransferFromResource {
                receiver,
                amount
            }
        );
    }

    // Updates the admin by nominating a new admin
    public entry fun nominate_admin(
        admin_addr: &signer, new_admin: address
    ) acquires Admin {
        // Ensure that only admin can add a new admin
        assert!(
            signer::address_of(admin_addr) == get_admin(),
            error::permission_denied(ENOT_ADMIN)
        );

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
        let admin_struct = borrow_global_mut<Admin>(@KGeNAdmin);
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

    // Allows the nominated admin to accept their role and become the new admin
    public entry fun accept_admin_role(new_admin: &signer) acquires Admin {
        let admin_struct = borrow_global_mut<Admin>(@KGeNAdmin);
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

    // Adds a platform to the list of allowed platforms.
    public entry fun add_platform(admin: &signer, platform: address) acquires Admin {
        assert!(
            signer::address_of(admin) == get_admin(),
            error::permission_denied(ENOT_ADMIN)
        );

        // Ensure that the platform address is not empty
        assert!(
            platform != @0x0,
            error::invalid_argument(EINVALID_ARGUMENT)
        );

        // Check if the platform already exists in the list
        let existing_platforms = &mut borrow_global_mut<Admin>(@KGeNAdmin).platform_list;
        let is_duplicate = smart_vector::contains(existing_platforms, &platform);
        assert!(
            !is_duplicate,
            error::invalid_argument(EPLATFORM_ALREADY_EXISTS)
        );

        smart_vector::push_back(existing_platforms, platform);

        event::emit(
            PlatformAddedEvent {
                admin_address: signer::address_of(admin),
                platform_address: platform
            }
        );

    }

    // Removes a platform from the list of allowed platforms.
    public entry fun remove_platform(admin: &signer, platform: address) acquires Admin {
        assert!(
            signer::address_of(admin) == get_admin(),
            error::permission_denied(ENOT_ADMIN)
        );

        let platform_list = &mut borrow_global_mut<Admin>(@KGeNAdmin).platform_list;

        // Ensure the platform address is not empty
        assert!(
            platform != @0x0,
            error::invalid_argument(EINVALID_ARGUMENT)
        );

        let (exists, index) = smart_vector::index_of(platform_list, &platform);

        // Ensure the platform exists in the list
        assert!(
            exists,
            error::not_found(EPLATFORM_NOT_FOUND)
        );

        // Remove the platform from the list using its index
        smart_vector::remove(platform_list, index);

        event::emit(
            PlatformRemovedEvent {
                admin_address: signer::address_of(admin),
                platform_address: platform
            }
        );

    }

    // Updates the APY table with new ranges.
    public entry fun manage_apy_table(
        admin: &signer,
        min_amount: vector<u64>, // Minimum stakes for new ranges
        max_amount: vector<u64>, // Maximum stakes for new ranges
        apy: vector<u64>, // APY values for new ranges
        duration: vector<u64> // Durations for new ranges
    ) acquires StakingAPYRange, Admin {
        let admin_address = signer::address_of(admin);

        // Ensure the caller is the admin
        assert!(
            admin_address == get_admin(),
            error::permission_denied(ENOT_ADMIN)
        );

        // Ensure all input vectors have the same length
        let length = vector::length(&min_amount);
        assert!(
            length == vector::length(&max_amount)
                && length == vector::length(&apy)
                && length == vector::length(&duration),
            error::invalid_argument(EAPY_ROWS_MISMATCH)
        );

        // Prepare the smart table
        if (exists<StakingAPYRange>(@KGeNAdmin)) {
            let apy_table = &mut borrow_global_mut<StakingAPYRange>(@KGeNAdmin).ranges;
            smart_table::clear(apy_table); // Clear existing entries

        };

        // Reset the range_id
        let current_range_id = borrow_global_mut<Admin>(@KGeNAdmin);
        current_range_id.range_id = 1;

        // Prepare keys and values for `add_all`
        let keys: vector<u64> = vector::empty();
        let values: vector<APYRange> = vector::empty();

        for (i in 0..length) {
            // Validate the range
            let min = *vector::borrow(&min_amount, i);
            let max = *vector::borrow(&max_amount, i);
            let apy_value = *vector::borrow(&apy, i);
            let duration_value = *vector::borrow(&duration, i);

            assert!(
                min> 0 && min < max,
                error::invalid_argument(EMIN_AMOUNT_GREATER_THAN_MAX)
            );
            // Construct key and value
            vector::push_back(&mut keys, current_range_id.range_id);
            vector::push_back(
                &mut values,
                APYRange {
                    min_amount: min,
                    max_amount: max,
                    apy: apy_value,
                    duration: duration_value
                }
            );

            // Increment range_id
            current_range_id.range_id = current_range_id.range_id + 1;
        };

        // Add all ranges to the smart table
        let apy_table = &mut borrow_global_mut<StakingAPYRange>(@KGeNAdmin).ranges;
        smart_table::add_all(apy_table, keys, values);

        event::emit(
            APYTableUpdated {
                admin_address: signer::address_of(admin),
                timestamp: timestamp::now_seconds()
            }
        );
    }

    // Updates the APY value for a specific range.
    public entry fun update_apy(
        admin: &signer, range_id: u64, new_apy: u64
    ) acquires Admin, StakingAPYRange {
        assert!(
            signer::address_of(admin) == get_admin(),
            error::permission_denied(ENOT_ADMIN)
        );

        let apy_table = &mut borrow_global_mut<StakingAPYRange>(@KGeNAdmin).ranges;

        assert!(
            smart_table::contains(apy_table, range_id),
            error::not_found(ERANGE_NOT_FOUND)
        );

        // Retrieve the existing range
        let current_range = smart_table::borrow(apy_table, range_id);

        // Create a new APYRange with the updated field
        let updated_range = APYRange {
            min_amount: current_range.min_amount,
            max_amount: current_range.max_amount,
            apy: new_apy,
            duration: current_range.duration
        };

        // Update the smart table with the modified range
        smart_table::upsert(apy_table, range_id, updated_range);
        event::emit(
            APYUpdated {
                range_id: range_id,
                admin_address: signer::address_of(admin),
                updated_apy: new_apy
            }
        );
    }

    // Add stake by users
    public entry fun add_stake(user: &signer, platform: &signer, input_amount: u64, input_duration: u64
    ) acquires StakingAPYRange, Admin, UserStakes{
        // verify platform
        assert!(
            verify_platform(&signer::address_of(platform)),
            error::invalid_argument(EINVALID_PLATFORM)
        );

        let user_address = signer::address_of(user);
        let apy_range_row = get_apy_range(input_amount, input_duration);
        let current_time = timestamp::now_seconds();

        let new_stake = StakeDetails{
            amount: input_amount,
            apy: apy_range_row.apy,
            duration: input_duration,
            start_time: current_time,
            last_harvest_time: current_time,
            total_claimed: 0
        };
        let resource_addr = get_resource_acc_address();
        if (!exists<UserStakes>(user_address)){
            let vec_id = vector::empty<u64>();
            let vec_stake = vector::empty<StakeDetails>();
            vector::push_back(&mut vec_id, 1);
            vector::push_back(&mut vec_stake, new_stake);

            move_to(user, UserStakes{
                stake_id: 1,
                stakes: simple_map::new_from<u64, StakeDetails>(vec_id, vec_stake)
            });
            rKGEN::transfer(user, resource_addr, input_amount);
            event::emit(
                AddStakeEvent { amount: input_amount, timestamp: current_time, stake_id: 1 }
            );
        } else {
            let user_stakes_table = borrow_global_mut<UserStakes>(user_address);
            user_stakes_table.stake_id = user_stakes_table.stake_id + 1;
            simple_map::add(&mut user_stakes_table.stakes, user_stakes_table.stake_id, new_stake);
            
            rKGEN::transfer(user, resource_addr, input_amount);
            event::emit(
                AddStakeEvent { amount: input_amount, timestamp: current_time, stake_id: user_stakes_table.stake_id }
            );
        };
    }

    public entry fun harvest(
        user: &signer, platform: &signer, stake_id: u64
    ) acquires UserStakes, Admin{
        // verify platform
        assert!(
            verify_platform(&signer::address_of(platform)),
            error::invalid_argument(EINVALID_PLATFORM)
        );
        let user_address = signer::address_of(user);
        assert!(
            is_stake_exists(user_address, stake_id),
            error::not_found(ESTAKE_NOT_EXIST)
        );

        let user_stake_table = borrow_global_mut<UserStakes>(user_address);
        let stake = simple_map::borrow_mut(&mut user_stake_table.stakes, &stake_id);

        // Ensure at least 24 hours have passed since last harvest
        let current_time = timestamp::now_seconds();
        assert!(
            current_time - stake.last_harvest_time >= HARVEST_TIME * 60,
            error::invalid_argument(EHARVEST_TOO_SOON)
        );

        //  ensure the current time is within the staking duration
        assert!(
            current_time <= stake.start_time + (stake.duration * SECONDS_IN_DAY),
            error::invalid_argument(EHARVEST_DURATION_OVER)
        );

        let total_rewards_earned =
            get_available_rewards(
                stake.start_time,
                stake.apy,
                stake.amount,
                current_time
            );
        
        let current_reward = total_rewards_earned - stake.total_claimed;

        // Transfer the current reward to the user
        let res_config = borrow_global<Admin>(@KGeNAdmin);
        let resource_signer =
            account::create_signer_with_capability(&res_config.signer_cap);
        rKGEN::transfer(&resource_signer, user_address, current_reward);

        stake.total_claimed = total_rewards_earned;
        stake.last_harvest_time = current_time;

        event::emit(
            HarvestEvent {
                reward: current_reward,
                timestamp: current_time,
                apy: stake.apy,
                stake_id: stake_id
            }
        );

    }

    public entry fun claim(
        user: &signer, platform: &signer, stake_id: u64
    ) acquires UserStakes, Admin {
        // verify platform
        assert!(
            verify_platform(&signer::address_of(platform)),
            error::invalid_argument(EINVALID_PLATFORM)
        );
        let user_address = signer::address_of(user);
        assert!(
            is_stake_exists(user_address, stake_id),
            error::not_found(ESTAKE_NOT_EXIST)
        );

        let user_stake_table = borrow_global_mut<UserStakes>(user_address);
        let stake = simple_map::borrow_mut(&mut user_stake_table.stakes, &stake_id);

        // Ensure at least 24 hours have passed since last harvest
        let current_time = timestamp::now_seconds();

        // Check if staking period is over or not
        assert!(
            current_time >= stake.start_time + (stake.duration * SECONDS_IN_DAY),
            error::invalid_argument(ECLAIM_TOO_SOON)
        );

        let total_rewards_earned =
            get_available_rewards(
                stake.start_time,
                stake.apy,
                stake.amount,
                stake.start_time + (stake.duration * SECONDS_IN_DAY)
            );
        
        let claimable_amount = total_rewards_earned - stake.total_claimed + stake.amount;

        // Transfer the current reward to the user
        let res_config = borrow_global<Admin>(@KGeNAdmin);
        let resource_signer =
            account::create_signer_with_capability(&res_config.signer_cap);
        rKGEN::transfer(&resource_signer, user_address, claimable_amount);

        event::emit(
            ClaimEvent {
                unstake_amount: claimable_amount,
                timestamp: current_time,
                apy: stake.apy,
                stake_id
            }
        );

        simple_map::remove(&mut user_stake_table.stakes, &stake_id);
    }

    // check if platform address exist in verified platfrom list
    inline fun verify_platform(platform: &address): bool acquires Admin {
        let platform_list = &borrow_global<Admin>(@KGeNAdmin).platform_list;
        smart_vector::contains(platform_list, platform)
    }

    //Calculate the available rewards for a user based on the stake details and the current time.
    fun get_available_rewards(
        start_time: u64,
        apy: u64,
        amount: u64,
        current_time: u64
    ): u64 {
        let passed_time = current_time - start_time;
        let seconds_in_year = 365 * 86400;

        let amount_u256 = amount as u256;
        let apy_u256 = apy as u256;
        let passed_time_u256 = passed_time as u256;
        let seconds_in_year_u256 = seconds_in_year as u256;

        let total_rewards_earned =
            amount_u256 * apy_u256 * passed_time_u256 / (seconds_in_year_u256 * 100);
        total_rewards_earned = total_rewards_earned / 10000;

        (total_rewards_earned & 0xFFFFFFFFFFFFFFFF as u64)
    }
}
