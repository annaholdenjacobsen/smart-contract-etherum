// SPDX-License-Identifier: none
pragma solidity ^0.8.4;

contract MarriageContract {

    // ATTRIBUTES
    address private spouse1;
    address private spouse2;

    bool public isEngaged;
    bool public isMarried;

    uint16 public weddingDay;

    address[] public participants;


    // STATE HANDLING
    enum State {Created, Registered, Aborted, Wed, Invalid}

    State public currentState;

    function transitionToRegistered() public {
        require(currentState == State.Created, "Invalid state transition");
        currentState = State.Registered;
    }

    function transitionToAborted() public {
        require(currentState == State.Registered || currentState == State.Wed, "Invalid state transition");
        currentState = State.Aborted;
    }
    function transitionToWed() public {
        require(currentState == State.Registered, "Invalid state transition");
        currentState = State.Wed;
    }
    function transitionToInvalid() public {
        require(currentState != State.Aborted, "invalid state transition");
        currentState = State.Invalid;
    }

    function getCurrentState() public view returns (State) {
        return currentState;
    }


    event Engaged(address indexed spouse1, address indexed spouse2);
    event Married(address indexed spouse1, address indexed spouse2);

    // TODO update after adding stuff
    constructor() {
        spouse1 = msg.sender;
        isEngaged = false;
        isMarried = false;
    }


    modifier onlySpouse() {
        require(msg.sender == spouse1 || msg.sender == spouse2, "Only spouses can call this function");
        _;
    }

    // PARTICIPANT FUNCTIONALITY
    function addParticipant(address _participant) public {
        participants.push(_participant);
    }

    function getParticipantCount() public view returns (uint) {
        return participants.length;
    }
    function getParticipantByIndex(uint index) public view returns (address) {
        require(index < participants.length, "Index out of range");
        return participants[index];
    }

    // ACTION FUNCTIONALITY
    function engage(address _spouse2) public {
        require(!isEngaged, "Already engaged");
        require(msg.sender != _spouse2, "Cannot marry yourself");

        spouse2 = _spouse2;
        isEngaged = true;

        emit Engaged(spouse1, spouse2);
    }

    function marry() public onlySpouse {
        require(isEngaged, "Both spouses must be engaged to marry");

        isMarried = true;
        emit Married(spouse1, spouse2);
    }
}
