//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "src/UniswapV2Pair.sol";
import "src/UniswapV2Factory.sol";
import {ERC20 as OpenZeppelinERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockToken is OpenZeppelinERC20 {
    constructor(
        string memory name,
        string memory symbol
    ) OpenZeppelinERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}
contract WETH is OpenZeppelinERC20 {
    constructor() OpenZeppelinERC20("Wrapped Ether", "WETH") {}

    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint amount) public {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {
        deposit();
    }
}

contract UniswapV2Test is Test {
    UniswapV2Factory public factory;
    MockToken public tokenA;
    MockToken public tokenB;
    UniswapV2Pair public pair;
    WETH public weth;

    function setUp() public {
        // Setup UniswapV2 environment
        factory = new UniswapV2Factory(address(this));
        tokenA = new MockToken("Token A", "TKNA");
        tokenB = new MockToken("Token B", "TKNB");
        weth = new WETH();
        address pairAddress = factory.createPair(
            address(tokenA),
            address(tokenB)
        );
        pair = UniswapV2Pair(pairAddress);
    }

    function testCreatePair() public view {
        assertEq(factory.allPairsLength(), 1);
        assertEq(
            factory.getPair(address(tokenA), address(tokenB)),
            address(pair)
        );
    }

    // Test arbitrary liquidity amounts
    function testAddLiquidity(uint amountA, uint amountB) public {
        // Ensure liquidity is within valid range
        vm.assume(amountA > 1000 && amountA < 1000000 * 10 * 18);
        vm.assume(amountB > 1000 && amountB < 1000000 * 10 * 18);

        tokenA.transfer(address(pair), amountA);
        tokenB.transfer(address(pair), amountB);
        pair.mint(address(this));

        uint expectedLiquidity = sqrt(amountA * amountB) - 1000; // Subtract minimum liquidity
        uint totalSupply = sqrt(amountA * amountB);

        assertEq(pair.balanceOf(address(this)), expectedLiquidity);
        assertEq(pair.totalSupply(), totalSupply);
    }

    // Test swap within initial liquidity bounds
    function testSwap(uint amountIn) public {
        vm.assume(amountIn > 1000 && amountIn <= 1000 * 10 * 18);

        // Initialize liquidity
        uint initialLiquidity = 1000 * 10 ** 18;
        tokenA.transfer(address(pair), initialLiquidity);
        tokenB.transfer(address(pair), initialLiquidity);
        pair.mint(address(this));

        // Execute swap
        tokenA.transfer(address(pair), amountIn);
        
        address recipient = address(this);
        uint erc20Balance = tokenA.balanceOf(address(this));

        bytes4 selector = bytes4(keccak256("transfer(address,uint256)"));

        bytes memory data = abi.encodeWithSelector(selector,recipient, erc20Balance);

        // bytes4 originalValue = 0x11111111;
        // bytes memory encoded = abi.encode(originalValue);

        // bytes memory data2 = abi.encode(selector,recipient, erc20Balance);

        bytes memory data2 = bytes(data[4:]);
        // // 解码
        // bytes4 decoded = abi.decode(encoded, (bytes4));

        (bytes4 sel2,address recipient2, uint256 amount2) = abi.decode(data2, (bytes4,address, uint256));

        console.log("recipient:", recipient2);
        console.log("amount:", amount2);

        // 输出结果
        // console.logBytes4( originalValue);
        // console.logBytes4( decoded);

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        console.log("reserve0:", reserve0);
        console.log("reserve1:", reserve1);

        uint expectedOutput = calculateExpectedOutput(
            reserve0,
            reserve1,
            amountIn
        );
        console.log("expectedOutput:", expectedOutput);

        // Apply slippage tolerance
        uint minOutput = (expectedOutput * 995) / 1000; // 0.5% tolerance

        uint balanceBefore = tokenB.balanceOf(address(this));
        pair.swap(0, minOutput, address(this), "");
        uint balanceAfter = tokenB.balanceOf(address(this));

        uint actualOutput = balanceAfter - balanceBefore;
        console.log("actualOutput:", actualOutput);
        console.log("minOutput:", minOutput);

        // Assert output within 1% margin
        assertApproxEqRel(actualOutput, expectedOutput, 1e16);
    }

    function testRemoveLiquidity(uint256 removedLiquidityPercentage) public {
        // Initialize liquidity
        uint initialLiquidity = 1000 * 10 ** 18;
        tokenA.transfer(address(pair), initialLiquidity);
        tokenB.transfer(address(pair), initialLiquidity);
        pair.mint(address(this));

        // Bound removal percentage
        removedLiquidityPercentage = bound(removedLiquidityPercentage, 1, 100);

        // Calculate liquidity to remove
        uint totalLiquidity = pair.balanceOf(address(this));
        uint liquidityToRemove = (totalLiquidity * removedLiquidityPercentage) /
            100;

        // Record balances before removal
        uint balanceABefore = tokenA.balanceOf(address(this));
        uint balanceBBefore = tokenB.balanceOf(address(this));

        // Remove liquidity
        pair.transfer(address(pair), liquidityToRemove);
        pair.burn(address(this));

        // Calculate returned tokens
        uint returnedA = tokenA.balanceOf(address(this)) - balanceABefore;
        uint returnedB = tokenB.balanceOf(address(this)) - balanceBBefore;

        // Calculate expected returns
        uint expectedA = (initialLiquidity * removedLiquidityPercentage) / 100;
        uint expectedB = (initialLiquidity * removedLiquidityPercentage) / 100;

        // Assert returned amounts within 1% margin
        assertApproxEqRel(returnedA, expectedA, 1e16);
        assertApproxEqRel(returnedB, expectedB, 1e16);

        // Verify remaining liquidity
        uint remainingLiquidity = pair.balanceOf(address(this));
        assertEq(remainingLiquidity, totalLiquidity - liquidityToRemove);
    }
    function testAddLiquidityETH() public {
        // Create the ETH/Token pair
        address pairAddress = factory.createPair(
            address(weth),
            address(tokenA)
        );
        UniswapV2Pair ethPair = UniswapV2Pair(pairAddress);

        // Prepare liquidity amounts
        uint tokenAmount = 1000 * 10 ** 18;
        uint ethAmount = 5 * 10 ** 18;

        // Transfer tokens to the pair
        tokenA.transfer(address(ethPair), tokenAmount);

        // Deposit ETH to WETH and transfer to the pair
        weth.deposit{value: ethAmount}();
        weth.transfer(address(ethPair), ethAmount);

        // Mint liquidity tokens
        ethPair.mint(address(this));

        // Calculate expected liquidity
        uint expectedLiquidity = sqrt(tokenAmount * ethAmount) - 1000; // Subtract minimum liquidity
        uint totalSupply = sqrt(tokenAmount * ethAmount);

        // Assert correct liquidity minted
        assertEq(ethPair.balanceOf(address(this)), expectedLiquidity);
        assertEq(ethPair.totalSupply(), totalSupply);

        // Additional assertions to verify pair creation
        // assertEq(factory.allPairsLength(), 1);
        assertEq(
            factory.getPair(address(weth), address(tokenA)),
            address(ethPair)
        );
    }
    function testSwa2pETHForTokenA(uint amountIn) public {
        vm.assume(amountIn > 1e16 && amountIn <= 10 * 1e18); // 0.01 ETH to 10 ETH

        // First, add liquidity
        testAddLiquidityETH();

        // Get the ETH/TokenA pair
        address pairAddress = factory.getPair(address(weth), address(tokenA));
        UniswapV2Pair ethPair = UniswapV2Pair(pairAddress);

        // Get reserves before swap
        (uint112 reserve0, uint112 reserve1, ) = ethPair.getReserves();
        uint reserveETH = address(weth) < address(tokenA) ? reserve0 : reserve1;
        uint reserveToken = address(weth) < address(tokenA)
            ? reserve1
            : reserve0;

        // Calculate expected output
        uint expectedOutput = calculateExpectedOutput(
            reserveETH,
            reserveToken,
            amountIn
        );

        // Record balance before swap
        uint balanceBefore = tokenA.balanceOf(address(this));

        // Perform swap
        weth.deposit{value: amountIn}();
        weth.transfer(address(ethPair), amountIn);
        if (address(weth) < address(tokenA)) {
            ethPair.swap(0, expectedOutput, address(this), "");
        } else {
            ethPair.swap(expectedOutput, 0, address(this), "");
        }

        // Check balance after swap
        uint balanceAfter = tokenA.balanceOf(address(this));
        uint actualOutput = balanceAfter - balanceBefore;

        // Assert output within 1% margin
        assertApproxEqRel(actualOutput, expectedOutput, 1e16);
    }

    function testSw2apTokenAForETH(uint amountIn) public {
        vm.assume(amountIn > 1e18 && amountIn <= 100 * 1e18); // 1 TokenA to 100 TokenA

        // First, add liquidity
        testAddLiquidityETH();

        // Get the ETH/TokenA pair
        address pairAddress = factory.getPair(address(weth), address(tokenA));
        UniswapV2Pair ethPair = UniswapV2Pair(pairAddress);

        // Get reserves before swap
        (uint112 reserve0, uint112 reserve1, ) = ethPair.getReserves();
        uint reserveToken = address(tokenA) < address(weth)
            ? reserve0
            : reserve1;
        uint reserveETH = address(tokenA) < address(weth) ? reserve1 : reserve0;

        // Calculate expected output
        uint expectedOutput = calculateExpectedOutput(
            reserveToken,
            reserveETH,
            amountIn
        );

        // Apply slippage tolerance
        uint minOutput = (expectedOutput * 995) / 1000; // 0.5% slippage tolerance

        // Record balance before swap
        uint balanceBefore = address(this).balance;

        // Approve and transfer TokenA to the pair
        tokenA.approve(address(ethPair), amountIn);
        tokenA.transfer(address(ethPair), amountIn);

        // Perform swap
        if (address(tokenA) < address(weth)) {
            ethPair.swap(0, minOutput, address(this), "");
        } else {
            ethPair.swap(minOutput, 0, address(this), "");
        }

        // Unwrap WETH
        uint wethBalance = weth.balanceOf(address(this));
        if (wethBalance > 0) {
            weth.withdraw(wethBalance);
        }

        // Check balance after swap
        uint balanceAfter = address(this).balance;
        uint actualOutput = balanceAfter - balanceBefore;

        // Assert output within 1% margin
        assertApproxEqRel(actualOutput, expectedOutput, 1e16);
    }

    function calculateExpectedOutput(
        uint reserveIn,
        uint reserveOut,
        uint amountIn
    ) public pure returns (uint amountOut) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;

        require(amountOut < reserveOut, "Insufficient output reserve");
    }

    // Calculate square root
    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
     receive() external payable {}
}
