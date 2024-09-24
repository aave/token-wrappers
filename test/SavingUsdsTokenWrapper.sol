// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;
import 'forge-std/console2.sol';

import {DataTypes} from 'aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol';
import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {BaseTokenWrapperTest} from './BaseTokenWrapper.t.sol';
import {SavingUsdsTokenWrapper} from '../src/SavingUsdsTokenWrapper.sol';
import {ICreditDelegationToken} from '../src/interfaces/ICreditDelegationToken.sol';

// frontend deposits usds and automatically converted to susds on aave
contract SavingUsdsTokenWrapperTest is BaseTokenWrapperTest {
  address constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
  address constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;

  // TODO Actual Address --> fork
  address constant AUSDS = 0x10Ac93971cdb1F5c778144084242374473c350Da;

  function setUp() public {
    // vm.createSelectFork(vm.envString('ETH_RPC_URL'));
    vm.createSelectFork(
      'https://rpc.tenderly.co/fork/881012fd-267f-41dc-93ba-8eb025b8bce2'
    );
    pool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    tokenWrapper = new SavingUsdsTokenWrapper(USDS, SUSDS, pool, OWNER);
    aTokenOut = AUSDS;
    tokenInDecimals = 18;
    permitSupported = true;
  }

  function testConstructor() public override {
    SavingUsdsTokenWrapper tempTokenWrapper = new SavingUsdsTokenWrapper(
      USDS,
      SUSDS,
      pool,
      OWNER
    );
    assertEq(tempTokenWrapper.TOKEN_IN(), USDS, 'Unexpected TOKEN_IN');
    assertEq(tempTokenWrapper.TOKEN_OUT(), SUSDS, 'Unexpected TOKEN_OUT');
    assertEq(address(tempTokenWrapper.POOL()), pool, 'Unexpected POOL');
    assertEq(tempTokenWrapper.owner(), OWNER, 'Unexpected owner');
    assertEq(
      IERC20(SUSDS).allowance(address(tempTokenWrapper), pool),
      type(uint256).max,
      'Unexpected TOKEN_OUT allowance'
    );
    assertEq(
      IERC20(USDS).allowance(address(tempTokenWrapper), SUSDS),
      type(uint256).max,
      'Unexpected TOKEN_IN allowance'
    );
  }
}
