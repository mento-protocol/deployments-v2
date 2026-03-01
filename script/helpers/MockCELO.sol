// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Minimal ERC20 with known storage layout for replacing GoldToken on forks.
/// @dev Storage layout: slot 0 = _balances, slot 1 = _allowances, slot 2 = _totalSupply.
///      No constructor dependencies — safe to etch via anvil_setCode.
contract MockCELO {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function name() external pure returns (string memory) { return "Celo"; }
    function symbol() external pure returns (string memory) { return "CELO"; }
    function decimals() external pure returns (uint8) { return 18; }
    function totalSupply() external view returns (uint256) { return _totalSupply; }
    function balanceOf(address account) external view returns (uint256) { return _balances[account]; }
    function allowance(address owner, address spender) external view returns (uint256) { return _allowances[owner][spender]; }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _allowances[from][msg.sender] -= amount;
        return _transfer(from, to, amount);
    }

    function mint(address to, uint256 amount) external {
        _totalSupply += amount;
        unchecked { _balances[to] += amount; }
        emit Transfer(address(0), to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        _balances[from] -= amount;
        unchecked { _balances[to] += amount; }
        emit Transfer(from, to, amount);
        return true;
    }
}
