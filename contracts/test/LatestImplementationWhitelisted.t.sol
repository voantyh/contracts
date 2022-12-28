pragma solidity ^0.8.0;

import { CErc20 } from "../compound/CErc20.sol";
import { ComptrollerFirstExtension, Comptroller } from "../compound/Comptroller.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { CErc20PluginDelegate } from "../compound/CErc20PluginDelegate.sol";
import { FuseFeeDistributor } from "../FuseFeeDistributor.sol";
import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { CTokenInterface } from "../compound/CTokenInterfaces.sol";
import { CTokenFirstExtension } from "../compound/CTokenFirstExtension.sol";
import { IERC4626 } from "../compound/IERC4626.sol";

import { BaseTest } from "./config/BaseTest.t.sol";

contract LatestImplementationWhitelisted is BaseTest {
  FuseFeeDistributor fuseAdmin;
  FusePoolDirectory fusePoolDirectory;

  address[] implementationsSet;
  address[] pluginsSet;

  function testBscImplementations() public fork(BSC_MAINNET) {
    testPoolImplementations();
    testMarketImplementations();
    testPluginImplementations();
  }

  function testPolygonImplementations() public fork(POLYGON_MAINNET) {
    testPoolImplementations();
    testMarketImplementations();
    testPluginImplementations();
  }

  function afterForkSetUp() internal override {
    fusePoolDirectory = FusePoolDirectory(ap.getAddress("FusePoolDirectory"));
    fuseAdmin = FuseFeeDistributor(payable(ap.getAddress("FuseFeeDistributor")));
  }

  function testPoolImplementations() internal {
    (, FusePoolDirectory.FusePool[] memory pools) = fusePoolDirectory.getActivePools();

    for (uint8 i = 0; i < pools.length; i++) {
      Comptroller comptroller = Comptroller(payable(pools[i].comptroller));
      address implementation = comptroller.comptrollerImplementation();

      bool added = false;
      for (uint8 k = 0; k < implementationsSet.length; k++) {
        if (implementationsSet[k] == implementation) {
          added = true;
        }
      }

      if (!added) implementationsSet.push(implementation);
    }

    emit log("listing the set");
    for (uint8 k = 0; k < implementationsSet.length; k++) {
      emit log_address(implementationsSet[k]);

      address latestImpl = fuseAdmin.latestComptrollerImplementation(implementationsSet[k]);
      bool whitelisted = fuseAdmin.comptrollerImplementationWhitelist(implementationsSet[k], latestImpl);
      assertTrue(
        whitelisted || implementationsSet[k] == latestImpl,
        "latest implementation for old implementation not whitelisted"
      );
    }
  }

  function testMarketImplementations() internal {
    (, FusePoolDirectory.FusePool[] memory pools) = fusePoolDirectory.getActivePools();

    for (uint8 i = 0; i < pools.length; i++) {
      ComptrollerFirstExtension comptroller = ComptrollerFirstExtension(payable(pools[i].comptroller));
      CTokenInterface[] memory markets = comptroller.getAllMarkets();
      for (uint8 j = 0; j < markets.length; j++) {
        CErc20Delegate delegate = CErc20Delegate(address(markets[j]));
        address implementation = delegate.implementation();

        bool added = false;
        for (uint8 k = 0; k < implementationsSet.length; k++) {
          if (implementationsSet[k] == implementation) {
            added = true;
          }
        }

        if (!added) implementationsSet.push(implementation);
      }
    }

    emit log("listing the set");
    for (uint8 k = 0; k < implementationsSet.length; k++) {
      emit log_address(implementationsSet[k]);
      (address latestCErc20Delegate, bool allowResign, bytes memory becomeImplementationData) = fuseAdmin
        .latestCErc20Delegate(implementationsSet[k]);

      bool whitelisted = fuseAdmin.cErc20DelegateWhitelist(implementationsSet[k], latestCErc20Delegate, allowResign);

      assertTrue(
        whitelisted || implementationsSet[k] == latestCErc20Delegate,
        "no whitelisted implementation for old implementation"
      );
    }
  }

  function testPluginImplementations() internal {
    (, FusePoolDirectory.FusePool[] memory pools) = fusePoolDirectory.getActivePools();

    for (uint8 i = 0; i < pools.length; i++) {
      ComptrollerFirstExtension comptroller = ComptrollerFirstExtension(payable(pools[i].comptroller));
      CTokenInterface[] memory markets = comptroller.getAllMarkets();
      for (uint8 j = 0; j < markets.length; j++) {
        CErc20PluginDelegate delegate = CErc20PluginDelegate(address(markets[j]));

        address plugin;
        try delegate.plugin() returns (IERC4626 _plugin) {
          plugin = address(_plugin);
        } catch {
          continue;
        }

        bool added = false;
        for (uint8 k = 0; k < pluginsSet.length; k++) {
          if (pluginsSet[k] == plugin) {
            added = true;
          }
        }

        if (!added) pluginsSet.push(plugin);
      }
    }

    emit log("listing the set");
    for (uint8 k = 0; k < pluginsSet.length; k++) {
      address latestPluginImpl = fuseAdmin.latestPluginImplementation(pluginsSet[k]);

      bool whitelisted = fuseAdmin.pluginImplementationWhitelist(pluginsSet[k], latestPluginImpl);
      emit log_address(pluginsSet[k]);

      assertTrue(
        whitelisted || pluginsSet[k] == latestPluginImpl,
        "no whitelisted implementation for old implementation"
      );
    }
  }

  function testMaiDust() public debuggingOnly forkAtBlock(POLYGON_MAINNET, 35632068) {
    address user = 0x2924973E3366690eA7aE3FCdcb2b4e136Cf7f8Cc;
    CErc20Delegate market = CErc20Delegate(0x28D0d45e593764C4cE88ccD1C033d0E2e8cE9aF3);
    CTokenFirstExtension asExtension = CTokenFirstExtension(address(market));

    vm.rollFork(hex"a49844015360e78d5764689d02b968ffe863e52ccfeea3e2a51f8f4e628ff60c");
    uint256 balanceBefore = asExtension.balanceOf(user);
    vm.prank(user);
    market.redeemUnderlying(type(uint256).max);
    uint256 balanceAfter = asExtension.balanceOf(user);

    emit log_named_uint("balanceBefore", balanceBefore);
    emit log_named_uint("balanceAfter", balanceAfter);
  }
}
