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

import {PositionInfo, PositionInfoLibrary} from "@uniswap/v4-periphery/src/libraries/PositionInfoLibrary.sol";

contract MNLiquidityManager is Script, Constants, Config, Initializable {
    using CurrencyLibrary for Currency;

    /////////////////////////////////////
    // --- Parameters to Configure --- //
    /////////////////////////////////////

    // --- pool configuration --- //
    // fees paid by swappers that accrue to liquidity providers
    uint24 lpFee; // 0.30%
    int24 tickSpacing;

    // starting price of the pool, in sqrtPriceX96
    uint160 startingPrice; // floor(sqrt(1) * 2^96)

    // --- liquidity position configuration --- //
    uint256 public token0Amount;
    uint256 public token1Amount;

    // range of the position
    int24 tickLower;
    int24 tickUpper;

    uint8 private constant DECIMALS_BASE = 18;

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
        tickLower = -600_000; // must be a multiple of tickSpacing
        tickUpper = 600_000;
    }

    // function initLiquidity() external returns (uint256 tokenId) {
    //     require(
    //         msg.sender == address(moonNinjaToken),
    //         "Must be called by A MoonNinja token"
    //     );

    //     uint256 tokensPerEth = moonNinjaToken.getCurrentPrice();

    //     token0Amount = token0.balanceOf(address(moonNinjaToken));
    //     token1Amount = token1.balanceOf(address(moonNinjaToken));

    //     // transfer tokens to the contract
    //     token0.transferFrom(
    //         address(moonNinjaToken),
    //         address(this),
    //         token0Amount
    //     );
    //     token1.transferFrom(
    //         address(moonNinjaToken),
    //         address(this),
    //         token1Amount
    //     );

    //     token0Amount = token0.balanceOf(address(this));
    //     token1Amount = token1.balanceOf(address(this));

    //     console.log("Token0 amount: ", token0Amount);
    //     console.log("Token1 amount: ", token1Amount);

    //     console.log("Tokens transferred to contract");

    //     console.log("Tokens per ETH: ", tokensPerEth);
    //     startingPrice = encodeSqrtRatioX96(token1Amount, token0Amount);

    //     console.log("Starting price: ", startingPrice);

    //     PoolKey memory pool = PoolKey({
    //         currency0: currency0,
    //         currency1: currency1,
    //         fee: lpFee,
    //         tickSpacing: tickSpacing,
    //         hooks: hookContract
    //     });
    //     bytes memory hookData = new bytes(0);

    //     // --------------------------------- //

    //     // Converts token amounts to liquidity units
    //     uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
    //         startingPrice,
    //         TickMath.getSqrtPriceAtTick(tickLower),
    //         TickMath.getSqrtPriceAtTick(tickUpper),
    //         token0Amount,
    //         token1Amount
    //     );

    //     // slippage limits
    //     uint256 amount0Max = token0Amount + 1 wei;
    //     uint256 amount1Max = token1Amount + 1 wei;

    //     (
    //         bytes memory actions,
    //         bytes[] memory mintParams
    //     ) = _mintLiquidityParams(
    //             pool,
    //             tickLower,
    //             tickUpper,
    //             liquidity,
    //             amount0Max,
    //             amount1Max,
    //             address(this),
    //             hookData
    //         );

    //     // multicall parameters
    //     bytes[] memory params = new bytes[](2);

    //     // initialize pool
    //     params[0] = abi.encodeWithSelector(
    //         posm.initializePool.selector,
    //         pool,
    //         startingPrice,
    //         hookData
    //     );

    //     // mint liquidity
    //     params[1] = abi.encodeWithSelector(
    //         posm.modifyLiquidities.selector,
    //         abi.encode(actions, mintParams),
    //         block.timestamp + 60
    //     );

    //     // if the pool is an ETH pair, native tokens are to be transferred
    //     uint256 valueToPass = currency0.isAddressZero() ? amount0Max : 0;

    //     tokenApprovals();

    //     // multicall to atomically create pool & add liquidity
    //     posm.multicall(params);

    //     // bytes[] memory results = posm.multicall{value: valueToPass}(params);
    //     // uint256 tokenId = abi.decode(results[0], (uint256));
    //     // console.log("Token ID: ", tokenId);

    //     uint256 postBalance0 = token0.balanceOf(address(this));
    //     uint256 postBalance1 = token1.balanceOf(address(this));

    //     console.log("Post Balance 0: ", postBalance0);
    //     console.log("Post Balance 1: ", postBalance1);

    //     console.log("token0 address: ", address(token0));
    //     console.log("token1 address: ", address(token1));
    //     console.log("moonNinjaToken address: ", address(moonNinjaToken));
    //     console.log("WETH address: ", address(WETH));

    //     tokenId = 69;
    // }

    function initLiquidity() external returns (uint256 tokenId) {
        require(
            msg.sender == address(moonNinjaToken), // Still seems unusual, ensure caller context is correct
            "Must be called by A MoonNinja token"
        );

        // --- Get initial balances from the caller (moonNinjaToken contract address) ---
        uint256 initialToken0Amount = token0.balanceOf(address(moonNinjaToken));
        uint256 initialToken1Amount = token1.balanceOf(address(moonNinjaToken));

        console.log("Initial Token0 amount: ", initialToken0Amount);
        console.log("Initial Token1 amount: ", initialToken1Amount);

        // --- Transfer tokens TO this contract ---
        token0.transferFrom(
            address(moonNinjaToken),
            address(this),
            initialToken0Amount
        );
        token1.transferFrom(
            address(moonNinjaToken),
            address(this),
            initialToken1Amount
        );

        // --- Get ACTUAL balances held by THIS contract ---
        // These are the amounts we have available to provide liquidity
        token0Amount = token0.balanceOf(address(this));
        token1Amount = token1.balanceOf(address(this));

        console.log("Available Token0 (WETH) amount: ", token0Amount);
        console.log("Available Token1 (MoonNinja) amount: ", token1Amount);

        // --- *** CHOOSE the starting price *** ---
        // Set the price to correspond to a tick WITHIN your range [-600, 600].
        // Example: Target the middle tick (0), which means a price ratio of 1.
        int24 targetTick = 105000; // Or choose another tick within [-600, 600] like -300, 300, etc.
        // Ensure targetTick is a multiple of tickSpacing (60). 0 is valid.

        if (token1 == WETH) {
            targetTick = -targetTick; // Invert the tick if token1 is WETH
        }

        require(
            targetTick % tickSpacing == 0,
            "Target tick not multiple of spacing"
        );
        require(
            targetTick >= tickLower && targetTick <= tickUpper,
            "Target tick outside range"
        );

        // Calculate the sqrtPriceX96 for the target tick
        uint160 targetStartingPrice = TickMath.getSqrtPriceAtTick(targetTick);
        console.log(
            "Target Starting Price (sqrtPriceX96): ",
            targetStartingPrice
        );
        console.log("Target Tick: ", targetTick);

        PoolKey memory pool = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: hookContract
        });
        bytes memory hookData = new bytes(0);

        // --------------------------------- //

        // --- Calculate liquidity based on AVAILABLE amounts and TARGET price ---
        // Get the sqrt prices for the bounds of your range
        uint160 sqrtPriceLower = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceUpper = TickMath.getSqrtPriceAtTick(tickUpper);

        targetStartingPrice = encodeSqrtRatioX96(token1Amount, token0Amount); // Use the price WITHIN the range

        // Calculate the maximum liquidity possible with the available tokens at the target price within the range
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            targetStartingPrice, // Use the price WITHIN the range
            sqrtPriceLower,
            sqrtPriceUpper,
            token0Amount, // Use the full available balance
            token1Amount // Use the full available balance
        );
        console.log("Calculated Liquidity: ", liquidity);

        // Check if liquidity is zero (might happen if balances are tiny or range invalid)
        require(liquidity > 0, "Calculated liquidity is zero");

        // --- Use full balances as max amounts to allow deposit ---
        // The actual amounts used will be determined by the `liquidity` value,
        // but setting max allows the function to use up to the full balance if needed.
        uint256 amount0Max = token0Amount;
        uint256 amount1Max = token1Amount;

        (bytes memory actions, bytes[] memory mintParams) = _mintLiquidityParams(
            pool,
            tickLower,
            tickUpper,
            liquidity, // Use the calculated liquidity
            amount0Max, // Allow up to the full balance
            amount1Max, // Allow up to the full balance
            address(this), // Mint NFT to this contract (or desired recipient)
            hookData
        );

        // multicall parameters
        bytes[] memory params = new bytes[](2);

        // initialize pool - Use the TARGET starting price
        params[0] = abi.encodeWithSelector(
            posm.initializePool.selector,
            pool,
            targetStartingPrice, // *** Use the price corresponding to targetTick ***
            hookData
        );

        // mint liquidity
        params[1] = abi.encodeWithSelector(
            posm.modifyLiquidities.selector,
            abi.encode(actions, mintParams),
            block.timestamp + 60
        );

        // If the pool is an ETH pair, native tokens are to be transferred (should be 0 here)
        uint256 valueToPass = currency0.isAddressZero() ? amount0Max : 0;
        valueToPass = currency1.isAddressZero() ? amount1Max : valueToPass; // Check both just in case

        tokenApprovals();

        // multicall to atomically create pool & add liquidity
        // Consider handling the return value if you need the tokenId
        posm.multicall{value: valueToPass}(params);

        /* // Optional: Decode actual tokenId if needed
        try posm.multicall{value: valueToPass}(params) returns (bytes[] memory results) {
             // Assuming MINT_POSITION is the first action returning the tokenId
             (tokenId) = abi.decode(results[0], (uint256));
             console.log("Minted Token ID: ", tokenId);
        } catch Error(string memory reason) {
            console.log("Multicall failed: ", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
             console.log("Multicall failed low level");
             revert(string(lowLevelData));
        }
        */
        if (tokenId == 0) {
            // Set dummy if not decoded
            tokenId = 69; // Keep your placeholder if needed
        }

        // Reread balances right before logging for accuracy
        uint256 finalBalance0 = token0.balanceOf(address(this));
        uint256 finalBalance1 = token1.balanceOf(address(this));

        // Use initial amounts captured at the start of the function
        // Ensure token0Amount and token1Amount hold the balances *before* the multicall

        // Log with correct labels based on token0/token1 addresses for this run
        console.log("Post Liquidity Add - Balance 0 (MNT): ", finalBalance0);
        console.log("Post Liquidity Add - Balance 1 (WETH): ", finalBalance1);
        console.log("Amount 0 (MNT) Deposited: ", token0Amount - finalBalance0);
        console.log(
            "Amount 1 (WETH) Deposited: ",
            token1Amount - finalBalance1
        );
    }

    function _getStartingPrice(
        uint256 balance0,
        uint256 balance1
    ) private view returns (uint160 sqrtPriceX96) {
        require(balance0 > 0 && balance1 > 0, "Invalid balances");

        uint256 price = (balance1 * 1e18) / balance0;
        uint256 sqrtPrice = (Math.sqrt(price) * (2 ** 96)) / 1e9;

        sqrtPriceX96 = uint160(sqrtPrice);
    }

    function encodeSqrtRatioX96(
        uint256 amount1,
        uint256 amount0
    ) internal pure returns (uint160 sqrtPriceX96) {
        require(amount0 > 0, "PriceMath: division by zero");

        // Multiply amount1 by 2^192 (left shift by 192) to preserve precision after the square root.
        uint256 ratioX192 = (amount1 << 192) / amount0;
        uint256 sqrtRatio = Math.sqrt(ratioX192);
        require(sqrtRatio <= type(uint160).max, "PriceMath: sqrt overflow");
        sqrtPriceX96 = uint160(sqrtRatio);
    }

    function _normalizeAmount(
        uint256 amount
    ) private view returns (uint256 normalizedAmount) {
        uint8 decimals = moonNinjaToken.decimals();

        if (decimals == DECIMALS_BASE) {
            return amount;
        } else if (decimals > DECIMALS_BASE) {
            return amount / (10 ** (decimals - DECIMALS_BASE));
        } else if (decimals < DECIMALS_BASE) {
            return amount * (10 ** (DECIMALS_BASE - decimals));
        }
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
            //uint8(Actions.SWEEP)
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

        // Currency currency = token0 == moonNinjaToken
        //     ? poolKey.currency0
        //     : poolKey.currency1;

        // params[2] = abi.encode(
        //     currency,
        //     address(0x0B15b524011cDF374B87Bd3ED0c844F8948B8608)
        // );
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
            console.log("approved token0");
        }
        if (!currency1.isAddressZero()) {
            token1.approve(address(PERMIT2), type(uint256).max);
            PERMIT2.approve(
                address(token1),
                address(posm),
                type(uint160).max,
                type(uint48).max
            );
            console.log("approved token1");
        }
    }
}
