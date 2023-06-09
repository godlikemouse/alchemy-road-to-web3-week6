// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./ExampleExternalContract.sol";

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

    constructor(address payable exampleExternalContractAddress) {
        exampleExternalContract = ExampleExternalContract(
            exampleExternalContractAddress
        );
    }

    // Stake function for a user to stake ETH in our contract
    function stake() public payable {
        balances[msg.sender] = balances[msg.sender] + msg.value;
        depositTimestamps[msg.sender] = block.timestamp;
        emit Stake(msg.sender, msg.value);
    }

    // Withdraw function for a user to remove their staked ETH inclusive
    // of both principal and any accrued interest
    function withdraw() public {
        require(balances[msg.sender] > 0, "You have no balance to withdraw!");
        uint256 individualBalance = balances[msg.sender];
        uint256 interest = ((block.timestamp - depositTimestamps[msg.sender]) **
            rewardRatePerSecond);
        uint256 indBalanceRewards = individualBalance + interest;
        balances[msg.sender] = 0;

        // Transfer all ETH via call! (not transfer) cc: https://solidity-by-example.org/sending-ether
        (bool sent, ) = msg.sender.call{value: indBalanceRewards}("");
        require(sent, "RIP; withdrawal failed :( ");
    }

    function execute() public {
        uint256 contractBalance = address(this).balance;
        (bool sent, ) = address(exampleExternalContract).call{
            value: contractBalance
        }("");
        require(sent, "Error Staker.execute failed :( ");
    }

    // Time to "kill-time" on our local testnet
    function killTime() public {
        currentBlock = block.timestamp;
    }

    // Function for our smart contract to receive ETH
    // cc: https://docs.soliditylang.org/en/latest/contracts.html#receive-ether-function
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
