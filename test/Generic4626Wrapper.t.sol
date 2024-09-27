// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;
import 'forge-std/console2.sol';

import {DataTypes} from 'aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol';
import {IERC20} from '../src/dependencies/IERC20.sol';
import {ERC20} from '../src/dependencies/ERC20.sol';
import {IERC20WithPermit} from 'aave-v3-core/contracts/interfaces/IERC20WithPermit.sol';
import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {IPoolConfigurator} from 'aave-v3-core/contracts/interfaces/IPoolConfigurator.sol';
import {ConfiguratorInputTypes} from 'aave-v3-core/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol';
import {IAToken} from 'aave-v3-core/contracts/interfaces/IAToken.sol';
import {Generic4626Wrapper} from '../src/Generic4626Wrapper.sol';
import {ICreditDelegationToken} from '../src/interfaces/ICreditDelegationToken.sol';
import {IBaseTokenWrapper} from '../src/interfaces/IBaseTokenWrapper.sol';
import {ERC4626} from '../src/dependencies/ERC4626.sol';
import {MockERC4626} from './mocks/MockERC4626.sol';
import {MockERC20} from './mocks/MockERC20.sol';
import {SigUtils} from './utils/SigUtils.sol';
import {BaseTokenWrapperTest} from './BaseTokenWrapper.t.sol';

contract Generic4626WrapperTest is BaseTokenWrapperTest {
  address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  ERC20 USDSToken;
  ERC4626 SUSDSToken;
  address USDS;
  address SUSDS;
  address constant POOL_CONFIGURATOR =
    0x64b761D848206f447Fe2dd461b0c635Ec39EbB27;
  address constant ADMIN = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;

  function setUp() public {
    vm.createSelectFork(vm.envString('ETH_RPC_URL'), 20784588);
    USDSToken = new ERC20('USDS', 'USDS');
    SUSDSToken = new MockERC4626(USDSToken);
    USDS = address(USDSToken);
    SUSDS = address(SUSDSToken);

    /*
    vm.createSelectFork(
      'https://rpc.tenderly.co/fork/881012fd-267f-41dc-93ba-8eb025b8bce2'
    );
    */
    pool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    tokenWrapper = new Generic4626Wrapper(USDS, SUSDS, pool, OWNER);
    tokenInDecimals = 18;
    permitSupported = true;

    ConfiguratorInputTypes.InitReserveInput[]
      memory reserveInputs = new ConfiguratorInputTypes.InitReserveInput[](1);
    reserveInputs[0] = ConfiguratorInputTypes.InitReserveInput({
      aTokenImpl: 0x7EfFD7b47Bfd17e52fB7559d3f924201b9DbfF3d,
      stableDebtTokenImpl: 0x15C5620dfFaC7c7366EED66C20Ad222DDbB1eD57,
      variableDebtTokenImpl: 0xaC725CB59D16C81061BDeA61041a8A5e73DA9EC6,
      underlyingAssetDecimals: ERC20(tokenWrapper.TOKEN_OUT()).decimals(),
      interestRateStrategyAddress: 0x847A3364Cc5fE389283bD821cfC8A477288D9e82,
      underlyingAsset: tokenWrapper.TOKEN_OUT(),
      treasury: 0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c,
      incentivesController: 0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb,
      aTokenName: 'AaveSUSDS',
      aTokenSymbol: 'ASUSDS',
      variableDebtTokenName: 'VariableDebtSUSDS',
      variableDebtTokenSymbol: 'VSUSDS',
      stableDebtTokenName: 'StableDebtSUSDS',
      stableDebtTokenSymbol: 'SSUSDS',
      params: bytes('')
    });

    vm.startPrank(ADMIN);
    IPoolConfigurator(POOL_CONFIGURATOR).initReserves(reserveInputs);
    IPoolConfigurator(POOL_CONFIGURATOR).setReserveActive(
      tokenWrapper.TOKEN_OUT(),
      true
    );
    IPoolConfigurator(POOL_CONFIGURATOR).setSupplyCap(
      tokenWrapper.TOKEN_OUT(),
      type(uint256).max
    );
    IPoolConfigurator(POOL_CONFIGURATOR).setBorrowCap(
      tokenWrapper.TOKEN_OUT(),
      type(uint256).max
    );
    IPoolConfigurator(POOL_CONFIGURATOR).setReserveBorrowing(
      tokenWrapper.TOKEN_OUT(),
      true
    );
    IPoolConfigurator(POOL_CONFIGURATOR).configureReserveAsCollateral(
      SUSDS,
      1e18,
      1e18,
      1e18
    );
    vm.stopPrank();

    // Try seeing if borrowing is enabled on the new asset
    DataTypes.ReserveData memory reserveData = IPool(pool).getReserveData(
      tokenWrapper.TOKEN_OUT()
    );

    uint256 collateralAmount = 1000e18;
    deal(SUSDS, address(this), collateralAmount);
    IERC20(SUSDS).approve(address(pool), collateralAmount);
    IPool(pool).supply(SUSDS, collateralAmount, address(this), 0);

    aTokenOut = IPool(pool).getReserveData(SUSDS).variableDebtTokenAddress;
  }

  function testConstructor() public override {
    Generic4626Wrapper tempTokenWrapper = new Generic4626Wrapper(
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
