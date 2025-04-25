// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

/// @notice Shared configuration between scripts
contract Config {
    /// @dev Default token addresses (Anvil example)
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    IHooks public immutable hookContract;

    Currency public immutable currency0;
    Currency public immutable currency1;

    constructor() {
        token0 = IERC20(address(0x0165878A594ca255338adfa4d48449f69242Eb8F));
        token1 = IERC20(address(0xa513E6E4b8f2a923D98304ec87F64353C4D5C853));
        hookContract = IHooks(address(0x0));

        currency0 = Currency.wrap(address(token0));
        currency1 = Currency.wrap(address(token1));
    }
}
