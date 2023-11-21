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
  address public dai = AaveV3EthereumAssets.DAI_UNDERLYING;
  address public sDai = AaveV3EthereumAssets.sDAI_UNDERLYING;
  address public pool = address(AaveV3Ethereum.POOL);
  address public owner = GovernanceV3Ethereum.EXECUTOR_LVL_1;

  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    console.log('Deploying contract SavingsDaiTokenWrapper');

    vm.startBroadcast(deployerPrivateKey);
    SavingsDaiTokenWrapper savingsDaiTokenWrapper = new SavingsDaiTokenWrapper(
      dai,
      sDai,
      pool,
      owner
    );
    vm.stopBroadcast();

    console.log(
      'SavingsDaiTokenWrapper contract deployed at ',
      address(savingsDaiTokenWrapper)
    );
  }
}
