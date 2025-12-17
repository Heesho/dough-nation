// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Unit
 * @notice ERC20 token minted as rewards for donations to the DoughNation protocol.
 * @dev Only the Rig contract can mint new tokens. Anyone can burn their own tokens.
 */
contract Unit is ERC20 {
    address public rig;

    error Unit__NotRig();
    error Unit__InvalidRig();

    event Unit__Minted(address indexed account, uint256 amount);
    event Unit__Burned(address indexed account, uint256 amount);
    event Unit__RigSet(address indexed rig);

    /**
     * @notice Deploy a new Unit token.
     * @dev The deployer (msg.sender) becomes the initial rig. This should be transferred
     *      to the Rig contract after deployment.
     */
    constructor() ERC20("Dough", "DOUGH") {
        rig = msg.sender;
    }

    /**
     * @notice Transfer minting rights to a new address (Rig).
     * @dev Only callable by the current rig. Once set to Rig contract, this becomes
     *      effectively immutable since Rig has no setRig function.
     * @param _rig New rig address
     */
    function setRig(address _rig) external {
        if (msg.sender != rig) revert Unit__NotRig();
        if (_rig == address(0)) revert Unit__InvalidRig();
        rig = _rig;
        emit Unit__RigSet(_rig);
    }

    /**
     * @notice Mint new tokens to an account.
     * @dev Only callable by the rig.
     * @param account Recipient address
     * @param amount Amount to mint
     */
    function mint(address account, uint256 amount) external {
        if (msg.sender != rig) revert Unit__NotRig();
        _mint(account, amount);
        emit Unit__Minted(account, amount);
    }

    /**
     * @notice Burn tokens from the caller's balance.
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit Unit__Burned(msg.sender, amount);
    }
}
