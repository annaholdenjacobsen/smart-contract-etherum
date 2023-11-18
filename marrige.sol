// SPDX-License-Identifier: none

pragma solidity ^0.8.20;

import "./marriage_license.sol";
import "./marriage-registry.sol";


contract MarriageContract {

    //The addresses of both spouses in an engagement
    address public spouse1;
    address public spouse2;

    // The date and time of the wedding
    uint32 public weddingDate; 

    // A mapping that checks if a spouse proposed
    mapping (address => bool) private spouseProposed;
    // A mapping that checks if the spouses has agreed to marry
    mapping (address => bool) private spouseSaidIDo;

    // The marrige registry that documents if an adress is married or not
    MarriageRegistry private marriageRegistry;
    // The marriage license that distributes wedding certificates
    MarriageLicense private marriageLicense;

    //Tokens for the weddingcertificate
    uint32 private tokenSpouse1;
    uint32 private tokenSpouse2;

    // Possible states in the smart contract
    enum State {Created, Engaged, Aborted, Wed, Invalid}
    // The current state of the contract
    State public currentState;

    //A list of proposed participations
    address[] public participations;
    //A mapping to check if the spouses has confirmed the proposed participations
    mapping (address => bool) private spouseConfirmedGuests;
    // An overview of all guests and their votes
    mapping(address => bool) public guestVoted;
    // The sum of all votes against the wedding
    uint8 public againstVotes;

    //A list over the proposed authorizedAccounts
    address[] private authorizedAccounts;
    //A mapping to check if the spouses has confirmed the proposed authorized accounts
    mapping (address => bool) private spouseConfirmedAuthorizedAccount;

    //A mapping of spouses and if they want a divorce
    mapping (address => bool) private spouseWantsDivorce;
    //A check to see if an authorized account has supported a divorce
    bool private authorizedAccountWantsDivorce;


    //Different events that occurs in the contract
    event proposalInitiated(address indexed spouse1, address indexed spouse2);
    event Engaged(address indexed spouse1, address indexed spouse2);
    event Married(address indexed spouse1, address indexed spouse2);
    event EngagementRevoked(address indexed spouse1, address indexed spouse2);
    event WeddingInvalid(address indexed spouse1, address indexed spouse2);
    event Divorce(address indexed spouse1, address indexed spouse2);
    event ParticipationsInvited(address[] participants);
    event ParticipationsProposed(address[] participants);

    //Constructer which runs when the contract is deployed
    constructor(address _marriageRegistryAddress, address _marriageLicenseAddress) {
        currentState = State.Created;
        marriageRegistry = MarriageRegistry(_marriageRegistryAddress);
        marriageLicense = MarriageLicense(_marriageLicenseAddress);
    }

    //Checks that the message sender is one of the spouses
    modifier onlySpouse() {
        require(msg.sender == spouse1 || msg.sender == spouse2, "Only spouses can call this function");
        _;
    }
    // Check if the message sender is already married using the MarriageRegistry instance
    modifier onlyUnmarried() {
        require(!marriageRegistry.isMarried(msg.sender), "Spouse is already married");
        _;
    }
    //Check if the message sender is one of the confirmed authorized accounts
    modifier onlyAuthorized() {
        bool isAuthorized = false;
        for (uint16 i=0; i < authorizedAccounts.length; i++) {
            if (authorizedAccounts[i] == msg.sender) {
                isAuthorized = true;
                break;
            }
        }
        require(isAuthorized, "You are not an authorized account");
        require(spouseConfirmedAuthorizedAccount[spouse1] && spouseConfirmedAuthorizedAccount[spouse2], "The spouses havent agreed on the authorized accounts");
        _;
    }


    //Checks if the message sender is in the participations list, and checks if both spouses had confirmed the list
    modifier onlyGuests() {
        bool isguest = false;
        for (uint16 i = 0; i < participations.length; i++) {
            if (participations[i] == msg.sender) {
                isguest = true;
                break;
            }
        }
        require(isguest, "You are not a guest at this wedding");
        require(spouseConfirmedGuests[spouse1] && spouseConfirmedGuests[spouse2], "You have not been invited by both spouses");
        _;
    }

    //A check to see if an address is a valid address
    function validAddress(address _address) private pure returns (bool) {
        return _address != address(0);
    }


    //The message sender proposes to an address and also suggests a weddingdate in UNIX format
    function propose(address _spouse2, uint32 _weddingDate) public onlyUnmarried{
        //Checks that the stade is valid, that you arent trying to marry yourself, that the address is valid and that the weddingdate isnt set less than 10 seconds in advance
        require(currentState != State.Aborted || currentState != State.Invalid, "If your marriage is invalid or aborted you cant get married again");
        require(msg.sender != _spouse2, "Cannot marry yourself");
        require(validAddress(_spouse2), "Invalid address");
        require(_weddingDate > block.timestamp + 10, "Cannot set date of wedding to be less than 10 seconds in advance");

        //Sets all the variables globally
        weddingDate = _weddingDate;
        spouse1 = msg.sender;
        spouse2 = _spouse2;
        spouseProposed[spouse1] = true;
        spouseProposed[spouse2] = false;

        //Emits the event that a proposal is initiated
        emit proposalInitiated(spouse1, spouse2);
    }
    //If the spouse wants to get married, but dont like the suggested weddingdate, you can counterpropose
    function counterProposal(uint32 _weddingDate) public onlyUnmarried {
        require(msg.sender == spouse2, "Someone other than spouse2 cannot propose a new wedding date");
        require(_weddingDate > block.timestamp + 10, "Cannot set date of wedding to be less than 10 seconds in advance");

        weddingDate = _weddingDate;
        spouseProposed[spouse1] = false;
        spouseProposed[spouse2] = true;

        emit proposalInitiated(spouse1, spouse2);
    }

    //Accept the proposal
    function acceptProposal() public onlyUnmarried {
        if(spouseProposed[spouse1]) {  //if spouse1 proposed, then the caller of the function has to be spouse 2
            require(msg.sender == spouse2, "Only spouse2 can accept spouse1's proposal");
        } else if (spouseProposed[spouse2]) { //If spouse2 proposed, then the caller of the function has to be spouse 1
            require(msg.sender == spouse1, "Only spouse1 can accept spouse2's proposal");
        }
        emit Engaged(spouse1, spouse2); //Emit the event that the spouses are engaged
        currentState = State.Engaged; //Change the state to enga
    }
    //Propose a guest list for the wedding
    function proposeParticipations(address[] memory _guests) public onlySpouse {
        //You need to be engaged to propose guests
        require(currentState == State.Engaged, "Invalid engagement status");
        //You cannot propose a new list if you have already agreed on a guest list
        require(spouseConfirmedGuests[spouse1] != true && spouseConfirmedGuests[spouse2] != true, "Spouses already agreed on participation list");

        //Goes through all proposed guests and checks that the addresses are valid
        for (uint8 i = 0; i < _guests.length; i++ ) {
            require(validAddress(_guests[i]), "Cannot invite an invalid address");
        }
        //Sets the variable globally
        participations = _guests;

        //When you propose a guest list you also automatically approve
        spouseConfirmedGuests[msg.sender] = true;

        //Send an event that a guest list is proposed
        emit ParticipationsProposed(_guests);
    }

    //Confirm participants
    function confirmParticipations() public onlySpouse {
        //You cant agree on a guest list twice
        require(!spouseConfirmedGuests[msg.sender], "Guest list already confirmed");
        //There has to be one or more proposed guests for you to be able to confirm the list
        require(participations.length > 0, "No participants proposed");
        
        //Spouse confirms the list
        spouseConfirmedGuests[msg.sender] = true;

        //Guests invited
        emit ParticipationsInvited(participations);
    }

    // Invalidate the wedding
    function InvalidateWedding() private {
        //The wedding cant be in the aborted state
        require(currentState != State.Aborted, "invalid state transition");
        require(isWeddingDay(), "Cant invalidate a wedding unless its the wedding day");

        // Set the state of the marriage to invalid
        currentState = State.Invalid;

        // Sets the marriage status of the spouses to false, in case they already got married
        marriageRegistry.revokeMarriage(spouse1);
        marriageRegistry.revokeMarriage(spouse2);
        // Emit the event that the wedding is invalid
        emit WeddingInvalid(spouse1,spouse2);

    }

    //Revoke engagement
    function revokeEngagement() public onlySpouse {
        //Checks that you actually are engaged
        require(currentState == State.Engaged, "You can't revoke an unactive engagement");
        //Changes the state to aborted
        currentState = State.Aborted;
        //Emits the event that the engagement is revoked
        emit EngagementRevoked(spouse1,spouse2);
    }


    //Spouse says "I do" and agrees to get married
    function sayIDo() public onlySpouse {
        //Checks that you are engaged to allow you to get married
        require(currentState == State.Engaged, "You must be engaged to say I do");
        //Set the mapped boolean to true
        spouseSaidIDo[msg.sender] = true;
    }

    // Return the date of the given unix timestamp
    function getDateFromTimestamp(uint32 timestamp) internal pure returns (uint32) {
        uint32 oneDay = 86400; // Number of seconds in one day
        uint32 dateOnly = (timestamp / oneDay) * oneDay;
        return dateOnly;
    }

    //Checks that the current date is the same as the weddingdate
    function isWeddingDay() private view returns (bool) {
        uint32 startOfDay = getDateFromTimestamp(weddingDate); 
        uint32 endOfDay = startOfDay + 86400;

        // Check if the current timestamp is within the wedding day
        return block.timestamp >= startOfDay && block.timestamp < endOfDay;
    }

    //"I now pronounce you husband and wife"
    function marry() public onlySpouse {
        //Check that the spouses isEngaged
        require(currentState == State.Engaged, "Both spouses must be engaged to marry");
        //Check that both spouses said I do
        require(spouseSaidIDo[spouse1] && spouseSaidIDo[spouse2], "Both spouses must say I do to get married");
        //Check that it is the wedding day
        require(isWeddingDay(), "Can't get married if its not your wedding day");

        // Update engaged and married status
        currentState = State.Wed;

        // Set marriage status in the registry
        marriageRegistry.setMarriage(spouse1);
        marriageRegistry.setMarriage(spouse2);

        // Create marriage license
        uint32[2] memory tokens = marriageLicense.createWeddingCertificate(spouse1,spouse2);
        // Save the tokens in the license for later, in case of divorce
        tokenSpouse1 = tokens[0];
        tokenSpouse2 = tokens[1];

        //Emit the event that the spouses got married
        emit Married(spouse1, spouse2);
    }

    //A spouse can register that they want a divorce
    function spouseWantDivorce() public onlySpouse {
        require(currentState == State.Wed, "You have to be married before you can get divorced");
        spouseWantsDivorce[msg.sender]=true;
    }

    //An authorized account can support the divorce
    function authorizedAccountWantDivorce() public onlyAuthorized {
        require(currentState == State.Wed, "The couple has to be married before they can get divorced");
        authorizedAccountWantsDivorce = true;
    }

    // A spouse can propose a list of authorized addresses
    function proposeAuthorizedAdresses(address[] memory _AuthorizedAddresses) public onlySpouse {
        //You need to be engaged or married to propose authorized accounts
        require(currentState == State.Engaged || currentState == State.Wed, "Invalid engagement status");
        //You cannot propose a new list if you have already agreed on a authorized account list
        require(spouseConfirmedAuthorizedAccount[spouse1] != true && spouseConfirmedAuthorizedAccount[spouse2] != true, "Spouses already agreed on participation list");

        //Goes through all proposed authorized accounts and checks that the addresses are valid
        for (uint8 i = 0; i < _AuthorizedAddresses.length; i++ ) {
            require(validAddress(_AuthorizedAddresses[i]), "Cannot invite an invalid address");
        }
        
        authorizedAccounts = _AuthorizedAddresses;

        //When you propose a authorized account list you also automatically approve
        spouseConfirmedAuthorizedAccount[msg.sender] = true;

    }
    // A spouse can approve of the proposed list of authorized accounts
      function confirmAuthorizedAccounts() public onlySpouse {
        //You cant agree on a authorized accounts twice
        require(!spouseConfirmedAuthorizedAccount[msg.sender], "Authorized accounts list already confirmed");
        //There has to be one or more proposed authorized accounts for you to be able to confirm the list
        require(authorizedAccounts.length > 0, "No authorized accounts proposed");
        
        //Spouse confirms the list
        spouseConfirmedAuthorizedAccount[msg.sender] = true;
    }

    // Execute the divorce between the spouses
    function divorce() public onlySpouse {
        require(currentState == State.Wed, "You have to be married to get divorced"); // Checks that you are married
        //Checks that either both spouses want to get divorced, or that one spouse and one authorized address agrees that the couple should divorce
        require((spouseWantsDivorce[spouse1] && spouseWantsDivorce[spouse2]) || ((spouseWantsDivorce[spouse1] || spouseWantsDivorce[spouse2]) && authorizedAccountWantsDivorce), "Both spouses need to agree, or one spouse and one authorized account, to get divorced");

        //Destroy the marriage license
        marriageLicense.divorce(spouse1, spouse2, [tokenSpouse1,tokenSpouse2]);

        //Register both spouses marriage status as single
        marriageRegistry.revokeMarriage(spouse1);
        marriageRegistry.revokeMarriage(spouse2);

        //Emit the event of the divorce between the spouses
        emit Divorce(spouse1, spouse2);

        //Set the current state to aborted
        currentState = State.Aborted;
    }

    //A guest can vote against the wedding
    function voteAgainstWedding() public onlyGuests {
        require(!guestVoted[msg.sender], "Guest has already voted"); //The guest isnt allowed to vote twice
        //The guest can vote while the couple is either engaged or wed, as long as it is on their wedding day
        require(currentState == State.Wed || currentState == State.Engaged, "Cannot stop a marriage that does not exist"); 
        require(isWeddingDay(), "Speak on the wedding day or forever hold your peace");
        
        //Set that the guest has voted, and increase the number of votes against the marriage
        guestVoted[msg.sender] = true;
        againstVotes++;

        //Check that if the total votes against the wedding is larger than half the amount of guests, the marriage is deeemed invalid
        if (againstVotes > participations.length / 2) {
            InvalidateWedding();
        }
    }

}
