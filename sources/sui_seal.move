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

/// Wraps and seals an object of type `T` into a `Sealed` container, 
/// effectively locking it and associating it with the transaction sender.
/// Emits a `SealedEvent` containing the new object ID and owner address.
public fun seal<T: store>(inner: T, ctx: &mut TxContext): Sealed<T> {
    let id = object::new(ctx);
    event::emit(SealedEvent { object_id: id.to_inner(), owner: ctx.sender() });

    Sealed { id, inner, owner: ctx.sender() }
}

/// Unseals the provided `Sealed` container by consuming it, 
/// verifying that the caller is the original owner. 
/// Destroys the container's UID and returns the inner object of type `T`.
public fun unseal<T: store>(sealed: Sealed<T>, ctx: &mut TxContext): T {
    let Sealed { id, inner, owner } = sealed;
    assert!(ctx.sender() == owner, ENotOwner);
    id.delete(); 
    inner
}

/// Completes the temporary access cycle by re-encapsulating the object `T`.
/// Consumes the mandatory `Receipt` to verify ownership continuity and 
/// creates a new `Sealed` container with a fresh object identity.
public fun reseal<T: store>(inner: T, receipt: Receipt<T>, ctx: &mut TxContext): Sealed<T> {
    let Receipt { owner } = receipt;
    Sealed { id: object::new(ctx), inner, owner }
}

/// Temporarily unlocks the `Sealed` container by consuming it and returning 
/// the inner object along with a mandatory `Receipt`. 
/// The lack of a 'drop' ability on the `Receipt` ensures the object 
/// must be re-sealed using the `reseal` function before the transaction ends.
public fun borrow_mut<T: store>(sealed: Sealed<T>, ctx: &mut TxContext): (T, Receipt<T>) {
    let Sealed { id, inner, owner } = sealed;
    assert!(ctx.sender() == owner, ENotOwner);
    id.delete();
    (inner, Receipt { owner })
}

/// Returns an immutable reference to the inner object of type `T` 
/// without consuming the `Sealed` container. This allows users to inspect 
/// the sealed contents while maintaining the integrity of the seal.
public fun borrow<T: store>(self: &Sealed<T>): &T {
    &self.inner
}

/// Returns the address of the original owner who sealed the object. 
/// This allows external modules or off-chain tools to verify ownership 
/// without needing access to the internal fields of the `Sealed` struct.
public fun owner<T: store>(self: &Sealed<T>): address {
    self.owner
}