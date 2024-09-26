// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {ICreditDelegationToken} from 'aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol';
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
  function borrowToken(uint256 amount, uint16 referralCode) external override {
    _borrowToken(amount, msg.sender, referralCode);
  }

  /// @inheritdoc BaseTokenWrapper
  function borrowTokenWithPermit(
    uint256 amount,
    uint16 referralCode,
    PermitSignature calldata signature
  ) external override {
    if (signature.deadline != 0) {
      address debtToken = IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2)
        .getReserveData(TOKEN_OUT)
        .variableDebtTokenAddress;

      ICreditDelegationToken(debtToken).delegationWithSig(
        msg.sender,
        address(this),
        amount,
        signature.deadline,
        signature.v,
        signature.r,
        signature.s
      );
    }
    _borrowToken(amount, msg.sender, referralCode);
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
