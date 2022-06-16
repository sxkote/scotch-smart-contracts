// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

interface IPartners {
    struct Partner {
      uint id;
      string name;
      address payable recipient;
      uint cashbackRate;
    }

    function getPartnerByName(string memory name) external view returns (Partner memory);
}