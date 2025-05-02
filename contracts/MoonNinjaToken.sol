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
import "@openzeppelin/contracts/proxy/Clones.sol";

//import {MNLiquidityManager} from "./MNLiquidityManager.sol";
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

    function getBondingFeeAddress() external view returns (address);

    function getMNLiquidityManagerAddress() external view returns (address);
}

interface IMNLiquidityManager {
    function initialize(address _moonNinjaToken, address _WETH) external;

    function run() external;
}

interface IWETH9 {
    function deposit() external payable;

    function withdraw(uint) external;

    function balanceOf(address) external view returns (uint);

    function transferFrom(address, address, uint) external returns (bool);

    function transfer(address, uint) external returns (bool);

    function approve(address, uint) external returns (bool);
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

contract MoonNinjaToken is
    Initializable,
    ERC20PermitUpgradeable,
    BancorFormula
{
    string public description;
    string public image;
    string public twitter;
    string public telegram;
    string public website;
    address public developer;

    address public devFeeReceiver;

    mapping(address => bool) public isAdmin;

    uint public maxSupply = 1_000_000_000e18;
    bool public isTokenGraduated = false;
    address public immutable DEAD_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    address public moonNinja;
    address public WETH;
    address public liquidityManager;

    uint public immutable bondingFee = 1;
    address public bondingFeeAddress;
    uint32 public connectorWeight;
    uint8 public constant DECIMALS = 18;

    // developer fee options
    // fees can be applied on transfer, buy, and sell

    uint32 public buyFee;
    uint32 public sellFee;
    uint32 public transferFee;

    // fee split options
    // fees can be split between the developer and burn
    // developerFee + burnFee = 100%

    uint32 public developerFee;
    uint32 public burnFee;

    event TokensPurchased(address indexed purchaser, uint amount, uint price);
    event TokensSold(address indexed seller, uint amount, uint price);

    //event LiquidityAdded(uint tokenAmount, uint ethAmount);

    constructor() {
        // Prevent initialization of the implementation contract itself
        _disableInitializers();
    }

    function initialize(
        TokenInitialization memory _tokenInit
    ) external initializer {
        __ERC20_init(_tokenInit.name, _tokenInit.symbol);

        description = _tokenInit.description;
        image = _tokenInit.image;
        twitter = _tokenInit.twitter;
        telegram = _tokenInit.telegram;
        website = _tokenInit.website;
        developer = _tokenInit.developer;
        devFeeReceiver = _tokenInit.developer;
        isAdmin[developer] = true;

        moonNinja = msg.sender;

        transferFee = _tokenInit.fees.transferFee;
        developerFee = _tokenInit.fees.developerFee;
        burnFee = _tokenInit.fees.burnFee;
        buyFee = _tokenInit.fees.buyFee;
        sellFee = _tokenInit.fees.sellFee;
        connectorWeight = _tokenInit.connectorWeight;

        maxSupply = _tokenInit.maxSupply;
        WETH = IMoonNinja(moonNinja).getWETH();

        address _liquidityManagerAddress = IMoonNinja(moonNinja)
            .getMNLiquidityManagerAddress();

        liquidityManager = Clones.clone(_liquidityManagerAddress);
        IMNLiquidityManager(liquidityManager).initialize(address(this), WETH);

        bondingFeeAddress = IMoonNinja(moonNinja).getBondingFeeAddress();

        _mint(address(this), maxSupply);
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
                _transfer(msg.sender, devFeeReceiver, developerFeeAmount);
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
        return (tokenAmount * (10 ** uint(DECIMALS))) / ethAmount;
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
        require(isAdmin[msg.sender], "Only admins can initialize liquidity");

        // make approvals

        IWETH9(WETH).approve(liquidityManager, type(uint256).max);
        _approve(address(this), liquidityManager, type(uint256).max);

        IMNLiquidityManager(liquidityManager).run();

        // uint256 lpToken = _createAndAddLiquidity(
        //     address(this),
        //     tokenBalance,
        //     ethBalance,
        //     3000 // 0.3% fee
        // );
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    function addAdmin(address _admin) external {
        require(msg.sender == developer, "Only developer can set admin");
        require(_admin != address(0), "Invalid address");
        require(!isAdmin[_admin], "Already an admin");

        isAdmin[_admin] = true;
    }

    function removeAdmin(address _admin) external {
        require(msg.sender == developer, "Only developer can remove admin");
        require(_admin != address(0), "Invalid address");
        require(isAdmin[_admin], "Not an admin");

        isAdmin[_admin] = false;
    }

    function setDevFeeReceiver(address _devFeeReceiver) external {
        require(isAdmin[msg.sender], "Only admins can set dev fee receiver");
        require(_devFeeReceiver != address(0), "Invalid address");

        devFeeReceiver = _devFeeReceiver;
    }

    function burn(uint256 amount) external {
        require(amount > 0, "Burn amount must be greater than zero");
        require(
            balanceOf(address(msg.sender)) >= amount,
            "Insufficient balance to burn"
        );

        _burn(address(this), amount);
    }
}
