module KGeNAdmin::rKGeN_staking {
    use std::error;
    use std::signer;
    use std::string::{String};
    use std::vector;
    use aptos_framework::account;
    use std::event;
    use aptos_framework::timestamp;
    use aptos_framework::account::SignerCapability;
    use aptos_std::smart_table;
    use aptos_std::simple_map;
    use std::option::{Self};
    use aptos_std::smart_vector;
    use rKGenAdmin::rKGEN::{Self};
    use aptos_framework::system_addresses;
    use aptos_std::string_utils::{to_string};

    // =====================================   ERROR CODES   =====================================
    const ECALLER_NOT_ADMIN: u64 = 1;
    const ERANGE_NOT_FOUND: u64 = 2;
    const EMIN_AMOUNT_GREATER_THAN_MAX: u64 = 3;
    const EINVALID_MIN_AMOUNT: u64 = 4;
    const EDURATION_NOT_FOUND: u64 = 6; // "Duration not found (on add stake)."
    const EAMOUNT_NOT_FOUND_FOR_DURATION: u64 = 7; // "Amount does not exist for the specified duration (on add stake)
    const EUSER_NOT_FOUND: u64 = 8;
    const ESTAKE_NOT_EXIST: u64 = 9;
    const EHARVEST_TOO_SOON: u64 = 10;
    const EINVALID_ARGUMENT: u64 = 11;
    const ECLAIM_TOO_SOON: u64 = 12;
    const EINVALID_PLATFORM: u64 = 13;
    const EPLATFORM_ALREADY_EXISTS: u64 = 14;
    const EAPY_ROWS_MISMATCH: u64 = 15;
    const ENOT_VALID_ADDRESS: u64 = 16;
    const EALREADY_EXIST: u64 = 17;
    const ENO_NOMINATED: u64 = 18;
    const EHARVEST_DURATION_OVER: u64 = 19;
    const EPLATFORM_NOT_FOUND: u64 = 20;
    const ESTAKE_DURATION_COMPLETED: u64 = 5;

    const HARVEST_TIME: u64 = 1440;
    const SECONDS_IN_DAY: u64 = 86400;

    // =====================================    STORAGE   =====================================

    // Represents the admin's information and configuration.
    struct Admin has key {
        admin: address,
        range_id: u64,
        platform_list: smart_vector::SmartVector<address>,
        signer_cap: SignerCapability,
        res_address: address,
        nominated_admin: option::Option<address>
    }

    // Represents a specific APY range configuration for staking.
    struct APYRange has store, drop, copy {
        // range_id: u8,
        min_amount: u64,
        max_amount: u64,
        apy: u8,
        duration: u64
    }

    // Stores and manages all APY ranges for staking in a smart table.
    struct StakingAPYRange has key {
        // ranges: vector<APYRange>
        // will store range_id - row of range
        ranges: smart_table::SmartTable<u64, APYRange>
    }

    // Represents the details of an individual stake made by a user.
    struct StakeDetails has store, drop, copy {
        stake_id: u64,
        amount: u64,
        apy: u8,
        duration: u64,
        start_time: u64,
        last_harvest_time: u64,
        total_claimed: u64
    }

    // Stores the list of stakes for a particular user.
    struct StakeList has store, drop, copy {
        stake_id: u64,
        stake_list: vector<StakeDetails>
    }

    // Stores all stakes made by users, indexed by their addresses.
    struct UserStakes has key {
        stakes: smart_table::SmartTable<address, StakeList>
    }

    // =====================================    EVENTS   =====================================

    //Event emitted when a stake is added.
    #[event]
    struct AddStakeEvent has drop, store {
        amount: u64,
        timestamp: u64,
        stake_id: u64
    }

    // Event emitted when rewards are harvested from a stake.
    #[event]
    struct HarvestEvent has drop, store {
        reward: u64,
        timestamp: u64,
        apy: u8,
        stake_id: u64
    }

