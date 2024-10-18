// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WETH is ERC20 {
    
    constructor() ERC20 ("Wrapped Ether","WETH"){}

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
      _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 _amount) external {
      _burn(msg.sender, _amount);
    }
}