// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {BaseTokenWrapperTest} from './BaseTokenWrapper.t.sol';
import {StakedEthTokenWrapper} from '../src/StakedEthTokenWrapper.sol';
import {ICreditDelegationToken} from '../src/interfaces/ICreditDelegationToken.sol';

contract StakedEthTokenWrapperTest is BaseTokenWrapperTest {
  address constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
  address constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
  address constant AWSTETH = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371;
  address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  function setUp() public {
    vm.createSelectFork(vm.envString('ETH_RPC_URL'), 20784588);
    pool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    tokenWrapper = new StakedEthTokenWrapper(STETH, WSTETH, pool, OWNER);
    aTokenOut = AWSTETH;
    tokenInDecimals = 18;
    permitSupported = true;
  }

  function testConstructor() public override {
    StakedEthTokenWrapper tempTokenWrapper = new StakedEthTokenWrapper(
      STETH,
      WSTETH,
      pool,
      OWNER
    );
    assertEq(tempTokenWrapper.TOKEN_IN(), STETH, 'Unexpected TOKEN_IN');
    assertEq(tempTokenWrapper.TOKEN_OUT(), WSTETH, 'Unexpected TOKEN_OUT');
    assertEq(address(tempTokenWrapper.POOL()), pool, 'Unexpected POOL');
    assertEq(tempTokenWrapper.owner(), OWNER, 'Unexpected owner');
  }

  function testBorrow() public {
    uint256 collateralAmount = 1000e18;
    uint256 borrowAmount = 100e18;
    address debtToken = IPool(pool)
      .getReserveData(tokenWrapper.TOKEN_OUT())
      .variableDebtTokenAddress;

    address alice = makeAddr('ALICE');
    deal(WETH, alice, collateralAmount);
    vm.startPrank(alice);

    IERC20(WETH).approve(address(pool), collateralAmount);
    IPool(pool).supply(WETH, collateralAmount, alice, 0);

    ICreditDelegationToken(debtToken).approveDelegation(
      address(tokenWrapper),
      borrowAmount
    );

    tokenWrapper.borrowToken(borrowAmount, address(alice));
    vm.stopPrank();

    uint256 borrowedAmount = tokenWrapper.getTokenInForTokenOut(borrowAmount);
    // Allow OBOB for rounding to nearest wei
    assertApproxEqAbs(
      IERC20(tokenWrapper.TOKEN_IN()).balanceOf(address(alice)),
      borrowedAmount,
      1
    );
  }

  function _dealTokenIn(address user, uint256 amount) internal override {
    vm.deal(user, amount);
    vm.prank(user);
    (bool success, ) = STETH.call{value: amount}('');
    require(success);
  }
}
