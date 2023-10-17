// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';

interface IBaseTokenWrapper {
  struct PermitSignature {
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  function supplyToken(
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;

  function supplyTokenWithPermit(
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode,
    PermitSignature calldata signature
  ) external;

  function withdrawToken(uint256 amount, address to) external returns (uint256);

  function withdrawTokenWithPermit(
    uint256 amount,
    address to,
    PermitSignature calldata signature
  ) external returns (uint256);

  function rescueTokens(IERC20 token, address to, uint256 amount) external;

  function rescueETH(address to, uint256 amount) external;

  function getTokenOutForTokenIn(
    uint256 amount
  ) external view returns (uint256);

  function getTokenInForTokenOut(
    uint256 amount
  ) external view returns (uint256);
}
