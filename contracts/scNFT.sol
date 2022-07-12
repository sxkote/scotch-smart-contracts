// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./scBeneficiary.sol";

contract ScotchNFT is ScotchBeneficiary, ERC721URIStorage {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  // maximum amount of NFTs to mint
  uint _maxNftToMint; 

  // price for minting NFT
  uint256 _mintingPrice;

  constructor() ERC721("Scotch NFT", "scNFT")
  {
    _maxNftToMint = 100;
    _mintingPrice = 0;
  }

  // ===========================================
  // ======= MAIN Scotch NFTS functions ========
  // ===========================================

  function createNFT(string memory tokenURI) public payable returns (uint256)
  {
     // charge minting-price
    _chargeFunds(_mintingPrice, "Minting Price should be sent to mint NFT");

    _tokenIds.increment();

    uint256 id = _tokenIds.current();
    _mint(msg.sender, id);
    _setTokenURI(id, tokenURI);

    return id;
  }

  function createNFTs(uint count, string memory baseURI) public payable
  {
    require(count <= _maxNftToMint, "Amount of NFTs exceeds Maximum Allowed Amount");

     // charge minting-price
    _chargeFunds(_mintingPrice * count, "Minting Price should be sent to mint NFT");

    address sender = msg.sender;

    for (uint i = 1; i <= count; i++)
    {
      _tokenIds.increment();

      uint256 id = _tokenIds.current();
      _mint(sender, id);

      _setTokenURI(id,  string.concat(baseURI, Strings.toString(i), ".json"));
    }
  }


  // ===========================================
  // ======= Secondary public functions ========
  // ===========================================

  // get minting-price
  function getMintingPrice() public view returns (uint256) {
    return _mintingPrice;
  }


  // ===========================================
  // =========== Owner's functions =============
  // ===========================================

  // set maximum amount of nfts that could be minted
  function setMaxNftToMint(uint maxNftToMint) public onlyOwner {
    _maxNftToMint = maxNftToMint;
  }

    // set minting-price
  function setMintingPrice(uint256 mintingPrice) public onlyOwner {
    _mintingPrice = mintingPrice;
  }
}

