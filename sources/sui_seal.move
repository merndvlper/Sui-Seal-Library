module sui_seal::seal;

use sui::event;

const ENotOwner: u64 = 0;

public struct SealedEvent has copy, drop {
    object_id: ID,
    owner: address,
}

public struct Sealed<T: store> has key, store {
    id: UID,
    inner: T,
    owner: address
}

public struct Receipt<phantom T> {
    owner: address
}

public fun seal<T: store>(inner: T, ctx: &mut TxContext): Sealed<T> {
    let id = object::new(ctx);
    event::emit(SealedEvent { object_id: id.to_inner(), owner: ctx.sender() });

    Sealed { id, inner, owner: ctx.sender() }
}

public fun unseal<T: store>(sealed: Sealed<T>, ctx: &mut TxContext): T {
    let Sealed { id, inner, owner } = sealed;
    assert!(ctx.sender() == owner, ENotOwner);
    id.delete(); 
    inner
}

public fun reseal<T: store>(inner: T, receipt: Receipt<T>, ctx: &mut TxContext): Sealed<T> {
    let Receipt { owner } = receipt;
    Sealed { id: object::new(ctx), inner, owner }
}

public fun borrow_mut<T: store>(sealed: Sealed<T>, ctx: &mut TxContext): (T, Receipt<T>) {
    let Sealed { id, inner, owner } = sealed;
    assert!(ctx.sender() == owner, ENotOwner);
    id.delete();
    (inner, Receipt { owner })
}

public fun borrow<T: store>(self: &Sealed<T>): &T {
    &self.inner
}

public fun owner<T: store>(self: &Sealed<T>): address {
    self.owner
}