// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/interfaces/IFoxswap.sol";
import "src/interfaces/IWETH.sol";
import "src/interfaces/IUniswapV2Pair.sol";
import "src/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Foxswap is IFoxswap {
    address payable public immutable WETH;
    IUniswapV2Factory public immutable factory;

    constructor(address _weth, address _factory) {
        WETH = payable(_weth);
        factory = IUniswapV2Factory(_factory);
    }

    function sellETH(
        address buyToken,
        uint256 minBuyAmount
    ) external payable override {
        require(msg.value > 0, "Must send ETH");

        // 1. Exchange ETH to WETH
        IWETH(WETH).deposit{value: msg.value}();

        // 2. Exchange WETH to buyToken
        address pair = factory.getPair(WETH, buyToken);
        require(pair != address(0), "Pair does not exist");

        uint256 amountIn = IWETH(WETH).balanceOf(address(this));
        IWETH(WETH).transfer(pair, amountIn);

        (uint reserve0, uint reserve1, ) = IUniswapV2Pair(pair).getReserves();
        uint amountOut;
        if (IUniswapV2Pair(pair).token0() == WETH) {
            amountOut = getAmountOut(amountIn, reserve0, reserve1);
            IUniswapV2Pair(pair).swap(0, amountOut, msg.sender, "");
        } else {
            amountOut = getAmountOut(amountIn, reserve1, reserve0);
            IUniswapV2Pair(pair).swap(amountOut, 0, msg.sender, "");
        }

        require(amountOut >= minBuyAmount, "Insufficient output amount");
    }

    function buyETH(
        address sellToken,
        uint256 sellAmount,
        uint256 minBuyAmount
    ) external override {
        // 1. Transfer sellToken from user to this contract
        IERC20(sellToken).transferFrom(msg.sender, address(this), sellAmount);

        // 2. Exchange sellToken to WETH
        address pair = factory.getPair(WETH, sellToken);
        require(pair != address(0), "Pair does not exist");

        IERC20(sellToken).transfer(pair, sellAmount);

        (uint reserve0, uint reserve1, ) = IUniswapV2Pair(pair).getReserves();
        uint amountOut;
        if (IUniswapV2Pair(pair).token0() == sellToken) {
            amountOut = getAmountOut(sellAmount, reserve0, reserve1);
            IUniswapV2Pair(pair).swap(0, amountOut, address(this), "");
        } else {
            amountOut = getAmountOut(sellAmount, reserve1, reserve0);
            IUniswapV2Pair(pair).swap(amountOut, 0, address(this), "");
        }

        require(amountOut >= minBuyAmount, "Insufficient output amount");

        // 3. Exchange WETH to ETH and transfer to msg.sender
        IWETH(WETH).withdraw(amountOut);
        payable(msg.sender).transfer(amountOut);
    }

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) internal pure returns (uint amountOut) {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    receive() external payable {}
}
