// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";

/// @title An Auction Contract for bidding and selling single and batched NFTs
/// @author Dev Stenor Tanaka
/// @notice This contract can be used for auctioning any NFTs, and accepts any ERC20 token as payment
contract NFTMarket is ReentrancyGuard, Ownable {
    address public nftContractAddress; 

    uint256 public listingPricePercentage;
    uint256 public unlistingPricePercentage;
    uint256 _profit;

    constructor(address _nftContractAddress, uint256 _listingPricePercentage, uint256 _unlistingPricePercentage) {
        _profit = 0;

        nftContractAddress = _nftContractAddress;
        listingPricePercentage = _listingPricePercentage;
        unlistingPricePercentage = _unlistingPricePercentage;
    }
  /* MarketItem and AuctionItem Struct */
    struct MarketItem {
        bool exist;
        address nftContract;
        uint256 tokenId;
        address payable creator;
        address payable currentOwner;
        uint256 price;
        string status;
        uint256 startAt;
        uint256 expiresAt;
    }

    // mapping marketItem
    mapping(uint256 => MarketItem) private idToMarketItem;
    // mapping auction item to bidders
    mapping(uint256 => address payable) private idToHighestBidder;
    mapping(uint256 => uint256) private idToHighestBid;

  /* Define events */
    event MarketItemCreated(
        address indexed nftContract,
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
        address nftContract,
        uint256 tokenId,
        address bidder,
        uint256 bidPrice
    );

    event AuctionEnded(
        address nftContract,
        uint256 tokenId,
        address highestBidder,
        uint256 highestBid
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

  /* Places an item for sale on the marketplace */
    function itemOnMarket(
        uint256 tokenId,
        uint256 price,
        string memory status,
        uint256 duration
    ) public payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei.");
        require(
            msg.value == price * listingPricePercentage / 10000,
            "Price must be equal to listing price."
        );
        if (keccak256(abi.encodePacked((status))) == keccak256(abi.encodePacked(("forAuction")))) {
            require ( duration >= 1,  "Auction duration must be more than 1 day.");
            idToHighestBidder[tokenId] = payable(msg.sender);
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
            nftContractAddress,
            tokenId,
            payable(creator),
            payable(msg.sender),
            price,
            status,
            block.timestamp,
            block.timestamp + (duration * 1 days)
        );

        _profit += msg.value;

        emit MarketItemCreated(
            nftContractAddress,
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
        MarketItem memory item = idToMarketItem[tokenId];
        item.status = "down";
        idToMarketItem[tokenId] = item;
        idToMarketItem[tokenId].currentOwner.transfer(item.price * unlistingPricePercentage / 10000);

        _profit -= (item.price * unlistingPricePercentage / 10000);

        emit MarketItemForSaleUpdated (
            tokenId,
            "down"
        );
    }

  /* Purchase & Bid for the NFT */
    /* Transfers ownership of the item, as well as funds between parties */
    function purchaseNFT(uint256 tokenId)
        public
        payable
        nonReentrant
    {
        require(idToMarketItem[tokenId].exist, "This NFT doesn't exist!");
        require(
            keccak256(abi.encodePacked((idToMarketItem[tokenId].status))) != keccak256(abi.encodePacked(("down"))),
            "This NFT isn't on sale.");
        require(idToMarketItem[tokenId].currentOwner != msg.sender, "You already have this NFT.");
        require(
            msg.value == idToMarketItem[tokenId].price,
            "Please submit the asking price in order to complete the purchase."
        );

        idToMarketItem[tokenId].currentOwner.transfer(msg.value);
        IERC721(nftContractAddress).transferFrom(idToMarketItem[tokenId].currentOwner, msg.sender, tokenId);
        idToMarketItem[tokenId].currentOwner = payable(msg.sender);
        idToMarketItem[tokenId].status = "down";

        emit NFTPurchased (
            tokenId,
            msg.sender,
            "down"
        );
    }

    /* Bid for NFT auction and refund */
    function bid(uint256 tokenId)
        public
        payable
        nonReentrant
    {
        require(idToMarketItem[tokenId].currentOwner != msg.sender, "You already have this NFT.");
        require(block.timestamp <= idToMarketItem[tokenId].expiresAt, "Auction is already ended.");
        require(idToMarketItem[tokenId].exist, "This NFT doesn't exist!");
        require(idToHighestBidder[tokenId] != msg.sender, "You have already bidded.");
        require(msg.value > idToHighestBid[tokenId], "There already is a higher bid.");

        idToHighestBidder[tokenId].transfer(idToHighestBid[tokenId]);

        idToHighestBidder[tokenId] = payable(msg.sender);
        idToHighestBid[tokenId] = msg.value;

        emit BidMade (
          nftContractAddress,
          tokenId,
          msg.sender,
          msg.value
        );
    }

  /* End the auction
    and send the highest bid to the Item owner
    and transfer the item to the highest bidder */
    function auctionEnd(uint256 tokenId) public {
      require(block.timestamp >= idToMarketItem[tokenId].expiresAt, "Auction not yet ended.");
      require(
        keccak256(abi.encodePacked((idToMarketItem[tokenId].status))) != keccak256(abi.encodePacked(("down"))),
        "Auction has already ended."
        );

      // End the auction
      idToMarketItem[tokenId].status = "down";
      //Send the highest bid to the seller.
      if (IERC721(nftContractAddress).ownerOf(tokenId) != idToHighestBidder[tokenId]) {
        idToMarketItem[tokenId].currentOwner.transfer(idToHighestBid[tokenId]);
      }
      // Transfer the item to the highest bidder
      IERC721(nftContractAddress).transferFrom(idToMarketItem[tokenId].currentOwner, idToHighestBidder[tokenId], tokenId);
      idToMarketItem[tokenId].currentOwner = idToHighestBidder[tokenId];

      emit AuctionEnded (
        nftContractAddress,
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
}