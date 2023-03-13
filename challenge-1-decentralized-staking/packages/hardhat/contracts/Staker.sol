// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

//TODO: Update the interest mechanism in the Staker.sol contract so that you receive a "non-linear" amount of ETH based on the blocks between deposit and withdrawal
//TODO: Allow users to deposit any arbitrary amount of ETH into the smart contract, not just 0.5 ETH.
//TODO: Instead of using the vanilla ExampleExternalContract contract, implement a function in Staker.sol that allows you to retrieve the ETH locked up in ExampleExternalContract and re-deposit it back into the Staker contract.
//  Make sure to only "white-list" a single address to call this new function to gate its usage!
//  Make sure that you create logic/remove existing code to ensure that users are able to interact with the Staker contract over and over again! We want to be able to ping-pong from Staker -> ExampleExternalContract repeatedly!

contract Staker {
    ExampleExternalContract public exampleExternalContract;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public depositTimestamps;

    uint256 public constant rewardRatePerSecond = 0.1 ether;
    uint256 public withdrawalDeadline = block.timestamp + 120 seconds;
    uint256 public claimDeadline = block.timestamp + 240 seconds;
    uint256 public currentBlock = 0;

    // Events
    event Stake(address indexed sender, uint256 amount);
    event Received(address, uint);
    event Execute(address indexed sender, uint256 amount);

    // Modifiers
    /*
  Checks if the withdrawal period has been reached or not
  */
    modifier withdrawalDeadlineReached(bool requireReached) {
        uint256 timeRemaining = withdrawalTimeLeft();
        if (requireReached) {
            require(timeRemaining == 0, "Withdrawal period is not reached yet");
        } else {
            require(timeRemaining > 0, "Withdrawal period has been reached");
        }
        _;
    }

    /*
  Checks if the claim period has ended or not
  */
    modifier claimDeadlineReached(bool requireReached) {
        uint256 timeRemaining = claimPeriodLeft();
        if (requireReached) {
            require(timeRemaining == 0, "Claim deadline is not reached yet");
        } else {
            require(timeRemaining > 0, "Claim deadline has been reached");
        }
        _;
    }

    /*
  Requires that the contract only be completed once!
  */
    modifier notCompleted() {
        bool completed = exampleExternalContract.completed();
        require(!completed, "Stake already completed!");
        _;
    }

    constructor(address exampleExternalContractAddress) {
        exampleExternalContract = ExampleExternalContract(
            exampleExternalContractAddress
        );
    }

    // Stake function for a user to stake ETH in our contract
    function stake()
        public
        payable
        withdrawalDeadlineReached(false)
        claimDeadlineReached(false)
    {
        balances[msg.sender] = balances[msg.sender] + msg.value;
        depositTimestamps[msg.sender] = block.timestamp;
        emit Stake(msg.sender, msg.value);
    }

    /*
  Withdraw function for a user to remove their staked ETH inclusive
  of both principal and any accrued interest
  */
    function withdraw()
        public
        withdrawalDeadlineReached(true)
        claimDeadlineReached(false)
        notCompleted
    {
        require(balances[msg.sender] > 0, "You have no balance to withdraw!");
        uint256 individualBalance = balances[msg.sender];
        uint256 indBalanceRewards = individualBalance +
            ((block.timestamp - depositTimestamps[msg.sender]) *
                rewardRatePerSecond);
        balances[msg.sender] = 0;

        // Transfer all ETH via call! (not transfer) cc: https://solidity-by-example.org/sending-ether
        (bool sent, bytes memory data) = msg.sender.call{
            value: indBalanceRewards
        }("");
        require(sent, "RIP; withdrawal failed :( ");
    }

    /*
  Allows any user to repatriate "unproductive" funds that are left in the staking contract
  past the defined withdrawal period
  */
    function execute() public claimDeadlineReached(true) notCompleted {
        uint256 contractBalance = address(this).balance;
        exampleExternalContract.complete{value: address(this).balance}();
    }

    /*
  READ-ONLY function to calculate the time remaining before the minimum staking period has passed
  */
    function withdrawalTimeLeft()
        public
        view
        returns (uint256 withdrawalTimeLeft)
    {
        if (block.timestamp >= withdrawalDeadline) {
            return (0);
        } else {
            return (withdrawalDeadline - block.timestamp);
        }
    }

    /*
  READ-ONLY function to calculate the time remaining before the minimum staking period has passed
  */
    function claimPeriodLeft() public view returns (uint256 claimPeriodLeft) {
        if (block.timestamp >= claimDeadline) {
            return (0);
        } else {
            return (claimDeadline - block.timestamp);
        }
    }

    /*
  Time to "kill-time" on our local testnet
  */
    function killTime() public {
        currentBlock = block.timestamp;
    }

    /*
  \Function for our smart contract to receive ETH
  cc: https://docs.soliditylang.org/en/latest/contracts.html#receive-ether-function
  */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
