// SPDX-License-Identifier: MIT
pragma solidity 0.8.4; //Do not change the solidity version as it negativly impacts submission grading

import "./Staker.sol";

contract ExampleExternalContract {
    Staker public staker;

    address ownerAddress;
    address stakerAddress;

    event Received(address, uint);
    event Sent(address, uint);

    constructor() {
        ownerAddress = msg.sender;
    }

    modifier ownerOnly() {
        require(msg.sender == ownerAddress, "Unauthorized");
        _;
    }

    function setStakerAddress(address payable _stakerAddress) public ownerOnly {
        staker = Staker(_stakerAddress);
    }

    function execute() public {
        uint256 contractBalance = address(this).balance;
        (bool sent, ) = address(staker).call{value: contractBalance}("");
        require(sent, "RIP; sendToStaker failed :( ");
        emit Sent(address(staker), contractBalance);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
