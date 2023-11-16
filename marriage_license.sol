// SPDX-License-Identifier: none
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MarriageLicense is ERC721 {
    // ATTRIBUTES
    uint32 private token1;
    uint32 private token2;
    
    address private spouse1;
    address private spouse2;
    bool public isMarried;
    uint16 public weddingDay;

    uint8 private spouseCounter;
    uint8 private authorizedCounter;
    uint256[] private tokensVoted;
    uint32 private verifyAddressesToken;
    address[] private authorizedAddresses;
    mapping ( address => uint8[] ) private authorizedVotingList;
    
    // Have a constructor for setting up important details regarding the marriage license
    constructor(address spouse, 
                bool marriageStatus, 
                uint16 weddingDate) 
                ERC721("Wedding", "wed") {
        spouse1 = msg.sender;
        spouse2 = spouse;
        weddingDay = weddingDate;
        isMarried = marriageStatus;

        spouseCounter = 0;
        authorizedCounter = 0; 
        verifyAddressesToken = 0;
        token1 = 50;
        token2 = 51;
    }

    IERC721 nftContract = IERC721(this);

    // STATE HANDLING
    event Divorce(address indexed spouse1, address indexed spouse2);

    modifier onlySpouse() {
        require(msg.sender == spouse1 || msg.sender == spouse2, "Only spouses can call this function");
        _;
    }

    // FUNCTIONALITY
    // Disable transfer-functionality
    /*
    function _transfer(address from, address to, uint256 value) internal virtual override (ERC721) {
        revert("NFT is non-transferable");
    }*/
    
    // d sies at vi skal bruke den over for å disable transferring ved å overskrive men det funka ikke så gjør d som nedenfor istedet maybe
    function TransferFrom() internal virtual {
        revert("NFT is non-transferable");
        
    }

  

    function createWeddingCertificate() public onlySpouse {
        require(isMarried, "Cannot produce wedding certificate for non-married people");
        require(nftContract.ownerOf(token1) == spouse1 || nftContract.ownerOf(token2) == spouse2,"Cannot create another wedding certificate when one exists for these spouses");
        
        // Create the token IDs
        token1 += 1;
        token2 += 1;

        // Create the wedding certificates
        _mint(spouse1, token1);
        _mint(spouse2, token2);
    }

    function authorizeAccounts(address authorizeAddress) public onlySpouse {
        // Check that an account is not being re-authorized
        for(uint8 i = 0; i < 3; i++) {
            require(authorizedAddresses[i] != authorizeAddress, "Cannot re-authorize an address");
        }

        // Check which of the spouses just voted on the address
        if(msg.sender == spouse1) {
            authorizedVotingList[authorizeAddress][0] = 1;
        } else if (msg.sender == spouse2) {
            authorizedVotingList[authorizeAddress][1] = 1;
        }

        // Check that both spouses have voted for authorizing the address, and if they have: create a token for voting for the address
        if(authorizedVotingList[authorizeAddress][0]+authorizedVotingList[authorizeAddress][1] == 2) {
            verifyAddressesToken += 1;
            authorizedAddresses.push(authorizeAddress);

            _mint(authorizeAddress, verifyAddressesToken);
        }
    }

    function divorce(uint256 tokenId) public onlySpouse {
        require(isMarried, "Non-married people cannot divorce");
        bool enoughParticipantsVoted = enoughParticipantsVote(tokenId, msg.sender);
        require(enoughParticipantsVoted, "Not enough participants agree to the divorce");

        // Burn the certificates
        _burn(token1);
        _burn(token2);

        // Update status
        isMarried = false;
        emit Divorce(spouse1, spouse2);
    }

    function enoughParticipantsVote(uint256 token, address sender) internal returns (bool) {
        // Check if the token has been used to vote already, and that the owner is using the token
        bool ownerToken = nftContract.ownerOf(token) == sender;
        bool alreadyVoted = false;
        for (uint8 i = 0; i < 3; i++) {
            if (token == tokensVoted[i]) {
                alreadyVoted = true;
            }
        }

        // If token has not already voted, check whether it is a spouse or an authorized address
        if (!alreadyVoted && ownerToken) {
            tokensVoted.push(token);
            if (sender == spouse1 || sender == spouse2) {
                spouseCounter += 1;
            }
            else {
                for(uint8 i = 0; i < 3; i++) {
                    if (sender == authorizedAddresses[i]) {
                        authorizedCounter += 1;
                    }
                }
            }
        }

        // Check new voting score to see if the NFT can be burned, if so return true
        if (spouseCounter == 2 || (spouseCounter == 1 && authorizedCounter > 0)) {
            return true;
        }
        return false;
    }

}