// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "../../../src/interfaces/IERC20.sol";
import {IUniswapV3Pool} from
    "../../../src/interfaces/uniswap-v3/IUniswapV3Pool.sol";

contract UniswapV3Flash {
    struct FlashCallbackData {
        uint256 amount0;
        uint256 amount1;
        address caller;
    }

    IUniswapV3Pool private immutable pool;
    IERC20 private immutable token0;
    IERC20 private immutable token1;

    constructor(address _pool) {
        pool = IUniswapV3Pool(_pool);
        token0 = IERC20(pool.token0());
        token1 = IERC20(pool.token1());
    }

    function flash(uint256 amount0, uint256 amount1) external {
        // Task 1 - ABI encode FlashCallbackData
        bytes memory data = abi.encode(
            FlashCallbackData({
                amount0: amount0,
                amount1: amount1,
                caller: msg.sender
            })
        );
        // Task 2 - Call IUniswapV3Pool.flash
        pool.flash(
            address(this), // recipient
            amount0, // amount0Requested
            amount1, // amount1Requested
            data // data
        );
    }

    function uniswapV3FlashCallback(
        // Pool fee x amount requested
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        // Task 3 - Check msg.sender is pool
        require(msg.sender == address(pool), "Invalid sender");
        // Task 4 - Decode data into FlashCallbackData
        FlashCallbackData memory callbackData = abi.decode(data, (FlashCallbackData));
        // Task 5  - Transfer fees from FlashCallbackData.caller
        if (fee0 > 0) {
            token0.transferFrom(
                callbackData.caller,
                address(pool),
                fee0
            );
        }
        if (fee1 > 0) {
            token1.transferFrom(
                callbackData.caller,
                address(pool),
                fee1
            );
        }

        if (callbackData.amount0 > 0) {
            // Task 6 - Transfer amount0 from FlashCallbackData.caller
            token0.transferFrom(
                callbackData.caller,
                callbackData.amount0 + fee0
            );
        }

        if (callbackData.amount1 > 0) {
            // Task 6 - Transfer amount1 from FlashCallbackData.caller
            token1.transferFrom(
                callbackData.caller,
                callbackData.amount1 + fee1
            );
        }
        // Task 6 - Repay pool, amount borrowed + fee
    }
}
