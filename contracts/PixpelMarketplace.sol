// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/utils/Counters.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PixpelNFT.sol";

import "hardhat/console.sol";

/// @title An Auction Contract for bidding and selling single and batched NFTs
/// @author Dev Stenor Tanaka
/// @notice This contract can be used for auctioning any NFTs, and accepts any ERC20 token as payment
contract PixpelNFTMarket is ReentrancyGuard, Ownable {
  using SafeMath for uint256;
  using Strings for uint256;

  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;
  Counters.Counter private _claimedTokenIds;

  address payable public nftContractAddress; 
  address public PIXPContractAddress;
  address public charityWalletAddress;

  uint256 public listingPricePercentage;
  uint256 public unlistingPricePercentage;

  uint256 private constant MINT_FEE = 1;
  uint256 private constant PERCENTAGE = 100;
  uint256 private constant ROYALTY_FEE = 3;
  uint256 private constant OPEN_MYSTERY_FEE = 1;
  uint256 private constant SAVE_PERCENTAGE_FOR_SINGLE = 10;
  uint256 private constant SAVE_PERCENTAGE_FOR_OTHER = 70;
  uint256 _profit;

  constructor(
    address _nftContractAddress, 
    address _pixpContractAddress, 
    uint256 _listingPricePercentage, 
    uint256 _unlistingPricePercentage, 
    address _charityWalletAddress
  ) {
    _profit = 0;

    nftContractAddress = payable(_nftContractAddress);
    listingPricePercentage = _listingPricePercentage;
    unlistingPricePercentage = _unlistingPricePercentage;
    PIXPContractAddress = _pixpContractAddress;
    charityWalletAddress = _charityWalletAddress;
  }
  /* MarketItem and AuctionItem Struct */
  struct MarketItem {
    bool exist;
    uint256 tokenId;
    address creator;
    address currentOwner;
    uint256 price;
    string status;
    uint256 startAt;
    uint256 expiresAt;
  }

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

  // mapping marketItem
  mapping(uint256 => MarketItem) private idToMarketItem;
  // mapping auction item to bidders
  mapping(uint256 => address) private idToHighestBidder;
  mapping(uint256 => uint256) private idToHighestBid;
  mapping(address => bool) public addressForRegister;
  mapping(uint256 => uint256) public totalSupplyForGameType;
  mapping(uint256 => NFTInfo) public NFTInfoForTokenId;
  mapping(uint256 => uint256) public mintedAmountForGameType;

  modifier onlyRegister() {
    require(
        addressForRegister[msg.sender],
        "Can only be called by register"
    );
    _;
  }

  /* Define events */
  event MarketItemCreated(
    uint256 indexed tokenId,
    address creator,
    address currentOwner,
    uint256 price,
    string status,
    uint256 startAt,
    uint256 expiresAt
  );

  event MarketItemForSaleUpdated(
    uint256 tokenId,
    string status
  );

  event NFTPurchased(
    uint256 tokenId,
    address currentOwner,
    string status
  );

  event BidMade(
    uint256 tokenId,
    address bidder,
    uint256 bidPrice
  );

  event AuctionEnded(
    uint256 tokenId,
    address highestBidder,
    uint256 highestBid
  );

  event NFTMinted(
      uint256 tokenId,
      uint256 gameId,
      uint256 price,
      address creator
  );

  /* Set and Get various percentages*/
  /* Returns the percentage of listing price of the contract */
  function getListingPricePercentage() public view returns (uint256) {
    return listingPricePercentage;
  }

  /* Sets the listing price of the contract */
  function setListingPricePercentage(uint256 _listingPricePercentage) public onlyOwner {
    listingPricePercentage = _listingPricePercentage;
  }

  /* Returns the percentage of unlisting price of the contract */
  function getUnlistingPricePercentage() public view returns (uint256) {
    return unlistingPricePercentage;
  }

  /* Sets the percentge of unlisting price of the contract */
  function setUnlistingPricePercentage(uint256 _unlistingPricePercentage) public onlyOwner {
    unlistingPricePercentage = _unlistingPricePercentage;
  }

  function mintNFT(uint256 _devId, uint256 _gameId, uint256 _amount, uint256 _price)
    public 
    onlyRegister
  {
    if(totalSupplyForGameType[_gameId] > 0) {
      require(totalSupplyForGameType[_gameId] >= mintedAmountForGameType[_gameId].add(_amount), "Can not mint anymore");
    }
    require(IERC20(PIXPContractAddress).balanceOf(msg.sender) >= _price.mul(_amount), "Insufficient funds.");
    require(IERC20(PIXPContractAddress).allowance(msg.sender, address(this)) >= _price.mul(_amount), "Allowance funds must exceed price");

    for(uint256 i = 0; i < _amount; i++) {            
      uint256 _newTokenId = _tokenIds.current();
      PixpelNFT(nftContractAddress).mint(msg.sender);
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
    mintedAmountForGameType[_gameId] = mintedAmountForGameType[_gameId].add(_amount);

    uint256 mintFee = _price.mul(_amount).mul(MINT_FEE).div(PERCENTAGE);
    uint256 commissionValue = _price.mul(_amount).sub(mintFee);

    require(IERC20(PIXPContractAddress).transferFrom(msg.sender, address(this), commissionValue), "Transfer failed");
    require(IERC20(PIXPContractAddress).transferFrom(msg.sender, charityWalletAddress, commissionValue), "Transfer fee failed");
  }

  function claimNFT()
    public
  {
    require(_claimedTokenIds.current() <= _tokenIds.current(), "Not exist this token.");

    uint256 _priceMinted = NFTInfoForTokenId[_claimedTokenIds.current()].price;

    require(IERC20(PIXPContractAddress).balanceOf(msg.sender) >= _priceMinted.mul(PERCENTAGE.add(OPEN_MYSTERY_FEE)).div(PERCENTAGE), "Insufficient funds.");
    require(IERC20(PIXPContractAddress).allowance(msg.sender, address(this)) >= _priceMinted.mul(PERCENTAGE.add(OPEN_MYSTERY_FEE)).div(PERCENTAGE), "Allowance funds must exceed price");
    require(IERC20(PIXPContractAddress).transferFrom(msg.sender, address(this), _priceMinted.mul(OPEN_MYSTERY_FEE).div(PERCENTAGE)), "Transfer open box fee failed.");

    uint256 _devId = NFTInfoForTokenId[_claimedTokenIds.current()].devId;

    uint256 commissionValue = 0;
    uint256 valueForCreator = 0;
    if(_devId == 1) {
      commissionValue = _priceMinted.mul(SAVE_PERCENTAGE_FOR_SINGLE).div(PERCENTAGE);
      valueForCreator = _priceMinted.sub(commissionValue);
    } else {
      commissionValue = _priceMinted.mul(SAVE_PERCENTAGE_FOR_OTHER).div(PERCENTAGE);
      valueForCreator = _priceMinted.sub(commissionValue);
    }
    
    require(IERC20(PIXPContractAddress).transferFrom(msg.sender, address(this), commissionValue), "Transfer open box fee failed.");
    require(IERC20(PIXPContractAddress).transferFrom(msg.sender, charityWalletAddress, valueForCreator), "Transfer to creator failed.");

    NFTInfoForTokenId[_claimedTokenIds.current()].lastSaledTime = block.timestamp;
    NFTInfoForTokenId[_claimedTokenIds.current()].currentOwner = msg.sender;
    NFTInfoForTokenId[_claimedTokenIds.current()].previousOwner = NFTInfoForTokenId[_claimedTokenIds.current()].creator;

    PixpelNFT(nftContractAddress).transferFrom(NFTInfoForTokenId[_claimedTokenIds.current()].creator, msg.sender, _claimedTokenIds.current());
    _claimedTokenIds.increment();
  }

  /* Places an item for sale on the marketplace */
  function itemOnMarket(
    uint256 tokenId,
    uint256 price,
    string memory status,
    uint256 duration
  ) public nonReentrant {
    require(!idToMarketItem[tokenId].exist, "This NFT already exist on market!");
    require(
      PixpelNFT(nftContractAddress).ownerOf(tokenId) == msg.sender, 
      "Not Owner."
    );
    require(price > 0, "Price must be at least 1 wei.");
    require(
      IERC20(PIXPContractAddress).balanceOf(msg.sender) >= price.mul(listingPricePercentage).div(10000),
      "Price must be equal to listing price."
    );
    require(
      IERC20(PIXPContractAddress).allowance(msg.sender, address(this)) >= price.mul(listingPricePercentage).div(10000), 
      "Allowance funds must exceed price"
    );
    if (keccak256(abi.encodePacked((status))) == keccak256(abi.encodePacked(("forAuction")))) {
      require ( duration >= 1,  "Auction duration must be more than 1 day.");
      idToHighestBidder[tokenId] = msg.sender;
      idToHighestBid[tokenId] = price;
    }

    address creator = address(0);
    if (idToMarketItem[tokenId].exist) {
      creator = idToMarketItem[tokenId].creator;
    } else {
      creator = msg.sender;
    }

    idToMarketItem[tokenId] = MarketItem(
      true,
      tokenId,
      creator,
      msg.sender,
      price,
      status,
      block.timestamp,
      block.timestamp + (duration * 1 days)
    );

    require(
      IERC20(PIXPContractAddress).transferFrom(msg.sender, address(this), price.mul(listingPricePercentage).div(10000)), 
      "Transfer failed."
    );

    _profit += price.mul(listingPricePercentage).div(10000);

    emit MarketItemCreated(
      tokenId,
      creator,
      msg.sender,
      price,
      status,
      block.timestamp,
      block.timestamp + (duration * 1 days)
    );
  }

  /* Down the NFT of the market for Sale */
  function itemDownMarket(uint256 tokenId) public {
    require(idToMarketItem[tokenId].exist, "This NFT doesn't exist!");
    require(idToMarketItem[tokenId].creator == msg.sender, "Not creator.");
    MarketItem memory item = idToMarketItem[tokenId];
    item.status = "down";
    idToMarketItem[tokenId] = item;
    // idToMarketItem[tokenId].currentOwner.transfer(item.price * unlistingPricePercentage / 10000);

    // _profit -= (item.price * unlistingPricePercentage / 10000);

    // require(
    //   IERC20(PIXPContractAddress).transferFrom(address(this), msg.sender, item.price.mul(unlistingPricePercentage).div(10000)), 
    //   "Transfer failed."
    // );

    // _profit -= (item.price.mul(unlistingPricePercentage).div(10000));

    emit MarketItemForSaleUpdated (
      tokenId,
      "down"
    );
  }

  /* Purchase & Bid for the NFT */
  /* Transfers ownership of the item, as well as funds between parties */
  function purchaseNFT(uint256 tokenId)
    public
    nonReentrant
  {
    require(idToMarketItem[tokenId].exist, "This NFT doesn't exist!");
    require(
      keccak256(abi.encodePacked((idToMarketItem[tokenId].status))) != keccak256(abi.encodePacked(("down"))),
      "This NFT isn't on sale.");
    require(idToMarketItem[tokenId].currentOwner != msg.sender, "You already have this NFT.");
    require(
      IERC20(PIXPContractAddress).balanceOf(msg.sender) >= idToMarketItem[tokenId].price,
      "Please submit the asking price in order to complete the purchase."
    );
    require(
      IERC20(PIXPContractAddress).allowance(msg.sender, address(this)) >= idToMarketItem[tokenId].price,
      "Please approve token in order to complete the purchase."
    );

    address creatorAddress = NFTInfoForTokenId[tokenId].creator;
    uint256 royaltyFee = NFTInfoForTokenId[tokenId].royalty;
    // (,,,,address creatorAddress,,,,,uint256 royaltyFee) = PixpelNFT(nftContractAddress).getNFTInfo(tokenId);
    uint256 royaltyValue = idToMarketItem[tokenId].price.mul(royaltyFee).div(100);
    uint256 purchaseValue = idToMarketItem[tokenId].price.sub(royaltyValue);

    require(
      IERC20(PIXPContractAddress).transferFrom(msg.sender, creatorAddress, royaltyValue), 
      "Transfer royalty fee failed."
    );
    require(
      IERC20(PIXPContractAddress).transferFrom(msg.sender, idToMarketItem[tokenId].currentOwner, purchaseValue), 
      "Transfer failed."
    );

    PixpelNFT(nftContractAddress).transferFrom(idToMarketItem[tokenId].currentOwner, msg.sender, tokenId);
    NFTInfoForTokenId[tokenId].currentOwner = msg.sender;
    NFTInfoForTokenId[tokenId].previousOwner = idToMarketItem[tokenId].currentOwner;
    NFTInfoForTokenId[tokenId].lastSaledTime = block.timestamp;
    NFTInfoForTokenId[tokenId].price = idToMarketItem[tokenId].price;
    
    idToMarketItem[tokenId].currentOwner = msg.sender;
    idToMarketItem[tokenId].status = "down";

    emit NFTPurchased (
      tokenId,
      msg.sender,
      "down"
    );
  }

  /* Bid for NFT auction and refund */
  function bid(uint256 tokenId, uint256 updatePrice)
    public
    nonReentrant
  {
    require(idToMarketItem[tokenId].currentOwner != msg.sender, "You already have this NFT.");
    require(IERC20(PIXPContractAddress).balanceOf(msg.sender) >= updatePrice, "Insufficient funds.");
    require(block.timestamp <= idToMarketItem[tokenId].expiresAt, "Auction is already ended.");
    require(idToMarketItem[tokenId].exist, "This NFT doesn't exist!");
    require(idToHighestBidder[tokenId] != msg.sender, "You have already bidded.");
    require(updatePrice > idToHighestBid[tokenId], "There already is a higher bid.");

    require(
      IERC20(PIXPContractAddress).transferFrom(address(this), idToHighestBidder[tokenId], idToHighestBid[tokenId]), 
      "Return bid amount failed."
    );
    require(
      IERC20(PIXPContractAddress).allowance(msg.sender, address(this)) >= updatePrice, 
      "Allowance funds must exceed price."
    );
    require(
      IERC20(PIXPContractAddress).transferFrom(msg.sender, address(this), updatePrice), 
      "Transfer failed."
    );

    // idToHighestBidder[tokenId].transfer(idToHighestBid[tokenId]);

    idToHighestBidder[tokenId] = msg.sender;
    idToHighestBid[tokenId] = updatePrice;

    emit BidMade (
      tokenId,
      msg.sender,
      updatePrice
    );
  }

  /* End the auction
  and send the highest bid to the Item owner
  and transfer the item to the highest bidder */
  function auctionEnd(uint256 tokenId) public {
    require(idToMarketItem[tokenId].creator == msg.sender, "Not creator.");
    require(
      IERC20(PIXPContractAddress).allowance(msg.sender, address(this)) >= idToHighestBid[tokenId],
      "Allowance funds must exceed price."
    );
    require(block.timestamp >= idToMarketItem[tokenId].expiresAt, "Auction not yet ended.");
    require(
      keccak256(abi.encodePacked((idToMarketItem[tokenId].status))) != keccak256(abi.encodePacked(("down"))),
      "Auction has already ended."
    );

    // End the auction
    idToMarketItem[tokenId].status = "down";
    //Send the highest bid to the seller.
    if (PixpelNFT(nftContractAddress).ownerOf(tokenId) != idToHighestBidder[tokenId]) {
      address creatorAddress = NFTInfoForTokenId[tokenId].creator;
      uint256 royaltyFee = NFTInfoForTokenId[tokenId].royalty;

      // (,,,,address creatorAddress,,,,,uint256 royaltyFee) = PixpelNFT(nftContractAddress).getNFTInfo(tokenId);
      uint256 royaltyValue = idToHighestBid[tokenId].mul(royaltyFee).div(100);
      uint256 purchaseValue = idToHighestBid[tokenId].sub(royaltyValue);

      require(
        IERC20(PIXPContractAddress).transferFrom(msg.sender, creatorAddress, royaltyValue), 
        "Transfer royalty fee failed."
      );
      require(
        IERC20(PIXPContractAddress).transferFrom(msg.sender, idToMarketItem[tokenId].currentOwner, purchaseValue), 
        "Transfer failed."
      );
    }
    // Transfer the item to the highest bidder
    PixpelNFT(nftContractAddress).transferFrom(idToMarketItem[tokenId].currentOwner, idToHighestBidder[tokenId], tokenId);
    NFTInfoForTokenId[tokenId].currentOwner = msg.sender;
    NFTInfoForTokenId[tokenId].previousOwner = idToMarketItem[tokenId].currentOwner;
    NFTInfoForTokenId[tokenId].lastSaledTime = block.timestamp;
    NFTInfoForTokenId[tokenId].price = idToMarketItem[tokenId].price;
    
    idToMarketItem[tokenId].currentOwner = idToHighestBidder[tokenId];

    emit AuctionEnded (
      tokenId,
      idToHighestBidder[tokenId],
      idToHighestBid[tokenId]
    );
  }

  /* Withdraw to the contract owner */
  function withdrawSiteProfit() public onlyOwner {
    require(_profit > 0, "No cash left to withdraw.");
    (bool success, ) = (msg.sender).call{value: _profit}("");
    require(success, "Transfer failed.");
    _profit = 0;
  }

  /* Gets a NFT to show ItemDetail */
  function getItemDetail(uint256 tokenId)
    external
    view
    returns (MarketItem memory)
  {
    MarketItem memory item = idToMarketItem[tokenId];
    return item;
  }

  /** Get contract Profit */
  function getProfit() public view returns (uint256) {
    return _profit;
  }

  function setNFTContractAddress(address _new) public onlyOwner {
    nftContractAddress = payable(_new);
  }

  function setPIXPContractAddress(address _new) public onlyOwner {
    PIXPContractAddress = _new;
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

  function setTotalSupplyForGame(uint256 _gameId, uint256 amount)
    public 
    onlyRegister
  {
    totalSupplyForGameType[_gameId] = amount;
  }

  function getTotalSupplyForGameType(uint256 _gameId)
    public
    view
    returns(uint256)
  {
    return totalSupplyForGameType[_gameId];
  }

  function getMintedAmountForGameType(uint256 _gameId)
    public
    view
    returns(uint256)
  {
    return mintedAmountForGameType[_gameId];
  }

  function getNFTCreator(uint256 _tokenId)
    public
    view
    returns(address)
  {
    require(_tokenId <= _tokenIds.current(), "This NFT does not exist.");
    return NFTInfoForTokenId[_tokenId].creator;
  }

  function getNFTRoyalty(uint256 _tokenId)
    public
    view
    returns(uint256)
  {
    require(_tokenId <= _tokenIds.current(), "This NFT does not exist.");
    return NFTInfoForTokenId[_tokenId].royalty;
  }

  function changeStatus(uint256 _tokenId, address _newOwner, address _prevOwner, uint256 _purchasedTime, uint256 purchasedPrice)
    public
  {
    NFTInfoForTokenId[_tokenId].price = purchasedPrice;
    NFTInfoForTokenId[_tokenId].lastSaledTime = _purchasedTime; 
    NFTInfoForTokenId[_tokenId].currentOwner = _newOwner;
    NFTInfoForTokenId[_tokenId].previousOwner = _prevOwner;
  }
}