// SPDX-License-Identifier: none
pragma solidity ^0.8.4;


contract MarriageRegistry {
    mapping(address => bool) public marriedAddresses;

    function isMarried(address _address) external view returns (bool) {
        return marriedAddresses[_address];
    }

    function setMarriage(address _address) external {
        marriedAddresses[_address] = true;
    }

    function revokeMarriage(address _address) external {
        marriedAddresses[_address] = false;
    }
}
