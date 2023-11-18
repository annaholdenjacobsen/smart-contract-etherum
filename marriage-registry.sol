// SPDX-License-Identifier: none
pragma solidity ^0.8.20;


// A global marriage registry
contract MarriageRegistry {
    // A mapping of which addresses are married
    mapping(address => bool) public marriedAddresses;

    //A getter that returns if the address is married or not
    function isMarried(address _address) public view returns (bool) {
        return marriedAddresses[_address];
    }

    //Set the addresses' state to married
    function setMarriage(address _address) public {
        marriedAddresses[_address] = true;
    }

    //Set the address' state to not married
    function revokeMarriage(address _address) public {
        marriedAddresses[_address] = false;
    }
}