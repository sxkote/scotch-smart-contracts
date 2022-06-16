// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

interface IDistributor {
    function distribute(uint256 marketItemId) external payable;
}