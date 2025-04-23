// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*  __  __                   _   _ _       _       
   |  \/  |                 | \ | (_)     (_)      
   | \  / | ___   ___  _ __ |  \| |_ _ __  _  __ _ 
   | |\/| |/ _ \ / _ \| '_ \| . ` | | '_ \| |/ _` |
   | |  | | (_) | (_) | | | | |\  | | | | | | (_| |
   |_|  |_|\___/ \___/|_| |_|_| \_|_|_| |_| |\__,_|
                                         _/ |      
                                        |__/   
*/

import "./MoonNinjaToken.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "hardhat/console.sol";

// Interface for the token's initialize function
interface IMoonNinjaToken {
    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _image,
        string memory _twitter,
        string memory _telegram,
        string memory _website,
        address _developer,
        address _moonNinjaAddress,
        address _bondingFeeAddress
    ) external;
}

contract MoonNinja {
    // MoonNinja is a factory contract for creating and managing MoonNinja tokens
    // It tracks the deployed tokens, trade history, and provides utility functions
    // for token creation and trading.
    // The contract allows users to create new tokens, trade them, and view trade history.
    // It also emits events for token creation and trade execution.

    address[] public deployedTokens;
    mapping(address => bool) public isDeployedToken;

    uint public totalTrades;
    uint public totalBuyTrades;
    uint public totalSellTrades;

    struct TradeDetails {
        bool isBuy;
        address tokenAddress;
        uint amount;
        uint price;
        address trader;
        uint timestamp;
    }

    TradeDetails[] public last250Trades;

    address public feeAddress;
    address public tokenLogicAddress;

    // Events

    event TradeExecuted(
        bool isBuy,
        address indexed tokenAddress,
        uint amount,
        uint price,
        address indexed trader,
        uint timestamp
    );

    event TokenCreated(
        address tokenAddress,
        string name,
        string symbol,
        string description,
        string image,
        string twitter,
        string telegram,
        string website,
        address developer
    );

    constructor(address _tokenLogicAddress) {
        feeAddress = msg.sender;
        tokenLogicAddress = _tokenLogicAddress;
    }

    function createToken(
        string memory name,
        string memory symbol,
        string memory description,
        string memory image,
        string memory twitter,
        string memory telegram,
        string memory website
    ) public {
        // Deploy using OZ Clones (EIP-1167)
        address cloneAddress = Clones.clone(tokenLogicAddress);

        // Initialize the clone contract
        IMoonNinjaToken(cloneAddress).initialize(
            name,
            symbol,
            description,
            image,
            twitter,
            telegram,
            website,
            msg.sender,
            address(this),
            feeAddress
        );

        deployedTokens.push(cloneAddress);
        isDeployedToken[cloneAddress] = true;

        emit TokenCreated(
            cloneAddress,
            name,
            symbol,
            description,
            image,
            twitter,
            telegram,
            website,
            msg.sender
        );

        console.log("Token created at address: ", cloneAddress);
    }

    function getDeployedTokens() public view returns (address[] memory) {
        return deployedTokens;
    }

    function isNinjaToken(address tokenAddress) public view returns (bool) {
        return isDeployedToken[tokenAddress];
    }

    function tradeEvent(
        bool isBuy,
        address trader,
        uint amount,
        uint price
    ) public {
        // Ensure the caller is one of our deployed tokens
        require(
            isDeployedToken[msg.sender],
            "Caller must be a valid MoonNinja token"
        );

        TradeDetails memory newTrade = TradeDetails(
            isBuy,
            msg.sender,
            amount,
            price,
            trader,
            block.timestamp
        );
        last250Trades.push(newTrade);
        if (last250Trades.length > 250) {
            delete last250Trades[0];
            for (uint i = 1; i < last250Trades.length; i++) {
                last250Trades[i - 1] = last250Trades[i];
            }
            last250Trades.pop();
        }

        totalTrades++;
        if (isBuy) {
            totalBuyTrades++;
        } else {
            totalSellTrades++;
        }

        emit TradeExecuted(
            isBuy,
            msg.sender,
            amount,
            price,
            trader,
            block.timestamp
        );
    }

    function getLast250Trades() public view returns (TradeDetails[] memory) {
        return last250Trades;
    }

    function getLastTrade() public view returns (TradeDetails memory) {
        if (last250Trades.length == 0) {
            revert("No trades executed yet");
        }
        return last250Trades[last250Trades.length - 1];
    }

    function getTradeTotals() public view returns (uint, uint, uint) {
        return (totalTrades, totalBuyTrades, totalSellTrades);
    }
}
