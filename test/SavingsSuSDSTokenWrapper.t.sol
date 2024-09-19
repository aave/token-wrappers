// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;
import 'forge-std/console2.sol';

import {DataTypes} from 'aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol';
import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {BaseTokenWrapperTest} from './BaseTokenWrapper.t.sol';
import {SavingsSuSDSTokenWrapper} from '../src/SavingsSuSDSTokenWrapper.sol';
import {ICreditDelegationToken} from '../src/interfaces/ICreditDelegationToken.sol';

// frontend deposits usds and automatically converted to susds on aave
contract SavingsSuSDSTokenWrapperTest is BaseTokenWrapperTest {
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

    tokenWrapper = new SavingsSuSDSTokenWrapper(USDS, SUSDS, pool, OWNER);
    aTokenOut = AUSDS;
    tokenInDecimals = 18;
    permitSupported = true;
  }

  function testConstructor() public override {
    SavingsSuSDSTokenWrapper tempTokenWrapper = new SavingsSuSDSTokenWrapper(
      USDS,
      SUSDS,
      pool,
      OWNER
    );
    assertEq(tempTokenWrapper.TOKEN_IN(), USDS, 'Unexpected TOKEN_IN');
    assertEq(tempTokenWrapper.TOKEN_OUT(), SUSDS, 'Unexpected TOKEN_OUT');
    assertEq(address(tempTokenWrapper.POOL()), pool, 'Unexpected POOL');
    assertEq(tempTokenWrapper.owner(), OWNER, 'Unexpected owner');
    assertEq(
      IERC20(SUSDS).allowance(address(tempTokenWrapper), pool),
      type(uint256).max,
      'Unexpected TOKEN_OUT allowance'
    );
    assertEq(
      IERC20(USDS).allowance(address(tempTokenWrapper), SUSDS),
      type(uint256).max,
      'Unexpected TOKEN_IN allowance'
    );
  }

  // function testBorrow() public {
  //   address alice = makeAddr('ALICE');
  //   deal(USDS, alice, 1000e18);
  //   vm.startPrank(alice);
  //   IERC20(USDS).approve(address(pool), 1000e18);
  //   IPool(pool).supply(USDS, 1000e18, alice, 0);
  //   vm.stopPrank();

  //   // TODO: Instead of checking pool, need to check reserve contract
  //   /*
  //   assertEq(
  //     IERC20(SUSDS).balanceOf(address(pool)),
  //     1e18,
  //     'Unexpected post-deal pool USDS balance'
  //   );*/

  //   deal(WETH, address(this), 20 ether);
  //   IERC20(WETH).approve(pool, 20 ether);
  //   IPool(pool).supply(WETH, 20 ether, address(this), 0);

  //   deal(USDS, address(this), 1e18);
  //   IERC20(USDS).approve(address(pool), 1e18);
  //   IPool(pool).supply(USDS, 1e18, address(this), 0);
  //   deal(SUSDS, address(this), 1e18);
  //   IERC20(SUSDS).approve(address(pool), 1e18);
  //   IPool(pool).supply(SUSDS, 1e18, address(this), 0);

  //   uint256 amount = 1e18;
  //   uint256 amountOut = tokenWrapper.getTokenOutForTokenIn(amount);
  //   uint256 usdsBefore = IERC20(USDS).balanceOf(address(this));
  //   ICreditDelegationToken(SUSDS).approveDelegation(
  //     address(tokenWrapper),
  //     amountOut
  //   );
  //   tokenWrapper.borrowToken(amount, address(this));
  //   uint256 usdsAfter = IERC20(USDS).balanceOf(address(this));

  //   assertEq(
  //     usdsAfter,
  //     usdsBefore + amount,
  //     'Unexpected USDS balance after borrow'
  //   );
  // }

  function testBorrow() public {
    address debtToken = IPool(pool)
      .getReserveData(SUSDS)
      .variableDebtTokenAddress;

    address alice = makeAddr('ALICE');
    uint256 collateralAmount = 1000e18;

    uint256 borrowAmount = 100e18;

    deal(WETH, alice, collateralAmount);

    vm.startPrank(alice);
    IERC20(WETH).approve(address(pool), collateralAmount);
    IPool(pool).supply(WETH, collateralAmount, alice, 0);

    ICreditDelegationToken(debtToken).approveDelegation(
      address(this),
      borrowAmount
    );
    vm.stopPrank();

    // IPool(pool).borrow(SUSDS, borrowAmount, 2, 0, alice);

    // console2.log('Borrowing USDS', address(tokenWrapper));
    tokenWrapper.borrowToken(borrowAmount, address(this));

    assertEq(IERC20(SUSDS).balanceOf(address(this)), borrowAmount);
  }
}
