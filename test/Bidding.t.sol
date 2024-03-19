// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Bidding} from "../src/Bidding.sol";

contract BiddingTest is Test {
    Bidding public bidding;

    function setUp() external {
        bidding = new Bidding();
    }
}
