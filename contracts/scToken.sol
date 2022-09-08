// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ScotchToken is ERC20 {

    uint256 constant public MAX_SUPPLY = 500_000_000e18;

    constructor(address initialKeeper) ERC20("Scotch", "SC")
    { 
        _mint(initialKeeper, MAX_SUPPLY);
    }
}