// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "iPartners.sol";

contract ScotchPartners is Ownable, iPartners  {
  using Counters for Counters.Counter;
  Counters.Counter private _ids;

  mapping(uint => Partner) private _partners;
  mapping(string => Partner) private _partnerNames;

  constructor() {}

  // ===========================================
  // ================== modifiers ==============
  // ===========================================

  modifier idExists(uint id) {
    require(id > 0 && id <= _ids.current(), "Invalid ID!");
    _;
  }

  // ===========================================
  // ================= reading =================
  // ===========================================

  function getPartnerById(uint id) public idExists(id) view returns (Partner memory) {
      return _partners[id];
  }

  function getPartnerByName(string memory name) public view returns (Partner memory) {
      return _partnerNames[name];
  }

  // ===========================================
  // ================ modifying ================
  // ===========================================
  function addPartner(string memory name, address payable recipient, uint cashbackRate) public onlyOwner returns (uint) { 
    require(name != "", "")
    require(recipient != address(0), "Partner's recipient address can't be zero!");
    _ids.increment();

    // new Partner ID
    uint id = _ids.current();

    // new Partner object
    Partner memory partner = Partner(
        id,
        name, 
        recipient,
        cashbackRate
    );

    _partners[id] = partner;
    _partnerNames[name]=partner;    
    
    return id;
  }

  function changePartnerRate(uint id, uint cashbackRate) public idExists(id) onlyOwner{
      _partners[id].cashbackRate = cashbackRate;
  }

  function changePartnerRecipient(uint id, address payable recipient) public idExists(id) onlyOwner{
      require(recipient != address(0), "Partner's recipient address can't be zero!");
      _partners[id].recipient = recipient;
  }

}