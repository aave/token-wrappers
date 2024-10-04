// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from 'openzeppelin/token/ERC20/IERC20.sol';
import {ERC20} from 'openzeppelin/token/ERC20/ERC20.sol';
import {ERC4626} from 'openzeppelin/token/ERC20/extensions/ERC4626.sol';

contract MockERC4626 is ERC4626 {
  constructor(IERC20 _asset) ERC20('SMOCK', 'SMOCK') ERC4626(_asset) {}
}