    // Event emitted when a stake is claimed (unstaked).
    #[event]
    struct ClaimEvent has drop, store {
        unstake_amount: u64,
        timestamp: u64,
        apy: u8,
        stake_id: u64
    }

    // Event emitted when the entire APY table is updated.
    #[event]
    struct APYTableUpdated has drop, store {
        admin_address: address,
        timestamp: u64
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
        updated_apy: u8
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

    // =====================================    INITAILIZATION OF MODULE =====================================
    // This function performs the following:
    // 1. Creates a resource account for the module.
    // 2. Transfers ownership of the APY range configuration and user stakes to the admin.
    fun init_module(admin: &signer) {

        let admin_address = signer::address_of(admin);

        // ===Resource acc creation===
        let seed = b"rkgen_resource_acc_seed";
        let (resource_signer, resource_signer_cap) =
            account::create_resource_account(admin, seed);
        let resource_account_address = signer::address_of(&resource_signer);

        // === transferring ownership of `StakingAPYRange`, `UserStakes` to admin ===
        let initial_range_id = 1;
        move_to(
            admin,
            Admin {
                admin: admin_address,
                range_id: initial_range_id,
                platform_list: smart_vector::new<address>(),
                signer_cap: resource_signer_cap,
                res_address: resource_account_address,
                nominated_admin: option::none()
            }
        );
        move_to(
            admin,
            StakingAPYRange {
                ranges: smart_table::new<u64, APYRange>()
            }
        );
        move_to(
            admin,
            UserStakes {
                stakes: smart_table::new<address, StakeList>()
            }
        );

    }

