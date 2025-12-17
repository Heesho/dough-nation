// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    // Override decimals to return 6 (like real USDC)
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    // Mint USDC to any address (for testing)
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
