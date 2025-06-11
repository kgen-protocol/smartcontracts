module KGeN::oracle_reward {
    use aptos_framework::account;
    use aptos_framework::fungible_asset::{Metadata};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::object::{Self, Object};
    use aptos_std::fixed_point64;
    use std::signer;
    use aptos_framework::timestamp;
    use std::error;
    use std::vector;
    use std::event;
    use aptos_std::smart_table;
    use aptos_std::simple_map;
    use std::string::{Self, String};
    use KGeN::oracle_keys;
    use KGeNAdmin::rKGeN_staking;

    // Constants for error codes to simplify error handling and debugging
    /// Only Admin can invoke this method
    const ENOT_ADMIN: u64 = 1;
    /// Invalid address provided
    const ENOT_VALID_ADDRESS: u64 = 2;
    /// Sender is not nominated
    const ENO_NOMINATED: u64 = 3;
    /// This already exists
    const EALREADY_EXIST: u64 = 4;
    /// Not exist
    const NOT_EXIST: u64 = 5;
    /// Invalid year provided
    const EINVALID_YEAR: u64 = 6;
    /// Upfront reward is not eligible for now
    const NOT_ELIGIBLE_FOR_UPFRONT: u64 = 7;
    /// Tier does not exist for this value
    const EINVALID_TIER: u64 = 8;
    /// This already exists
    const EALREADY_CLAIMED: u64 = 9;
    /// Cannot claim now
    const ECANNOT_CLAIM_YET: u64 = 10;
    /// Reward is not applicable
    const REWARD_NOT_APPLICABLE: u64 = 11;

    const REWARD_SEED: vector<u8> = b"oracle reward seed";
    const YIELD_DECIMALS: u64 = 10000;
    const SECONDS_PER_DAY: u64 = 86400;
    const OFFSET19700101: u64 = 2440588; // Constant for Unix epoch offset
    const RKGEN_DECIMAL: u64 = 100000000;
    const USDT_DECIMAL: u64 = 1000000;

    struct Tiers has drop, store, copy {
        min_keys: u64,
        max_keys: u64,
        stablecoin_yield: u64,
        bonus_rKGeN_yield: u64,
        rKGeN_per_key: u64
    }

    // oracle nodes reward-related data
    struct Oracles_info has drop, store {
        reward_wallet: address,
        is_upfront_released: bool,
        registration_date: u64,
        is_stablecoin_applied: bool,
        is_reward_applicable: bool,
        last_rewarded_time: u64,
        stablecoin_rewarded: u64,
        rKGeN_bonus_rewarded: u64,
        rKGeN_rewarded: u64,
        total_rKGeN_held: u64
    }

    struct YearMonth has drop, copy, store {
        reward_year: u64,
        reward_month: u64
    }

    struct AdminStore has key {
        resource_account: address,
        resource_account_cap: account::SignerCapability,
        custom_time: u64,
        is_auto: bool
    }

    struct RewardConfig has key {
        key_price: u64,
        days_for_upfront: u64,
        stablecoin_metadata: address,
        rKGeN_metadata: address
    }

    struct TiersTable has key {
        tiers: smart_table::SmartTable<u64, Tiers>
    }

    struct OracleStore has key {
        records: smart_table::SmartTable<address, Oracles_info>
    }

    // Event emitted when the admin role is updated
    #[event]
    struct AddedOracle has drop, store {
        oracle_primary_wallet: address,
        reward_wallet: address
    }

    #[event]
    struct RemovedOracleRewardWallet has drop, store {
        oracle_primary_wallet: address
    }

    #[event]
    struct UpdateOraclePrimaryWallet has drop, store {
        oracle_primary_wallet: address,
        new_oracle_primary_wallet: address
    }

    #[event]
    struct UpdatedOracleRewardWallet has drop, store {
        oracle_primary_wallet: address,
        new_reward_wallet: address
    }

    #[event]
    struct ManualTimeUpdated has drop, store {
        new_custom_time: u64
    }

    #[event]
    struct CustomTimestampToggled has drop, store {
        is_auto: bool
    }

    #[event]
    struct TiersTableAdded has drop, store {
        update_time: u64
    }

    #[event]
    struct UpfrontTransfer has drop, store {
        oracle: address,
        reward_wallet: address,
        rewards: u64,
        release_time: u64
    }

    #[event]
    struct ClaimReward has drop, store {
        oracle: address,
        reward_wallet: address,
        stable_coins: u64,
        rKGeN_reward: u64,
        rKGeN_bonus_reward: u64,
        claim_time: u64
    }

    #[view]
    public fun is_reward_applicable(oracle_primary_wallet: address): bool acquires OracleStore {
        let oracles_info = get_oracle_info(oracle_primary_wallet);
        oracles_info.is_reward_applicable
    }

    #[view]
    public fun get_oracle_info(oracle_primary_wallet: address): Oracles_info acquires OracleStore {
        let admin_struct = borrow_global<OracleStore>(@KGeN);
        if (!smart_table::contains(&admin_struct.records, oracle_primary_wallet)) {
            Oracles_info {
                reward_wallet: @0x0,
                is_upfront_released: false,
                registration_date: 0,
                is_stablecoin_applied: false,
                is_reward_applicable: false,
                last_rewarded_time: 0,
                stablecoin_rewarded: 0,
                rKGeN_bonus_rewarded: 0,
                rKGeN_rewarded: 0,
                total_rKGeN_held: 0
            }
        } else {
            let oi = smart_table::borrow(&admin_struct.records, oracle_primary_wallet);

            Oracles_info {
                reward_wallet: oi.reward_wallet,
                is_upfront_released: oi.is_upfront_released,
                registration_date: oi.registration_date,
                is_stablecoin_applied: oi.is_stablecoin_applied,
                is_reward_applicable: oi.is_reward_applicable,
                last_rewarded_time: oi.last_rewarded_time,
                stablecoin_rewarded: oi.stablecoin_rewarded,
                rKGeN_bonus_rewarded: oi.rKGeN_bonus_rewarded,
                rKGeN_rewarded: oi.rKGeN_rewarded,
                total_rKGeN_held: oi.total_rKGeN_held
            }
        }
    }

    #[view]
    public fun get_claimable_rewards(
        oracle_primary_wallet: address
    ): simple_map::SimpleMap<String, u64> acquires AdminStore, TiersTable, OracleStore, RewardConfig {
        let oracles_info = get_oracle_info(oracle_primary_wallet);
        let rewards = simple_map::new<String, u64>();
        if (!oracles_info.is_reward_applicable) {
            simple_map::add(&mut rewards, string::utf8(b"stablecoin_claimable"), 0);
            simple_map::add(&mut rewards, string::utf8(b"rKGeN_claimable"), 0);
            simple_map::add(&mut rewards, string::utf8(b"rKGeN_bonus_claimable"), 0);
            return rewards
        };
        let current_timestamp = timestamp::now_seconds();
        if (is_manual_time_applicable()) {
            current_timestamp = get_manual_time();
        };
        let (curr_year, curr_month, curr_day) = timestamp_to_date(current_timestamp);

        let (last_year, last_month, last_day) =
            timestamp_to_date(oracles_info.last_rewarded_time);

        // Ensure user can claim only on or after the last day of the month

        // let reward_months = vector[];  // Track months for which rewards will be distribut
        let reward_months = vector::empty<YearMonth>(); // Track months for which rewards will be distribut
        let reward_year = last_year;
        let reward_month = last_month;

        // Iterate through months that were missed
        while (can_claim(
            curr_year,
            curr_month,
            curr_day,
            reward_year,
            reward_month,
            last_day
        )) {
            vector::push_back(&mut reward_months, YearMonth { reward_year, reward_month });

            // Move to the next month
            if (reward_month == 12) {
                reward_month = 1;
                reward_year = reward_year + 1;
            } else {
                reward_month = reward_month + 1;
            }
        };
        let meta = borrow_global<RewardConfig>(@KGeN);

        let rKGeN_meta = get_metadata_object(meta.rKGeN_metadata);
        let total_rK_coins = 0;
        let total_rKb_coins = 0;
        let total_stable_coins = 0;

        // let key_balance = 300;
        let key_balance = oracle_keys::get_balance(oracle_primary_wallet);
        let (sy, by, ry) = get_reward_yield(key_balance);

        let first_claim = oracles_info.registration_date
            == oracles_info.last_rewarded_time;

        let i = 0;
        let len = vector::length(&reward_months);
        if (!oracles_info.is_upfront_released
            && days_from_registration(oracles_info.registration_date)
                >= meta.days_for_upfront) {
            let reward = (ry * 10) / 100;
            total_rK_coins = total_rK_coins + (reward * key_balance);
        };

        while (i < len) {

            let YearMonth { reward_year, reward_month } =
                *vector::borrow(&reward_months, i);
            let (reg_year, reg_month, reg_day) =
                timestamp_to_date(oracles_info.registration_date);
            let total_days = get_days_in_month(reward_year, reward_month);
            let active_days = total_days;
            let rKGeN_applied = true;

            // First-time claim condition
            if (first_claim
                && reward_year == reg_year
                && reward_month == reg_month) {
                active_days = total_days - reg_day + 1;
                if (days_from_registration(oracles_info.registration_date)
                    < total_days / 2) {
                    rKGeN_applied = false;
                };
            };

            let rKGeN_remaining =
                primary_fungible_store::balance(oracles_info.reward_wallet, rKGeN_meta);
            let total_rKGeN = oracles_info.total_rKGeN_held;
            if (total_rKGeN < rKGeN_remaining) {
                total_rKGeN = rKGeN_remaining;
            };

            let stable_coins = 0;
            let rK_coins = 0;
            let rKb_coins = 0;

            if (oracles_info.is_stablecoin_applied) {
                stable_coins = calculate_stablecoin(
                    meta.key_price,
                    key_balance,
                    sy,
                    active_days,
                    total_days,
                    rKGeN_remaining,
                    total_rKGeN
                );
            };

            if (by > 0 && rKGeN_applied) {
                rKb_coins = calculate_bonus_reward(
                    by,
                    ry,
                    key_balance,
                    rKGeN_remaining,
                    total_rKGeN
                );
            };

            if (rKGeN_applied) {
                rK_coins = calculate_rKGeN_reward(ry, key_balance);
            };

            total_rK_coins = total_rK_coins + rK_coins;
            total_rKb_coins = total_rKb_coins + rKb_coins;
            total_stable_coins = total_stable_coins + stable_coins;

            // Mark first claim as done after processing the first month
            first_claim = false;
            i = i + 1
        };
        simple_map::add(
            &mut rewards, string::utf8(b"stablecoin_claimable"), total_stable_coins
        );
        simple_map::add(&mut rewards, string::utf8(b"rKGeN_claimable"), total_rK_coins);
        simple_map::add(
            &mut rewards, string::utf8(b"rKGeN_bonus_claimable"), total_rKb_coins
        );
        rewards
    }

    #[view]
    public fun get_key_price(): u64 acquires RewardConfig {
        borrow_global<RewardConfig>(@KGeN).key_price
    }

    #[view]
    public fun get_days_for_upfront_release(): u64 acquires RewardConfig {
        borrow_global<RewardConfig>(@KGeN).days_for_upfront
    }

    #[view]
    public fun get_stablecoin_metadata(): address acquires RewardConfig {
        borrow_global<RewardConfig>(@KGeN).stablecoin_metadata
    }

    #[view]
    public fun get_rKGeN_metadata(): address acquires RewardConfig {
        borrow_global<RewardConfig>(@KGeN).rKGeN_metadata
    }

    #[view]
    public fun get_tier_table(): simple_map::SimpleMap<u64, Tiers> acquires TiersTable {
        let admin_struct = borrow_global<TiersTable>(@KGeN);
        smart_table::to_simple_map(&admin_struct.tiers)
    }

    #[view]
    public fun get_resource_account(): address acquires AdminStore {
        let admin_struct = borrow_global<AdminStore>(@KGeN);
        admin_struct.resource_account
    }

    #[view]
    public fun is_manual_time_applicable(): bool acquires AdminStore {
        let admin_struct = borrow_global<AdminStore>(@KGeN);
        !admin_struct.is_auto
    }

    #[view]
    public fun get_manual_time(): u64 acquires AdminStore {
        let admin_struct = borrow_global<AdminStore>(@KGeN);
        admin_struct.custom_time
    }

    // Date Time Calculations
    #[view]
    public fun timestamp_to_date(timestamp: u64): (u64, u64, u64) {
        let days_i64 = timestamp / SECONDS_PER_DAY;

        let l = days_i64 + 68569 + (OFFSET19700101);

        let n = 4 * l / 146097;
        l = l - (146097 * n + 3) / 4;

        let year_i64 = 4000 * (l + 1) / 1461001;

        l = l - 1461 * year_i64 / 4 + 31;
        let month_i64 = 80 * l / 2447;
        let day_i64 = l - 2447 * month_i64 / 80;
        l = month_i64 / 11;
        month_i64 = month_i64 + 2 - 12 * l;
        year_i64 = 100 * (n - 49) + year_i64 + l;

        // Convert back to u64
        ((year_i64), (month_i64), (day_i64))
    }

    #[view]
    // Function to get days in a month
    public fun get_days_in_month(year: u64, month: u64): u64 {
        if (month == 1
            || month == 3
            || month == 5
            || month == 7
            || month == 8
            || month == 10
            || month == 12) { 31 }
        else if (month != 2) { 30 }
        else {
            if (is_leap_year(year)) 29
            else 28
        }
    }

    #[view]
    // Function to check if a year is a leap year
    public fun is_leap_year(year: u64): bool {
        ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0)
    }

    #[view]
    public fun days_from_registration(registration_date: u64): u64 acquires AdminStore {
        let current_timestamp = timestamp::now_seconds();
        if (is_manual_time_applicable()) {
            current_timestamp = get_manual_time();
        };
        if (registration_date >= current_timestamp) { 0 }
        else {
            (current_timestamp - registration_date) / SECONDS_PER_DAY
        }
    }

    inline fun assert_oracle_exist(oracle: &address) {
        let o = borrow_global<OracleStore>(@KGeN);
        assert!(
            smart_table::contains(&o.records, *oracle),
            error::unauthenticated(NOT_EXIST)
        );
    }

    // To get signer sign e.g. module is a signer now for the bucket core
    inline fun get_resource_account_sign(): signer acquires AdminStore {
        account::create_signer_with_capability(
            &borrow_global<AdminStore>(@KGeN).resource_account_cap
        )
    }

    inline fun get_metadata_object(object: address): Object<Metadata> {
        object::address_to_object<Metadata>(object)
    }

    inline fun get_reward_yield(keys_amount: u64): (u64, u64, u64) acquires TiersTable {
        let t = borrow_global<TiersTable>(@KGeN);
        let (r1, r2, r3) = (0, 0, 0);
        smart_table::for_each_ref<u64, Tiers>(
            &t.tiers,
            |_key, value| {

                let Tiers {
                    min_keys,
                    max_keys,
                    stablecoin_yield,
                    bonus_rKGeN_yield,
                    rKGeN_per_key
                } = *value;

                if (keys_amount >= min_keys && keys_amount < max_keys) {
                    (r1, r2, r3) = (stablecoin_yield, bonus_rKGeN_yield, rKGeN_per_key);
                }
            }
        );
        (r1, r2, r3)
    }

    // Determines if an oracle can claim rewards based on date comparisons
    inline fun can_claim(
        cy: u64, // current_year
        cm: u64, // current_month
        cd: u64, // current_day
        ly: u64, // last_year (of reward)
        lm: u64, // last_month (of reward)
        ld: u64 // last_day (of reward)
    ): bool {
        // Calculate the last day of the current month
        let last_day_of_current_month = get_days_in_month(cy, cm);
        let res = false;

        // Case 1: Different year (e.g., 2023 - 2024)
        if (cy > ly) {
            res = true;
        };

        // Case 2: Same year but later month (e.g., Jan - Feb)
        if (cy == ly && cm > lm) {
            res = true;
        };

        // Case 3: Same year and month, but it's the last day of month
        // and wasn't the last day before
        if (cy == ly
            && cm == lm
            && cd == last_day_of_current_month
            && ld != last_day_of_current_month) {
            res = true;
        };

        // If none of the conditions are met, user cannot claim yet
        res
    }

    // :!:>initialize
    fun init_module(admin: &signer) {
        let (resource_account, resource_account_cap) =
            account::create_resource_account(admin, REWARD_SEED);
        // Default Tiers
        let t_vec = vector::empty<Tiers>();
        let i_vec = vector::empty<u64>();
        vector::push_back(&mut i_vec, 1);
        vector::push_back(&mut i_vec, 2);
        vector::push_back(&mut i_vec, 3);
        vector::push_back(&mut i_vec, 4);
        vector::push_back(
            &mut t_vec,
            Tiers {
                min_keys: 200,
                max_keys: 500,
                stablecoin_yield: 25000,
                bonus_rKGeN_yield: 0,
                rKGeN_per_key: 1500
            }
        );
        vector::push_back(
            &mut t_vec,
            Tiers {
                min_keys: 500,
                max_keys: 1000,
                stablecoin_yield: 35000,
                bonus_rKGeN_yield: 50000,
                rKGeN_per_key: 1500
            }
        );
        vector::push_back(
            &mut t_vec,
            Tiers {
                min_keys: 1000,
                max_keys: 2000,
                stablecoin_yield: 40000,
                bonus_rKGeN_yield: 75000,
                rKGeN_per_key: 1500
            }
        );
        vector::push_back(
            &mut t_vec,
            Tiers {
                min_keys: 2000,
                max_keys: 4000,
                stablecoin_yield: 45000,
                bonus_rKGeN_yield: 100000,
                rKGeN_per_key: 1500
            }
        );

        let tiers = smart_table::new<u64, Tiers>();
        smart_table::add_all(&mut tiers, i_vec, t_vec);

        let records = smart_table::new<address, Oracles_info>();
        move_to(
            admin,
            AdminStore {
                resource_account: signer::address_of(&resource_account),
                resource_account_cap,
                custom_time: timestamp::now_seconds(),
                is_auto: true
            }
        );

        move_to(
            admin,
            RewardConfig {
                key_price: 500,
                days_for_upfront: 30,
                stablecoin_metadata:
                    @0x357b0b74bc833e95a115ad22604854d6b0fca151cecd94111770e5d6ffc9dc2b,
                rKGeN_metadata:
                    @0x726ccb3c1ac023b3b24f9f2fc4c07b16f6e26f21b978651fde271767e0b641c4
            }
        );

        move_to(admin, TiersTable { tiers });

        move_to(admin, OracleStore { records });
    } // <:!:initialize

    // ----------------------- Admin Updation -----------------------------

    package fun remove_primary_wallet(oracle_primary_wallet: address) acquires OracleStore {
        let admin_struct = borrow_global_mut<OracleStore>(@KGeN);
        assert!(
            smart_table::contains(&admin_struct.records, oracle_primary_wallet),
            error::unauthenticated(NOT_EXIST)
        );
        smart_table::remove(&mut admin_struct.records, oracle_primary_wallet);
        event::emit(RemovedOracleRewardWallet { oracle_primary_wallet });
    }

    package fun update_reward_wallet(
        oracle_primary_wallet: address, new_reward_wallet: address
    ) acquires OracleStore {
        let admin_struct = borrow_global_mut<OracleStore>(@KGeN);
        assert!(
            smart_table::contains(&admin_struct.records, oracle_primary_wallet),
            error::unauthenticated(NOT_EXIST)
        );
        let val = smart_table::borrow_mut(
            &mut admin_struct.records, oracle_primary_wallet
        );
        val.reward_wallet = new_reward_wallet;
        event::emit(
            UpdatedOracleRewardWallet { oracle_primary_wallet, new_reward_wallet }
        );
    }

    package fun update_oracle_primary_wallet(
        oracle_primary_wallet: address, new_oracle_primary_wallet: address
    ) acquires OracleStore {
        let admin_struct = borrow_global_mut<OracleStore>(@KGeN);
        assert!(
            smart_table::contains(&admin_struct.records, oracle_primary_wallet),
            error::unauthenticated(NOT_EXIST)
        );
        let val = smart_table::remove(&mut admin_struct.records, oracle_primary_wallet);
        smart_table::add(&mut admin_struct.records, new_oracle_primary_wallet, val);
        event::emit(
            UpdateOraclePrimaryWallet { oracle_primary_wallet, new_oracle_primary_wallet }
        );
    }

    package fun add_reward_wallet(
        oracle_primary_wallet: address,
        reward_wallet: address,
        is_stablecoin_applied: bool,
        is_reward_applicable: bool
    ) acquires OracleStore, AdminStore {
        let admin_struct = borrow_global_mut<OracleStore>(@KGeN);
        let current_time = timestamp::now_seconds();
        if (is_manual_time_applicable()) {
            current_time = get_manual_time();
        };
        let oracle_info = Oracles_info {
            reward_wallet,
            is_upfront_released: false,
            registration_date: current_time,
            is_stablecoin_applied,
            is_reward_applicable,
            last_rewarded_time: current_time,
            stablecoin_rewarded: 0,
            rKGeN_bonus_rewarded: 0,
            rKGeN_rewarded: 0,
            total_rKGeN_held: 0
        };

        smart_table::add(&mut admin_struct.records, oracle_primary_wallet, oracle_info);
        event::emit(AddedOracle { oracle_primary_wallet, reward_wallet: reward_wallet });
    }

    package fun add_new_tier(
        min_keys: vector<u64>,
        max_keys: vector<u64>,
        stablecoin_yield: vector<u64>,
        bonus_rKGeN_yield: vector<u64>,
        rKGeN_per_key: vector<u64>
    ) acquires TiersTable {
        let l = vector::length(&min_keys);
        assert!(
            l == vector::length(&max_keys)
                && l == vector::length(&rKGeN_per_key)
                && vector::length(&stablecoin_yield)
                    == vector::length(&bonus_rKGeN_yield)
                && l == vector::length(&bonus_rKGeN_yield),
            error::permission_denied(ENOT_ADMIN)
        );

        let admin_struct = borrow_global_mut<TiersTable>(@KGeN);

        for (i in 0..l) {
            let t = Tiers {
                min_keys: *vector::borrow(&min_keys, i),
                max_keys: *vector::borrow(&max_keys, i),
                stablecoin_yield: *vector::borrow(&stablecoin_yield, i),
                bonus_rKGeN_yield: *vector::borrow(&bonus_rKGeN_yield, i),
                rKGeN_per_key: *vector::borrow(&rKGeN_per_key, i)
            };
            smart_table::upsert(&mut admin_struct.tiers, i + 1, t);
        };

        event::emit(TiersTableAdded { update_time: timestamp::now_seconds() });
    }

    package fun manage_key_price(new_key_price: u64) acquires RewardConfig {
        let admin_struct = borrow_global_mut<RewardConfig>(@KGeN);
        assert!(
            admin_struct.key_price != new_key_price,
            error::unauthenticated(EALREADY_EXIST)
        );
        admin_struct.key_price = new_key_price;
    }

    package fun set_manual_timestamp(new_custom_time: u64) acquires AdminStore {
        let admin_struct = borrow_global_mut<AdminStore>(@KGeN);
        admin_struct.custom_time = new_custom_time;
        event::emit(ManualTimeUpdated { new_custom_time });
    }

    package fun toggle_custom_time(state: bool) acquires AdminStore {
        let admin_struct = borrow_global_mut<AdminStore>(@KGeN);
        admin_struct.is_auto = state;
        event::emit(CustomTimestampToggled { is_auto: state });
    }

    package fun manage_days_for_upfront(new_days_for_upfront: u64) acquires RewardConfig {
        let admin_struct = borrow_global_mut<RewardConfig>(@KGeN);
        assert!(
            admin_struct.days_for_upfront != new_days_for_upfront,
            error::unauthenticated(EALREADY_EXIST)
        );
        admin_struct.days_for_upfront = new_days_for_upfront;
    }

    package fun manage_stablecoin_metadata(
        new_stablecoin_metadata: address
    ) acquires RewardConfig {
        let admin_struct = borrow_global_mut<RewardConfig>(@KGeN);
        assert!(
            admin_struct.stablecoin_metadata != new_stablecoin_metadata,
            error::unauthenticated(EALREADY_EXIST)
        );
        admin_struct.stablecoin_metadata = new_stablecoin_metadata;
    }

    package fun manage_rKGeN_metadata(new_rKGeN_metadata: address) acquires RewardConfig {
        let admin_struct = borrow_global_mut<RewardConfig>(@KGeN);
        assert!(
            admin_struct.rKGeN_metadata != new_rKGeN_metadata,
            error::unauthenticated(EALREADY_EXIST)
        );
        admin_struct.rKGeN_metadata = new_rKGeN_metadata;
    }

    package fun transfer_upfront_rKGeN(
        oracle_primary_wallet: &signer
    ) acquires AdminStore, TiersTable, OracleStore, RewardConfig {
        let rec = borrow_global_mut<OracleStore>(@KGeN);
        let meta = borrow_global<RewardConfig>(@KGeN);
        assert!(
            smart_table::contains(
                &rec.records, signer::address_of(oracle_primary_wallet)
            ),
            error::unauthenticated(NOT_EXIST)
        );
        let oracles_info =
            smart_table::borrow_mut(
                &mut rec.records, signer::address_of(oracle_primary_wallet)
            );
        assert!(
            oracles_info.is_reward_applicable,
            error::unauthenticated(REWARD_NOT_APPLICABLE)
        );

        // Check upfront time_period is over or not.
        assert!(
            !oracles_info.is_upfront_released,
            error::permission_denied(NOT_ELIGIBLE_FOR_UPFRONT)
        );
        let d = days_from_registration(oracles_info.registration_date);
        assert!(
            d >= meta.days_for_upfront,
            error::permission_denied(NOT_ELIGIBLE_FOR_UPFRONT)
        );
        let key_balance =
            oracle_keys::get_balance(signer::address_of(oracle_primary_wallet));
        let (_, _, reward) = get_reward_yield(key_balance);
        reward = (reward * 10) / 100;

        oracles_info.rKGeN_rewarded =
            oracles_info.rKGeN_rewarded + reward * key_balance * RKGEN_DECIMAL;
        oracles_info.total_rKGeN_held = reward * key_balance * RKGEN_DECIMAL;
        oracles_info.is_upfront_released = true;

        transfer_rewards_from_resource(
            oracles_info.reward_wallet,
            meta.rKGeN_metadata,
            reward * key_balance * RKGEN_DECIMAL
        );

        event::emit(
            UpfrontTransfer {
                oracle: signer::address_of(oracle_primary_wallet),
                reward_wallet: oracles_info.reward_wallet,
                rewards: reward * key_balance,
                release_time: timestamp::now_seconds()
            }
        );

    }

    // PRIVATE FUNCTION TO TRANSFER TOKENS
    package fun transfer_rewards_from_resource(
        wallet: address, metadata: address, amount: u64
    ) acquires AdminStore {
        primary_fungible_store::transfer(
            &get_resource_account_sign(),
            get_metadata_object(metadata),
            wallet,
            amount
        );
    }

    package fun claim_oracle_reward(
        oracle_primary_wallet: &signer
    ) acquires AdminStore, TiersTable, OracleStore, RewardConfig {
        let rec = borrow_global_mut<OracleStore>(@KGeN);
        assert!(
            smart_table::contains(
                &rec.records, signer::address_of(oracle_primary_wallet)
            ),
            error::unauthenticated(NOT_EXIST)
        );

        let meta = borrow_global<RewardConfig>(@KGeN);
        let oracles_info =
            smart_table::borrow_mut(
                &mut rec.records, signer::address_of(oracle_primary_wallet)
            );

        assert!(
            oracles_info.is_reward_applicable,
            error::unauthenticated(REWARD_NOT_APPLICABLE)
        );

        let current_timestamp = timestamp::now_seconds();
        if (is_manual_time_applicable()) {
            current_timestamp = get_manual_time();
        };

        let (curr_year, curr_month, curr_day) = timestamp_to_date(current_timestamp);

        let (last_year, last_month, last_day) =
            timestamp_to_date(oracles_info.last_rewarded_time);

        // Ensure user can claim only on or after the last day of the month
        // let last_day_of_prev_month = get_last_day_of_month(last_year, last_month);
        assert!(
            can_claim(
                curr_year,
                curr_month,
                curr_day,
                last_year,
                last_month,
                last_day
            ),
            error::invalid_argument(ECANNOT_CLAIM_YET)
        );

        // let reward_months = vector[];  // Track months for which rewards will be distribut
        let reward_months = vector::empty<YearMonth>(); // Track months for which rewards will be distribut
        let reward_year = last_year;
        let reward_month = last_month;

        // Iterate through months that were missed
        while (can_claim(
            curr_year,
            curr_month,
            curr_day,
            reward_year,
            reward_month,
            last_day
        )) {
            vector::push_back(&mut reward_months, YearMonth { reward_year, reward_month });

            // Move to the next month
            if (reward_month == 12) {
                reward_month = 1;
                reward_year = reward_year + 1;
            } else {
                reward_month = reward_month + 1;
            }
        };

        let rKGeN_meta = get_metadata_object(meta.rKGeN_metadata);
        let total_rK_coins = 0;
        let total_rKb_coins = 0;
        let total_stable_coins = 0;

        let key_balance =
            oracle_keys::get_balance(signer::address_of(oracle_primary_wallet));
        let (sy, by, ry) = get_reward_yield(key_balance);

        let first_claim = oracles_info.registration_date
            == oracles_info.last_rewarded_time;

        let i = 0;
        let len = vector::length(&reward_months);
        if (!oracles_info.is_upfront_released
            && days_from_registration(oracles_info.registration_date)
                >= meta.days_for_upfront) {
            let reward = (ry * 10) / 100;
            oracles_info.rKGeN_rewarded =
                oracles_info.rKGeN_rewarded + reward * key_balance * RKGEN_DECIMAL;
            oracles_info.total_rKGeN_held = reward * key_balance * RKGEN_DECIMAL;
            oracles_info.is_upfront_released = true;

            transfer_rewards_from_resource(
                oracles_info.reward_wallet,
                meta.rKGeN_metadata,
                reward * key_balance * RKGEN_DECIMAL
            );

            event::emit(
                UpfrontTransfer {
                    oracle: signer::address_of(oracle_primary_wallet),
                    reward_wallet: oracles_info.reward_wallet,
                    rewards: reward * key_balance,
                    release_time: timestamp::now_seconds()
                }
            );
        };

        while (i < len) {

            let YearMonth { reward_year, reward_month } =
                *vector::borrow(&reward_months, i);
            let (reg_year, reg_month, reg_day) =
                timestamp_to_date(oracles_info.registration_date);
            let total_days = get_days_in_month(reward_year, reward_month);
            let active_days = total_days;
            let rKGeN_applied = true;

            // First-time claim condition
            if (first_claim
                && reward_year == reg_year
                && reward_month == reg_month) {
                active_days = total_days - reg_day + 1;
                if (days_from_registration(oracles_info.registration_date)
                    < total_days / 2) {
                    rKGeN_applied = false;
                };
            };

            let rKGeN_remaining =
                primary_fungible_store::balance(oracles_info.reward_wallet, rKGeN_meta);
            rKGeN_remaining =
                rKGeN_remaining
                    + rKGeN_staking::get_staked_balance(oracles_info.reward_wallet);
            let total_rKGeN = oracles_info.total_rKGeN_held;
            if (total_rKGeN < rKGeN_remaining) {
                total_rKGeN = rKGeN_remaining;
                oracles_info.total_rKGeN_held = rKGeN_remaining;
            };

            let stable_coins = 0;
            let rK_coins = 0;
            let rKb_coins = 0;

            if (oracles_info.is_stablecoin_applied) {
                stable_coins = calculate_stablecoin(
                    meta.key_price,
                    key_balance,
                    sy,
                    active_days,
                    total_days,
                    rKGeN_remaining,
                    total_rKGeN
                );
            };

            if (by > 0 && rKGeN_applied) {
                rKb_coins = calculate_bonus_reward(
                    by,
                    ry,
                    key_balance,
                    rKGeN_remaining,
                    total_rKGeN
                );
            };

            if (rKGeN_applied) {
                rK_coins = calculate_rKGeN_reward(ry, key_balance);
            };

            total_rK_coins = total_rK_coins + rK_coins;
            total_rKb_coins = total_rKb_coins + rKb_coins;
            total_stable_coins = total_stable_coins + stable_coins;

            // Mark first claim as done after processing the first month
            first_claim = false;
            i = i + 1
        };

        // Transfer rewards
        if (oracles_info.is_stablecoin_applied) {
            oracles_info.last_rewarded_time = current_timestamp;
            // Update reward tracking
            oracles_info.stablecoin_rewarded =
                oracles_info.stablecoin_rewarded + total_stable_coins * USDT_DECIMAL;
            transfer_rewards_from_resource(
                oracles_info.reward_wallet,
                meta.stablecoin_metadata,
                total_stable_coins * USDT_DECIMAL
            );
        };

        if (total_rK_coins > 0 || total_rKb_coins > 0) {
            oracles_info.last_rewarded_time = current_timestamp;
            let amt = total_rK_coins + total_rKb_coins;
            oracles_info.rKGeN_rewarded =
                oracles_info.rKGeN_rewarded + total_rK_coins * RKGEN_DECIMAL;
            oracles_info.rKGeN_bonus_rewarded =
                oracles_info.rKGeN_bonus_rewarded + total_rKb_coins * RKGEN_DECIMAL;
            oracles_info.total_rKGeN_held =
                oracles_info.total_rKGeN_held + amt * RKGEN_DECIMAL;
            transfer_rewards_from_resource(
                oracles_info.reward_wallet,
                meta.rKGeN_metadata,
                amt * RKGEN_DECIMAL
            );
        };

        // Emit event
        event::emit(
            ClaimReward {
                oracle: signer::address_of(oracle_primary_wallet),
                reward_wallet: oracles_info.reward_wallet,
                stable_coins: total_stable_coins,
                rKGeN_reward: total_rK_coins,
                rKGeN_bonus_reward: total_rKb_coins,
                claim_time: current_timestamp
            }
        );
    }

    // -------------------- Functions involved in reward calculations ------------------------
    // Calculates stablecoin yield based on multiple parameters
    //
    // # Parameters
    // * `price_of_one_key`: Market price of a single key
    // * `keys`: Number of keys held
    // * `stablecoin_yield`: Annual stablecoin yield percentage (e.g., 120 for 12%)
    // * `active_days`: Number of days the keys were actively held in the current period
    // * `total_days`: Total days in the current period (typically month)
    // * `rKGeN_remaining`: Remaining rKGEN tokens
    // * `rKGEN_sent`: Total rKGEN tokens sent
    //
    // # Returns
    // Calculated stablecoin yield amount
    //
    // # Formula
    // stable_coins = ((no_of_keys * price_of_one_key) * (stablecoin_yield / 12))
    //                * (active_days / total_days_in_month)
    //                * (rKGeN_remaining / rKGEN_sent)
    #[view]
    public fun calculate_stablecoin(
        price_of_one_key: u64,
        keys: u64,
        stablecoin_yield: u64,
        active_days: u64,
        total_days: u64,
        rKGeN_remaining: u64,
        rKGEN_sent: u64
    ): u64 {
        // Convert annual yield to monthly yield (divide by 1200 to get percentage)
        let m_yield = fixed_point64::create_from_rational(stablecoin_yield as u128, 1200);

        // Calculate the ratio of active days to total days in the period
        let active_ratio =
            fixed_point64::create_from_rational(active_days as u128, total_days as u128);

        if (rKGEN_sent == 0) {
            rKGEN_sent = 1;
            rKGeN_remaining = 1;
        };

        // Calculate the ratio of remaining rKGEN to sent rKGEN
        let rKGeN_ratio =
            fixed_point64::create_from_rational(
                rKGeN_remaining as u128, rKGEN_sent as u128
            );

        // Calculate total value of keys
        let m = keys * price_of_one_key;

        // Multiply by monthly yield
        let res = fixed_point64::multiply_u128(m as u128, m_yield);

        // Adjust by active days ratio
        res = fixed_point64::multiply_u128(res as u128, active_ratio);

        // Adjust by rKGEN ratio
        res = fixed_point64::multiply_u128(res as u128, rKGeN_ratio);

        // Convert to u64, remove decimal precision, and divide by 10000 to get final result
        (res & 0xFFFFFFFFFFFFFFFF as u64) / 10000
    }

    // Calculates the rKGeN yield for a given number of keys
    //
    // # Parameters
    // * `rKGeN_per_key`: Amount of rKGeN yield per key
    // * `keys`: Number of keys held
    //
    // # Returns
    // Calculated rKGeN yield amount
    //
    // # Calculation
    // - Applies 90% monthly yield (900000/3600 = 90%)
    // - Multiplies rKGeN per key by applied yield percentage
    // - Multiplies by total number of keys
    // - Converts to appropriate decimal precision
    #[view]
    public fun calculate_rKGeN_reward(rKGeN_per_key: u64, keys: u64): u64 {
        // Create a fixed-point representation of 90% monthly yield
        // 900000/3600 = 250 (90%)
        let applied_amount = fixed_point64::create_from_rational(900000, 3600);

        // Multiply rKGeN per key by the applied yield
        let r = fixed_point64::multiply_u128(rKGeN_per_key as u128, applied_amount);

        // Multiply by total number of keys
        r = r * (keys as u128);

        // Convert to u64 and adjust decimal precision
        let res = (r & 0xFFFFFFFFFFFFFFFF as u64);
        res / 10000
    }

    // Calculates the bonus rKGeN yield for a given number of keys
    //
    // # Parameters
    // * `bonus_rKGeN_yield`: Bonus yield percentage
    // * `rKGeN_per_key`: Amount of rKGeN per key
    // * `keys`: Number of keys held
    // * `rKGeN_remaining`: Remaining rKGEN tokens
    // * `rKGEN_sent`: Total rKGEN tokens sent
    //
    // # Returns
    // Calculated bonus rKGeN yield amount
    //
    // # Calculation
    // - Converts rKGeN per key to monthly yield
    // - Calculates ratio of remaining to sent rKGEN
    // - Applies bonus percentage
    // - Adjusts yield by rKGEN ratio
    // - Multiplies by number of keys
    #[view]
    public fun calculate_bonus_reward(
        bonus_rKGeN_yield: u64,
        rKGeN_per_key: u64,
        keys: u64,
        rKGeN_remaining: u64,
        rKGEN_sent: u64
    ): u64 {
        // Convert rKGeN per key to monthly yield
        // Divide by 36 to get monthly rate
        let r_month = fixed_point64::create_from_rational(rKGeN_per_key as u128, 36);
        if (rKGEN_sent == 0) {
            rKGEN_sent = 1;
            rKGeN_remaining = 1;
        };

        // Calculate the ratio of remaining rKGEN to sent rKGEN
        let rKGeN_ratio =
            fixed_point64::create_from_rational(
                rKGeN_remaining as u128, rKGEN_sent as u128
            );

        // Convert bonus yield to decimal (divide by 100)
        let b = bonus_rKGeN_yield / 100;

        // Multiply bonus by monthly rKGeN yield
        let r = fixed_point64::multiply_u128(b as u128, r_month);

        // Adjust yield by rKGEN remaining/sent ratio
        r = fixed_point64::multiply_u128(r, rKGeN_ratio);

        // Convert to u64 and adjust decimal precision
        let res = (r & 0xFFFFFFFFFFFFFFFF as u64);
        res * keys / 10000
    }
}
