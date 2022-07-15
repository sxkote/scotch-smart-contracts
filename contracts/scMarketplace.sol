// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;
pragma experimental ABIEncoderV2;

import "./iDistributor.sol";
import "./scBeneficiary.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// V1.8
contract ScotchMarketplace is ScotchBeneficiary, ReentrancyGuard {
  using SafeERC20 for IERC20;

  // Market-Item Status
  enum MarketItemStatus {
    // 0: market-item is active and can be sold
    Active,
    // 1: market-item is already sold
    Sold,
    // 2: market-item is cancelled by NFT owner
    Cancelled,
    // 3: market-item is deleted by Scotch owner
    Deleted
  }

  // input for market-item placement
  struct MarketItemInput {
    address tokenContract;
    uint256 tokenId;
    address priceContract;
    uint256 priceAmount;
    address[] whiteList;
  }

  // Market-Rate structure
  struct MarketRate {
    bool isActive;         // is market-rate active (is valid for specific address)
    uint256 listingPrice;  // listing price of a new market-item (for seller to create market-item)
    uint256 cancelPrice;   // the price for cancelling market-item on the market (by NFT owner)
    uint feePercent;       // fee % to charge from market-item price (seller will receive (100-feePercent)/100 * price)
  }

  // Market-Item structure
  struct MarketItem {
    uint256 itemId;           // id of the market-item
    address tokenContract;    // original (sellable) NFT token contract address
    uint256 tokenId;          // original (sellable) NFT token Id
    address payable seller;   // seller of the original NFT
    address payable buyer;    // buyer of the market-item - new owner of the sellable NFT
    address priceContract;    // ERC-20 price token address (Zero address => native token)
    uint256 price;            // price = amount of ERC-20 (or native token) price tokens to buy market-item
    MarketItemStatus status;  // status of the market-item
    uint256 fee;              // amount of fee (in ERC-20 price tokens) that were charged during the sale
    uint256 position;         // positive position in active market-items array (1..N)
    uint partnerId;           // Id of the partner, from which the sale was made
    address[] whiteList;      // white list of addresses that could buy market-item
  }

  // Events of Marketplace
  event MarketItemPlaced(uint256 indexed marketItemId, address indexed tokenContract, uint256 tokenId, address indexed seller, address priceContract, uint256 price);
  event MarketItemSold(uint256 indexed marketItemId, address indexed buyer);
  event MarketItemRemoved(uint256 indexed marketItemId, MarketItemStatus status);


  // counter for market items Id
  using Counters for Counters.Counter;
  Counters.Counter private _itemIds;

  // collection of market-items
  mapping(uint256 => MarketItem) private _items;

  // active-market-items collection - collection of active market-items ids only
  uint256[] private _activeItems;

  // mapping of (Token Contract, TokenID) => Active Position
  mapping(address => mapping(uint256 => uint256))  private _activeTokens;

  // collection of market-rates
  mapping(address => MarketRate) private _rates;

  // mapping of (marketItemID, buyer address) => allowed to buy flag
  mapping(uint256 => mapping(address => bool))  private _allowedToBuy;

  // maximal amount of items, that could be sold in one transaction
  uint public _maxItemsForSale;



  constructor() {
    _beneficiary = Beneficiary(BeneficiaryMode.None, payable(address(0)));
    _activeItems = new uint256[](0);
    _rates[address(0)] = MarketRate(true, 0, 0, 3);
    _maxItemsForSale = 100;
  }

  // ===========================================
  // ======= Scotch Marketplace modifiers ======
  // ===========================================

  modifier idExists(uint256 marketItemId) {
    require(marketItemId > 0 && marketItemId <= _itemIds.current(), "Invalid Market Item ID!");
    _;
  }

  modifier isActive(uint256 marketItemId) {
    require(_items[marketItemId].status == MarketItemStatus.Active, "Market Item is not Active");
    _;
  }

  // ===========================================
  // ==== MAIN Scotch Marketplace functions ====
  // ===========================================

  // create new market-item - listing of original NFT on Marketplace
  function placeMarketItem(address tokenContract, uint256 tokenId, address priceContract, uint256 price, address[] memory whiteList) public payable {
    require(price > 0, "Price must be positive (at least 1 wei)");

    // check if token is already placed in the market
    uint256 existingMarketItemId = findActiveMarketItem(tokenContract, tokenId);
    require(existingMarketItemId == 0, "That token is already placed on the market");

    // seller of the Token
    address seller = _msgSender();

    // token validation
    int validation = _checkTokenValidity(seller, tokenContract, tokenId);
    require(validation != - 1, "Only owner of the NFT can place it to the Marketplace");
    require(validation != - 2, "NFT should be approved to the Marketplace");
    require(validation == 0, "NFT is not valid to be sold on the Marketplace");

    // market-rate for seller
    uint256 listingPrice = _getValidRate(seller).listingPrice;

    // charge listing-price from seller
    _chargeFunds(listingPrice, "Listing Price should be sent to place NFT on the Marketplace");

    // build market-item input
    MarketItemInput memory input = MarketItemInput(tokenContract, tokenId, priceContract, price, whiteList);

    // create market-item
    _createMarketItem(seller, input);
  }

  function placeMarketItems(MarketItemInput[] memory input) public payable {
    require(input.length > 0, "At least one item input should be specified");
    require(input.length <= _maxItemsForSale, "Amount of specified items exceeds Maximum Allowed Amount");

    // seller of the Token
    address seller = _msgSender();

    // market-rate for seller
    uint256 listingPrice = _getValidRate(seller).listingPrice;

    // charge listing-price from seller
    _chargeFunds(listingPrice * input.length, "Listing Price should be sent to place NFT on the Marketplace");

    for (uint i = 0; i < input.length; i++)
    {
      require(input[i].priceAmount > 0, "Price must be positive (at least 1 wei)");

      // check if token is already placed in the market
      uint256 existingMarketItemId = findActiveMarketItem(input[i].tokenContract, input[i].tokenId);
      require(existingMarketItemId == 0, "That token is already placed on the market");

      // token validation
      int validation = _checkTokenValidity(seller, input[i].tokenContract, input[i].tokenId);
      require(validation != - 1, "Only owner of the NFT can place it to the Marketplace");
      require(validation != - 2, "NFT should be approved to the Marketplace");
      require(validation == 0, "NFT is not valid to be sold on the Marketplace");

      // create market-item
      _createMarketItem(seller, input[i]);
    }
  }

  // make deal on sell market-item, receive payment and transfer original NFT
  function makeMarketSale(uint256 marketItemId, uint partnerId) public payable idExists(marketItemId) isActive(marketItemId) nonReentrant {
    // address of the buyer for nft
    address buyer = _msgSender();
    // address of the market-item seller
    address payable seller = _items[marketItemId].seller;
    // original nft tokenId
    uint256 tokenId = _items[marketItemId].tokenId;

    // nft token contract && approval for nft
    IERC721 hostTokenContract = IERC721(_items[marketItemId].tokenContract);
    bool allApproved = hostTokenContract.isApprovedForAll(seller, address(this));
    if (!allApproved) {
      address approvedAddress = hostTokenContract.getApproved(tokenId);
      require(approvedAddress == address(this), "Market Item (NFT) should be approved to the Marketplace");
    }

    // check white-list if it was set up
    if (_items[marketItemId].whiteList.length > 0)
      require(_allowedToBuy[marketItemId][buyer] == true, "Your address is not specified in White-List for current Market Item");

    // charge price from seller & send to buyer & beneficiary
    uint256 feeAmount = _chargePrice(marketItemId, buyer);

    // update market-item info
    _items[marketItemId].buyer = payable(buyer);
    _items[marketItemId].fee = feeAmount;
    _items[marketItemId].partnerId = partnerId;

    // transfer original nft from seller to buyer
    hostTokenContract.safeTransferFrom(seller, buyer, tokenId);

    // remove market-item with Sold status
    _removeMarketItem(marketItemId, MarketItemStatus.Sold);

    // if beneficiary 'Distributor' mode specified => call distribute method for current marketItemId
    if (_beneficiary.mode == BeneficiaryMode.Distributor && _beneficiary.recipient != address(0))
    {
      // build distributor Host Contract
      IDistributor distributorHost = IDistributor(_beneficiary.recipient);
      distributorHost.distribute(marketItemId);
    }

    emit MarketItemSold(marketItemId, buyer);
  }

  // cancel market-item placement on Scotch Marketplace
  function cancelMarketItem(uint256 marketItemId) public payable idExists(marketItemId) isActive(marketItemId) nonReentrant {
    // address of the market-item seller
    address payable seller = _items[marketItemId].seller;
    // check market-item Seller is cancelling the market-item
    require(_msgSender() == seller, "Only Seller can cancel Market Item");
    // market-rate for seller
    uint256 cancelPrice = _getValidRate(seller).cancelPrice;

    // charge cancel-price from seller
    _chargeFunds(cancelPrice, "Cancel Price should be sent to cancel NFT placement on the Marketplace");

    // remove market-item with Cancelled status
    _removeMarketItem(marketItemId, MarketItemStatus.Cancelled);
  }


  // ===========================================
  // ======= Secondary public functions ========
  // ===========================================

  // get Rate for sender address
  function getRate() public view returns (MarketRate memory) {
    return _getValidRate(_msgSender());
  }

  // get market-item info by id
  function getMarketItem(uint256 marketItemId) public view idExists(marketItemId) returns (MarketItem memory) {
    return _items[marketItemId];
  }

  // get count of all market-items
  function getAllMarketItemsCount() public view returns (uint256) {
    return _itemIds.current();
  }

  // get count of active (not sold and not removed) market-items
  function getActiveMarketItemsCount() public view returns (uint256) {
    return _activeItems.length;
  }

  // get active active market-item by index (1 based)
  function getActiveMarketItem(uint256 position) public view returns (MarketItem memory) {
    require(_activeItems.length > 0, "There are no any Active Market Items yet!");
    require(position >= 1 && position <= _activeItems.length, "Position should be positive number in Active Market Items Count range (1..N)");
    return _items[_activeItems[position - 1]];
  }

  // find existing active market-item by tokenContract & tokenId
  function findActiveMarketItem(address tokenContract, uint256 tokenId) public view returns (uint256) {
    return _activeTokens[tokenContract][tokenId];
  }


  // ===========================================
  // =========== Owner's functions =============
  // ===========================================

  // set maximum amount of items that could be sold
  function setMaxItemsForSale(uint maxItemsForSale) public onlyOwner {
    _maxItemsForSale = maxItemsForSale;
  }

  // get Rate for specific address
  function getCustomRate(address adr) public view onlyOwner returns (MarketRate memory){
    return _getCustomRate(adr);
  }

  // set market-rate for specific address
  function setCustomRate(address adr, uint256 newListingPrice, uint256 newCancelPrice, uint newFeePercent) public onlyOwner {
    _rates[adr] = MarketRate(true, newListingPrice, newCancelPrice, newFeePercent);
  }

  // remove market-rate for specific address
  function removeCustomRate(address adr) public onlyOwner {
    if (adr == address(0))
      return;

    delete _rates[adr];
  }

  // remove market-item placement on Scotch Marketplace
  function deleteMarketItem(uint256 marketItemId) public onlyOwner idExists(marketItemId) isActive(marketItemId) nonReentrant {
    // remove market-item with Deleted status
    _removeMarketItem(marketItemId, MarketItemStatus.Deleted);
  }


  // ===========================================
  // ======= Internal helper functions =========
  // ===========================================
  // get Rate for specific address
  function _getCustomRate(address adr) private view returns (MarketRate memory) {
    return _rates[adr];
  }

  // get Rate for specific address
  function _getValidRate(address adr) private view returns (MarketRate memory) {
    // get active market-rate for specific address
    if (_rates[adr].isActive)
      return _rates[adr];

    // return default market-rate
    return _rates[address(0)];
  }

  // check if original NFT is valid to be placed on Marketplace
  function _checkTokenValidity(address seller, address tokenContract, uint256 tokenId) private view returns (int) {
    IERC721 hostTokenContract = IERC721(tokenContract);

    // get owner of the NFT (seller should be the owner of the NFT)
    address tokenOwner = hostTokenContract.ownerOf(tokenId);
    if (tokenOwner != seller)
      return - 1;

    // check approval for all
    bool allApproved = hostTokenContract.isApprovedForAll(seller, address(this));
    if (!allApproved)
    {
      // get approved address of the NFT (NFT should be approved to Marketplace)
      address tokenApproved = hostTokenContract.getApproved(tokenId);
      if (tokenApproved != address(this))
        return - 2;
    }

    return 0;
  }

  // add new MaketItem to Marketplace
  function _createMarketItem(address seller, MarketItemInput memory input) private {
    // new market-item ID
    _itemIds.increment();
    uint256 marketItemId = _itemIds.current();

    // push active market-item in array
    _activeItems.push(marketItemId);
    // position in active market-item array
    uint256 position = _activeItems.length;

    // create new market-item
    _items[marketItemId] = MarketItem(
      marketItemId, // ID of the market item
      input.tokenContract, // token Contract
      input.tokenId, // token ID
      payable(seller), // seller
      payable(address(0)), // buyer
      input.priceContract, // price Contract
      input.priceAmount, // price value
      MarketItemStatus.Active, // status
      0, // fee value
      position, // position
      0, // partnerId
      input.whiteList           // white list
    );

    // update token position to active market-item position
    _activeTokens[input.tokenContract][input.tokenId] = position;

    // setup white list for market item
    if (input.whiteList.length > 0)
    {
      for (uint i; i < input.whiteList.length; i++)
        _allowedToBuy[marketItemId][input.whiteList[i]] = true;
    }

    emit MarketItemPlaced(marketItemId, input.tokenContract, input.tokenId, seller, input.priceContract, input.priceAmount);
  }

  // remove market-item from marketplace
  function _removeMarketItem(uint256 marketItemId, MarketItemStatus status) private idExists(marketItemId) isActive(marketItemId) {
    // define index of market-item in active array
    uint index = _items[marketItemId].position - 1;
    // check market-item has position in active-market-item array
    require(index >= 0 && index < _activeItems.length, "Market Item has no position in Active Items array");
    // check market-item position in active-market-items array
    require(_activeItems[index] == marketItemId, "Market Item is not on the position in Active Items array!");
    // check that new status should NOT be Active
    require(status != MarketItemStatus.Active, "Specify correct status to remove Market Item!");

    // update market-item status & position
    _items[marketItemId].status = status;
    _items[marketItemId].position = 0;

    // replacing current active-market-item with last element
    if (index < _activeItems.length - 1) {
      // define last active-market-item ID
      uint256 lastItemId = _activeItems[_activeItems.length - 1];
      // replacing with last element
      _activeItems[index] = lastItemId;
      // update last active-market-item position
      _items[lastItemId].position = index + 1;
      _activeTokens[_items[lastItemId].tokenContract][_items[lastItemId].tokenId] = index + 1;
    }

    // remove last element from array = deleting item in array
    _activeItems.pop();

    // remove token position for current market-item
    delete _activeTokens[_items[marketItemId].tokenContract][_items[marketItemId].tokenId];

    emit MarketItemRemoved(marketItemId, status);
  }


  // charge price and fees during the deal
  function _chargePrice(
    uint256 marketItemId,
    address buyer)
  private returns (uint256) {
    // address of the market-item seller
    address payable seller = _items[marketItemId].seller;
    // price amount
    uint256 priceAmount = _items[marketItemId].price;
    // price contract
    address priceContract = _items[marketItemId].priceContract;


    // market-rate for seller
    uint feePercent = _getValidRate(seller).feePercent;
    // commission fee amount
    uint256 feeAmount = feePercent * priceAmount / 100;

    // amount that should be send to Seller
    uint256 sellerAmount = priceAmount - feeAmount;
    require(sellerAmount > 0, "Invalid Seller Amount calculated!");


    // charge price and fees in Native Token
    if (priceContract == address(0))
    {
      require(msg.value >= priceAmount, "Please submit the Price amount in order to complete the purchase");

      // transfer seller-amount to seller
      seller.transfer(sellerAmount);

      // send fee funds to _beneficiary
      if (_isBeneficiaryExists() && feeAmount > 0)
        _beneficiary.recipient.transfer(feeAmount);
    }
    // charge price and fees in ERC20 Token
    else
    {
      // address of the Scotch Marketplace
      address marketplace = address(this);

      // check price amount allowance to marketplace
      IERC20 hostPriceContract = IERC20(priceContract);
      uint256 priceAllowance = hostPriceContract.allowance(buyer, marketplace);
      require(priceAllowance >= priceAmount, "Please allow Price amount of ERC-20 Token in order to complete purchase");

      // transfer price amount to marketplace
      hostPriceContract.safeTransferFrom(buyer, marketplace, priceAmount);

      // transfer seller-amount to seller
      hostPriceContract.transfer(seller, sellerAmount);

      // send fee funds to _beneficiary
      if (_isBeneficiaryExists() && feeAmount > 0)
        hostPriceContract.transfer(_beneficiary.recipient, feeAmount);
    }

    return feeAmount;
  }
}
