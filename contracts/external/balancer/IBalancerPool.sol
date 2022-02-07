// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.7.0;

interface IBalancerPool {
    function getFinalTokens() external view returns (address[] memory);

    function getNormalizedWeight(address token) external view returns (uint);

    function getSwapFee() external view returns (uint);

    function getNumTokens() external view returns (uint);

    function getBalance(address token) external view returns (uint);

    function totalSupply() external view returns (uint);

    function joinPool(uint poolAmountOut, uint[] calldata maxAmountsIn) external;

    function swapExactAmountIn(
        address tokenIn,
        uint tokenAmountIn,
        address tokenOut,
        uint minAmountOut,
        uint maxPrice
    ) external returns (uint tokenAmountOut, uint spotPriceAfter);

    function swapExactAmountOut(
        address tokenIn,
        uint maxAmountIn,
        address tokenOut,
        uint tokenAmountOut,
        uint maxPrice
    ) external returns (uint tokenAmountIn, uint spotPriceAfter);

    function joinswapExternAmountIn(
        address tokenIn,
        uint tokenAmountIn,
        uint minPoolAmountOut
    ) external returns (uint poolAmountOut);

    function exitPool(uint poolAmountIn, uint[] calldata minAmountsOut) external;

    function exitswapExternAmountOut(
        address tokenOut,
        uint tokenAmountOut,
        uint maxPoolAmountIn
    ) external returns (uint poolAmountIn);
}