    // =====================================   ADMIN METHODS =====================================
    // Updates the admin by nominating a new admin
    public entry fun nominate_admin(admin_addr: &signer, new_admin: address) acquires Admin {
        // Ensure that only admin can add a new admin
        assert!(
            signer::address_of(admin_addr) == get_admin(),
            error::permission_denied(ECALLER_NOT_ADMIN)
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
            error::permission_denied(ECALLER_NOT_ADMIN)
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
            error::permission_denied(ECALLER_NOT_ADMIN)
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
        apy: vector<u8>, // APY values for new ranges
        duration: vector<u64> // Durations for new ranges
    ) acquires StakingAPYRange, Admin {
        let admin_address = signer::address_of(admin);

        // Ensure the caller is the admin
        assert!(
            admin_address == get_admin(),
            error::permission_denied(ECALLER_NOT_ADMIN)
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
                min < max,
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
        admin: &signer, range_id: u64, new_apy: u8
    ) acquires Admin, StakingAPYRange {
        assert!(
            signer::address_of(admin) == get_admin(),
            error::permission_denied(ECALLER_NOT_ADMIN)
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

    // =====================================   USER METHODS =====================================

    // Adds a stake for the user with the specified amount and duration.
    public entry fun add_stake(
        user: &signer,
        platform: &signer,
        input_amount: u64,
        input_duration: u64
    ) acquires StakingAPYRange, UserStakes, Admin {

        // verify platform
        assert!(
            verify_platform(&signer::address_of(platform)),
            error::invalid_argument(EINVALID_PLATFORM)
        );

        let user_address = signer::address_of(user);

        //  Validate input
        validate_add_stake_input_duration(input_duration);

        //  Fetch APY Range for the given amount and duration
        let apy_range_row = get_apy_range(input_amount);

        //  Initialize or update user stakes
        let user_stakes_table = borrow_global_mut<UserStakes>(@KGeNAdmin);

        if (!smart_table::contains(&user_stakes_table.stakes, user_address)) {

            let new_stake = initialize_stake();

            add_stake_details(
                &mut new_stake,
                input_amount,
                input_duration,
                apy_range_row.apy,
                0 //total_claimed
            );

            smart_table::add(&mut user_stakes_table.stakes, user_address, new_stake);
        } else {

            // Fetch the existing stakes for the user
            let existing_stakes =
                smart_table::borrow_mut(&mut user_stakes_table.stakes, user_address);

            add_stake_details(
                existing_stakes,
                input_amount,
                input_duration,
                apy_range_row.apy,
                0 //total_claimed
            );
            // Debug message to confirm the new stake addition
        };

        // transfer
        let resource_addr = get_resource_acc_address();
        rkgen_transfer(user, resource_addr, input_amount);

    }

    // Harvest the rewards for a user from a specific stake.
    public entry fun harvest(
        user: &signer, platform: &signer, stake_id: u64
    ) acquires UserStakes, Admin {
        // verify platform
        assert!(
            verify_platform(&signer::address_of(platform)),
            error::invalid_argument(EINVALID_PLATFORM)
        );

        let user_stake_table = borrow_global_mut<UserStakes>(@KGeNAdmin);
        let user_address = signer::address_of(user);

        validate_harvest_input(user_stake_table, user_address);
        let stake = get_stake(user_stake_table, user_address, stake_id);

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

        let total_rewards_claimed = get_total_claimed_rewards(stake);

        // Calculate the current reward to be harvested
        let current_reward = total_rewards_earned - total_rewards_claimed;

        // Transfer the current reward to the user
        let res_config = borrow_global<Admin>(@KGeNAdmin);
        let resource_signer =
            account::create_signer_with_capability(&res_config.signer_cap);
        rkgen_transfer(&resource_signer, user_address, current_reward);

        event::emit(
            HarvestEvent {
                reward: current_reward,
                timestamp: current_time,
                apy: stake.apy,
                stake_id: stake_id
            }
        );

        // Update the last harvest time to the current time
        update_total_claimed(stake, current_reward);
        update_last_harvest_time(stake, current_time);

    }

    // Claim the rewards for a user from a specific stake.
    public entry fun claim(
        user: &signer, platform: &signer, stake_id: u64
    ) acquires UserStakes, Admin {
        // verify platform
        assert!(
            verify_platform(&signer::address_of(platform)),
            error::invalid_argument(EINVALID_PLATFORM)
        );

        let user_stake_table = borrow_global_mut<UserStakes>(@KGeNAdmin);
        let user_address = signer::address_of(user);

        // Fetch the user's stake details
        let stake = get_stake(user_stake_table, user_address, stake_id);

        // Ensure staking duration has been completed
        let current_time = timestamp::now_seconds();

        assert!(
            current_time >= stake.start_time + (stake.duration * SECONDS_IN_DAY),
            error::invalid_argument(ECLAIM_TOO_SOON)
        );

        // Calculate the total rewards earned
        let total_rewards_earned =
            get_available_rewards(
                stake.start_time,
                stake.apy,
                stake.amount,
                stake.start_time + (stake.duration * SECONDS_IN_DAY)
            );

        let total_rewards_claimed = get_total_claimed_rewards(stake);

        // Calculate the current reward to be harvested
        let current_reward = total_rewards_earned - total_rewards_claimed;

        // Calculate total payout (staked amount + unclaimed rewards)
        let total_payout = stake.amount + current_reward;

        // Transfer the current reward to the user
        let res_config = borrow_global<Admin>(@KGeNAdmin);
        let resource_signer =
            account::create_signer_with_capability(&res_config.signer_cap);
        rkgen_transfer(&resource_signer, user_address, total_payout);

        event::emit(
            ClaimEvent {
                unstake_amount: total_payout,
                timestamp: current_time,
                apy: stake.apy,
                stake_id: stake.stake_id
            }
        );

        // Remove the stake record from the user's stake list
        remove_stake(user_stake_table, user_address, stake_id);

    }

    // =====================================   ADD STAKE  HELPER METHODS =====================================

    // Validates the input parameters.
    inline fun validate_add_stake_input_duration(input_duration: u64) acquires StakingAPYRange {
        assert!(
            duration_exists(input_duration),
            error::not_found(EDURATION_NOT_FOUND)
        );
    }

    // Fetches the appropriate APY range based on the input amount.
    fun get_apy_range(input_amount: u64): APYRange acquires StakingAPYRange {

        let read_apy_table = borrow_global<StakingAPYRange>(@KGeNAdmin);
        let apy_range_row = option::none<APYRange>();
        let found = false;

        smart_table::for_each_ref<u64, APYRange>(
            &read_apy_table.ranges,
            |_key, value| {

                let APYRange { min_amount, max_amount, apy: _, duration: _ } = *value;

                if (input_amount >= min_amount && input_amount <= max_amount) {
                    apy_range_row = option::some<APYRange>(*value);
                    found = true // Mark as found
                };

            }
        );
        assert!(found, error::out_of_range(EAMOUNT_NOT_FOUND_FOR_DURATION));

        option::extract(&mut apy_range_row)
    }

    // Initializes an empty stake.
    fun initialize_stake(): StakeList {
        let initial_stake_id = 1;
        StakeList {
            stake_id: initial_stake_id,
            stake_list: vector::empty<StakeDetails>()
        }
    }

    // Adds a new stake detail to the user's stakes.
    fun add_stake_details(
        stake_list_table: &mut StakeList,
        amount: u64,
        duration: u64,
        apy: u8,
        total_claimed: u64
    ) {
        let current_time = timestamp::now_seconds();

        let stake_id = stake_list_table.stake_id;
        let stake_detail = StakeDetails {
            stake_id: stake_id,
            amount,
            apy,
            duration,
            start_time: current_time,
            last_harvest_time: current_time,
            total_claimed

        };
        vector::push_back(&mut stake_list_table.stake_list, stake_detail);

        event::emit(
            AddStakeEvent { amount: amount, timestamp: current_time, stake_id: stake_id }
        );

        // incrementing stake_id
        stake_list_table.stake_id = stake_list_table.stake_id + 1;

    }

    // =====================================  HARVEST & CLAIM HELPER METHODS =====================================
    //Validate if the user is eligible to harvest rewards (if user exists).
    fun validate_harvest_input(
        user_stake_table: &UserStakes, user_address: address
    ) {
        // check if user exist
        assert!(
            smart_table::contains(&user_stake_table.stakes, user_address),
            error::not_found(EUSER_NOT_FOUND)
        );

    }

    // Retrieve the specific stake for a user based on their stake ID.
    fun get_stake(
        user_stake_table: &mut UserStakes, user_address: address, input_stake_id: u64
    ): &mut StakeDetails {
        // Borrow the user's stake list
        let stake_list =
            &mut smart_table::borrow_mut(&mut user_stake_table.stakes, user_address).stake_list;
        // Use `find` to locate the stake by its ID
        let (found, stake_index) = vector::find<StakeDetails>(
            stake_list,
            |stake_details| {
                let StakeDetails {
                    stake_id,
                    amount: _,
                    apy: _,
                    duration: _,
                    start_time: _,
                    last_harvest_time: _,
                    total_claimed: _

                } = *stake_details;

                stake_id == input_stake_id
            }
        );

        // Ensure the stake exists
        assert!(found, error::not_found(ESTAKE_NOT_EXIST));

        // Return the found stake
        vector::borrow_mut(stake_list, stake_index)
    }

    //Calculate the available rewards for a user based on the stake details and the current time.
    fun get_available_rewards(
        start_time: u64,
        apy: u8,
        amount: u64,
        current_time: u64
    ): u64 {
        let passed_time = current_time - start_time;
        let seconds_in_year = 365 * SECONDS_IN_DAY;

        let amount_u256 = amount as u256;
        let apy_u256 = apy as u256;
        let passed_time_u256 = passed_time as u256;
        let seconds_in_year_u256 = seconds_in_year as u256;
    
         let total_rewards_earned = amount_u256 * apy_u256 * passed_time_u256
            / (seconds_in_year_u256 * 100);

         (total_rewards_earned & 0xFFFFFFFFFFFFFFFF as u64)


    }

    // Get the total rewards that have been claimed by the user for a specific stake.
    fun get_total_claimed_rewards(stake: &mut StakeDetails): u64 {
        stake.total_claimed
    }

    // Update the total rewards claimed by the user for a specific stake.
    fun update_total_claimed(
        stake: &mut StakeDetails, current_reward: u64
    ) {
        let total_claimed = stake.total_claimed;

        let updated_claim = total_claimed + current_reward;
        stake.total_claimed = updated_claim;

    }

    //  Update the last harvest time for a specific stake.
    fun update_last_harvest_time(
        stake: &mut StakeDetails, current_time: u64
    ) {
        stake.last_harvest_time = current_time;
    }

    //remove a stake by the stake ID.
    fun remove_stake(
        user_stake_table: &mut UserStakes, user_address: address, input_stake_id: u64
    ) {
        // Borrow the user's stake list
        let user_stake_records =
            smart_table::borrow_mut(&mut user_stake_table.stakes, user_address);
        let stake_list = &mut user_stake_records.stake_list;

        // Use the `find` inline function to locate the stake by ID
        let (found, stake_index) = vector::find<StakeDetails>(
            stake_list,
            |stake_details| {
                let StakeDetails {
                    stake_id,
                    amount: _,
                    apy: _,
                    duration: _,
                    start_time: _,
                    last_harvest_time: _,
                    total_claimed: _

                } = *stake_details;

                stake_id == input_stake_id
            }
        );

        // Ensure the stake exists
        assert!(found, error::not_found(ESTAKE_NOT_EXIST));

        // Remove the stake from the list
        vector::remove<StakeDetails>(stake_list, stake_index);

    }

    // =====================================  HELPER METHODS =====================================

    // check if platform address exist in verified platfrom list
    inline fun verify_platform(platform: &address): bool acquires Admin {
        let platform_list = &borrow_global<Admin>(@KGeNAdmin).platform_list;
        smart_vector::contains(platform_list, platform)
    }

    // Function to check if any APYRange satisfies the condition

    fun duration_exists(input_duration: u64): bool acquires StakingAPYRange {

        let apy_table = &borrow_global<StakingAPYRange>(@KGeNAdmin).ranges;
        smart_table::any<u64, APYRange>(
            apy_table,
            |_key, value| {

                let APYRange { min_amount: _, max_amount: _, apy: _, duration } = *value;

                duration == input_duration

            }

        )

    }

    // rkgen transfer function
    fun rkgen_transfer(sender: &signer, to: address, amount: u64) {
        let amount_ = amount as u64;
        rKGEN::transfer(sender, to, amount_);
    }

    // =====================================  VIEW METHODS =====================================

    // Get a mapping of all users to their respective stake lists.
    #[view]
    public fun get_all_users_stakes(): simple_map::SimpleMap<address, StakeList> acquires UserStakes {
        let user_stakes = borrow_global<UserStakes>(@KGeNAdmin);
        smart_table::to_simple_map(&user_stakes.stakes)
    }

    //  Get the stake records for a specific user.
    #[view]
    public fun get_user_stake_records(
        user_address: address
    ): vector<StakeDetails> acquires UserStakes {
        let user_stakes_table = borrow_global<UserStakes>(@KGeNAdmin);
        // Access the list of stakes for the user
        let user_stake_records =
            smart_table::borrow(&user_stakes_table.stakes, user_address);
        let stake_list = user_stake_records.stake_list;
        stake_list

    }

    // Get admin
    #[view]
    public fun get_admin(): address acquires Admin {
        borrow_global<Admin>(@KGeNAdmin).admin
    }

    // Get all available staking ranges
    #[view]
    public fun get_staking_ranges(): simple_map::SimpleMap<u64, APYRange> acquires StakingAPYRange {
        let apy_table = borrow_global<StakingAPYRange>(@KGeNAdmin);
        smart_table::to_simple_map(&apy_table.ranges)
    }

    // Get a specific staking range by its ID.
    #[view]
    public fun get_staking_range_by_range_id(range_id: u64): APYRange acquires StakingAPYRange {
        let apy_table = borrow_global<StakingAPYRange>(@KGeNAdmin);

        assert!(
            smart_table::contains(&apy_table.ranges, range_id),
            error::not_found(ERANGE_NOT_FOUND)
        );

        *smart_table::borrow(&apy_table.ranges, range_id)
    }

    //  Get a specific stake of user by its ID.
    #[view]
    public fun get_stake_by_stake_id(
        user_address: address, input_stake_id: u64
    ): StakeDetails acquires UserStakes {
        // Borrow the global UserStakes
        let user_stakes_table = borrow_global<UserStakes>(@KGeNAdmin);
        validate_harvest_input(user_stakes_table, user_address);

        // Access the list of stakes for the user
        let user_stake_records =
            smart_table::borrow(&user_stakes_table.stakes, user_address);
        let stake_list = &user_stake_records.stake_list;

        // Use the `find` inline function to locate the stake by ID
        let (found, stake_index) = vector::find<StakeDetails>(
            stake_list,
            |stake_details| {
                let StakeDetails {
                    stake_id,
                    amount: _,
                    apy: _,
                    duration: _,
                    start_time: _,
                    last_harvest_time: _,
                    total_claimed: _

                } = *stake_details;

                stake_id == input_stake_id
            }
        );

        // Ensure the stake exists
        assert!(found, error::not_found(ESTAKE_NOT_EXIST));

        // Return the found stake details
        *vector::borrow(stake_list, stake_index)
    }

    // Get the resource account address associated with the admin
    #[view]
    public fun get_resource_acc_address(): address acquires Admin {
        borrow_global<Admin>(@KGeNAdmin).res_address
    }

    // Get the list of authorized platforms.
    #[view]
    public fun get_authorised_platforms(): vector<address> acquires Admin {
        let platform = borrow_global<Admin>(@KGeNAdmin);
        smart_vector::to_vector(&platform.platform_list)
    }

    // Get the current reward to harvest
    #[view]
    public fun get_current_reward(user_address: address, stake_id: u64): u64 acquires UserStakes {
        // let user_stake_table = borrow_global_mut<UserStakes>(@KGeNAdmin);
        // let stake = get_stake(user_stake_table, user_address, stake_id);
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
    public fun get_staked_balance(user_address: address): u64 acquires UserStakes {
        let user_stake_table = borrow_global<UserStakes>(@KGeNAdmin);

        let user_stake_records =
            smart_table::borrow(&user_stake_table.stakes, user_address);
        let stake_list = user_stake_records.stake_list;

        let i = 0;
        let total_staked_balance = 0;
        while (i < vector::length(&stake_list)) {
            let stake_details = vector::borrow(&stake_list, i);
            total_staked_balance = stake_details.amount + total_staked_balance;
            i = i + 1;
        };
        total_staked_balance
    }

    // Get claimable reward for a specific stake
    #[view]
    public fun get_total_claimable_reward(
        user_address: address, stake_id: u64
    ): u64 acquires UserStakes {
        let stake = get_stake_by_stake_id(user_address, stake_id);
        let end_time = stake.start_time + (stake.duration * SECONDS_IN_DAY);
        let total_rewards_available =
            get_available_rewards(
                stake.start_time,
                stake.apy,
                stake.amount,
                end_time
            );

        let total_rewards_claimed = stake.total_claimed;

        // Calculate the current reward to be harvested
        let available_reward = total_rewards_available - total_rewards_claimed;

        // Add the initial stake amount to the available rewards

        let total_claimable = available_reward + stake.amount;

        // Return the total claimable amount
        total_claimable
    }
}
