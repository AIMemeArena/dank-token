// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.19;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "openzeppelin-contracts/contracts/utils/Nonces.sol";
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {Votes} from "openzeppelin-contracts/contracts/governance/utils/Votes.sol";

/**
 * @title BaseToken
 * @dev Implementation of the base token with voting and permit capabilities.
 * Inherits from ERC20, ERC20Permit, and ERC20Votes.
 */
contract BaseToken is ERC20, ERC20Permit, ERC20Votes {
    /// @notice Maximum supply of tokens that can ever exist
    uint256 public immutable MAX_SUPPLY;

    /**
     * @dev Constructor that sets up the token with name, symbol and initializes max supply
     * @param tokenName Name of the token
     * @param tokenSymbol Symbol of the token
     */
    constructor(
        string memory tokenName, 
        string memory tokenSymbol,
        uint256 maxSupply
    ) ERC20Permit(tokenName) ERC20(tokenName, tokenSymbol) {
        MAX_SUPPLY = maxSupply;
    }

    /**
     * @dev Returns the current timestamp as the clock value
     * @return Current block timestamp as uint48
     */
    function clock() public view virtual override returns (uint48) {
        return Time.timestamp();
    }

    /**
     * @dev Returns the clock mode for the contract
     * @return String indicating the clock mode is timestamp-based
     */
    function CLOCK_MODE() public view virtual override returns (string memory) {
        // Check that the clock was not modified
        if (clock() != Time.timestamp()) {
            revert Votes.ERC6372InconsistentClock();
        }
        return "mode=timestamp";
    }

    /**
     * @dev Internal function to return the maximum supply
     * @return Maximum token supply
     */
    function _maxSupply() internal view virtual override returns (uint256) {
        return MAX_SUPPLY;
    }

    /**
     * @dev Returns the current nonce for an address
     * @param _owner Address to query nonce for
     * @return Current nonce value
     */
    function nonces(address _owner)
        public 
        view 
        override(ERC20Permit, Nonces) 
        returns (uint256) 
    {
        return Nonces.nonces(_owner);
    }

    /**
     * @dev Hook that is called before any transfer of tokens
     * @param _from Address tokens are transferred from
     * @param _to Address tokens are transferred to
     * @param _value Amount of tokens to transfer
     */
    function _update(address _from, address _to, uint256 _value) internal virtual override(ERC20, ERC20Votes) {
        return ERC20Votes._update(_from, _to, _value);
    }
}
