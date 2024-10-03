// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;
import 'forge-std/console2.sol';

import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {IDefaultInterestRateStrategyV2} from 'aave-v3-core/contracts/interfaces/IDefaultInterestRateStrategyV2.sol';
import {IAaveOracle} from 'aave-v3-core/contracts/interfaces/IAaveOracle.sol';
import {MockAggregator} from 'aave-v3-core/contracts/mocks/oracle/CLAggregators/MockAggregator.sol';
import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {IPoolConfigurator} from 'aave-v3-core/contracts/interfaces/IPoolConfigurator.sol';
import {ConfiguratorInputTypes} from 'aave-v3-core/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol';
import {IAToken} from 'aave-v3-core/contracts/interfaces/IAToken.sol';
import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {Generic4626Wrapper} from '../src/Generic4626Wrapper.sol';
import {ICreditDelegationToken} from '../src/interfaces/ICreditDelegationToken.sol';
import {IBaseTokenWrapper} from '../src/interfaces/IBaseTokenWrapper.sol';
import {MockERC4626} from './mocks/MockERC4626.sol';
import {MockERC20} from './mocks/MockERC20.sol';
import {SigUtils} from './utils/SigUtils.sol';
import {BaseTokenWrapperTest} from './BaseTokenWrapper.t.sol';

contract Generic4626WrapperTest is BaseTokenWrapperTest {
  address constant WETH = AaveV3EthereumAssets.WETH_UNDERLYING;
  address constant ADMIN = AaveV3Ethereum.ACL_ADMIN;
  IPoolConfigurator constant POOL_CONFIGURATOR =
    AaveV3Ethereum.POOL_CONFIGURATOR;
  IAaveOracle constant AAVE_ORACLE = AaveV3Ethereum.ORACLE;
  MockERC20 unwrappedToken;
  MockERC4626 wrappedToken;
  address unwrapped;
  address wrapped;

  function setUp() public {
    vm.createSelectFork(vm.envString('ETH_RPC_URL'), 20784588);
    pool = address(AaveV3Ethereum.POOL);
    unwrappedToken = new MockERC20('UNWRAPPED');
    wrappedToken = new MockERC4626(unwrappedToken);
    unwrapped = address(unwrappedToken);
    wrapped = address(wrappedToken);

    // Put some underlying asset into the ERC4626 vault
    unwrappedToken.approve(wrapped, 1e50);
    wrappedToken.deposit(1e50, address(this));

    // Airdrop some extra underlying asset to the vault
    deal(unwrapped, address(this), 10e18);
    unwrappedToken.transfer(wrapped, 10e18);

    tokenWrapper = new Generic4626Wrapper(unwrapped, wrapped, pool, OWNER);
    tokenInDecimals = 18;
    permitSupported = true;

    IDefaultInterestRateStrategyV2.InterestRateData
      memory interestRateData = IDefaultInterestRateStrategyV2
        .InterestRateData({
          optimalUsageRatio: 8000,
          baseVariableBorrowRate: 1000,
          variableRateSlope1: 1000,
          variableRateSlope2: 1000
        });

    ConfiguratorInputTypes.InitReserveInput[]
      memory reserveInputs = new ConfiguratorInputTypes.InitReserveInput[](1);
    reserveInputs[0] = ConfiguratorInputTypes.InitReserveInput({
      aTokenImpl: AaveV3Ethereum.DEFAULT_A_TOKEN_IMPL_REV_1,
      stableDebtTokenImpl: AaveV3Ethereum.DEFAULT_STABLE_DEBT_TOKEN_IMPL_REV_1,
      variableDebtTokenImpl: AaveV3Ethereum
        .DEFAULT_VARIABLE_DEBT_TOKEN_IMPL_REV_1,
      useVirtualBalance: true,
      interestRateStrategyAddress: AaveV3EthereumAssets
        .WETH_INTEREST_RATE_STRATEGY,
      underlyingAsset: tokenWrapper.TOKEN_OUT(),
      treasury: address(AaveV3Ethereum.COLLECTOR),
      incentivesController: AaveV3Ethereum.DEFAULT_INCENTIVES_CONTROLLER,
      aTokenName: 'AaveWrapped',
      aTokenSymbol: 'AWrapped',
      variableDebtTokenName: 'VariableDebtWrapped',
      variableDebtTokenSymbol: 'VWrapped',
      stableDebtTokenName: 'StableDebtWrapped',
      stableDebtTokenSymbol: 'SWrapped',
      params: bytes(''),
      interestRateData: abi.encode(interestRateData)
    });

    vm.startPrank(ADMIN);
    POOL_CONFIGURATOR.initReserves(reserveInputs);
    POOL_CONFIGURATOR.setReserveActive(tokenWrapper.TOKEN_OUT(), true);
    POOL_CONFIGURATOR.setReserveBorrowing(tokenWrapper.TOKEN_OUT(), true);

    // Set asset oracle
    MockAggregator oracle = new MockAggregator(1);
    address[] memory assets = new address[](1);
    assets[0] = tokenWrapper.TOKEN_OUT();
    address[] memory sources = new address[](1);
    sources[0] = address(oracle);
    AAVE_ORACLE.setAssetSources(assets, sources);
    vm.stopPrank();

    // Supply some of the new asset to pool
    uint256 collateralAmount = 1000e18;
    deal(tokenWrapper.TOKEN_OUT(), address(this), collateralAmount);
    IERC20(tokenWrapper.TOKEN_OUT()).approve(address(pool), collateralAmount);
    IPool(pool).supply(
      tokenWrapper.TOKEN_OUT(),
      collateralAmount,
      address(this),
      0
    );

    aTokenOut = IPool(pool)
      .getReserveData(tokenWrapper.TOKEN_OUT())
      .aTokenAddress;
  }

  function testConstructor() public override {
    Generic4626Wrapper tempTokenWrapper = new Generic4626Wrapper(
      unwrapped,
      wrapped,
      pool,
      OWNER
    );
    assertEq(tempTokenWrapper.TOKEN_IN(), unwrapped, 'Unexpected TOKEN_IN');
    assertEq(tempTokenWrapper.TOKEN_OUT(), wrapped, 'Unexpected TOKEN_OUT');
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

    (address alice, uint256 userPrivateKey) = makeAddrAndKey('ALICE');
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

    (address alice, uint256 userPrivateKey) = makeAddrAndKey('ALICE');
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
