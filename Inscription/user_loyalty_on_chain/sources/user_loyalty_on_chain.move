module UserLoyaltyOnChain::user_loyalty_on_chain {
    use aptos_framework::event;
    use std::string:: String;

    #[event]
    struct OnChainData has drop, store {
        userId: String,
        eventId: String,
        timestamp: u64,
    }

    public entry fun emit_on_chain_data(userId:String, eventId:String, timestamp:u64) {
        event::emit(OnChainData{
            userId: userId,
            eventId: eventId,
            timestamp: timestamp,
        });
    }
}