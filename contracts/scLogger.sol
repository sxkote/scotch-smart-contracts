// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

abstract contract ScotchLogger {

  string[] public _logs;

  constructor(){
    _logs = new string[](0);
  }

  function _log(string memory message) internal {
    _logs.push(message);
  }
}
