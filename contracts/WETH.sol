// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";

contract WETH9 {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public {
        require(balanceOf[msg.sender] >= amount, "WETH9: insufficient balance");
        balanceOf[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }

    function totalSupply() public view returns (uint256) {
        return address(this).balance;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        console.log("approve");
        console.log("msg.sender", msg.sender);
        console.log("spender", spender);
        console.log("amount", amount);
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        return transferFrom(msg.sender, to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        console.log("transferFrom");
        console.log("from", from);
        console.log("to", to);
        console.log("amount", amount);
        uint256 fromBalance = balanceOf[from];
        console.log("fromBalance", fromBalance);
        uint256 fromAllowance = allowance[from][msg.sender];
        console.log("fromAllowance", fromAllowance);
        require(balanceOf[from] >= amount, "WETH9: insufficient balance");

        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                require(allowed >= amount, "WETH9: insufficient allowance");
                allowance[from][msg.sender] = allowed - amount;
            }
        }

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        console.log("transferFrom weth");
        console.log("from", from);
        console.log("to", to);
        console.log("amount", amount);

        return true;
    }
}
