// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;
import 'forge-std/console2.sol';

import {DataTypes} from 'aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol';
import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IERC20WithPermit} from 'aave-v3-core/contracts/interfaces/IERC20WithPermit.sol';
import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {IAToken} from 'aave-v3-core/contracts/interfaces/IAToken.sol';
import {SavingUsdsTokenWrapper} from '../src/SavingUsdsTokenWrapper.sol';
import {ICreditDelegationToken} from '../src/interfaces/ICreditDelegationToken.sol';
import {IBaseTokenWrapper} from '../src/interfaces/IBaseTokenWrapper.sol';
import {BaseTokenWrapperTest} from './BaseTokenWrapper.t.sol';
import {SigUtils} from './utils/SigUtils.sol';

// frontend deposits usds and automatically converted to susds on aave
contract SavingUsdsTokenWrapperTest is BaseTokenWrapperTest {
  address constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
  address constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
  address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  // TODO Actual Address --> fork
  address constant AUSDS = 0x10Ac93971cdb1F5c778144084242374473c350Da;

  function setUp() public {
    // vm.createSelectFork(vm.envString('ETH_RPC_URL'));
    vm.createSelectFork(
      'https://rpc.tenderly.co/fork/881012fd-267f-41dc-93ba-8eb025b8bce2'
    );
    pool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    tokenWrapper = new SavingUsdsTokenWrapper(USDS, SUSDS, pool, OWNER);
    aTokenOut = AUSDS;
    tokenInDecimals = 18;
    permitSupported = true;
  }

  function testConstructor() public override {
    SavingUsdsTokenWrapper tempTokenWrapper = new SavingUsdsTokenWrapper(
      USDS,
      SUSDS,
      pool,
      OWNER
    );
    assertEq(tempTokenWrapper.TOKEN_IN(), USDS, 'Unexpected TOKEN_IN');
    assertEq(tempTokenWrapper.TOKEN_OUT(), SUSDS, 'Unexpected TOKEN_OUT');
    assertEq(address(tempTokenWrapper.POOL()), pool, 'Unexpected POOL');
    assertEq(tempTokenWrapper.owner(), OWNER, 'Unexpected owner');
  }

  function testBorrow() public {
    uint256 collateralAmount = 1000e18;
    uint256 borrowAmount = 100e18;
    address debtToken = IPool(pool)
      .getReserveData(tokenWrapper.TOKEN_OUT())
      .variableDebtTokenAddress;

    address alice = makeAddr('ALICE');
    deal(WETH, alice, collateralAmount);

    vm.startPrank(alice);

    IERC20(WETH).approve(address(pool), collateralAmount);
    IPool(pool).supply(WETH, collateralAmount, alice, 0);

    ICreditDelegationToken(debtToken).approveDelegation(
      address(tokenWrapper),
      borrowAmount
    );

    tokenWrapper.borrowToken(borrowAmount, 0);
    vm.stopPrank();

    uint256 borrowedAmount = tokenWrapper.getTokenInForTokenOut(borrowAmount);
    assertEq(
      IERC20(tokenWrapper.TOKEN_IN()).balanceOf(address(alice)),
      borrowedAmount
    );
  }

  function testBorrowTokenWithPermit() public {
    uint256 borrowAmount = 100e18;
    uint256 collateralAmount = 1000e18;

    uint256 userPrivateKey = 0xA11CE;
    address alice = address(vm.addr(userPrivateKey));
    deal(WETH, alice, collateralAmount);

    address debtToken = IPool(pool)
      .getReserveData(tokenWrapper.TOKEN_OUT())
      .variableDebtTokenAddress;

    vm.startPrank(alice);

    IERC20(WETH).approve(address(pool), collateralAmount);

    IPool(pool).supply(WETH, collateralAmount, alice, 0);

    uint256 deadline = block.timestamp + 1 hours;
    uint256 nonce = IAToken(debtToken).nonces(alice);

    (uint8 v, bytes32 r, bytes32 s) = _signCreditDelegation(
      userPrivateKey,
      address(tokenWrapper),
      borrowAmount,
      nonce,
      deadline,
      debtToken
    );
    IBaseTokenWrapper.PermitSignature memory signature = IBaseTokenWrapper
      .PermitSignature({deadline: deadline, v: v, r: r, s: s});

    tokenWrapper.borrowTokenWithPermit(borrowAmount, 1, signature);

    vm.stopPrank();

    uint256 borrowedAmount = tokenWrapper.getTokenInForTokenOut(borrowAmount);
    assertEq(
      IERC20(tokenWrapper.TOKEN_IN()).balanceOf(address(alice)),
      borrowedAmount
    );
  }

  function testBorrowTokenWithPermitZeroAmount() public {
    uint256 borrowAmount = 0;
    uint256 collateralAmount = 1000e18;

    uint256 userPrivateKey = 0xA11CE;
    address alice = address(vm.addr(userPrivateKey));
    deal(WETH, alice, collateralAmount);

    address debtToken = IPool(pool)
      .getReserveData(tokenWrapper.TOKEN_OUT())
      .variableDebtTokenAddress;

    vm.startPrank(alice);

    IERC20(WETH).approve(address(pool), collateralAmount);

    IPool(pool).supply(WETH, collateralAmount, alice, 0);

    uint256 deadline = block.timestamp + 1 hours;
    uint256 nonce = IAToken(debtToken).nonces(alice);

    (uint8 v, bytes32 r, bytes32 s) = _signCreditDelegation(
      userPrivateKey,
      address(tokenWrapper),
      borrowAmount,
      nonce,
      deadline,
      debtToken
    );
    IBaseTokenWrapper.PermitSignature memory signature = IBaseTokenWrapper
      .PermitSignature({deadline: deadline, v: v, r: r, s: s});

    vm.expectRevert('INSUFFICIENT_AMOUNT_TO_BORROW');
    tokenWrapper.borrowTokenWithPermit(borrowAmount, 1, signature);
  }

  function _signCreditDelegation(
    uint256 privateKey,
    address delegatee,
    uint256 value,
    uint256 nonce,
    uint256 deadline,
    address debtToken
  ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
    SigUtils.CreditDelegation memory creditDelegation = SigUtils
      .CreditDelegation({
        delegatee: delegatee,
        value: value,
        nonce: nonce,
        deadline: deadline
      });

    bytes32 domainSeparator = IAToken(debtToken).DOMAIN_SEPARATOR();
    bytes32 digest = SigUtils.getCreditDelegationTypedDataHash(
      creditDelegation,
      domainSeparator
    );

    return vm.sign(privateKey, digest);
  }
}
