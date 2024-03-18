// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";


error InvalidBid(uint256 lastBid);

contract Bidding is Ownable2Step {

    // the bidding duration will get extended
    // by this duration after every successful bid
    uint256 public constant EXTEND_DURATION = 10 minutes;

    // bidding time will get closed after this
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

    event NewBid(address indexed newBidder, uint256 indexed bid, address indexed previousBidder);

    event PeriodOver(address indexed winner, uint256 indexed winningBid, uint256 indexed commissionFees);

    // TODO: start timer from deployment
    constructor() Ownable(msg.sender) {

    }

    function bid() external payable {
        // pay the highest bidder if the bidding period is over
        if(_isLastPeriodOver()) {
            uint256 balance = address(this).balance;
    
            // give the owner 5% commision
            // percentage is calculated using BPS
            uint256 ownerCommission = (balance * 500) / 10_000;
            payable(owner()).transfer(ownerCommission);

            // caller becomes the winner and takes away rest of the money
            payable(msg.sender).transfer(address(this).balance);
            
            emit PeriodOver(msg.sender, msg.value, ownerCommission);

            // reset for next period
            _resetGame();
        }

        uint256 highestBid = _highestBid;

        // revert if the bidding amount is not greater
        // than the highest bid
        if (msg.value <= highestBid)
           revert InvalidBid(highestBid);

        // update the highest bid
        _highestBid = msg.value;

        address payable previousBidder = _highestBidder;
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
        _lastBidTime = 0;
    }

    function _isLastPeriodOver() private returns(bool) {
        uint256 lastBidTime = _lastBidTime;

        if (lastBidTime == 0) return false;

        uint256 overTime = lastBidTime + _timeUntilOver;

        if(overTime >= block.timestamp) {
            // update `_timeUntilOver` if the bidding period is not over yet
            _timeUntilOver = overTime - block.timestamp;
            return false;
        }

        return true;
    }
}
