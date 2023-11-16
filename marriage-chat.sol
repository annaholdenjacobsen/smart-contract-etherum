// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WeddingContract is Ownable {
    enum WeddingStatus { Engaged, ParticipationsConfirmed, WeddingDay, Revoked, Invalid }

    struct Engagement {
        uint256 weddingDate;
        address fiance1;
        address fiance2;
        bool isRevoked;
        WeddingStatus status;
        mapping(address => bool) guests;
        mapping(address => bool) participationsConfirmed;
    }

    mapping(uint256 => Engagement) public engagements;
    uint256 public engagementCounter;

    modifier onlyFiances(uint256 _engagementId) {
        require(
            msg.sender == engagements[_engagementId].fiance1 ||
            msg.sender == engagements[_engagementId].fiance2,
            "You are not one of the fiances"
        );
        _;
    }

    modifier onlyAuthorized() {
        require(
            authorizedAccounts[msg.sender],
            "You are not an authorized account"
        );
        _;
    }

    event EngagementRegistered(uint256 indexed engagementId, address indexed fiance1, address indexed fiance2, uint256 weddingDate);
    event ParticipationsConfirmed(uint256 indexed engagementId);
    event EngagementRevoked(uint256 indexed engagementId);
    event WeddingCompleted(uint256 indexed engagementId);
    event WeddingInvalid(uint256 indexed engagementId);
    event WeddingCertificateIssued(uint256 indexed engagementId, address indexed spouse1, address indexed spouse2, string ipfsHash);

    function registerEngagement(address _fiance2, uint256 _weddingDate) external {
        require(_fiance2 != address(0) && _fiance2 != msg.sender, "Invalid address");
        require(engagements[engagementCounter].status == WeddingStatus.Revoked, "A wedding engagement is still active");
        
        engagements[engagementCounter] = Engagement({
            weddingDate: _weddingDate,
            fiance1: msg.sender,
            fiance2: _fiance2,
            isRevoked: false,
            status: WeddingStatus.Engaged
        });

        emit EngagementRegistered(engagementCounter, msg.sender, _fiance2, _weddingDate);
        engagementCounter++;
    }

    function confirmParticipations(uint256 _engagementId, address[] calldata _guests) external onlyFiances(_engagementId) {
        require(engagements[_engagementId].status == WeddingStatus.Engaged, "Invalid engagement status");
        
        for (uint256 i = 0; i < _guests.length; i++) {
            engagements[_engagementId].guests[_guests[i]] = true;
        }

        engagements[_engagementId].status = WeddingStatus.ParticipationsConfirmed;

        emit ParticipationsConfirmed(_engagementId);
    }

    function revokeEngagement(uint256 _engagementId) external onlyFiances(_engagementId) {
        require(engagements[_engagementId].status != WeddingStatus.Revoked, "Engagement is already revoked");

        engagements[_engagementId].isRevoked = true;
        engagements[_engagementId].status = WeddingStatus.Revoked;

        emit EngagementRevoked(_engagementId);
    }

    function completeWedding(uint256 _engagementId) external onlyFiances(_engagementId) {
        require(engagements[_engagementId].status == WeddingStatus.ParticipationsConfirmed, "Invalid engagement status");

        engagements[_engagementId].status = WeddingStatus.WeddingDay;

        emit WeddingCompleted(_engagementId);
    }

    function declareInvalidWedding(uint256 _engagementId) external onlyFiances(_engagementId) {
        require(engagements[_engagementId].status == WeddingStatus.WeddingDay, "Invalid engagement status");

        engagements[_engagementId].status = WeddingStatus.Invalid;

        emit WeddingInvalid(_engagementId);
    }

    function issueWeddingCertificate(uint256 _engagementId, string memory _ipfsHash) external onlyFiances(_engagementId) {
        require(engagements[_engagementId].status == WeddingStatus.WeddingDay, "Invalid engagement status");
        
        mint(msg.sender, _ipfsHash);

        emit WeddingCertificateIssued(_engagementId, engagements[_engagementId].fiance1, engagements[_engagementId].fiance2, _ipfsHash);
    }

    // Authorized accounts for certain functionalities
    mapping(address => bool) public authorizedAccounts;

    function addAuthorizedAccount(address _account) external onlyOwner {
        authorizedAccounts[_account] = true;
    }

    function removeAuthorizedAccount(address _account) external onlyOwner {
        authorizedAccounts[_account] = false;
    }
}

contract WeddingCertificate is ERC721Enumerable, Ownable {
    constructor() ERC721("WeddingCertificate", "WEDDINGCERT") {}

    function mint(address _to, uint256 _tokenId, string memory _ipfsHash) external onlyOwner {
        _safeMint(_to, _tokenId);
        _setTokenURI(_tokenId, _ipfsHash);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
        require(from == address(0) || to == address(0), "Token is non-transferable");
    }
}
