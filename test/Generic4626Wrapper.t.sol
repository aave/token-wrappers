// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {IDefaultInterestRateStrategyV2} from 'aave-v3-core/contracts/interfaces/IDefaultInterestRateStrategyV2.sol';
import {IAaveOracle} from 'aave-v3-core/contracts/interfaces/IAaveOracle.sol';
import {MockAggregator} from 'aave-v3-core/contracts/mocks/oracle/CLAggregators/MockAggregator.sol';
import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {IPoolConfigurator} from 'aave-v3-core/contracts/interfaces/IPoolConfigurator.sol';
import {ConfiguratorInputTypes} from 'aave-v3-core/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol';
import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {MockERC4626} from './mocks/MockERC4626.sol';
import {MockERC20} from './mocks/MockERC20.sol';
import {BaseTokenWrapperTest} from './BaseTokenWrapper.t.sol';

import {Generic4626Wrapper} from 'src/Generic4626Wrapper.sol';

contract Generic4626WrapperTest is BaseTokenWrapperTest {
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
    borrowSupported = true;
    collateralAsset = AaveV3EthereumAssets.WETH_UNDERLYING;

    _listAsset(wrapped);

    // Supply some of the new asset to pool
    uint256 collateralAmount = 1000e18;
    deal(wrapped, address(this), collateralAmount);
    IERC20(wrapped).approve(address(pool), collateralAmount);
    IPool(pool).supply(wrapped, collateralAmount, address(this), 0);

    aTokenOut = IPool(pool).getReserveData(wrapped).aTokenAddress;
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

  function _listAsset(address underlying) internal {
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
      underlyingAsset: underlying,
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
    POOL_CONFIGURATOR.setReserveActive(underlying, true);
    POOL_CONFIGURATOR.setReserveBorrowing(underlying, true);

    // Set asset oracle
    MockAggregator oracle = new MockAggregator(1);
    address[] memory assets = new address[](1);
    assets[0] = underlying;
    address[] memory sources = new address[](1);
    sources[0] = address(oracle);
    AAVE_ORACLE.setAssetSources(assets, sources);
    vm.stopPrank();
  }
}
