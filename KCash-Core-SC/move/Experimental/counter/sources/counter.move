module CAddr::demo_counter{
    use std::signer;

    /// Resource that wraps an integer counter
    struct Bucket has key { reward1: u64 }

// init module --- Bucket reward 0
// mint (admin - signer, user-- address, amount)  {
//   let a = admin.mint(amount)
//  deposit_ref(user, a)
// }
    /// Publish a `Bucket` resource with value `reward1` under the given `account`
    public entry fun publish(account: &signer, reward1: u64) {
      // "Pack" (create) a Bucket resource. This is a privileged operation that
      // can only be done inside the module that declares the `Bucket` resource
      move_to(account, Bucket { reward1 })
    }

    /// Read the value in the `Bucket` resource stored at `addr`
    #[view]
    public fun get_count(addr: address): u64 acquires Bucket {
        borrow_global<Bucket>(addr).reward1
    }

    /// Increment the value of `addr`'s `Bucket` resource
    /// publish ---address
    /// admin increa
    public entry fun increment(addr: address) acquires Bucket {
        let c_ref = &mut borrow_global_mut<Bucket>(addr).reward1;
        *c_ref = *c_ref + 1
    }

    /// Reset the value of `account`'s `Bucket` to 0
    public entry fun reset(account: &signer) acquires Bucket {
        let c_ref = &mut borrow_global_mut<Bucket>(signer::address_of(account)).reward1;
        *c_ref = 0
    }

    /// Delete the `Bucket` resource under `account` and return its value
    public entry fun delete(account: &signer) acquires Bucket {
        // remove the Bucket resource
        let c = move_from<Bucket>(signer::address_of(account));
        // "Unpack" the `Bucket` resource into its fields. This is a
        // privileged operation that can only be done inside the module
        // that declares the `Bucket` resource
        let Bucket { reward1 } = c;
    }

    /// Return `true` if `addr` contains a `Bucket` resource
    #[view]
    public fun exists_counter(addr: address): bool {
        exists<Bucket>(addr)
    }
}