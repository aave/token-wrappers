// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {ICreditDelegationToken} from 'aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol';
import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IERC4626} from './dependencies/IERC4626.sol';
import {IUSDS} from './dependencies/IUSDS.sol';
import {BaseTokenWrapper} from './BaseTokenWrapper.sol';

/**
 * @title Generic4626Wrapper
 * @author Aave
 * @notice Generic contract to wrap an ERC20 to ERC4626 to on supply to Aave, or unwrap from ERC4626 to ERC20 on withdrawal
 */
contract Generic4626Wrapper is BaseTokenWrapper {
  /**
   * @dev Constructor
   * @param tokenIn Address for the ERC20 token
   * @param tokenOut Address for the ERC4626 token
   * @param pool The address of the Aave Pool
   * @param owner The address to transfer ownership to
   */
  constructor(
    address tokenIn,
    address tokenOut,
    address pool,
    address owner
  ) BaseTokenWrapper(tokenIn, tokenOut, pool, owner) {
    IERC20(tokenIn).approve(tokenOut, type(uint256).max);
  }

  /// @inheritdoc BaseTokenWrapper
  function getTokenOutForTokenIn(
    uint256 amount
  ) external view override returns (uint256) {
    return IERC4626(TOKEN_OUT).previewDeposit(amount);
  }

  /// @inheritdoc BaseTokenWrapper
  function getTokenInForTokenOut(
    uint256 amount
  ) external view override returns (uint256) {
    return IERC4626(TOKEN_OUT).previewRedeem(amount);
  }

  /// @inheritdoc BaseTokenWrapper
  function _wrapTokenIn(uint256 amount) internal override returns (uint256) {
    return IERC4626(TOKEN_OUT).deposit(amount, address(this));
  }

  /// @inheritdoc BaseTokenWrapper
  function _unwrapTokenOut(uint256 amount) internal override returns (uint256) {
    return IERC4626(TOKEN_OUT).redeem(amount, address(this), address(this));
  }
}
