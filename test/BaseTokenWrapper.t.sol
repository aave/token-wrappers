// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {IAToken} from 'aave-v3-core/contracts/interfaces/IAToken.sol';
import {MintableERC20} from 'aave-v3-core/contracts/mocks/tokens/MintableERC20.sol';
import {BaseTokenWrapper} from '../src/BaseTokenWrapper.sol';
import {IBaseTokenWrapper} from '../src/interfaces/IBaseTokenWrapper.sol';

interface IERC2612 {
  function nonces(address owner) external view returns (uint256);

  function DOMAIN_SEPARATOR() external view returns (bytes32);

  function permit(
    address owner,
    address spender,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;
}

abstract contract BaseTokenWrapperTest is Test {
  bytes32 constant PERMIT_TYPEHASH =
    keccak256(
      'Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'
    );
  uint256 constant DEAL_AMOUNT = 1_000;
  uint16 constant REFERRAL_CODE = 0;
  uint256 constant MAX_DEAL_AMOUNT = 1_000;
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
    uint256 suppliedAmount = tokenWrapper.supplyToken(
      dealAmountScaled,
      ALICE,
      REFERRAL_CODE
    );
    vm.stopPrank();

    assertEq(tokenIn.balanceOf(ALICE), 0, 'Unexpected ending tokenIn balance');
    assertEq(
      suppliedAmount,
      IAToken(aTokenOut).balanceOf(ALICE),
      'Unexpected supply return/balance mismatch'
    );
    assertLe(
      estimateFinalBalance - IAToken(aTokenOut).balanceOf(ALICE),
      1,
      'Unexpected ending aToken balance'
    );
  }

