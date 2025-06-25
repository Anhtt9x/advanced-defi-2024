// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {IUniswapV2Pair} from
    "../../../src/interfaces/uniswap-v2/IUniswapV2Pair.sol";
import {IERC20} from "../../../src/interfaces/IERC20.sol";

contract UniswapV2Arb2 {
    struct FlashSwapData {
        // Caller of flashSwap (msg.sender inside flashSwap)
        address caller;
        // Pair to flash swap from
        address pair0;
        // Pair to swap from
        address pair1;
        // True if flash swap is token0 in and token1 out
        bool isZeroForOne;
        // Amount in to repay flash swap
        uint256 amountIn;
        // Amount to borrow from flash swap
        uint256 amountOut;
        // Revert if profit is less than this minimum
        uint256 minProfit;
    }

    // Exercise 1
    // - Flash swap to borrow tokenOut
    /**
     * @param pair0 Pair contract to flash swap
     * @param pair1 Pair contract to swap
     * @param isZeroForOne True if flash swap is token0 in and token1 out
     * @param amountIn Amount in to repay flash swap
     * @param minProfit Minimum profit that this arbitrage must make
     */
    function flashSwap(
        address pair0,
        address pair1,
        bool isZeroForOne,
        uint256 amountIn,
        uint256 minProfit
    ) external {
        // Write your code here
        // Don’t change any other code
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair0).getReserves();

        uint256 amount0Out = isZeroForOne ?
                            getAmountOut(amountIn, reserve0, reserve1)
                            : getAmountOut(amountIn, reserve1, reserve0);

        bytes memory data = abi.encode(
            FlashSwapData({
                caller: msg.sender,
                pair0: pair0,
                pair1: pair1,
                isZeroForOne: isZeroForOne,
                amountIn: amountIn,
                amountOut: amount0Out,
                minProfit: minProfit
            })
        );

        IUniswapV2Pair(pair0).swap({
            amount0Out: isZeroForOne ? 0 : amount0Out,
            amount1Out: isZeroForOne ? amount0Out : 0,
            to: address(this),
            data: data
        });

        // Hint - use getAmountOut to calculate amountOut to borrow
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0Out,
        uint256 amount1Out,
        bytes calldata data
    ) external {
        // Write your code here
        // Don’t change any other code
        FlashSwapData memory params = abi.decode(data, (FlashSwapData));

        address token0 = IUniswapV2Pair(params.pair0).token0();
        address token1 = IUniswapV2Pair(params.pair0).token1();
        (address tokenIn, address tokenOut) = params.isZeroForOne
            ? (token0, token1)
            : (token1, token0);

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(params.pair1).getReserves();
        uint256 amountOut = params.isZeroForOne 
                            ? getAmountOut(params.amount0Out, reserve1, reserve0) 
                            : getAmountOut(params.amount1Out, reserve0, reserve1);


            IERC20(tokenOut).transfer(
                params.pair1,
                params.amountOut
            );

        IUniswapV2Pair(params.pair1).swap({
            amount0Out: params.isZeroForOne ? params.amountOut : 0,
            amount1Out: params.isZeroForOne ? 0 : params.amountOut,
            to: address(this),
            data: ""
        });

        IERC20(tokenIn).transfer(
            params.pair0,
            params.amountIn
        );

        uint256 profit = amount0Out - params.amountIn;
        require(profit >= params.minProfit, "UniswapV2Arb2: Insufficient profit");
        IERC20(tokenOut).transfer(params.caller, profit);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
