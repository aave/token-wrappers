// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {BaseTokenWrapperTest} from './BaseTokenWrapper.t.sol';
import {StakedEthTokenWrapper} from '../src/StakedEthTokenWrapper.sol';

contract StakedEthTokenWrapperTest is BaseTokenWrapperTest {
  address constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
  address constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
  address constant AWSTETH = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371;

  function setUp() public {
    vm.createSelectFork(vm.envString('ETH_RPC_URL'));
    pool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    tokenWrapper = new StakedEthTokenWrapper(STETH, WSTETH, pool, OWNER);
    aTokenOut = AWSTETH;
    tokenInDecimals = 18;
    permitSupported = true;
  }

  function testConstructor() public override {
    new StakedEthTokenWrapper(STETH, WSTETH, pool, OWNER);
  }

  function _dealTokenIn(address user, uint256 amount) internal override {
    vm.deal(user, amount);
    vm.prank(user);
    (bool success, ) = STETH.call{value: amount}('');
    require(success);
  }
}
