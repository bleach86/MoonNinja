// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*  __  __                   _   _ _       _       
   |  \/  |                 | \ | (_)     (_)      
   | \  / | ___   ___  _ __ |  \| |_ _ __  _  __ _ 
   | |\/| |/ _ \ / _ \| '_ \| . ` | | '_ \| |/ _` |
   | |  | | (_) | (_) | | | | |\  | | | | | | (_| |
   |_|  |_|\___/ \___/|_| |_|_| \_|_|_| |_| |\__,_|
                                         _/ |      
                                        |__/   
*/

import "forge-std/Script.sol";
import {PositionManager} from "@uniswap/v4-periphery/src/PositionManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {Constants} from "./base/Constants.sol";
import {Config} from "./base/Config.sol";

contract MNLiquidityManager is Script, Constants, Config, Initializable {
    using CurrencyLibrary for Currency;

    /////////////////////////////////////
    // --- Parameters to Configure --- //
    /////////////////////////////////////

    // --- pool configuration --- //
    // fees paid by swappers that accrue to liquidity providers
    uint24 lpFee = 3000; // 0.30%
    int24 tickSpacing = 60;

    // starting price of the pool, in sqrtPriceX96
    uint160 startingPrice = 79228162514264337593543950336; // floor(sqrt(1) * 2^96)

    // --- liquidity position configuration --- //
    uint256 public token0Amount = 1e18;
    uint256 public token1Amount = 1e18;

    // range of the position
    int24 tickLower = -600; // must be a multiple of tickSpacing
    int24 tickUpper = 600;

    /////////////////////////////////////

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _moonNinjaToken,
        address _WETH
    ) external initializer {
        Config.setConfig(_moonNinjaToken, _WETH);

        lpFee = 3000; // 0.30%
        tickSpacing = 60;
        tickLower = -600; // must be a multiple of tickSpacing
        tickUpper = 600;
    }

    function initLiquidity() external {
        require(msg.sender == address(token0), "Must be called by token0");
        // tokens should be sorted

        token0Amount = token0.balanceOf(address(token0));
        token1Amount = token1.balanceOf(address(token0));

        startingPrice = getStartingPrice(token0Amount, token1Amount);

        // transfer tokens to the contract
        token0.transferFrom(address(token0), address(this), token0Amount);
        token1.transferFrom(address(token0), address(this), token1Amount);

        PoolKey memory pool = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: hookContract
        });
        bytes memory hookData = new bytes(0);

        // --------------------------------- //

        // Converts token amounts to liquidity units
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            startingPrice,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            token0Amount,
            token1Amount
        );

        // slippage limits
        uint256 amount0Max = token0Amount + 1 wei;
        uint256 amount1Max = token1Amount + 1 wei;

        (
            bytes memory actions,
            bytes[] memory mintParams
        ) = _mintLiquidityParams(
                pool,
                tickLower,
                tickUpper,
                liquidity,
                amount0Max,
                amount1Max,
                address(this),
                hookData
            );

        // multicall parameters
        bytes[] memory params = new bytes[](2);

        // initialize pool
        params[0] = abi.encodeWithSelector(
            posm.initializePool.selector,
            pool,
            startingPrice,
            hookData
        );

        // mint liquidity
        params[1] = abi.encodeWithSelector(
            posm.modifyLiquidities.selector,
            abi.encode(actions, mintParams),
            block.timestamp + 60
        );

        // if the pool is an ETH pair, native tokens are to be transferred
        uint256 valueToPass = currency0.isAddressZero() ? amount0Max : 0;

        return;

        vm.startBroadcast();
        tokenApprovals();
        vm.stopBroadcast();

        // multicall to atomically create pool & add liquidity
        vm.broadcast();
        posm.multicall{value: valueToPass}(params);
    }

    function getStartingPrice(
        uint256 balance0,
        uint256 balance1
    ) public pure returns (uint160 sqrtPriceX96) {
        uint256 price = balance0 / balance1;
        uint256 sqrtPrice = Math.sqrt(price) * (2 ** 96);

        sqrtPriceX96 = uint160(sqrtPrice);
    }

    /// @dev helper function for encoding mint liquidity operation
    /// @dev does NOT encode SWEEP, developers should take care when minting liquidity on an ETH pair
    function _mintLiquidityParams(
        PoolKey memory poolKey,
        int24 _tickLower,
        int24 _tickUpper,
        uint256 liquidity,
        uint256 amount0Max,
        uint256 amount1Max,
        address recipient,
        bytes memory hookData
    ) internal pure returns (bytes memory, bytes[] memory) {
        bytes memory actions = abi.encodePacked(
            uint8(Actions.MINT_POSITION),
            uint8(Actions.SETTLE_PAIR)
        );

        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(
            poolKey,
            _tickLower,
            _tickUpper,
            liquidity,
            amount0Max,
            amount1Max,
            recipient,
            hookData
        );
        params[1] = abi.encode(poolKey.currency0, poolKey.currency1);
        return (actions, params);
    }

    function tokenApprovals() public {
        if (!currency0.isAddressZero()) {
            token0.approve(address(PERMIT2), type(uint256).max);
            PERMIT2.approve(
                address(token0),
                address(posm),
                type(uint160).max,
                type(uint48).max
            );
        }
        if (!currency1.isAddressZero()) {
            token1.approve(address(PERMIT2), type(uint256).max);
            PERMIT2.approve(
                address(token1),
                address(posm),
                type(uint160).max,
                type(uint48).max
            );
        }
    }
}
