// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {IPoolConfigurator} from 'aave-v3-core/contracts/interfaces/IPoolConfigurator.sol';
import {BaseTokenWrapperTest} from './BaseTokenWrapper.t.sol';
import {SavingsDaiTokenWrapper} from '../src/SavingsDaiTokenWrapper.sol';
import {ICreditDelegationToken} from '../src/interfaces/ICreditDelegationToken.sol';

contract SavingsDaiTokenWrapperTest is BaseTokenWrapperTest {
  address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
  address constant SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
  address constant ASDAI = 0x4C612E3B15b96Ff9A6faED838F8d07d479a8dD4c;
  address constant POOL_CONFIGURATOR =
    0x64b761D848206f447Fe2dd461b0c635Ec39EbB27;
  address constant ADMIN = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;

  function setUp() public {
    vm.createSelectFork(vm.envString('ETH_RPC_URL'), 20784588);
    pool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    tokenWrapper = new SavingsDaiTokenWrapper(DAI, SDAI, pool, OWNER);
    aTokenOut = ASDAI;
    tokenInDecimals = 18;
    permitSupported = false;
  }

  function testConstructor() public override {
    SavingsDaiTokenWrapper tempTokenWrapper = new SavingsDaiTokenWrapper(
      DAI,
      SDAI,
      pool,
      OWNER
    );
    assertEq(tempTokenWrapper.TOKEN_IN(), DAI, 'Unexpected TOKEN_IN');
    assertEq(tempTokenWrapper.TOKEN_OUT(), SDAI, 'Unexpected TOKEN_OUT');
    assertEq(address(tempTokenWrapper.POOL()), pool, 'Unexpected POOL');
    assertEq(tempTokenWrapper.owner(), OWNER, 'Unexpected owner');
    assertEq(
      IERC20(SDAI).allowance(address(tempTokenWrapper), pool),
      type(uint256).max,
      'Unexpected TOKEN_OUT allowance'
    );
    assertEq(
      IERC20(DAI).allowance(address(tempTokenWrapper), SDAI),
      type(uint256).max,
      'Unexpected TOKEN_IN allowance'
    );
  }

  function testBorrowNotPermitted() public {
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
    vm.expectRevert('INVALID_ACTION');
    tokenWrapper.borrowToken(borrowAmount, address(alice), 0);
    vm.stopPrank();
  }
}
