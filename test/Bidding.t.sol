// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Bidding} from "../src/Bidding.sol";

contract BiddingTest is Test {
    Bidding public bidding;

    address private BIDDER1 = address(11);
    address private BIDDER2 = address(22);
    address private BIDDER3 = address(33);
    address private BIDDER4 = address(44);

    // EVENTS
    event NewBid(
        address indexed newBidder,
        uint256 indexed bid,
        address indexed previousBidder
    );

    event PeriodOver(
        address indexed winner,
        uint256 indexed winningAmount,
        uint256 indexed commissionFees
    );

    event EmptyPeriod(
        uint256 indexed newPeriodStartingTime,
        address indexed bidder,
        uint256 indexed amountRefunded
    );

    function setUp() external {
        deal(address(this), 0);
        bidding = new Bidding();
    }

    function testViewFunctions() public {
        assertEq(bidding.EXTEND_DURATION(), 10 minutes);
        assertEq(bidding.getHighestBid(), 0);
        assertEq(bidding.getHighestBidder(), address(0));
        assertEq(bidding.getTimeUntilOver(), 60 minutes);
        assertEq(bidding.getLastBidTime(), 1);
        assertEq(bidding.isPeriodEmpty(), false);

        // after 15 minutes, `_timeUntilOver` should reduce to 45 minutes
        skip(15 minutes);
        assertEq(bidding.getTimeUntilOver(), 45 minutes);

        // after bidding period, the period gets empty as no one participated in the bidding
        skip(45 minutes + 1);
        assertEq(bidding.isPeriodEmpty(), true);
        assertEq(bidding.getTimeUntilOver(), 0);
    }

    function testFirstBidderBidsAfterAPeriodIsOver() public {
        skip(60 minutes + 1);
        assertEq(bidding.getTimeUntilOver(), 0);
        assertEq(bidding.isPeriodEmpty(), true);

        hoax(BIDDER1, 2 ether);

        vm.expectEmit(true, true, true, false, address(bidding));
        emit EmptyPeriod(block.timestamp, BIDDER1, 1 ether);
        bidding.bid{value: 1 ether}();

        // BIDDER1 must have received back his money
        assertEq(address(BIDDER1).balance, 2 ether);

        // `_lastBidTime` must get updated
        assertEq(bidding.getLastBidTime(), block.timestamp);

        // rest of the state vars should not get affected
        assertEq(bidding.getHighestBid(), 0);
        assertEq(bidding.getHighestBidder(), address(0));
        assertEq(bidding.getTimeUntilOver(), 60 minutes);
        assertEq(bidding.isPeriodEmpty(), false);
    }

    function testBiddingMustHappenDuringBiddingPeriod() public {
        testFirstBidderBidsAfterAPeriodIsOver();
        // first bid of 1 ether after 10 mins
        hoax(BIDDER1, 10 ether);
        skip(10 minutes);

        vm.expectEmit(true, true, true, false, address(bidding));
        emit NewBid(BIDDER1, 1 ether, address(0));
        bidding.bid{value: 1 ether}();

        assertEq(bidding.getHighestBid(), 1 ether);
        assertEq(bidding.getHighestBidder(), BIDDER1);
        assertEq(bidding.getTimeUntilOver(), 60 minutes);
        assertEq(bidding.getLastBidTime(), block.timestamp);
        assertEq(bidding.isPeriodEmpty(), false);

        // balances
        assertEq(BIDDER1.balance, 9 ether);
        assertEq(address(bidding).balance, 1 ether);

        // second bid of 2 ether after 30 mins
        hoax(BIDDER2, 10 ether);
        skip(30 minutes);

        vm.expectEmit(true, true, true, false, address(bidding));
        emit NewBid(BIDDER2, 2 ether, BIDDER1);
        bidding.bid{value: 2 ether}();

        assertEq(bidding.getHighestBid(), 2 ether);
        assertEq(bidding.getHighestBidder(), BIDDER2);
        assertEq(bidding.getTimeUntilOver(), 40 minutes);
        assertEq(bidding.getLastBidTime(), block.timestamp);
        assertEq(bidding.isPeriodEmpty(), false);

        // balances
        assertEq(BIDDER2.balance, 8 ether);
        assertEq(address(bidding).balance, 3 ether);

        // third bid of 5 ether after 35 mins
        hoax(BIDDER3, 20 ether);
        skip(35 minutes);

        vm.expectEmit(true, true, true, false, address(bidding));
        emit NewBid(BIDDER3, 5 ether, BIDDER2);
        bidding.bid{value: 5 ether}();

        assertEq(bidding.getHighestBid(), 5 ether);
        assertEq(bidding.getHighestBidder(), BIDDER3);
        assertEq(bidding.getTimeUntilOver(), 15 minutes);
        assertEq(bidding.getLastBidTime(), block.timestamp);
        assertEq(bidding.isPeriodEmpty(), false);

        // balances
        assertEq(BIDDER3.balance, 15 ether);
        assertEq(address(bidding).balance, 8 ether);
    }

    function testBiddingMustEndCorrectly() public {
        testBiddingMustHappenDuringBiddingPeriod();

        // BIDDER1 bids again with all his might at the last moment!
        vm.prank(BIDDER1);
        skip(15 minutes);

        vm.expectEmit(true, true, true, false, address(bidding));
        emit NewBid(BIDDER1, 9 ether, BIDDER3);
        bidding.bid{value: 9 ether}();

        assertEq(bidding.getHighestBid(), 9 ether);
        assertEq(bidding.getHighestBidder(), BIDDER1);
        assertEq(bidding.getTimeUntilOver(), 10 minutes);
        assertEq(bidding.getLastBidTime(), block.timestamp);
        assertEq(bidding.isPeriodEmpty(), false);

        // balances
        assertEq(BIDDER1.balance, 0);
        assertEq(address(bidding).balance, 17 ether);

        // BIDDER3 tries to out bid BIDDER1, but he's just too late
        vm.prank(BIDDER3);
        skip(10 minutes + 1);

        vm.expectEmit(true, true, true, false, address(bidding));
        emit PeriodOver(BIDDER1, 16.15 ether, 0.85 ether);
        bidding.bid{value: 15 ether}();

        // values must get reset
        assertEq(bidding.getHighestBid(), 0 ether);
        assertEq(bidding.getHighestBidder(), address(0));
        assertEq(bidding.getTimeUntilOver(), 60 minutes);
        assertEq(bidding.getLastBidTime(), block.timestamp);
        assertEq(bidding.isPeriodEmpty(), false);

        // balances
        assertEq(address(this).balance, 0.85 ether);
        assertEq(BIDDER1.balance, 16.15 ether);
        assertEq(BIDDER3.balance, 15 ether);
        assertEq(address(bidding).balance, 0 ether);
    }

    function testAnotherBiddingRound() public {
        testBiddingMustEndCorrectly();

        // first bid of another period of 10 ether after 40 mins
        hoax(BIDDER4, 20 ether);
        skip(40 minutes);

        vm.expectEmit(true, true, true, false, address(bidding));
        emit NewBid(BIDDER4, 10 ether, address(0));
        bidding.bid{value: 10 ether}();

        assertEq(bidding.getHighestBid(), 10 ether);
        assertEq(bidding.getHighestBidder(), BIDDER4);
        assertEq(bidding.getTimeUntilOver(), 30 minutes);
        assertEq(bidding.getLastBidTime(), block.timestamp);
        assertEq(bidding.isPeriodEmpty(), false);

        // balances
        assertEq(BIDDER4.balance, 10 ether);
        assertEq(address(bidding).balance, 10 ether);
    }

    receive() external payable {}
}
