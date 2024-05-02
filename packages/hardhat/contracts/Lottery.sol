// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title Lottery contract
/// @author @ZK-solidity-army
/// @notice You can use this contract to deploy the custom Lottery
/// @dev This contract implements a relatively weak randomness source, since there is no cliff period between the randao reveal and the actual usage in this contract
contract Lottery is AccessControl {

    bytes32 public constant STARTER_ROLE = keccak256("STARTER_ROLE");
    bytes32 public constant WINNER_ROLE = keccak256("WINNER_ROLE");
    bytes32 public constant DEVELOPER_ROLE = keccak256("DEVELOPER_ROLE");

    // defaults to 0.001 Eth
    uint256 public constant TICKET_PRICE = 10 ** 16;
    uint256 public constant STATER_FEE = 5 * (10 ** 15);
    uint256 public constant DEV_FEE = 10 ** 15;

    uint256 public constant totalPrice = TICKET_PRICE + STATER_FEE + DEV_FEE;

    /// @notice Amount available to withdraw to the lottery starter
    uint256 public starterPool;

    /// @notice Amount available to withdraw to the developer of the lottery
    uint256 public developerPool;

    /// @notice Amount in the prize pool potentially available to the winner(s)
    uint256 public prizePool;

    /// @notice Flag indicating whether the lottery is open for bets or not
    bool public betsOpen = true;

    /// @notice Timestamp of the lottery closing time
    uint256 public betsClosingTime;

    string lotteryName;

    /// @dev List of bet slots
    address[] public _slots;

    constructor(uint256 duration, string memory _lotteryName, uint256 _starterFee)  {
        require(duration < 14 days, "Lottery cannot be open for longer than 14 days");
        if (duration == 0) {
            betsClosingTime = block.timestamp + 14 days;
        } else {
            betsClosingTime = block.timestamp + duration;
        }

        if (_starterFee == 0) {
            starterFee = 500000000000000;
        } else {
            starterFee = _starterFee;
        }

        totalPrice = TICKET_PRICE + DEV_FEE + starterFee;

        lotteryName = _lotteryName;

        _grantRole(STARTER_ROLE, msg.sender);

        _grantRole(DEVELOPER_ROLE, address(0xD0C1c389A5879da74B035614835A0D98c4c0DD5c));
    }

    /// @notice checks if the lottery is at open state and the current block timestamp is lower than the lottery closing date
    modifier whenBetsOpen() {
        require(
            betsOpen && block.timestamp < betsClosingTime,
            "Lottery is closed"
        );
        _;
    }

    modifier whenBetsClosed() {
        require(
            !betsOpen && block.timestamp > betsClosingTime,
            "Lottery is still running."
        );
        _;
    }

    event PrizeWithdraw(
        address indexed to,
        uint value
    );

    function bet() public payable whenBetsOpen {
        require(msg.value == totalPrice, "Invalid bet amount");
        developerPool += DEV_FEE;
        starterPool += starterFee;
        prizePool += TICKET_PRICE;
        _slots.push(msg.sender);
    }

    /// @notice Returns a random number calculated from the previous block randao
    /// @dev This only works after The Merge
    function getRandomNumber() public view returns (uint256 randomNumber) {
        randomNumber = block.prevrandao;
    }

    /// @notice Closes the lottery and calculates the prize, if any
    /// @dev Anyone can call this function at any time after the closing time
    function closeLottery() external {
        require(block.timestamp >= betsClosingTime, "Too soon to close");
        require(betsOpen, "Already closed");
        if (_slots.length > 0) {
            uint256 winnerIndex = getRandomNumber() % _slots.length;
            address winner = _slots[winnerIndex];
            _grantRole(WINNER_ROLE, winner);
        }
        betsOpen = false;
    }

    function withdrawPrizePool() public onlyRole(WINNER_ROLE) {
        payable(msg.sender).transfer(prizePool);
        emit PrizeWithdraw(msg.sender, prizePool);
        prizePool = 0;
    }

    function withdrawStarterFees() public whenBetsClosed onlyRole(STARTER_ROLE) {
        payable(msg.sender).transfer(starterPool);
        starterPool = 0;
    }
}
