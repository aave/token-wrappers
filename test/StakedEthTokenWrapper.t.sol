// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {AaveV2EthereumAssets} from 'aave-address-book/AaveV2Ethereum.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {ICreditDelegationToken} from 'aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol';
import {BaseTokenWrapperTest} from './BaseTokenWrapper.t.sol';
import {StakedEthTokenWrapper} from '../src/StakedEthTokenWrapper.sol';

contract StakedEthTokenWrapperTest is BaseTokenWrapperTest {
  address constant STETH = AaveV2EthereumAssets.stETH_UNDERLYING;
  address constant WSTETH = AaveV3EthereumAssets.wstETH_UNDERLYING;
  address constant AWSTETH = AaveV3EthereumAssets.wstETH_A_TOKEN;
  address constant WETH = AaveV3EthereumAssets.WETH_UNDERLYING;

  function setUp() public {
    vm.createSelectFork(vm.envString('ETH_RPC_URL'), 20784588);
    pool = address(AaveV3Ethereum.POOL);
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

  function _dealTokenIn(address user, uint256 amount) internal override {
    vm.deal(user, amount);
    vm.prank(user);
    (bool success, ) = STETH.call{value: amount}('');
    require(success);
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
