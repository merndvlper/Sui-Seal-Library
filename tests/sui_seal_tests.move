#[test_only]
module sui_seal::seal_tests;

use sui::test_scenario;
use sui_seal::seal::{Self, Sealed};

// a Simple Object for Test
public struct Dummy has store, key {
    id: UID,
    value: u64
}

#[test]
fun test_seal_function() {
    let owner = @0xA1;
    let mut scenario = test_scenario::begin(owner);

    scenario.next_tx(owner);
    {
        let ctx = scenario.ctx();
        let item = Dummy { id: object::new(ctx), value: 500 };
        
        let sealed_item = seal::seal(item, ctx);
        
        assert!(sealed_item.owner() == owner, 0);
        
        transfer::public_transfer(sealed_item, owner);
    };

    scenario.next_tx(owner);
    {
        assert!(scenario.has_most_recent_for_sender<Sealed<Dummy>>(), 1);
    };

    scenario.end();
}

#[test]
fun test_unseal_function() {
    let owner = @0xA1;
    let mut scenario = test_scenario::begin(owner);

    scenario.next_tx(owner);
    {
        let ctx = scenario.ctx();
        let item = Dummy { id: object::new(ctx), value: 777 };
        let sealed = seal::seal(item, ctx);
        transfer::public_transfer(sealed, owner);
    };

    scenario.next_tx(owner);
    {
        let sealed = scenario.take_from_sender<Sealed<Dummy>>();
        let ctx = scenario.ctx();

        let item = seal::unseal(sealed, ctx);

        assert!(item.value == 777, 0);

        transfer::public_transfer(item, owner);
    };

    scenario.next_tx(owner);
    {
        assert!(!scenario.has_most_recent_for_sender<Sealed<Dummy>>(), 1);
        
        assert!(scenario.has_most_recent_for_sender<Dummy>(), 2);
    };

    scenario.end();
}

#[test]
fun test_borrow_mut_and_reseal_flow() {
    let owner = @0xA1;
    let mut scenario = test_scenario::begin(owner);

    scenario.next_tx(owner);
    {
        let ctx = scenario.ctx();
        let item = Dummy { id: object::new(ctx), value: 100 };
        let sealed = seal::seal(item, ctx);
        transfer::public_transfer(sealed, owner);
    };

    scenario.next_tx(owner);
    {
        let sealed = scenario.take_from_sender<Sealed<Dummy>>();
        let ctx = scenario.ctx();

        let (mut item, receipt) = seal::borrow_mut(sealed, ctx);
        
        item.value = 250;

        let resealed = seal::reseal(item, receipt, ctx);
        transfer::public_transfer(resealed, owner);
    };

    scenario.next_tx(owner);
    {
        let sealed = scenario.take_from_sender<Sealed<Dummy>>();
        
        let item_ref = seal::borrow(&sealed);
        assert!(item_ref.value == 250, 0);

        test_scenario::return_to_sender(&scenario, sealed);
    };

    scenario.end();
}