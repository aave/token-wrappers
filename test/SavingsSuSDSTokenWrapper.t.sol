// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;
import 'forge-std/console2.sol';

import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {BaseTokenWrapperTest} from './BaseTokenWrapper.t.sol';
import {SavingsSuSDSTokenWrapper} from '../src/SavingsSuSDSTokenWrapper.sol';

interface IPayload {
  function execute() external;

  function sUSDS() external view returns (address);
}

// frontend deposits usds and automatically converted to susds on aave

contract SavingsSuSDSTokenWrapperTest is BaseTokenWrapperTest {
  address constant USDS = 0x1923DfeE706A8E78157416C29cBCCFDe7cdF4102;
  address constant SUSDS = 0x4e7991e5C547ce825BdEb665EE14a3274f9F61e0;

  address constant AUSDS = 0x4C612E3B15b96Ff9A6faED838F8d07d479a8dD4c;

  function setUp() public {
    vm.createSelectFork(vm.envString('ETH_RPC_URL'));
    // short gov executor

    // //https://etherscan.io/address/0x2749Ef5641B90DCD17Ee2C0cbFbbA5b440e14fec#code
    IPayload deployedPayload = IPayload(
      0x2749Ef5641B90DCD17Ee2C0cbFbbA5b440e14fec
    );
    vm.prank(0xEE56e2B3D491590B5b31738cC34d5232F378a8D5);

    deployedPayload.execute();
    pool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    // in, out, pool, owner
    tokenWrapper = new SavingsSuSDSTokenWrapper(USDS, SUSDS, pool, OWNER);
    aTokenOut = AUSDS;
    tokenInDecimals = 18;
    permitSupported = false;
  }

  function testConstructor() public override {
    SavingsSuSDSTokenWrapper tempTokenWrapper = new SavingsSuSDSTokenWrapper(
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
