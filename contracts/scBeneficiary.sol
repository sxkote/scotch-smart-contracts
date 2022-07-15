// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
 

abstract contract ScotchBeneficiary is Ownable {
  using SafeERC20 for IERC20;

   // Beneficiary (commission recipient) Mode
  enum BeneficiaryMode{
    // 0: No Beneficiary Specified
    None,
    // 1: Beneficiary - simple the recipient address
    Beneficiary,
    // 2: Distributor - the service to distribute money
    Distributor
  }

  // Beneficiary Model
  struct Beneficiary {
    BeneficiaryMode mode;       // mode of the beneficiary send funds
    address payable recipient;  // beneficiary recipient address
  }

  // beneficiary - receiver of the funds - the address where the funds will be sent
  Beneficiary internal _beneficiary;


  // ===========================================
  // ======= Secondary public functions ========
  // ===========================================

  // get current beneficiary info
  function getBeneficiary() public view returns (Beneficiary memory) {
    return _beneficiary;
  }


  // ===========================================
  // =========== Owner's functions =============
  // ===========================================

  // change beneficiary of the Scotch Marketplace
  function changeBeneficiary(BeneficiaryMode mode, address payable recipient) public virtual onlyOwner {
    if (mode == BeneficiaryMode.None)
      require(recipient == address(0), "Beneficiar mode None requires zero address for recipient!");
    else
      require(recipient != address(0), "Beneficiary recipient address should be specified!");

    _beneficiary.mode = mode;
    _beneficiary.recipient = recipient;
  }

  // send accumulated funds to recipient (native-token = zero tokenContract)
  function sendFunds(uint256 amount, address tokenContract) public virtual onlyOwner {
    require(_isBeneficiaryExists(), "Beneficiary should be specified!");
    require(amount > 0, "Send Amount should be positive!");

    // address of the current contract
    address current = address(this);

    if (tokenContract == address(0)) {
      // get Scotch Marketplace balance in native token
      uint256 balance = current.balance;
      require(balance >= amount, "Send Amount exceeds Smart Contract's native token balance!");

      // send native token amount to _beneficiar
      _beneficiary.recipient.transfer(amount);
    }
    else {
      // get ERC-20 Token Contract
      IERC20 hostTokenContract = IERC20(tokenContract);
      // get Scotch Marketplace balance in ERC-20 Token
      uint256 balance = hostTokenContract.balanceOf(current);
      require(balance >= amount, "Send Amount exceeds Smart Contract's ERC-20 token balance!");
      // send ERC-20 token amount to recipient
      hostTokenContract.transfer(_beneficiary.recipient, amount);
    }
  }

  // ===========================================
  // ======= Internal helper functions =========
  // ===========================================

  // check if beneficiary is specified to send funds
  function _isBeneficiaryExists() internal view virtual returns (bool){
    return _beneficiary.mode != BeneficiaryMode.None && _beneficiary.recipient != address(0);
  }

   // charge funds from caller in native tokens
  function _chargeFunds(uint256 amount, string memory message) internal virtual {
    if (amount > 0) {
      // check payment for appropriate funds amount
      require(msg.value >= amount, message);

      // send funds to _beneficiary
      if (_isBeneficiaryExists())
        _beneficiary.recipient.transfer(msg.value);
    }
  }
}
