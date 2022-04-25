/**
 *Submitted for verification at testnet.snowtrace.io on 2022-01-21
*/

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PixpelNFT is ReentrancyGuard, ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Burnable, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    string private baseTokenURI;
    address public PIXPContractAddress;
    address public charityWalletAddress;

    uint256 private constant MINT_FEE = 1;
    uint256 private constant PERCENTAGE = 100;
    uint256 private constant ROYALTY_FEE = 3;

    struct NFTInfo {
        uint256 tokenId;
        uint256 devId;
        uint256 gameId;
        uint256 price;
        address creator;
        uint256 mintedTime;
        uint256 lastSaledTime;
        address currentOwner;
        address previousOwner;
        uint256 royalty;
    }

    mapping(address => bool) public addressForRegister;
    mapping(uint256 => uint256) public totalSupplyForGameType;
    mapping(uint256 => NFTInfo) public NFTInfoForTokenId;
    
    modifier onlyRegister() {
        require(
            addressForRegister[msg.sender],
            "Can only be called by register"
        );
        _;
    }

    event NFTMinted(
        uint256 tokenId,
        uint256 gameId,
        uint256 price,
        address creator
    );
    
    constructor(address _pixpContractAddress, address _charityWalletAddress) ERC721("PixpelNFT", "PIXPNT") {
        PIXPContractAddress = _pixpContractAddress;
        charityWalletAddress = _charityWalletAddress;
    }
    receive() external payable {}

    function _baseURI() 
        internal 
        view 
        override 
        returns(string memory) 
    {
        return baseTokenURI;
    }
    
    function setBaseURI(string memory _newuri) 
        external 
        onlyOwner 
    {
        baseTokenURI = _newuri;
    }

    function mintNFT(uint256 _devId, uint256 _gameId, uint256 _amount, uint256 _price) 
        public 
        onlyRegister
    {
        require(IERC20(PIXPContractAddress).balanceOf(msg.sender) >= _price.mul(_amount), "Insufficient funds.");
        require(IERC20(PIXPContractAddress).allowance(msg.sender, address(this)) >= _price.mul(_amount), "Allowance funds must exceed price");

        for(uint256 i = 0; i < _amount; i++) {            
            uint256 _newTokenId = _tokenIds.current();
            _safeMint(msg.sender, _newTokenId);
            _tokenIds.increment();

            NFTInfoForTokenId[_newTokenId].tokenId = _newTokenId;
            NFTInfoForTokenId[_newTokenId].devId = _devId;
            NFTInfoForTokenId[_newTokenId].gameId = _gameId;
            NFTInfoForTokenId[_newTokenId].price = _price;
            NFTInfoForTokenId[_newTokenId].creator = msg.sender;
            NFTInfoForTokenId[_newTokenId].mintedTime = block.timestamp;
            NFTInfoForTokenId[_newTokenId].lastSaledTime = block.timestamp;
            NFTInfoForTokenId[_newTokenId].currentOwner = msg.sender;
            NFTInfoForTokenId[_newTokenId].previousOwner = address(0);
            NFTInfoForTokenId[_newTokenId].royalty = ROYALTY_FEE;
            
            emit NFTMinted(
                _newTokenId,
                _gameId,
                _price,
                msg.sender
            );
        }

        uint256 mintFee = _price.mul(_amount).mul(MINT_FEE).div(PERCENTAGE);
        uint256 commissionValue = _price.mul(_amount).sub(mintFee);

        require(IERC20(PIXPContractAddress).transferFrom(msg.sender, address(this), commissionValue), "Transfer failed");
        require(IERC20(PIXPContractAddress).transferFrom(msg.sender, charityWalletAddress, commissionValue), "Transfer fee failed");
    }

    function tokensOfOwner(address _owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(_owner);
        uint256[] memory tokensIds = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokensIds[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensIds;
    }

    function _totalSupply() 
        internal 
        view 
        returns (uint) 
    {
        return _tokenIds.current();
    }

    function withdrawAll() 
        public 
        payable 
        onlyOwner 
    {
        uint256 balance = address(this).balance;
        require(balance > 0);
        _widthdraw(msg.sender, address(this).balance);
    }

    function _widthdraw(
        address _address, 
        uint256 _amount
    ) private 
    {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
    }

    function tokenURI(uint256 tokenId) 
        public 
        view 
        virtual 
        override (ERC721, ERC721URIStorage)
        returns (string memory) 
    {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(),".json")) : "";
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function registerAddress(address _register) 
        public
        onlyOwner
    {
        require(_register != owner(), "Can not be registered.");
        addressForRegister[_register] = true;
    }

    function unregisterAddress(address _unregister)
        public
        onlyOwner
    {
        addressForRegister[_unregister] = false;
    }

    function isRegister()
        public 
        view
        returns(bool)
    {
        return addressForRegister[msg.sender];
    }
}