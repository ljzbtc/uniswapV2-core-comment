// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWETH is IERC20 {
    // 存入 ETH 并铸造等量的 WETH
    function deposit() external payable;

    // 销毁 WETH 并提取等量的 ETH
    function withdraw(uint256 amount) external;

    // 接收 ETH 的回退函数
    receive() external payable;

    // 存款事件
    event Deposit(address indexed dst, uint256 wad);

    // 提款事件
    event Withdrawal(address indexed src, uint256 wad);
}