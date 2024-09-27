// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {ERC20} from '../../src/dependencies/ERC20.sol';
import {ERC4626} from '../../src/dependencies/ERC4626.sol';

contract MockERC4626 is ERC4626 {
  constructor(IERC20 _asset) ERC20('SMOCK', 'SMOCK') ERC4626(_asset) {}
}
