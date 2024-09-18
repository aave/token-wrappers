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
  address constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
  address constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;

  // fork
  address constant AUSDS = 0x5c647cE0Ae10658ec44FA4E11A51c96e94efd1Dd;

  // fork
  // address constant ASUSDS = 0x5c647ce0ae10658ec44fa4e11a51c96e94efd1dd;

  function setUp() public {
    // vm.createSelectFork(vm.envString('ETH_RPC_URL'));
    vm.createSelectFork(
      'https://rpc.tenderly.co/fork/26fdbc41-5ae7-4f5a-9b47-a4ae15e05ce0'
    );
    // short gov executor
    pool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    // in, out, pool, owner
    tokenWrapper = new SavingsSuSDSTokenWrapper(USDS, SUSDS, pool, OWNER);
    aTokenOut = AUSDS;
    tokenInDecimals = 18;
    permitSupported = true;
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
