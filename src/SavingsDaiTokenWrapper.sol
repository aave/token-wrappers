// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {ISavingsDai} from './interfaces/ISavingsDai.sol';
import {DaiAbstract} from './interfaces/DaiAbstract.sol';
import {BaseTokenWrapper} from './BaseTokenWrapper.sol';

/**
 * @title SavingsDaiTokenWrapper
 * @author Aave
 * @notice Contract to wrap Dai to sDai on supply to Aave, or unwrap from sDai to Dai on withdrawal
 */
contract SavingsDaiTokenWrapper is BaseTokenWrapper {
  /**
   * @dev Constructor
   * @param tokenIn Address for Dai
   * @param tokenOut Address for sDai
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
  function supplyTokenWithPermit(
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode,
    PermitSignature calldata signature
  ) external override returns (uint256) {
    uint256 nonce = DaiAbstract(TOKEN_IN).nonces(msg.sender);
    DaiAbstract(TOKEN_IN).permit(
      msg.sender,
      address(this),
      nonce,
      signature.deadline,
      true,
      signature.v,
      signature.r,
      signature.s
    );
    return _supplyToken(amount, onBehalfOf, referralCode);
  }

  /// @inheritdoc BaseTokenWrapper
  function getTokenOutForTokenIn(
    uint256 amount
  ) external view override returns (uint256) {
    return ISavingsDai(TOKEN_OUT).previewDeposit(amount);
  }

  /// @inheritdoc BaseTokenWrapper
  function getTokenInForTokenOut(
    uint256 amount
  ) external view override returns (uint256) {
    return ISavingsDai(TOKEN_OUT).previewRedeem(amount);
  }

  /// @inheritdoc BaseTokenWrapper
  function _wrapTokenIn(uint256 amount) internal override returns (uint256) {
    return ISavingsDai(TOKEN_OUT).deposit(amount, address(this));
  }

  /// @inheritdoc BaseTokenWrapper
  function _unwrapTokenOut(uint256 amount) internal override returns (uint256) {
    return ISavingsDai(TOKEN_OUT).redeem(amount, address(this), address(this));
  }
}
