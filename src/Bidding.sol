// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

error InvalidBid(uint256 lastBid);

contract Bidding is Ownable2Step, ReentrancyGuard {
    // the bidding duration will get extended
    // by this duration after every successful bid
    uint256 public constant EXTEND_DURATION = 10 minutes;

    // a bidding period will get over after this
    // duration and a winner will be selected
    uint256 private _timeUntilOver = 60 minutes;

    // current highest bid amount in wei
    // by default, 0
    uint256 private _highestBid;

    // current highest bidder
    // this address will become the winner
    // if no one bids higher than him in the next `timeUntilOver`
    address payable private _highestBidder;

    // timestamp at which the last bid was made
    uint256 private _lastBidTime;

    // EVENTS

    event NewBid(
        address indexed newBidder,
        uint256 indexed bid,
        address indexed previousBidder
    );

    event PeriodOver(
        address indexed winner,
        uint256 indexed winningBid,
        uint256 indexed commissionFees
    );

    event EmptyPeriod(
        uint256 indexed newPeriodStartingTime,
        address indexed bidder,
        uint256 indexed amountRefunded
    );

    constructor() Ownable(msg.sender) {
        // the time for first bid starts from
        // the deployment time
        _lastBidTime = block.timestamp;
    }

    function getHighestBid() external view returns (uint256) {
        return _highestBid;
    }

    function getHighestBidder() external view returns (address payable) {
        return _highestBidder;
    }

    function getTimeUntilOver() external view returns (uint256) {
        return _timeUntilOver;
    }

    function getLastBidTime() external view returns (uint256) {
        return _lastBidTime;
    }

    // returns true if the last period has ended
    // without anyone participating in it
    function isPeriodEmpty() external view returns (bool) {
        uint256 overTime = _lastBidTime + _timeUntilOver;

        return address(this).balance == 0 && block.timestamp > overTime;
    }

    function bid() external payable nonReentrant {
        address payable previousBidder = _highestBidder;
        uint256 highestBid = _highestBid;

        if (_isLastPeriodOver()) {
            // interaction before checks and effects is safe
            // because we're using `nonReentrant` modifier
            _returnCurrentBidderMoney();

            uint256 balance = address(this).balance;
            // if no one participated in the last period
            // start a new period from now and return
            // the current bidder's money
            if (balance == 0) {
                _lastBidTime = block.timestamp;

                emit EmptyPeriod(block.timestamp, msg.sender, msg.value);
                return;
            }

            // give the owner 5% commision
            // percentage is calculated using BPS
            uint256 ownerCommission = (balance * 500) / 10_000;
            payable(owner()).transfer(ownerCommission);

            emit PeriodOver(previousBidder, highestBid, ownerCommission);

            // reset for next period
            _resetGame();

            // last bidder becomes the winner and takes away rest of the money
            previousBidder.transfer(address(this).balance);

            // make sure that the contract doesn't have any money left after a period is over
            assert(address(this).balance == 0);
            return;
        }

        // revert if the bidding amount is not greater
        // than the highest bid
        if (msg.value <= highestBid) revert InvalidBid(highestBid);

        // update the highest bid
        _highestBid = msg.value;

        // update the higgest bidder
        _highestBidder = payable(msg.sender);

        // extend the bidding period by 10 mins
        _timeUntilOver += EXTEND_DURATION;

        // update the last bid time
        _lastBidTime = block.timestamp;

        emit NewBid(msg.sender, msg.value, previousBidder);
    }

    function _resetGame() private {
        _timeUntilOver = 60 minutes;
        _highestBid = 0;
        _highestBidder = payable(address(0));
        // the first bidder of next period
        // will have 60 minutes from now to make a bid
        _lastBidTime = block.timestamp;
    }

    function _returnCurrentBidderMoney() private {
        // since the bidding time is over, return the current
        // bidder's money if they sent any
        if (msg.value > 0) payable(msg.sender).transfer(msg.value);
    }

    function _isLastPeriodOver() private returns (bool) {
        uint256 overTime = _lastBidTime + _timeUntilOver;

        if (overTime >= block.timestamp) {
            // update `_timeUntilOver` if the bidding period is not over yet
            _timeUntilOver = overTime - block.timestamp;
            return false;
        }

        return true;
    }
}
