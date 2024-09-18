// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IUSDS} from './interfaces/IUSDS.sol';
import {BaseTokenWrapper} from './BaseTokenWrapper.sol';

/**
 * @title SavingsSuSDSTokenWrapper
 * @author Aave
 * @notice Contract to wrap USDS to SuSDS on supply to Aave, or unwrap from SuSDS to USDS on withdrawal
 */
contract SavingsSuSDSTokenWrapper is BaseTokenWrapper {
  /**
   * @dev Constructor
   * @param tokenIn Address for USDS
   * @param tokenOut Address for SUSDS
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

  ///@inheritdoc BaseTokenWrapper
  function borrowToken(uint256 amount, address to) external override {
    POOL.borrow(TOKEN_OUT, amount, 1, 0, to);
    _unwrapTokenOut(amount);
    IERC20(TOKEN_IN).transfer(to, amount);
  }

  /// @inheritdoc BaseTokenWrapper
  function getTokenOutForTokenIn(
    uint256 amount
  ) external view override returns (uint256) {
    return IUSDS(TOKEN_OUT).previewDeposit(amount);
  }

  /// @inheritdoc BaseTokenWrapper
  function getTokenInForTokenOut(
    uint256 amount
  ) external view override returns (uint256) {
    return IUSDS(TOKEN_OUT).previewRedeem(amount);
  }

  /// @inheritdoc BaseTokenWrapper
  function _wrapTokenIn(uint256 amount) internal override returns (uint256) {
    return IUSDS(TOKEN_OUT).deposit(amount, address(this));
  }

  /// @inheritdoc BaseTokenWrapper
  function _unwrapTokenOut(uint256 amount) internal override returns (uint256) {
    return IUSDS(TOKEN_OUT).redeem(amount, address(this), address(this));
  }
}
