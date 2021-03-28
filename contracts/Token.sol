// contracts/Farming.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 initialSupply
    )
        public
        ERC20(name, symbol)
    {
        _setupDecimals(decimals);

        if (initialSupply > 0) {
            _mint(owner(), initialSupply);
        }
    }

    function mint(address to, uint256 value) public onlyOwner {
        _mint(to, value);
    }
}
