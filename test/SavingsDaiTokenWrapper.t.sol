// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {BaseTokenWrapperTest} from './BaseTokenWrapper.t.sol';

import {SavingsDaiTokenWrapper} from 'src/SavingsDaiTokenWrapper.sol';

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
    collateralAsset = AaveV3EthereumAssets.WETH_UNDERLYING;
    borrowSupported = false;
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
}
