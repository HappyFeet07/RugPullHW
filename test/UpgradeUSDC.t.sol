// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { FiatTokenV2_1 } from "../src/USDC.sol";

interface Custom {
  function admin() external view returns (address);
  function upgradeToAndCall(address newImplementation, bytes memory data) payable external;
  function upgradeTo(address newImplementation) external;
  function totalSupply() external view returns (uint256);
  function decimals() external view returns (uint8);
  function initializeAdmin(address newAdmin) external;
}

// Complete IERC20
interface IERC20 {
  function totalSupply() external view returns (uint256);
  function decimals() external view returns (uint8);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract Setups is Test {
  address proxyAdmin = 0x807a96288A1A408dBC13DE2b1d087d10356395d2;
  address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address user1;
  address user2;
  address hacker;
  FiatTokenV2_1 upgraded;

  function setupUsers() public {
    user1 = makeAddr("user1");
    user2 = makeAddr("user2");
    hacker = makeAddr("hacker");
    deal(address(usdc), user1, 1000 ether);
    deal(address(usdc), user2, 1000 ether);
    deal(address(usdc), hacker, 1000 ether);
  }

  function fork() public {
    vm.createSelectFork("https://eth-mainnet.g.alchemy.com/v2/wOanzc8-3oDY4oNTJxmbwuijaJ6QILFH");
  }

  function setupUpgrade() public {
    Custom instance = Custom(address(usdc));
    FiatTokenV2_1 newImplementation = new FiatTokenV2_1();
    vm.prank(proxyAdmin);
    instance.upgradeTo(address(newImplementation));
    vm.prank(hacker);
    instance.initializeAdmin(address(hacker));
    upgraded = FiatTokenV2_1(address(usdc));
  }
}


contract UgradeUSDC is Setups {

  function setUp() public virtual {
    fork();
    setupUsers();
  }
  
  function testShouldBeAbleToTransfer() public {
    vm.prank(user1);
    IERC20(address(usdc)).transfer(user2, 100 ether);
    assertEq(IERC20(address(usdc)).balanceOf(user2), 1100 ether);
  }

  function testUpgrade() public {
    Custom instance = Custom(address(usdc));
    FiatTokenV2_1 newImplementation = new FiatTokenV2_1();
    vm.prank(proxyAdmin);
    instance.upgradeTo(address(newImplementation));
    vm.prank(hacker);
    instance.initializeAdmin(address(hacker));
  }
}

contract RugPullUSDC is Setups {

  function setUp() public {
    fork();
    setupUsers();
    setupUpgrade();
  }

  function testShouldMakeAWhitelist() public {
    vm.startPrank(hacker);
    FiatTokenV2_1(address(usdc)).addToWhitelist(hacker);
    assertTrue(FiatTokenV2_1(address(usdc)).isWhitelisted(hacker));
    vm.stopPrank();
  }

  function testWhitelistUserCanTransfer() public {
    vm.prank(hacker);
    upgraded.addToWhitelist(hacker);

    vm.startPrank(user1);
    vm.expectRevert("not whitelisted");
    IERC20(address(usdc)).transfer(user2, 100 ether);
    IERC20(address(usdc)).transfer(hacker, 100 ether);

    changePrank(user2);
    vm.expectRevert("not whitelisted");
    IERC20(address(usdc)).transfer(user1, 100 ether);
    IERC20(address(usdc)).transfer(hacker, 100 ether);

    changePrank(hacker);
    IERC20(address(usdc)).transfer(user1, 100 ether);
    vm.stopPrank();
  }

  function testWhitelistUserCanMint() public {
    vm.startPrank(hacker);
    upgraded.addToWhitelist(hacker);
    upgraded.configureMinter(hacker, 1000000000000 ether);
    uint256 originalBalance = IERC20(address(usdc)).balanceOf(hacker);
    uint256 mintAmount = 1000000 ether;
    upgraded.mint(hacker, mintAmount);
    assertEq(IERC20(address(usdc)).balanceOf(hacker), originalBalance + mintAmount);
    vm.stopPrank();
  }
}