// SPDX-License-Identifier: none

pragma solidity ^0.8.20;

import "./marriage_license.sol";

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


contract MarriageContract {

    //The addresses of both spouses in an engagement
    address public spouse1;
    address public spouse2;

    // The date and time of the wedding
    uint32 public weddingDate; 

    // A mapping that checks what spouse proposed
    mapping (uint8 => bool) public spouseProposed;
    // A mapping that checks if the spouses has agreed to marry
    mapping (address => bool) public spouseSaidIDo;

    // The marrige registry that documents if an adress is married or not
    MarriageRegistry public marriageRegistry;

    // The marriage license that distributes wedding certificates
    MarriageLicense public marriegeLicense;

    // Possible states in the smart contract
    enum State {Created, Engaged, Aborted, Wed, Invalid}

    // The current state of the contract
    State public currentState;

    //A list of proposed participations
    address[] public participations;

    //A mapping to check if the spouses has confirmed the proposed participations
    mapping (address => bool) public confirmedParticipations;


    uint16 public votingDeadline;


    // A vote object that checks if a guest already have voted, and if they vote against the wedding
    struct Vote {
        bool hasVoted;
        bool voteAgainst;
    }

    // An overview of all guests and their votes
    mapping(address => Vote) public guestVotes;

    // The sum of all votes against the wedding
    uint16 public againstVotes;



    //Propose participants
    function proposeParticipations(address[] memory _guests) public onlySpouse {
        //You need to be engaged to propose guests
        require(currentState == State.Engaged, "Invalid engagement status");
        //You cannot propose a new list if you have already agreed on a guest list
        require(confirmedParticipations[spouse1] != true && confirmedParticipations[spouse2] != true, "Spouses already agreed on participation list");

        //Goes through all proposed guests and checks that the addresses are valid
        for (uint8 i=0; i < _guests.length; i++ ) {
            require(validAddress(_guests[i]), "Cannot invite an invalid address");
        }

        //Set the participations list to the proposed guests
        participations = _guests;
        //When you propose a guest list you also automatically approve
        confirmedParticipations[msg.sender] = true;

        //Send an event that a guest list is proposed
        emit ParticipationsProposed(_guests);
    }

    //Confirm participants
    function confirmParticipations() public onlySpouse {
        //You have to be engaged to confirm a guest list
        require(currentState == State.Engaged, "Invalid engagement status");
        //You cant agree on a guest list twice
        require(confirmedParticipations[msg.sender] != true, "Guest list already confirmed");
        //There has to be one or more proposed guests for you to be able to confirm the list
        require(participations.length > 0, "No participants proposed");
        
        //Spouse confirms the list
        confirmedParticipations[msg.sender] = true;

        //Guests invited
        emit ParticipationsInvited(participations);
    }


    //TODO add a certain time frame limit

    // Invalidate the wedding
    function InvalidateWedding() private {
        //The wedding cant be in the aborted state
        require(currentState != State.Aborted, "invalid state transition");

        // Set the state of the marriage to invalid
        currentState = State.Invalid;

        // Sets the marriage status of the spouses to false, in case they already got married
        marriageRegistry.revokeMarriage(spouse1);
        marriageRegistry.revokeMarriage(spouse2);

        // Emit the event that the wedding is invalid
        emit WeddingInvalid(spouse1,spouse2);

    }

    event proposalInitiated(address indexed spouse1, address indexed spouse2);
    event Engaged(address indexed spouse1, address indexed spouse2);
    event Married(address indexed spouse1, address indexed spouse2);
    event EngagementRevoked(address indexed spouse1, address indexed spouse2);
    event WeddingCompleted(address indexed spouse1, address indexed spouse2);
    event WeddingInvalid(address indexed spouse1, address indexed spouse2);
    event WeddingCertificateIssued(uint256 indexed engagementId, address indexed spouse1, address indexed spouse2, string ipfsHash);

    event ParticipationsInvited(address[] participants);
    event ParticipationsProposed(address[] participants);

    // TODO update after adding stuff
    constructor() {
        spouse1 = msg.sender;
        spouseProposed[0] = false;
        spouseProposed[1] = false;
        currentState = State.Created;
    }


    modifier onlySpouse() {
        //Checks that the message sender is one of the spouses
        require(msg.sender == spouse1 || msg.sender == spouse2, "Only spouses can call this function");
        _;
    }


    //OBS Denne funker ikke
   modifier onlyUnmarried() {
    // Check if the message sender is already married using the MarriageRegistry instance
    require(!marriageRegistry.isMarried(msg.sender), "Spouse is already married");
    _;
}


    // Denne er et problemn når gjest nr 2 skal vote against wedding, skjønner ikke hvorfor
    modifier onlyGuests() {
        bool isguest = false;
        //Checks if the message sender is in the participations list, and checks if both spouses had confirmed the list
        for (uint16 i = 0; i < participations.length; i++) {
            if (participations[i] == msg.sender) {
                isguest = true;
                break;
            }
        }
        require(isguest, "You are not a guest at this wedding");
        require(confirmedParticipations[spouse1] && confirmedParticipations[spouse2], "You have not been invited by both spouses");
        _;
    }

    function validAddress(address _address) private pure returns (bool) {
        return _address != address(0);
    }

    // ACTION FUNCTIONALITY

    //Spouse 1 proposes to Spouse 2
    //Calldata specifies that you cant change the value within the function
    function propose(address _spouse2, uint32 _weddingDate) external {
        require(msg.sender != _spouse2, "Cannot marry yourself");
        require(validAddress(_spouse2), "Invalid address");
        require(_weddingDate > block.timestamp + 10, "Cannot set date of wedding to be less than 10 seconds in advance");

        weddingDate = _weddingDate;
        spouse1 = msg.sender;
        spouse2 = _spouse2;
        spouseProposed[0] = true;
        spouseProposed[1] = false;

        emit proposalInitiated(spouse1, spouse2);
    }

    function counterProposal(uint32 _weddingDate) external onlyUnmarried {
        require(msg.sender == spouse2, "Someone other than spouse2 cannot propose a new wedding date");
        require(_weddingDate > block.timestamp + 10, "Cannot set date of wedding to be less than 10 seconds in advance");

        weddingDate = _weddingDate;
        spouseProposed[0] = false;
        spouseProposed[1] = true;

        emit proposalInitiated(spouse1, spouse2);
    }

    //Spouse 2 accepts proposal, engagement initiated
    //TODO maybe check if you can disagree on date but not proposal
    function acceptProposal() public onlyUnmarried {
        if(spouseProposed[0]) {
            require(msg.sender == spouse2, "Only spouse2 can accept spouse1's proposal");
            emit Engaged(spouse1, spouse2);
        } else if (spouseProposed[1]) {
            require(msg.sender == spouse1, "Only spouse1 can accept spouse2's proposal");
            emit Engaged(spouse1, spouse2);
        }
    }

    //Revoke engagement
    function revokeEngagement() public onlySpouse {
        require(currentState == State.Engaged, "You can't revoke an unactive engagement");

        currentState = State.Aborted;

        emit EngagementRevoked(spouse1,spouse2);
    }


    //Spouse agree to get married
    function sayIDo() public onlySpouse {
        require(currentState == State.Engaged, "You must be engaged to say I do");
        spouseSaidIDo[msg.sender] = true;
    }

    // Meg som har køddet rundt aner ikke om det funker
    function getDateFromTimestamp(uint32 timestamp) public pure returns (uint32) {
        uint32 oneDay = 86400; // Number of seconds in one day
        uint32 dateOnly = (timestamp / oneDay) * oneDay;
        return dateOnly;
    }

    //TODO fikse denne 
    function isWeddingDay() private view returns (bool) {
        uint32 startOfDay = getDateFromTimestamp(weddingDate); // assuming weddingDate is the start of the wedding day in Unix timestamp
        uint32 endOfDay = startOfDay + 86400;

        // Check if the current timestamp is within the wedding day
        return block.timestamp >= startOfDay && block.timestamp < endOfDay;
    }

    //Ikke debugga enda pga isWeddingday
    function marry() public onlySpouse {
        //Check that the spouses isEngaged
        require(currentState == State.Engaged, "Both spouses must be engaged to marry");
        //Check that both spouses said I do
        require(spouseSaidIDo[spouse1] && spouseSaidIDo[spouse2], "Both spouses must say I do to get married");
        //Check that it is the wedding day
        require(isWeddingDay(), "Cant get married if its not your wedding day");

        //Update engaged and married status
        currentState = State.Wed;

        //TODO create marriage license
      
        //Emit married event
        emit Married(spouse1, spouse2);
    }

    //Funker når første gjest bruker den, failer når nr 2 prøver seg
    function voteAgainstWedding() public onlyGuests {
        require(!guestVotes[msg.sender].hasVoted, "Guest has already voted");
        require(currentState == State.Wed, "Cannot stop a marriage that does not exist");
        require(isWeddingDay(), "Speak on the wedding day or forever hold your peace");

        guestVotes[msg.sender] = Vote(true, true);
        againstVotes++;

        if (againstVotes > participations.length / 2) {
            InvalidateWedding();
        }
    }

}
