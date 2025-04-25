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

import {MNLiquidityManager} from "./MNLiquidityManager.sol";
import {BancorFormula} from "./bonding_curve/BancorFormula.sol";

import "forge-std/console.sol";

// Interface for sending trade events to the MoonNinja contract
interface IMoonNinja {
    function tradeEvent(
        bool isBuy,
        address trader,
        uint amount,
        uint price
    ) external;
}

contract MoonNinjaToken is
    Initializable,
    ERC20Upgradeable,
    MNLiquidityManager,
    BancorFormula
{
    string public description;
    string public image;
    string public twitter;
    string public telegram;
    string public website;
    address public developer;
    uint immutable maxSupply = 1_000_000_000e18;

    address public moonNinja;

    uint public immutable tradingFee = 1;
    address public bondingFeeAddress;

    uint32 public connectorWeight;

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

    bool public initialized = false;

    event TokensPurchased(address indexed purchaser, uint amount, uint price);
    event TokensSold(address indexed seller, uint amount, uint price);

    //event LiquidityAdded(uint tokenAmount, uint ethAmount);

    constructor() MNLiquidityManager() {
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
        connectorWeight = 100000;

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

        uint tokenAmount = quoteBuy(netAmount);
        uint currentTokensPerETH = (tokenAmount * 1e18) / netAmount;

        require(balanceOf(address(this)) > tokenAmount, "sold out");

        _transfer(address(this), msg.sender, tokenAmount);
        payable(address(bondingFeeAddress)).transfer(fee);

        emit TokensPurchased(msg.sender, tokenAmount, currentTokensPerETH);

        IMoonNinja(moonNinja).tradeEvent(
            true,
            address(msg.sender),
            tokenAmount,
            currentTokensPerETH
        );
    }

    function sellTokens(uint _tokenAmount) public {
        require(balanceOf(msg.sender) >= _tokenAmount, "too poor");

        uint ethAmountReceived = quoteSell(_tokenAmount);
        uint currentTokensPerETH = (_tokenAmount * 1e18) / ethAmountReceived;

        require(
            address(this).balance >= ethAmountReceived,
            "Insufficient contract balance"
        );
        _transfer(msg.sender, address(this), _tokenAmount);

        uint fee;
        uint netAmount;
        (fee, netAmount) = applyFee(ethAmountReceived);

        payable(bondingFeeAddress).transfer(fee);
        payable(msg.sender).transfer(netAmount);

        emit TokensSold(msg.sender, _tokenAmount, currentTokensPerETH);

        IMoonNinja(moonNinja).tradeEvent(
            false,
            address(msg.sender),
            _tokenAmount,
            currentTokensPerETH
        );
    }

    function getCurrentPrice() public view returns (uint tokensPerETH) {
        uint ethAmount = 1e18; // 1 ETH
        uint tokenAmount = quoteBuy(ethAmount);
        return (tokenAmount * 1e18) / ethAmount;
    }

    function quoteBuy(uint _ethAmount) public view returns (uint) {
        uint256 connectorBalance = address(this).balance;

        return
            calculatePurchaseReturn(
                balanceOf(address(this)),
                connectorBalance,
                connectorWeight,
                _ethAmount
            );
    }

    function quoteSell(uint _tokenAmount) public view returns (uint) {
        uint256 connectorBalance = address(this).balance;

        return
            calculateSaleReturn(
                balanceOf(address(this)),
                connectorBalance,
                connectorWeight,
                _tokenAmount
            );
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

    function initializeLiquidity() external {
        require(msg.sender == developer, "Only dev");

        uint tokenBalance = balanceOf(address(this));
        uint ethBalance = address(this).balance;

        // uint256 lpToken = _createAndAddLiquidity(
        //     address(this),
        //     tokenBalance,
        //     ethBalance,
        //     3000 // 0.3% fee
        // );
    }
}
