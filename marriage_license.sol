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
    uint256 public weddingDay;

    uint8 private spouseCounter;
    uint8 private authorizedCounter;
    uint256[] private tokensVoted;
    mapping (address => bool ) private authorizedAddresses;
    mapping ( address => uint8[] ) private authorizedVotingList;
    
    // Have a constructor for setting up important details regarding the marriage license
    constructor() ERC721("Wedding", "wed") {
        spouse1 = msg.sender;

        spouseCounter = 0;
        authorizedCounter = 0;
    }

    IERC721 nftContract = IERC721(this);

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

    function createWeddingCertificate(uint32 _token1, uint32 _token2) public {
        require(isMarried, "Cannot produce wedding certificate for non-married people");
        require(nftContract.ownerOf(hashToken(token1)) == spouse1 || nftContract.ownerOf(hashToken(token2)) == spouse2,"Cannot create another wedding certificate when one exists for these spouses");
        
        // Create the token IDs
        token1 = _token1;
        token2 = _token2;
        

        // Create the wedding certificates
        _mint(spouse1, hashToken(token1));
        _mint(spouse2, hashToken(token2));
    }

    function hashToken(uint32 token) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(token)));
    }

    function setSpouses(address _spouse1, address _spouse2) public {
        spouse1 = _spouse1;
        spouse2 = _spouse2;
    }

    function setMarriageStatus(bool status) public {
        isMarried = status;
    }

    function getMarriageStatus() view public returns (bool) {
        return isMarried;
    }

    function authorizeAccounts(address authorizeAddress, uint8 tokenId) public {
        // Check that an account is not being re-authorized
        require(!authorizedAddresses[authorizeAddress], "Cannot re-authorize an address");

        // Check which of the spouses just voted on the address
        if(msg.sender == spouse1) {
            authorizedVotingList[authorizeAddress][0] = 1;
        } else if (msg.sender == spouse2) {
            authorizedVotingList[authorizeAddress][1] = 1;
        }

        // Check that both spouses have voted for authorizing the address, and if they have: create a token for voting for the address
        if(authorizedVotingList[authorizeAddress][0]+authorizedVotingList[authorizeAddress][1] == 2) {
            authorizedAddresses[authorizeAddress] = true;

            _mint(authorizeAddress, hashToken(tokenId));
        }
    }

    function divorce(uint32 tokenId) public {
        require(isMarried, "Non-married people cannot divorce");
        bool enoughParticipantsVoted = enoughParticipantsVote(hashToken(tokenId), msg.sender);
        require(enoughParticipantsVoted, "Not enough participants agree to the divorce");

        // Burn the certificates
        _burn(hashToken(token1));
        _burn(hashToken(token2));

        // Update status
        setMarriageStatus(false);
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
                if (authorizedAddresses[sender]) {
                    authorizedCounter += 1;
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