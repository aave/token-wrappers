// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {AaveV2EthereumAssets} from 'aave-address-book/AaveV2Ethereum.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';

import {BaseTokenWrapperTest} from './BaseTokenWrapper.t.sol';

import {StakedEthTokenWrapper} from 'src/StakedEthTokenWrapper.sol';

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
    collateralAsset = AaveV3EthereumAssets.WETH_UNDERLYING;
    borrowSupported = false;
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
    // Custom deal function for stETH
    deal(address(this), amount);
    (bool success, ) = payable(tokenWrapper.TOKEN_IN()).call{value: amount}('');
    require(success, 'DEAL_FAILURE');
    IERC20(tokenWrapper.TOKEN_IN()).transfer(user, amount);
  }
}
