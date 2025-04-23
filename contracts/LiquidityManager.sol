// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Minimal {
    function approve(address spender, uint amount) external returns (bool);
}

interface IUniswapV2Router02 {
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);
}

abstract contract LiquidityManager {
    event LiquidityAdded(uint tokenAmount, uint ethAmount);

    function _createAndAddLiquidity(
        address routerAddress,
        address tokenAddress,
        uint tokenAmount,
        uint ethAmount
    ) internal {
        require(tokenAmount > 0, "No tokens");
        require(ethAmount > 0, "No ETH");

        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);

        IERC20Minimal(tokenAddress).approve(routerAddress, tokenAmount);

        router.addLiquidityETH{value: ethAmount}(
            tokenAddress,
            tokenAmount,
            0,
            0,
            address(this),
            block.timestamp + 600
        );

        emit LiquidityAdded(tokenAmount, ethAmount);
    }
}
