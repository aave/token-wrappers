// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {Script} from 'forge-std/Script.sol';
import 'forge-std/Test.sol';
import {SavingsDaiTokenWrapper} from '../src/SavingsDaiTokenWrapper.sol';
import {AaveV3EthereumAssets, AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';

/**
 * @dev Deploy Ethereum
 */
contract DeploySavingsDaiTokenWrapper is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    console.log('Deploying contract SavingsDaiTokenWrapper');

    vm.startBroadcast(deployerPrivateKey);
    SavingsDaiTokenWrapper savingsDaiTokenWrapper = new SavingsDaiTokenWrapper(
      AaveV3EthereumAssets.DAI_UNDERLYING,
      AaveV3EthereumAssets.sDAI_UNDERLYING,
      address(AaveV3Ethereum.POOL),
      GovernanceV3Ethereum.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();

    console.log(
      'SavingsDaiTokenWrapper contract deployed at ',
      address(savingsDaiTokenWrapper)
    );
  }
}
