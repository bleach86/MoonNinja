// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PositionManager} from "@uniswap/v4-periphery/src/PositionManager.sol";
import {IAllowanceTransfer} from "./IAllowanceTransfer.sol";

/// @notice Shared constants used in scripts
contract Constants {
    IPoolManager constant POOLMANAGER =
        IPoolManager(address(0x67366782805870060151383F4BbFF9daB53e5cD6));
    PositionManager constant posm =
        PositionManager(
            payable(address(0x1Ec2eBf4F37E7363FDfe3551602425af0B3ceef9))
        );
    IAllowanceTransfer constant PERMIT2 =
        IAllowanceTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));
}
