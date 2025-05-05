// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

interface IERC20Extended is IERC20 {
    function decimals() external view returns (uint8);

    function getCurrentPrice() external view returns (uint tokensPerETH);
}

/// @notice Shared configuration between scripts
contract Config {
    /// @dev Default token addresses (Anvil example)
    IERC20Extended public token0;
    IERC20Extended public token1;

    IERC20Extended public moonNinjaToken;
    IERC20Extended public WETH;

    IHooks public hookContract;

    Currency public currency0;
    Currency public currency1;

    bool private _initialized;

    function setConfig(address _moonNinjaToken, address _WETH) internal {
        require(!_initialized, "Already initialized");
        _initialized = true;
        moonNinjaToken = IERC20Extended(_moonNinjaToken);
        WETH = IERC20Extended(_WETH);
        hookContract = IHooks(address(0x0));

        if (_moonNinjaToken <= _WETH) {
            token0 = IERC20Extended(_moonNinjaToken);
            token1 = IERC20Extended(_WETH);
        } else {
            token0 = IERC20Extended(_WETH);
            token1 = IERC20Extended(_moonNinjaToken);
        }

        currency0 = Currency.wrap(address(token0));
        currency1 = Currency.wrap(address(token1));
    }
}
