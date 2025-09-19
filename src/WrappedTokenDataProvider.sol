// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {Ownable} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/Ownable.sol';
import {IBaseTokenWrapper} from './interfaces/IBaseTokenWrapper.sol';
import {IPoolAddressesProvider} from 'aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {DataTypes} from 'aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol';
import {IERC20Detailed} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {AggregatorInterface} from 'lib/aave-v3-core/contracts/dependencies/chainlink/AggregatorInterface.sol';

contract WrappedTokenDataProvider is Ownable {

    struct TokenDetails {
        address token;
        uint256 balance;
        int256 latestAnswer;
        uint8 decimals;
        string name;
        string symbol;
    }

    struct WrappedToken {
        TokenDetails tokenIn;
        TokenDetails tokenOut;
        address tokenWrapperContract;
    }

    struct WrappedTokenConfig {
        address tokenInOracle;
        address tokenOutOracle;
        address tokenWrapperContract;
    }

    mapping(address => WrappedTokenConfig[]) public wrappedTokenConfigMap;

    constructor(address owner) {
        transferOwnership(owner);
    }

    function addTokenWrapperConfig(address poolAddress, address tokenInOracleAddress, address tokenOutOracleAddress, address tokenWrapperContractAddress) external onlyOwner {
        address tokenWrapperPoolAddress = address(IBaseTokenWrapper(tokenWrapperContractAddress).POOL());
        require(tokenWrapperPoolAddress == poolAddress, 'Invalid pool address for provided token wrapper contract');

        wrappedTokenConfigMap[poolAddress].push(WrappedTokenConfig({
            tokenInOracle: tokenInOracleAddress,
            tokenOutOracle: tokenOutOracleAddress,
            tokenWrapperContract: tokenWrapperContractAddress
        }));
    }

    function getWrappedTokenData(address poolAddress, address user) external view returns (WrappedToken[] memory) {
        WrappedTokenConfig[] memory wrappedTokenConfigs = wrappedTokenConfigMap[poolAddress];
        if (wrappedTokenConfigs.length == 0) {
            return new WrappedToken[](0);
        }

        WrappedToken[] memory wrappedTokens = new WrappedToken[](wrappedTokenConfigs.length);

        for (uint256 i = 0; i < wrappedTokenConfigs.length; i++) {
            WrappedToken memory wrappedToken;
            WrappedTokenConfig memory wrappedTokenConfig = wrappedTokenConfigs[i];

            address wrapper = wrappedTokenConfig.tokenWrapperContract;
            address tokenIn = IBaseTokenWrapper(wrapper).TOKEN_IN();
            address tokenOut = IBaseTokenWrapper(wrapper).TOKEN_OUT();

            wrappedToken.tokenIn = getTokenDetails(tokenIn, wrappedTokenConfig.tokenInOracle, user);
            wrappedToken.tokenOut = getTokenDetails(tokenOut, wrappedTokenConfig.tokenOutOracle, user);

            wrappedToken.tokenWrapperContract = wrapper;

            wrappedTokens[i] = wrappedToken;
        }

        return wrappedTokens;
    }

    function getTokenDetails(address token, address oracle, address user) internal view returns (TokenDetails memory) {
        IERC20Detailed tokenInstance = IERC20Detailed(token);
        return TokenDetails({
            token: token,
            decimals: tokenInstance.decimals(),
            name: tokenInstance.name(),
            symbol: tokenInstance.symbol(),
            balance: tokenInstance.balanceOf(user),
            latestAnswer: AggregatorInterface(oracle).latestAnswer()
        });
    }
}