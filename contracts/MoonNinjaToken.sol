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

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
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

    function getWETH() external view returns (address);
}

interface IWETH9 {
    function deposit() external payable;

    function withdraw(uint) external;

    function balanceOf(address) external view returns (uint);

    function transferFrom(address, address, uint) external returns (bool);

    function transfer(address, uint) external returns (bool);
}

contract MoonNinjaToken is
    Initializable,
    ERC20PermitUpgradeable,
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
    bool public isTokenGraduated = false;
    address public constant DEAD_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    address public moonNinja;
    address public WETH;

    uint public immutable bondingFee = 1;
    address public bondingFeeAddress;

    uint32 public connectorWeight;

    // developer fee options
    // fees can be applied on transfer, buy, and sell
    // The maximum fee is 10%

    uint32 private constant MAX_FEE = 10; // 10% max fee

    uint32 public buyFee = 0; // 0% buy fee
    uint32 public sellFee = 0; // 0% sell fee
    uint32 public transferFee = 10; // 10% transfer fee

    // fee split options
    // fees can be split between the developer and burn
    // developerFee + burnFee = 100%

    uint32 public developerFee = 50; // 0% developer fee
    uint32 public burnFee = 50; // 0% burn fee

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
        address bondingFeeAddress;
        uint32 connectorWeight;
        FeeDetails fees;
        bool antiWhale;
        uint32 maxAntiWhaleAmount;
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
        address _developer
    ) external initializer {
        __ERC20_init(_name, _symbol);

        description = _description;
        image = _image;
        twitter = _twitter;
        telegram = _telegram;
        website = _website;
        developer = _developer;
        moonNinja = msg.sender;

        transferFee = 10; // 10% transfer fee
        developerFee = 50; // 50% developer fee
        burnFee = 50; // 50% burn fee

        WETH = IMoonNinja(moonNinja).getWETH();

        initLM(address(this), WETH);

        _mint(address(this), maxSupply);
    }

    function initializeStage2(
        address _bondingFeeAddress,
        uint32 _connectorWeight
    ) external {
        require(!initialized, "Already initialized");
        initialized = true;

        bondingFeeAddress = _bondingFeeAddress;
        connectorWeight = _connectorWeight;
    }

    receive() external payable {
        if (msg.sender != WETH) {
            buyTokens(0);
        }
    }

    function applyBondingFee(uint amount) internal pure returns (uint, uint) {
        uint fee = (amount * bondingFee) / 100;
        uint netAmount = amount - fee;

        return (fee, netAmount);
    }

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(to != address(0), "Transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 fee = 0;

        if (transferFee > 0) {
            fee = (amount * transferFee) / 100;
            // calculate the fee split
            uint256 developerFeeAmount = (fee * developerFee) / 100;
            uint256 burnFeeAmount = (fee * burnFee) / 100;

            // transfer the fee to the developer
            if (developerFeeAmount > 0) {
                _transfer(msg.sender, developer, developerFeeAmount);
            }
            // burn the fee
            if (burnFeeAmount > 0) {
                _burn(msg.sender, burnFeeAmount);
            }
        }

        // apply apply transfer fee if applicable
        uint256 netAmount = amount - fee;

        // transfer the tokens
        _transfer(msg.sender, to, netAmount);

        return true;
    }

    function buyTokens(uint amountWETH) public payable {
        require(msg.value > 1 || amountWETH > 0, "send some ETH");
        uint ethAmount;

        if (msg.value > 0) {
            IWETH9(WETH).deposit{value: msg.value}();
            ethAmount = msg.value;
        } else {
            ethAmount = amountWETH;
            IWETH9(WETH).transferFrom(msg.sender, address(this), amountWETH);
        }

        uint fee;
        uint netAmount;
        (fee, netAmount) = applyBondingFee(ethAmount);

        uint tokenAmount = quoteBuy(netAmount);
        uint currentTokensPerETH = (tokenAmount * 1e18) / netAmount;

        require(balanceOf(address(this)) > tokenAmount, "sold out");

        _transfer(address(this), msg.sender, tokenAmount);
        IWETH9(WETH).transfer(bondingFeeAddress, fee);

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
            IWETH9(WETH).balanceOf(address(this)) >= ethAmountReceived,
            "Insufficient contract balance"
        );
        _transfer(msg.sender, address(this), _tokenAmount);

        uint fee;
        uint netAmount;
        (fee, netAmount) = applyBondingFee(ethAmountReceived);

        IWETH9(WETH).withdraw(netAmount);
        IWETH9(WETH).transfer(bondingFeeAddress, fee);

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
        uint ethAmount = 1 ether;
        uint tokenAmount = quoteBuy(ethAmount);
        return (tokenAmount * 1e18) / ethAmount;
    }

    function quoteBuy(uint _ethAmount) public view returns (uint) {
        uint256 connectorBalance = IWETH9(WETH).balanceOf(address(this));

        return
            calculatePurchaseReturn(
                balanceOf(address(this)),
                connectorBalance,
                connectorWeight,
                _ethAmount
            );
    }

    function quoteSell(uint _tokenAmount) public view returns (uint) {
        uint256 connectorBalance = IWETH9(WETH).balanceOf(address(this));

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

        run();

        // uint256 lpToken = _createAndAddLiquidity(
        //     address(this),
        //     tokenBalance,
        //     ethBalance,
        //     3000 // 0.3% fee
        // );
    }
}
