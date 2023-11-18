// SPDX-License-Identifier: none
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./marriage-registry.sol";

contract MarriageLicense is ERC721 {
    // Start the tokencounter from 1 when contract is initialized  
    uint32 private tokenCounter = 1;

    //Create a marriagecertificate joined by the spouses tokens to their NFTs
    struct MarriageCertificate {
        uint32 tokenSpouse1;
        uint32 tokenSpouse2;
    }

    // A mapping from each address to their marriage certificate
    mapping (address => MarriageCertificate) private token;
    // A mapping that checks if the given address has had a certificate issued
    mapping (address=> bool) private certificateIssued;

    //The marriageregistry which is deployed
    MarriageRegistry private marriageRegistry;

    
    // Have a constructor for setting up important details regarding the marriage license
    constructor(address _marriageRegistryAddress) ERC721("WeddingCertificate", "<3") {
        marriageRegistry = MarriageRegistry(_marriageRegistryAddress);
    }

    //An event that displayes if a wedding certificate has been issued
    event weddingCertificateIssued(address indexed spouse1, address indexed spouse2);

    IERC721 nftContract = IERC721(this);

    //The marriage certificate is non-transferable
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(from == address(0) || to == address(0) || tokenId < 0, "NFT is non-transferable");
        revert("NFT is non-transferable");
    }

    // Issue a wedding certificate to a couple
    function createWeddingCertificate(address spouse1, address spouse2) public returns (uint32[2] memory) {
        //Avoid that someone gives you a certificate before you are married
        require(marriageRegistry.isMarried(spouse1) && marriageRegistry.isMarried(spouse2), "You have to be married to get a certificate");
        //Avoid that someone exchanges your token if you already have one
        require(certificateIssued[spouse1] != true && certificateIssued[spouse2] != true, "Certificate already issued for this marriage");
     
        // Create the token IDs for spouse 1
        token[spouse1].tokenSpouse1 = tokenCounter;
        token[spouse2].tokenSpouse1 = tokenCounter;
        // Create the NFT based on the token
        _safeMint(spouse1, hashToken(token[spouse1].tokenSpouse1));
        certificateIssued[spouse1] = true;
        tokenCounter++;

        //Create the token IDs for spouse 2
        token[spouse2].tokenSpouse2 = tokenCounter;
        token[spouse1].tokenSpouse2 = tokenCounter;
        // Create the NFT based on the token
        _safeMint(spouse2, hashToken(token[spouse2].tokenSpouse2));
        certificateIssued[spouse2] = true;
        tokenCounter++;

        //Emit the event that the wedding certificate has been issued
        emit weddingCertificateIssued(spouse1, spouse2);

        //Return the spouses tokens so they can store them incase they want to divorce
        return [token[spouse1].tokenSpouse1, token[spouse1].tokenSpouse2];

    }

    //A function to hash the token
    function hashToken(uint32 _token) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_token)));
    }

    // Burn the wedding certificate in case the couple wants a divorce
    function divorce(address _spouse1, address _spouse2, uint32[2] calldata _tokens) public {
        //Check that the tokens are the same to make sure the people calling the function are authorized to make the decision
        require(token[_spouse1].tokenSpouse1 == _tokens[0] && token[_spouse2].tokenSpouse2 == _tokens[1], "You arent authorized to divorce");
        // Burn the certificates
        _burn(hashToken(token[_spouse1].tokenSpouse1));
        _burn(hashToken(token[_spouse2].tokenSpouse2));

        //Set the certificate issued state to false
        certificateIssued[_spouse1] = false;
        certificateIssued[_spouse1] = false;
    }

}