  function testSupplyTokenToOther() public {
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
    assertEq(
      IAToken(aTokenOut).balanceOf(BOB),
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
    uint256 suppliedAmount = tokenWrapper.supplyToken(
      dealAmountScaled,
      BOB,
      REFERRAL_CODE
    );
    vm.stopPrank();

    assertEq(tokenIn.balanceOf(ALICE), 0, 'Unexpected ending tokenIn balance');
    assertEq(
      suppliedAmount,
      IAToken(aTokenOut).balanceOf(BOB),
      'Unexpected supply return/balance mismatch'
    );
    assertLe(
      estimateFinalBalance - IAToken(aTokenOut).balanceOf(BOB),
      1,
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
            IERC2612(address(tokenIn)).nonces(ALICE),
            deadline
          )
        )
      )
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_KEY, digest);
    IBaseTokenWrapper.PermitSignature memory signature = IBaseTokenWrapper
      .PermitSignature(deadline, v, r, s);

    if (permitSupported) {
      vm.startPrank(ALICE);
      uint256 suppliedAmount = tokenWrapper.supplyTokenWithPermit(
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
        suppliedAmount,
        IAToken(aTokenOut).balanceOf(ALICE),
        'Unexpected supply return/balance mismatch'
      );
      assertLe(
        estimateFinalBalance - IAToken(aTokenOut).balanceOf(ALICE),
        1,
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

  function testPermitGriefingSupplyTokenWithPermit() public {
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
            IERC2612(address(tokenIn)).nonces(ALICE),
            deadline
          )
        )
      )
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_KEY, digest);
    IBaseTokenWrapper.PermitSignature memory signature = IBaseTokenWrapper
      .PermitSignature(deadline, v, r, s);

    if (permitSupported) {
      vm.startPrank(BOB);
      IERC2612(address(tokenIn)).permit(
        ALICE,
        address(tokenWrapper),
        dealAmountScaled,
        deadline,
        v,
        r,
        s
      );
      vm.stopPrank();
      vm.startPrank(ALICE);
      uint256 suppliedAmount = tokenWrapper.supplyTokenWithPermit(
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
        suppliedAmount,
        IAToken(aTokenOut).balanceOf(ALICE),
        'Unexpected supply return/balance mismatch'
      );
      assertLe(
        estimateFinalBalance - IAToken(aTokenOut).balanceOf(ALICE),
        1,
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

  function testRevertSupplyTokenZeroAmount() public {
    vm.prank(ALICE);
    vm.expectRevert('INSUFFICIENT_AMOUNT_TO_SUPPLY');
    tokenWrapper.supplyToken(0, ALICE, REFERRAL_CODE);
  }

  function testRevertSupplyTokenInsufficientReceived() public {
    IERC20 tokenIn = IERC20(tokenWrapper.TOKEN_IN());
    _dealTokenIn(ALICE, 1);

    vm.startPrank(ALICE);
    tokenIn.approve(address(tokenWrapper), 1);
    vm.expectRevert('INSUFFICIENT_WRAPPED_TOKEN_RECEIVED');
    tokenWrapper.supplyToken(1, ALICE, REFERRAL_CODE);
    vm.stopPrank();
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
    uint256 withdrawnAmount = tokenWrapper.withdrawToken(aTokenBalance, ALICE);
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
    assertLe(
      withdrawnAmount - tokenIn.balanceOf(ALICE),
      1,
      'Unexpected withdraw return/balance mismatch'
    );
  }

  function testWithdrawTokenInsufficientBalance() public {
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
    vm.expectRevert('INSUFFICIENT_BALANCE_TO_WITHDRAW');
    tokenWrapper.withdrawToken(aTokenBalance + 1, ALICE);
    vm.stopPrank();
  }

  function testWithdrawTokenMaxValue() public {
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
    IAToken(aTokenOut).approve(address(tokenWrapper), type(uint256).max);
    uint256 withdrawnAmount = tokenWrapper.withdrawToken(
      type(uint256).max,
      ALICE
    );
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

    assertLe(
      withdrawnAmount - tokenIn.balanceOf(ALICE),
      1,
      'Unexpected withdraw return/balance mismatch'
    );
  }

  function testWithdrawTokenToOther() public {
    testSupplyToken();
    IERC20 tokenIn = IERC20(tokenWrapper.TOKEN_IN());

    uint256 aTokenBalance = IAToken(aTokenOut).balanceOf(ALICE);
    assertGt(aTokenBalance, 0, 'Unexpected starting aToken balance');
    assertEq(
      tokenIn.balanceOf(ALICE),
      0,
      'Unexpected starting tokenIn balance'
    );
    assertEq(tokenIn.balanceOf(BOB), 0, 'Unexpected starting tokenIn balance');
    uint256 estimateFinalBalance = tokenWrapper.getTokenInForTokenOut(
      aTokenBalance
    );

    vm.startPrank(ALICE);
    IAToken(aTokenOut).approve(address(tokenWrapper), aTokenBalance);
    uint256 withdrawnAmount = tokenWrapper.withdrawToken(aTokenBalance, BOB);
    vm.stopPrank();

    assertEq(
      IAToken(aTokenOut).balanceOf(ALICE),
      0,
      'Unexpected ending aToken balance'
    );
    assertEq(tokenIn.balanceOf(ALICE), 0, 'Unexpected ending tokenIn balance');
    assertLe(
      estimateFinalBalance - tokenIn.balanceOf(BOB),
      1,
      'Unexpected ending tokenIn balance'
    );
    assertLe(
      withdrawnAmount - tokenIn.balanceOf(BOB),
      1,
      'Unexpected withdraw return/balance mismatch'
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
    IBaseTokenWrapper.PermitSignature memory signature = IBaseTokenWrapper
      .PermitSignature(deadline, v, r, s);

    vm.startPrank(ALICE);
    uint256 withdrawnAmount = tokenWrapper.withdrawTokenWithPermit(
      aTokenBalance,
      ALICE,
      signature
    );
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
    assertLe(
      withdrawnAmount - tokenIn.balanceOf(ALICE),
      1,
      'Unexpected withdraw return/balance mismatch'
    );
  }

  function testPermitGriefingWithdrawTokenWithPermit() public {
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
    IBaseTokenWrapper.PermitSignature memory signature = IBaseTokenWrapper
      .PermitSignature(deadline, v, r, s);

    vm.startPrank(BOB);
    IERC2612(aTokenOut).permit(
      ALICE,
      address(tokenWrapper),
      aTokenBalance,
      deadline,
      v,
      r,
      s
    );
    vm.stopPrank();

    vm.startPrank(ALICE);
    uint256 withdrawnAmount = tokenWrapper.withdrawTokenWithPermit(
      aTokenBalance,
      ALICE,
      signature
    );
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
    assertLe(
      withdrawnAmount - tokenIn.balanceOf(ALICE),
      1,
      'Unexpected withdraw return/balance mismatch'
    );
  }

  function testRevertWithdrawTokenZeroAmount() public {
    vm.prank(ALICE);
    vm.expectRevert('INSUFFICIENT_AMOUNT_TO_WITHDRAW');
    tokenWrapper.withdrawToken(0, ALICE);
  }

  function testRescueTokens() public {
    uint256 dealAmountScaled = DEAL_AMOUNT * 10 ** 18;
    MintableERC20 MOCK_TOKEN = new MintableERC20('Mock Token', 'MOCK', 18);
    MOCK_TOKEN.mint(address(tokenWrapper), dealAmountScaled);

    assertEq(
      MOCK_TOKEN.balanceOf(address(tokenWrapper)),
      dealAmountScaled,
      'Unexpected starting tokenWrapper token balance'
    );
    assertEq(
      MOCK_TOKEN.balanceOf(OWNER),
      0,
      'Unexpected starting owner token balance'
    );

    vm.prank(OWNER);
    tokenWrapper.rescueTokens(MOCK_TOKEN, OWNER, dealAmountScaled);

    assertEq(
      MOCK_TOKEN.balanceOf(address(tokenWrapper)),
      0,
      'Unexpected final tokenWrapper token balance'
    );
    assertEq(
      MOCK_TOKEN.balanceOf(OWNER),
      dealAmountScaled,
      'Unexpected final owner token balance'
    );
  }

  function testRescueETH() public {
    uint256 ethAmount = 100 ether;
    assertEq(
      address(tokenWrapper).balance,
      0,
      'Unexpected initial contract ETH balance'
    );
    vm.deal(address(tokenWrapper), ethAmount);
    assertEq(
      address(tokenWrapper).balance,
      ethAmount,
      'Unexpected post-deal ETH balance'
    );
    assertEq(OWNER.balance, 0, 'Unexpected owner ETH balance');

    vm.prank(OWNER);
    tokenWrapper.rescueETH(OWNER, ethAmount);

    assertEq(
      address(tokenWrapper).balance,
      0,
      'Unexpected post-rescue contract ETH balance'
    );
    assertEq(
      OWNER.balance,
      ethAmount,
      'Unexpected post-rescue owner ETH balance'
    );
  }

  function testRevertRescueNotOwner() public {
    MintableERC20 MOCK_TOKEN = new MintableERC20('Mock Token', 'MOCK', 18);
    vm.startPrank(ALICE);
    vm.expectRevert('Ownable: caller is not the owner');
    tokenWrapper.rescueTokens(MOCK_TOKEN, OWNER, 0);
    vm.expectRevert('Ownable: caller is not the owner');
    tokenWrapper.rescueETH(OWNER, 0);
    vm.stopPrank();
  }

  function testFuzzSupplyToken(uint256 amount, address referee) public {
    amount = bound(amount, 1, MAX_DEAL_AMOUNT);
    IERC20 tokenIn = IERC20(tokenWrapper.TOKEN_IN());

    uint256 amountScaled = amount * 10 ** tokenInDecimals;
    _dealTokenIn(ALICE, amountScaled);
    uint256 estimateFinalBalance = tokenWrapper.getTokenOutForTokenIn(
      amountScaled
    );

    vm.startPrank(ALICE);
    tokenIn.approve(address(tokenWrapper), amountScaled);
    uint256 suppliedAmount = tokenWrapper.supplyToken(
      amountScaled,
      referee,
      REFERRAL_CODE
    );
    vm.stopPrank();

    assertEq(tokenIn.balanceOf(ALICE), 0, 'Unexpected ending tokenIn balance');
    assertLe(
      estimateFinalBalance - IAToken(aTokenOut).balanceOf(referee),
      1,
      'Unexpected ending aToken balance'
    );
  }

  function testFuzzWithdrawToken(uint256 aTokenBalance) public {
    testSupplyToken();
    IERC20 tokenIn = IERC20(tokenWrapper.TOKEN_IN());
    uint256 aTokenBalanceOriginal = IAToken(aTokenOut).balanceOf(ALICE);
    aTokenBalance = bound(aTokenBalance, 1000, aTokenBalanceOriginal - 1); //using 1000 as min to ignore dust amounts
    assertGt(aTokenBalanceOriginal, 0, 'Unexpected starting aToken balance');
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
    uint256 withdrawnAmount = tokenWrapper.withdrawToken(aTokenBalance, ALICE);
    vm.stopPrank();

    assertGt(
      IAToken(aTokenOut).balanceOf(ALICE),
      0,
      'Unexpected ending aToken balance'
    );
    assertGt(tokenIn.balanceOf(ALICE), 0, 'Unexpected ending tokenIn balance');
    assertGt(withdrawnAmount, 0, 'Unexpected withdraw return/balance mismatch');
  }

  function _dealTokenIn(address user, uint256 amount) internal virtual {
    deal(tokenWrapper.TOKEN_IN(), user, amount);
  }
}
