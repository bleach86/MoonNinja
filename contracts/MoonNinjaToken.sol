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

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./LiquidityManager.sol";

// Interface for sending trade events to the MoonNinja contract
interface IMoonNinja {
    function tradeEvent(
        bool isBuy,
        address trader,
        uint amount,
        uint price
    ) external;
}

contract MoonNinjaToken is Initializable, ERC20Upgradeable, LiquidityManager {
    string public description;
    string public image;
    string public twitter;
    string public telegram;
    string public website;
    address public developer;
    uint immutable maxSupply = 1_000_000e18;

    address public moonNinja;

    uint public immutable tradingFee = 1;
    address public bondingFeeAddress;

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

    bool public initialized = false;

    event TokensPurchased(address indexed purchaser, uint amount, uint price);
    event TokensSold(address indexed seller, uint amount, uint price);

    //event LiquidityAdded(uint tokenAmount, uint ethAmount);

    constructor() {
        // Prevent initialization of the implementation contract itself
        _disableInitializers();
    }

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
    ) external initializer {
        __ERC20_init(_name, _symbol);

        description = _description;
        image = _image;
        twitter = _twitter;
        telegram = _telegram;
        website = _website;
        developer = _developer;
        moonNinja = _moonNinjaAddress;
        bondingFeeAddress = _bondingFeeAddress;

        _mint(address(this), maxSupply);
    }

    function _setNameAndSymbol(
        string memory _name,
        string memory _symbol
    ) internal pure {
        _name = _name;
        _symbol = _symbol;
    }

    function applyFee(uint amount) internal pure returns (uint, uint) {
        uint fee = (amount * tradingFee) / 100;
        uint netAmount = amount - fee;

        return (fee, netAmount);
    }

    function buyTokens() public payable {
        require(msg.value > 1, "send some ETH");

        uint fee;
        uint netAmount;
        (fee, netAmount) = applyFee(msg.value);

        uint tokensPerETH = quoteBuy(netAmount);
        uint tokenAmount = (netAmount * tokensPerETH) / 1e18;
        require(balanceOf(address(this)) > tokenAmount, "sold out");

        _transfer(address(this), msg.sender, tokenAmount);
        payable(address(bondingFeeAddress)).transfer(fee);

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

        IMoonNinja(moonNinja).tradeEvent(
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

        uint fee;
        uint netAmount;
        (fee, netAmount) = applyFee(ethAmount);

        payable(bondingFeeAddress).transfer(fee);
        payable(msg.sender).transfer(netAmount);

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

        IMoonNinja(moonNinja).tradeEvent(
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

    function initializeLiquidity(address uniswapRouter) external {
        require(msg.sender == developer, "Only dev");

        uint tokenBalance = balanceOf(address(this));
        uint ethBalance = address(this).balance;

        _createAndAddLiquidity(
            uniswapRouter,
            address(this),
            tokenBalance,
            ethBalance
        );
    }
}
