// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IUniswapV2Pair} from
    "../../../src/interfaces/uniswap-v2/IUniswapV2Pair.sol";
import {IERC20} from "../../../src/interfaces/IERC20.sol";

error InvalidToken();

contract UniswapV2FlashSwap {
    IUniswapV2Pair private immutable pair;
    address private immutable token0;
    address private immutable token1;

    constructor(address _pair) {
        pair = IUniswapV2Pair(_pair);
        token0 = pair.token0();
        token1 = pair.token1();
    }

    function flashSwap(address token, uint256 amount) external {
        if (token != token0 && token != token1) {
            revert InvalidToken();
        }

        // Write your code here
        // Don’t change any other code

        // 1. Determine amount0Out and amount1Out
        (uint256 amount0Out, uint256 amount1Out) = token == token0 ? (amount, uint256(0)) : (uint256(0), amount);

        // 2. Encode token and msg.sender as bytes
        bytes memory data = abi.encode(token, msg.sender);

        // 3. Call pair.swap
        pair.swap({
            amount0Out: amount0Out,
            amount1Out: amount1Out,
            to: address(this),
            data: data
        });
    }

    // Uniswap V2 callback
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        // Write your code here
        // Don’t change any other code

        // 1. Require msg.sender is pair contract
        // 2. Require sender is this contract
        // Alice -> FlashSwap ---- to = FlashSwap ----> UniswapV2Pair
        //                    <-- sender = FlashSwap --
        // Eve ------------ to = FlashSwap -----------> UniswapV2Pair
        //          FlashSwap <-- sender = Eve --------
        require(msg.sender == address(pair), "Invalid pair");
        require(sender == address(this), "Invalid sender");

        // 3. Decode token and caller from data
        (address token, address caller) = abi.decode(data, (address, address));
        // 4. Determine amount borrowed (only one of them is > 0)
        uint256 amount = token == token0 ? amount0 : amount1;

        uint256 fee = (amount * 3) / 997 + 1; // Uniswap V2 fee is 0.3%
        uint256 amountToRepay = amount + fee;

        IERC20(token).transferFrom(caller, address(this), fee); // Send borrowed amount to caller
        IERC20(token).transfer(address(pair), amountToRepay); // Repay the pair

    }
}
