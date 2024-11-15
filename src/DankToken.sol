// SPDX-License-Identifier: Apache 2
pragma solidity >=0.6.12 <0.9.0;

import {BaseToken} from "src/BaseToken.sol";

/**
 * @title DankToken
 * @dev ERC20 token for Meme Arena platform
 * @notice This contract implements the core token functionality for the AI Meme Arena ecosystem
 * @dev Inherits from BaseToken which provides ERC20, permit and voting capabilities
 * @dev Initial supply is minted  to initialHolder address during deployment
 * @dev Token has a fixed maximum supply defined in the BaseToken contract
 */
contract DankToken is BaseToken {
    /**
     * @notice Creates a new DankToken contract
     * @dev Initializes the token with name, symbol and mints total supply to initial holder
     * @dev Emits TokenInitialized event after successful initialization
     * @param _name The name of the token
     * @param _symbol The symbol of the token
     * @param _initialHolder The initial holder of the token who receives the total supply
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _initialHolder
    ) BaseToken(_name, _symbol) {
        _mint(_initialHolder, MAX_SUPPLY);
        
        emit TokenInitialized(_name, _symbol, MAX_SUPPLY, _initialHolder);
    }

    /**
     * @dev Emitted when token is initialized
     * @dev Contains core token information for indexing and tracking
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param maxSupply The maximum supply of tokens
     * @param initialHolder The address that received the initial token supply
     */
    event TokenInitialized(
        string name,
        string symbol,
        uint256 maxSupply,
        address initialHolder
    );
}