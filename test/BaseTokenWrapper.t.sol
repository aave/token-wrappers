// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {Test, console2} from 'forge-std/Test.sol';
import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {IAToken} from 'aave-v3-core/contracts/interfaces/IAToken.sol';
import {BaseTokenWrapper} from '../src/BaseTokenWrapper.sol';

interface IERC2612 {
  function nonces(address owner) external view returns (uint256);

  function DOMAIN_SEPARATOR() external view returns (bytes32);
}

abstract contract BaseTokenWrapperTest is Test {
  bytes32 constant PERMIT_TYPEHASH =
    keccak256(
      'Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'
    );
  uint256 constant DEAL_AMOUNT = 1_000;
  uint16 constant REFERRAL_CODE = 0;
  address immutable ALICE;
  uint256 immutable ALICE_KEY;
  address immutable BOB;
  address immutable OWNER;
  address pool;
  BaseTokenWrapper tokenWrapper;
  address aTokenOut;
  uint256 tokenInDecimals;
  bool permitSupported;

  constructor() {
    (ALICE, ALICE_KEY) = makeAddrAndKey('alice');
    BOB = makeAddr('bob');
    OWNER = makeAddr('owner');
  }

  function testConstructor() public virtual;

  function testSupplyToken() public {
    IERC20 tokenIn = IERC20(tokenWrapper.TOKEN_IN());
    assertEq(
      tokenIn.balanceOf(ALICE),
      0,
      'Unexpected starting tokenIn balance'
    );
    assertEq(
      IAToken(aTokenOut).balanceOf(ALICE),
      0,
      'Unexpected starting aToken balance'
    );

    uint256 dealAmountScaled = DEAL_AMOUNT * 10 ** tokenInDecimals;
    _dealTokenIn(ALICE, dealAmountScaled);
    uint256 estimateFinalBalance = tokenWrapper.getTokenOutForTokenIn(
      dealAmountScaled
    );

    vm.startPrank(ALICE);
    tokenIn.approve(address(tokenWrapper), dealAmountScaled);
    tokenWrapper.supplyToken(dealAmountScaled, ALICE, REFERRAL_CODE);
    vm.stopPrank();

    assertEq(tokenIn.balanceOf(ALICE), 0, 'Unexpected ending tokenIn balance');
    assertEq(
      IAToken(aTokenOut).balanceOf(ALICE),
      estimateFinalBalance,
      'Unexpected ending aToken balance'
    );
  }

  function testSupplyTokenWithPermit() public {
    IERC20 tokenIn = IERC20(tokenWrapper.TOKEN_IN());
    assertEq(
      tokenIn.balanceOf(ALICE),
      0,
      'Unexpected Alice starting tokenIn balance'
    );
    assertEq(
      IAToken(aTokenOut).balanceOf(ALICE),
      0,
      'Unexpected Alice starting aToken balance'
    );

    uint256 dealAmountScaled = DEAL_AMOUNT * 10 ** tokenInDecimals;
    _dealTokenIn(ALICE, dealAmountScaled);
    uint256 estimateFinalBalance = tokenWrapper.getTokenOutForTokenIn(
      dealAmountScaled
    );

    uint256 deadline = block.timestamp + 1;
    bytes32 digest = keccak256(
      abi.encodePacked(
        hex'1901',
        IERC2612(address(tokenIn)).DOMAIN_SEPARATOR(),
        keccak256(
          abi.encode(
            PERMIT_TYPEHASH,
            ALICE,
            address(tokenWrapper),
            dealAmountScaled,
            IAToken(aTokenOut).nonces(ALICE),
            deadline
          )
        )
      )
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_KEY, digest);
    BaseTokenWrapper.PermitSignature memory signature = BaseTokenWrapper
      .PermitSignature(deadline, v, r, s);

    if (permitSupported) {
      vm.startPrank(ALICE);
      tokenWrapper.supplyTokenWithPermit(
        dealAmountScaled,
        ALICE,
        REFERRAL_CODE,
        signature
      );
      vm.stopPrank();

      assertEq(
        tokenIn.balanceOf(ALICE),
        0,
        'Unexpected ending tokenIn balance'
      );
      assertEq(
        IAToken(aTokenOut).balanceOf(ALICE),
        estimateFinalBalance,
        'Unexpected ending aToken balance'
      );
    } else {
      vm.startPrank(ALICE);
      vm.expectRevert();
      tokenWrapper.supplyTokenWithPermit(
        dealAmountScaled,
        ALICE,
        REFERRAL_CODE,
        signature
      );
      vm.stopPrank();
    }
  }

  function testWithdrawToken() public {
    testSupplyToken();
    IERC20 tokenIn = IERC20(tokenWrapper.TOKEN_IN());

    uint256 aTokenBalance = IAToken(aTokenOut).balanceOf(ALICE);
    assertGt(aTokenBalance, 0, 'Unexpected starting aToken balance');
    assertEq(
      tokenIn.balanceOf(ALICE),
      0,
      'Unexpected starting tokenIn balance'
    );
    uint256 estimateFinalBalance = tokenWrapper.getTokenInForTokenOut(
      aTokenBalance
    );

    vm.startPrank(ALICE);
    IAToken(aTokenOut).approve(address(tokenWrapper), aTokenBalance);
    tokenWrapper.withdrawToken(aTokenBalance, ALICE);
    vm.stopPrank();

    assertEq(
      IAToken(aTokenOut).balanceOf(ALICE),
      0,
      'Unexpected ending aToken balance'
    );
    assertLe(
      estimateFinalBalance - tokenIn.balanceOf(ALICE),
      1,
      'Unexpected ending tokenIn balance'
    );
  }

  function testWithdrawTokenWithPermit() public {
    testSupplyToken();
    IERC20 tokenIn = IERC20(tokenWrapper.TOKEN_IN());

    uint256 aTokenBalance = IAToken(aTokenOut).balanceOf(ALICE);
    assertGt(aTokenBalance, 0, 'Unexpected starting aToken balance');
    assertEq(
      tokenIn.balanceOf(ALICE),
      0,
      'Unexpected starting tokenIn balance'
    );
    uint256 estimateFinalBalance = tokenWrapper.getTokenInForTokenOut(
      aTokenBalance
    );

    uint256 deadline = block.timestamp + 100;
    bytes32 digest = keccak256(
      abi.encodePacked(
        hex'1901',
        IAToken(aTokenOut).DOMAIN_SEPARATOR(),
        keccak256(
          abi.encode(
            PERMIT_TYPEHASH,
            ALICE,
            address(tokenWrapper),
            aTokenBalance,
            IAToken(aTokenOut).nonces(ALICE),
            deadline
          )
        )
      )
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_KEY, digest);
    BaseTokenWrapper.PermitSignature memory signature = BaseTokenWrapper
      .PermitSignature(deadline, v, r, s);

    vm.startPrank(ALICE);
    tokenWrapper.withdrawTokenWithPermit(aTokenBalance, ALICE, signature);
    vm.stopPrank();

    assertEq(
      IAToken(aTokenOut).balanceOf(ALICE),
      0,
      'Unexpected ending aToken balance'
    );
    assertLe(
      estimateFinalBalance - tokenIn.balanceOf(ALICE),
      1,
      'Unexpected ending tokenIn balance'
    );
  }

  function testRescueTokens() public {}

  function _dealTokenIn(address user, uint256 amount) internal virtual {
    deal(tokenWrapper.TOKEN_IN(), user, amount);
  }
}
