// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* ____  _   _ __  __ ____             _ 
  |  _ \| | | |  \/  |  _ \  ___  ___ | |
  | |_) | | | | |\/| | |_) |/ __|/ _ \| |
  |  __/| |_| | |  | |  __/ \__ \ (_) | |
  |_|    \___/|_|  |_|_| (_) ___/\___/|_|
  Degenerate memecoin factory on Ethereum
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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

    struct TradeTotals {
        uint totalTrades;
        uint totalBuyTrades;
        uint totalSellTrades;
    }

    TradeDetails[] public last250Trades;

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

    function createToken(
        string memory name,
        string memory symbol,
        string memory description,
        string memory image,
        string memory twitter,
        string memory telegram,
        string memory website
    ) public {
        MoonNinjaToken newToken = new MoonNinjaToken(
            name,
            symbol,
            description,
            image,
            twitter,
            telegram,
            website,
            msg.sender,
            address(this)
        );
        deployedTokens.push(address(newToken));
        isDeployedToken[address(newToken)] = true;

        emit TokenCreated(
            address(newToken),
            name,
            symbol,
            description,
            image,
            twitter,
            telegram,
            website,
            msg.sender
        );
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

    function getTradeTotals() public view returns (TradeTotals memory) {
        return TradeTotals(totalTrades, totalBuyTrades, totalSellTrades);
    }
}

contract MoonNinjaToken is ERC20 {
    string public description;
    string public image;
    string public twitter;
    string public telegram;
    string public website;
    address public developer;
    uint immutable maxSupply = 1_000_000e18;

    address public moonNinja;

    struct TradeDetails {
        bool isBuy;
        address tokenAddress;
        uint amount;
        uint price;
        address trader;
        uint timestamp;
    }

    struct TokenDetails {
        string name;
        string symbol;
        address tokenAddress;
        address developer;
        uint maxSupply;
        string description;
        string image;
        string twitter;
        string telegram;
        string website;
    }

    TradeDetails[] public trades;
    mapping(address => TradeDetails[]) public userTrades;

    event TokensPurchased(address indexed purchaser, uint amount, uint price);
    event TokensSold(address indexed seller, uint amount, uint price);
    event LiquidityAdded(uint tokenAmount, uint ethAmount);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _image,
        string memory _twitter,
        string memory _telegram,
        string memory _website,
        address _developer,
        address moonNinjaAddress
    ) ERC20(_name, _symbol) {
        description = _description;
        image = _image;
        twitter = _twitter;
        telegram = _telegram;
        website = _website;
        developer = _developer;
        moonNinja = moonNinjaAddress;
        _mint(address(this), maxSupply);
    }

    function buyTokens() public payable {
        require(msg.value > 1, "send some ETH");
        uint tokensPerETH = quoteBuy(msg.value);
        uint tokenAmount = (msg.value * tokensPerETH) / 1e18;
        require(balanceOf(address(this)) > tokenAmount, "sold out");
        _transfer(address(this), msg.sender, tokenAmount);

        TradeDetails memory trade = TradeDetails(
            true,
            address(this),
            tokenAmount,
            tokensPerETH,
            msg.sender,
            block.timestamp
        );

        trades.push(trade);
        userTrades[msg.sender].push(trade);

        emit TokensPurchased(msg.sender, tokenAmount, tokensPerETH);

        MoonNinja(moonNinja).tradeEvent(
            true,
            address(msg.sender),
            tokenAmount,
            tokensPerETH
        );
    }

    function sellTokens(uint _tokenAmount) public {
        require(balanceOf(msg.sender) >= _tokenAmount, "too poor");
        uint tokensPerETH = quoteSell(_tokenAmount);
        uint ethAmount = (_tokenAmount * 1e18) / tokensPerETH;
        require(
            address(this).balance >= ethAmount,
            "Insufficient contract balance"
        );
        _transfer(msg.sender, address(this), _tokenAmount);
        payable(msg.sender).transfer(ethAmount);

        TradeDetails memory trade = TradeDetails(
            false,
            address(this),
            _tokenAmount,
            tokensPerETH,
            msg.sender,
            block.timestamp
        );

        trades.push(trade);
        userTrades[msg.sender].push(trade);

        emit TokensSold(msg.sender, _tokenAmount, tokensPerETH);

        MoonNinja(moonNinja).tradeEvent(
            false,
            address(msg.sender),
            _tokenAmount,
            tokensPerETH
        );
    }

    function getCurrentPrice() public view returns (uint tokensPerETH) {
        uint remainingTokens = balanceOf(address(this));
        uint contractETHBalance = address(this).balance;
        if (contractETHBalance < 0.01 ether) contractETHBalance = 0.01 ether;

        tokensPerETH = (remainingTokens * 1e18) / contractETHBalance;
    }

    function quoteBuy(uint _ethAmount) public view returns (uint tokensPerETH) {
        uint currentTokensPerETH = getCurrentPrice();
        uint tokenAmount = (_ethAmount * currentTokensPerETH) / 1e18;
        uint remainingTokens = balanceOf(address(this));
        tokensPerETH =
            ((remainingTokens - (tokenAmount / 2)) * 1e18) /
            (address(this).balance + (_ethAmount / 2));
    }

    function quoteSell(
        uint _tokenAmount
    ) public view returns (uint tokensPerETH) {
        uint currentTokensPerETH = getCurrentPrice();
        uint ethAmount = (_tokenAmount * 1e18) / currentTokensPerETH;
        uint remainingTokens = balanceOf(address(this));
        tokensPerETH =
            ((remainingTokens + (_tokenAmount / 2)) * 1e18) /
            (address(this).balance - (ethAmount / 2));
    }

    function getTradeHistory() public view returns (TradeDetails[] memory) {
        return trades;
    }

    function getUserTradeHistory(
        address user
    ) public view returns (TradeDetails[] memory) {
        return userTrades[user];
    }

    function getTokenDetails() public view returns (TokenDetails memory) {
        return
            TokenDetails(
                name(),
                symbol(),
                address(this),
                developer,
                maxSupply,
                description,
                image,
                twitter,
                telegram,
                website
            );
    }
}
