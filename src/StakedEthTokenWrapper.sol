// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IWstETH} from './interfaces/IWstETH.sol';
import {BaseTokenWrapper} from './BaseTokenWrapper.sol';

/**
 * @title StakedEthTokenWrapper
 * @author Aave
 * @notice Contract to wrap stETH to wstETH on supply to Aave, or unwrap from wstETH to ETH on withdrawal
 */
contract StakedEthTokenWrapper is BaseTokenWrapper {
  /**
   * @dev Constructor
   * @param tokenIn Address for stETH
   * @param tokenOut Address for wstETH
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
    return IWstETH(TOKEN_OUT).getWstETHByStETH(amount);
  }

  /// @inheritdoc BaseTokenWrapper
  function getTokenInForTokenOut(
    uint256 amount
  ) external view override returns (uint256) {
    return IWstETH(TOKEN_OUT).getStETHByWstETH(amount);
  }

  /// @inheritdoc BaseTokenWrapper
  function _wrapTokenIn(uint256 amount) internal override returns (uint256) {
    return IWstETH(TOKEN_OUT).wrap(amount);
  }

  /// @inheritdoc BaseTokenWrapper
  function _unwrapTokenOut(uint256 amount) internal override returns (uint256) {
    return IWstETH(TOKEN_OUT).unwrap(amount);
  }
}
