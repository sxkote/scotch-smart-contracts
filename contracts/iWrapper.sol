// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

interface IWrapper {
    function wrap721(
        address _underlineContract, 
        uint256 _tokenId, 
        uint256 _unwrapAfter,
        uint256 _transferFee,
        address _royaltyBeneficiary,
        uint256 _royaltyPercent,
        uint256 _unwraptFeeThreshold,
        address _transferFeeToken
    ) external payable returns (uint256);
}