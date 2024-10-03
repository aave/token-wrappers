// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {SafeERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/SafeERC20.sol';
import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IERC4626} from 'openzeppelin/interfaces/IERC4626.sol';
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
    // Intentionally left blank
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
    SafeERC20.safeApprove(IERC20(TOKEN_IN), TOKEN_OUT, amount);
    uint256 wrappedAmount = IERC4626(TOKEN_OUT).deposit(amount, address(this));
    SafeERC20.safeApprove(IERC20(TOKEN_IN), TOKEN_OUT, 0);
    return wrappedAmount;
  }

  /// @inheritdoc BaseTokenWrapper
  function _unwrapTokenOut(uint256 amount) internal override returns (uint256) {
    return IERC4626(TOKEN_OUT).redeem(amount, address(this), address(this));
  }
}
