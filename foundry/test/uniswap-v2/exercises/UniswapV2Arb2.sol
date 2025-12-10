// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

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
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pair0).getReserves();
        uint256 amountOut = isZeroForOne ? getAmountOut(amountIn, reserve0, reserve1) : getAmountOut(amountIn, reserve1, reserve0);
        // Hint - use getAmountOut to calculate amountOut to borrow
        FlashSwapData memory params = FlashSwapData({
            caller: msg.sender,
            pair0: pair0,
            pair1: pair1,
            isZeroForOne: isZeroForOne,
            amountIn: amountIn,
            amountOut: amountOut,
            minProfit: minProfit
        });
        bytes memory data = abi.encode(params);
        IUniswapV2Pair(pair0).swap(isZeroForOne ? 0 : amountOut, isZeroForOne ? amountOut : 0, address(this), data);
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
        require(sender == address(this), "Not sender");
        require(msg.sender == address(params.pair0), "Not pair");

        (address tokenIn, address tokenOut) = params.isZeroForOne ? (IUniswapV2Pair(params.pair0).token0(), IUniswapV2Pair(params.pair0).token1()) : (IUniswapV2Pair(params.pair0).token1(), IUniswapV2Pair(params.pair0).token0());
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(params.pair1).getReserves();
        // Remember pair0 and pair1 are same pair but different pools (WETH-USDC on Uniswap and SushiSwap, so the orders are same)
        uint256 amountOut = params.isZeroForOne ? getAmountOut(params.amountOut, reserve1, reserve0) : getAmountOut(params.amountOut, reserve0, reserve1);

        IERC20(tokenOut).transfer(params.pair1, params.amountOut);
        IUniswapV2Pair(params.pair1).swap(params.isZeroForOne ? amountOut : 0, params.isZeroForOne ? 0 : amountOut, address(this), "");

        IERC20(tokenIn).transfer(params.pair0, params.amountIn);
        require(amountOut >= params.amountIn + params.minProfit, "Insufficient balance");
        IERC20(tokenIn).transfer(params.caller, amountOut - params.amountIn);
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
