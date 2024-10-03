// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {ICreditDelegationToken} from 'aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol';
import {BaseTokenWrapperTest} from './BaseTokenWrapper.t.sol';
import {SavingsDaiTokenWrapper} from '../src/SavingsDaiTokenWrapper.sol';

contract SavingsDaiTokenWrapperTest is BaseTokenWrapperTest {
  address constant DAI = AaveV3EthereumAssets.DAI_UNDERLYING;
  address constant SDAI = AaveV3EthereumAssets.sDAI_UNDERLYING;
  address constant ASDAI = AaveV3EthereumAssets.sDAI_A_TOKEN;
  address constant WETH = AaveV3EthereumAssets.WETH_UNDERLYING;

  function setUp() public {
    vm.createSelectFork(vm.envString('ETH_RPC_URL'), 20784588);
    pool = address(AaveV3Ethereum.POOL);
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
    tokenWrapper.borrowToken(borrowAmount, 0);
    vm.stopPrank();
  }
}
