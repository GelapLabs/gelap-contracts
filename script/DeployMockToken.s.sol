// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MockERC20.sol";

contract DeployMockToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        MockToken token = new MockToken();
        console.log("MockToken deployed at:", address(token));

        vm.stopBroadcast();
    }
}
