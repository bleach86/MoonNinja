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

import "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "forge-std/console.sol";

struct FeeDetails {
    uint32 buyFee;
    uint32 sellFee;
    uint32 transferFee;
    uint32 developerFee;
    uint32 burnFee;
}

struct TokenInitialization {
    string name;
    string symbol;
    uint8 decimals;
    uint maxSupply;
    string description;
    string image;
    string twitter;
    string telegram;
    string discord;
    string website;
    address developer;
    uint32 connectorWeight;
    FeeDetails fees;
    bool antiWhale;
    uint32 maxAntiWhaleAmount;
}

// Interface for the token's initialize function
interface IMoonNinjaToken {
    function initialize(TokenInitialization memory _tokenInit) external;

    function buyTokens(uint amountWETH) external payable;

    function burn(uint amount) external;

    function balanceOf(address account) external view returns (uint);
}

interface IWETH {
    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract MoonNinja is Ownable {
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

    address public feeAddress;
    address public tokenLogicAddress;
    address public WETH;
    address public MNLiquidityManagerAddress;

    struct TokenInfo {
        string name;
        string symbol;
        string description;
        string image;
        string twitter;
        string telegram;
        string website;
        address developer;
    }

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

    constructor(
        address _tokenLogicAddress,
        address _wethAddress,
        address _MNLiquidityManagerAddress
    ) Ownable(msg.sender) {
        feeAddress = msg.sender;
        tokenLogicAddress = _tokenLogicAddress;
        WETH = _wethAddress;
        MNLiquidityManagerAddress = _MNLiquidityManagerAddress;
    }

    function createToken(
        TokenInitialization memory tokenInit,
        uint _WETHAmount
    ) public payable {
        // Deploy using OZ Clones (EIP-1167)
        address cloneAddress = Clones.clone(tokenLogicAddress);

        // Initialize the clone contract
        IMoonNinjaToken(cloneAddress).initialize(tokenInit);

        deployedTokens.push(cloneAddress);
        isDeployedToken[cloneAddress] = true;

        emit TokenCreated(
            cloneAddress,
            tokenInit.name,
            tokenInit.symbol,
            tokenInit.description,
            tokenInit.image,
            tokenInit.twitter,
            tokenInit.telegram,
            tokenInit.website,
            msg.sender
        );

        if (msg.value > 0) {
            IMoonNinjaToken(cloneAddress).buyTokens{value: msg.value}(0);
        } else {
            IWETH(WETH).transferFrom(msg.sender, address(this), _WETHAmount);

            IWETH(WETH).approve(cloneAddress, _WETHAmount);
            IMoonNinjaToken(cloneAddress).buyTokens(_WETHAmount);
        }

        uint tokenBalance = IMoonNinjaToken(cloneAddress).balanceOf(
            address(this)
        );

        if (tokenBalance > 0) {
            IMoonNinjaToken(cloneAddress).burn(tokenBalance);
        }
    }

    function getDeployedTokens() public view returns (address[] memory) {
        return deployedTokens;
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

    function getTradeTotals() public view returns (uint, uint, uint) {
        return (totalTrades, totalBuyTrades, totalSellTrades);
    }

    function getWETH() public view returns (address) {
        return WETH;
    }

    function getBondingFeeAddress() public view returns (address) {
        return feeAddress;
    }

    function getMNLiquidityManagerAddress() public view returns (address) {
        return MNLiquidityManagerAddress;
    }

    function setBondingFeeAddress(address _feeAddress) public onlyOwner {
        feeAddress = _feeAddress;
    }

    function setTokenLogicAddress(address _tokenLogicAddress) public onlyOwner {
        tokenLogicAddress = _tokenLogicAddress;
    }

    function setMNLiquidityManagerAddress(
        address _MNLiquidityManagerAddress
    ) public onlyOwner {
        MNLiquidityManagerAddress = _MNLiquidityManagerAddress;
    }
}
