// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
// import your contracts here

contract MyTokenScript is Script {

    // TokenIdoSale public idoSale;

    function setUp() public {}

    function run() public {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // deploy your contracts here
        
        // idoSale = new TokenIdoSale(
        //     address(0x0), // TOKEN_CONTRACT
        //     address(0x0), // PROJECT_OWNER
        //     1731732076, // IDO_START_TIME
        //     1732762076 // IDO_END_TIME
        // );
        console.log("MyToken deployed to:", address(0));

        vm.stopBroadcast();
    }
}

