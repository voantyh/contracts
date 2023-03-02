// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";

import { MidasFlywheel } from "../midas/strategies/flywheel/MidasFlywheel.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { ComptrollerFirstExtension, DiamondExtension } from "../compound/ComptrollerFirstExtension.sol";
import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { FuseFeeDistributor } from "../FuseFeeDistributor.sol";
import { Unitroller } from "../compound/Unitroller.sol";
import { CTokenInterface, CTokenExtensionInterface } from "../compound/CTokenInterfaces.sol";

import { IFlywheelBooster } from "flywheel-v2/interfaces/IFlywheelBooster.sol";
import { IFlywheelRewards } from "flywheel-v2/interfaces/IFlywheelRewards.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract ComptrollerTest is BaseTest {
  Comptroller internal comptroller;
  MidasFlywheel internal flywheel;
  address internal nonOwner = address(0x2222);

  event Failure(uint256 error, uint256 info, uint256 detail);

  function setUp() public {
    ERC20 rewardToken = new MockERC20("RewardToken", "RT", 18);
    comptroller = new Comptroller(payable(address(this)));
    MidasFlywheel impl = new MidasFlywheel();
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), address(dpa), "");
    flywheel = MidasFlywheel(address(proxy));
    flywheel.initialize(rewardToken, IFlywheelRewards(address(2)), IFlywheelBooster(address(3)), address(this));
  }

  function test__setFlywheel() external {
    comptroller._addRewardsDistributor(address(flywheel));

    assertEq(comptroller.rewardsDistributors(0), address(flywheel));
  }

  function test__setFlywheelRevertsIfNonOwner() external {
    vm.startPrank(nonOwner);
    vm.expectEmit(false, false, false, true, address(comptroller));
    emit Failure(1, 2, 0);
    comptroller._addRewardsDistributor(address(flywheel));
  }

  function testBscRefactoredBorrowCaps() public debuggingOnly fork(BSC_MAINNET) {
    _testRefactoredBorrowCaps();
  }

  function testPolygonRefactoredBorrowCaps() public debuggingOnly fork(POLYGON_MAINNET) {
    _testRefactoredBorrowCaps();
  }

  function testMoonbeamRefactoredBorrowCaps() public debuggingOnly fork(MOONBEAM_MAINNET) {
    _testRefactoredBorrowCaps();
  }

  function testEvmosRefactoredBorrowCaps() public debuggingOnly fork(EVMOS_MAINNET) {
    _testRefactoredBorrowCaps();
  }

  function testFantomRefactoredBorrowCaps() public debuggingOnly fork(FANTOM_OPERA) {
    _testRefactoredBorrowCaps();
  }

  function _testRefactoredBorrowCaps() internal {
    FusePoolDirectory fpd = FusePoolDirectory(ap.getAddress("FusePoolDirectory"));
    FusePoolDirectory.FusePool[] memory pools = fpd.getAllPools();
    for (uint256 i = 0; i < pools.length; i++) {
      Comptroller pool = Comptroller(pools[i].comptroller);
      uint256 borrowCap = pool.borrowCapForCollateral(address(1), address(2));
      assertEq(borrowCap, 0, "dummy borrow cap non-zero");
    }
  }
}
