// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

/// @notice Shared configuration between scripts
contract Config {
    /// @dev Default token addresses (Anvil example)
    IERC20 public token0;
    IERC20 public token1;
    IHooks public hookContract;

    Currency public currency0;
    Currency public currency1;

    bool private _initialized;

    constructor() {
        // token0 = IERC20(_moonNinjaToken);
        // token1 = IERC20(_WETH);
        // hookContract = IHooks(address(0x0));
        // currency0 = Currency.wrap(address(token0));
        // currency1 = Currency.wrap(address(token1));
        //_disableInitializers();
    }

    function setConfig(address _moonNinjaToken, address _WETH) internal {
        require(!_initialized, "Already initialized");
        _initialized = true;
        token0 = IERC20(_moonNinjaToken);
        token1 = IERC20(_WETH);
        hookContract = IHooks(address(0x0));

        currency0 = Currency.wrap(address(token0));
        currency1 = Currency.wrap(address(token1));
    }
}
