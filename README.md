# REDOX - global state management for PureScript apps

[![Maintainer: coot](https://img.shields.io/badge/maintainer-coot-lightgrey.svg)](http://github.com/coot) [![documentation](https://pursuit.purescript.org/packages/purescript-redox/badge)](https://pursuit.purescript.org/packages/purescript-redox)
[![Build Status](https://travis-ci.org/coot/purescript-redox.svg?branch=master)](https://travis-ci.org/coot/purescript-redox)

Redox - since it mixes well with [Thermite](https://github.com/paf31/purescript-thermite) ;)

This is `redux` type store, but instead of forcing you to write interpreter
as a reducer you are free (or rather cofree ;)) to write it the way you want.
The library will give you different schemes how the store is updated.  Now
there is only one `Redox.DSL`, but in near future there will be at least one
more using coroutines (similar to how
[Thermite](https://github.com/paf31/purescript-thermite) updates react
component state). 

## Redox.DSL

A DSL has to be interpreted in the `Aff` monad.  Since `Aff` has an instance of
`MonadEff` this does not restrict you in any way.  Checkout tests how to write
synchronous and asynchronous commands

In general if your `DSL` is generated by a functor `C` (for commands):
```purescript
type DSL = Free C
```
then you have to find a functor `RunC eff` which pairs with `C`:
```purescript
pair :: forall eff x y. C (x -> y) -> RunC eff x -> Aff eff y
```
You can deduce from `pair` type that if `C` is a sum type then `RunC` is
a product - that's how it interprets `C`.

Then the interpreter has type:
```purescript
type Interp eff a = Cofree (RunC eff)
```

This give rise to a function
```purescript
runInterp :: forall state. DSL(state -> state) -> RunC eff state -> Aff eff state
runInterp cmds state = exploreM pair cmds $ mkInterp state
```

You can feed this function into `Redox.DSL.dispatch`:
```purescript
dispatchS :: forall eff state. DSL(state -> state) -> Aff (redox :: Redox | eff) state
dispatchS = Redox.DSL.dispatch (\_ _ -> pure unit) runInterp store
```

Check out tests for an example or this
[repo](https://github.com/coot/purescript-dsl-example).  However you can write
an interpreter without `Cofree`, simply by using `State` to track the state, or
just by hand.  The advantage of using `Cofree` is that whenever you will change
`C` the compiler will force you to update `RunC` in compatible way.

## Incremental updates
The `Redox.DSL.dispatch` function will dispatch changes to the store when the
`Aff` computation resolves.  You may want to dispatch every node of your
interpreter i.e. when each DSL command is run in the `do` block`. For example
if you try to 
```purescript
dispatch do
  cmd1 arg1
  cmd2 arg2
```
The `dispatch` will update the store when cmd2 finishes.  But you can build
this into the interpreter.  Since this is common, there is a function in `Redox.Utils` to
modify an interpreter of type `Cofree f a` so that it updates the store on
every step of the `Cofree` comonad:
```purescript
Redox.Utils.mkIncInterp
  :: forall state f
   . (Functor f)
  => Store state
  -> Cofree f state
  -> Cofree f state
```
Note that this function will not dispatch subscriptions.  If you build that
into your interpreterer or you can use `dispatchP` which does not run subscriptions.
```purescript
Redox.DSL.dispatchP
  :: forall state dsl eff
   . (Error -> Eff (redox :: REDOX | eff) Unit)
  -> (dsl -> state -> Aff (redox :: REDOX | eff) state)
  -> Store state
  -> dsl
  -> Eff (redox :: REDOX | eff) (Canceler (redox :: REDOX | eff))
```
which will not touch the store, (the `P` suffix stands for pure).

## Store middlewares via hoisting Cofree
You can modify your interpreter using
```purescript
Redox.Utils.hoistCofree'
  :: forall f state
   . (Functor f)
  => (f (Cofree f state) -> f (Cofree f state))
  -> Cofree f state
  -> Cofree f state
```

This is a version of `Control.Comonad.Cofree.hostCofree` but here the first
argument does not need to be a natural transformation.  This let you add
effects to the interpreter.  For example `mkIncInterp` is build using it.
Another example is to add a logger.

```purescript
addLogger
  :: forall state f
   . (Functor f)
  => Cofree f state
  -> Cofree f state
addLogger interp = hoistCofree' nat interp
  where
    nat :: f (Cofree f state) -> f (Cofree f state)
    nat fa = g <$> fa

    g :: Cofree f state -> Cofree f state
    g cof = unsafePerformEff do
      -- Control.Comonad.Cofree.head 
      log $ unsafeCoerce (head cof)
      pure cof
```

There are plenty of other things you can do with the interpreter in this way, e.g.
undo/redo stack, optimistic updates, crash reporting, delay actions (or
just some actions, via prisms).
