// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;
import 'forge-std/console2.sol';

import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IUSDS} from './dependencies/IUSDS.sol';
import {BaseTokenWrapper} from './BaseTokenWrapper.sol';

/**
 * @title SavingUsdsTokenWrapper
 * @author Aave
 * @notice Contract to wrap USDS to SuSDS on supply to Aave, or unwrap from SuSDS to USDS on withdrawal
 */
contract SavingUsdsTokenWrapper is BaseTokenWrapper {
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

  /// @inheritdoc BaseTokenWrapper
  function borrowToken(
    uint256 amount,
    address to,
    uint16 referralCode
  ) external override {
    require(amount > 0, 'INSUFFICIENT_AMOUNT_TO_BORROW');
    uint256 balanceBeforeBorrow = IERC20(TOKEN_OUT).balanceOf(address(this));
    POOL.borrow(TOKEN_OUT, amount, 2, referralCode, address(to));
    uint256 balanceAfterBorrow = IERC20(TOKEN_OUT).balanceOf(address(this));
    uint256 amountIn = _unwrapTokenOut(
      balanceAfterBorrow - balanceBeforeBorrow
    );
    IERC20(TOKEN_IN).transfer(to, amountIn);
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
