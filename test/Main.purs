module Test.Main where

import Prelude
import Control.Monad.Aff.AVar (AVAR)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Console (CONSOLE)
import Control.Monad.Eff.Exception (EXCEPTION)
import Redox.Store (ReadRedox, WriteRedox, CreateRedox, SubscribeRedox)
import Test.Unit.Console (TESTOUTPUT)
import Test.Unit.Main (runTest)
import Test.Free (testSuite) as Free
import Test.Store (testSuite) as Store

main :: forall eff. Eff (readRedox :: ReadRedox, writeRedox :: WriteRedox, createRedox :: CreateRedox, subscribeRedox :: SubscribeRedox, avar :: AVAR, console :: CONSOLE, testOutput :: TESTOUTPUT, err :: EXCEPTION | eff) Unit
main = runTest do
  Free.testSuite
  Store.testSuite

