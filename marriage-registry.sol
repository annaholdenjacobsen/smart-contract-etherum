// SPDX-License-Identifier: none
pragma solidity ^0.8.20;


// Denne er helt ute å kjøre, får ikke til å aksessere infoen riktig
contract MarriageRegistry {
    mapping(address => bool) public marriedAddresses;

    function isMarried(address _address) public view returns (bool) {
        return marriedAddresses[_address];
    }

    function setMarriage(address _address) public {
        marriedAddresses[_address] = true;
    }

    function revokeMarriage(address _address) public {
        marriedAddresses[_address] = false;
    }
}