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
  address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
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

  function testBorrow() public {
    uint256 collateralAmount = 1000e18;
    uint256 borrowAmount = 100e18;
    address debtToken = IPool(pool)
      .getReserveData(tokenWrapper.TOKEN_OUT())
      .variableDebtTokenAddress;

    // Prank pool admin and set borrowing enabled for SDAI on pool configurator
    vm.startPrank(ADMIN);
    IPoolConfigurator(POOL_CONFIGURATOR).setReserveBorrowing(
      tokenWrapper.TOKEN_OUT(),
      true
    );

    address alice = makeAddr('ALICE');
    deal(WETH, alice, collateralAmount);
    changePrank(alice);

    IERC20(WETH).approve(address(pool), collateralAmount);
    IPool(pool).supply(WETH, collateralAmount, alice, 0);

    ICreditDelegationToken(debtToken).approveDelegation(
      address(tokenWrapper),
      borrowAmount
    );

    tokenWrapper.borrowToken(borrowAmount, address(alice));
    vm.stopPrank();

    uint256 borrowedAmount = tokenWrapper.getTokenInForTokenOut(borrowAmount);
    assertEq(
      IERC20(tokenWrapper.TOKEN_IN()).balanceOf(address(alice)),
      borrowedAmount
    );
  }
}
