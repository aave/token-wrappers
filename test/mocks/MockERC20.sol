// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Permit} from 'openzeppelin/token/ERC20/extensions/ERC20Permit.sol';
import {ERC20} from 'openzeppelin/token/ERC20/ERC20.sol';

contract MockERC20 is ERC20Permit {
  constructor(string memory name) ERC20Permit(name) ERC20(name, name) {
    _mint(msg.sender, 1e50);
  }
}
