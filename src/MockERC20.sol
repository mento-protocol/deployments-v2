// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract MockERC20 is ERC20, ERC20Burnable, Ownable {
    uint8 private immutable _DECIMALS;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, address initialOwner_)
        ERC20(name_, symbol_)
        Ownable(initialOwner_)
    {
        _DECIMALS = decimals_;
    }

    function mint(address to_, uint256 amount_) external onlyOwner {
        _mint(to_, amount_);
    }

    function decimals() public view virtual override returns (uint8) {
        return _DECIMALS;
    }
}
