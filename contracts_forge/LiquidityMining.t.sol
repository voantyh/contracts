// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/stdlib.sol";
import "forge-std/Vm.sol";

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {CErc20} from "../contracts/compound/CErc20.sol";
import {CToken} from "../contracts/compound/CToken.sol";
import {MockERC20} from "@rari-capital/solmate/src/test/utils/mocks/MockERC20.sol";
import {WhitePaperInterestRateModel} from "../contracts/compound/WhitePaperInterestRateModel.sol";
import {Unitroller} from "../contracts/compound/Unitroller.sol";
import {Comptroller} from "../contracts/compound/Comptroller.sol";
import {CErc20Delegate} from "../contracts/compound/CErc20Delegate.sol";
import {CErc20Delegator} from "../contracts/compound/CErc20Delegator.sol";
import {RewardsDistributorDelegate} from "../contracts/compound/RewardsDistributorDelegate.sol";
import {RewardsDistributorDelegator} from "../contracts/compound/RewardsDistributorDelegator.sol";
import {ComptrollerInterface} from "../contracts/compound/ComptrollerInterface.sol";
import {InterestRateModel} from "../contracts/compound/InterestRateModel.sol";
import {FuseFeeDistributor} from "../contracts/FuseFeeDistributor.sol";
import {FusePoolDirectory} from "../contracts/FusePoolDirectory.sol";
import {MockPriceOracle} from "../contracts/oracles/1337/MockPriceOracle.sol";

contract LiquidityMiningTest is DSTest {
  using stdStorage for StdStorage;

  Vm public constant vm = Vm(HEVM_ADDRESS);

  StdStorage stdstore;

  MockERC20 underlyingToken;
  MockERC20 rewardsToken;

  WhitePaperInterestRateModel interestModel;
  Comptroller comptroller;
  CErc20Delegate cErc20Delegate;
  CErc20 cErc20;
  RewardsDistributorDelegate rewardsDistributorDelegate;
  RewardsDistributorDelegate rewardsDistributor;
  FuseFeeDistributor fuseAdmin;
  FusePoolDirectory fusePoolDirectory;
  uint256 depositAmount = 100e18;
  uint256 supplyRewardPerBlock = 10e18;
  uint256 borrowRewardPerBlocK = 1e18;

  address fuseOwner = 0x5eA4A9a7592683bF0Bc187d6Da706c6c4770976F;

  address[] markets;
  address[] emptyAddresses;
  address[] newUnitroller;
  bool[] falseBoolArray;
  bool[] trueBoolArray;
  address[] newImplementation;

  function setUp() public {
    underlyingToken = new MockERC20("UnderlyingToken", "UT", 18);
    rewardsToken = new MockERC20("RewardsToken", "RT", 18);
    interestModel = new WhitePaperInterestRateModel(1e18, 1e18);
    fuseAdmin = FuseFeeDistributor(payable(0xa731585ab05fC9f83555cf9Bff8F58ee94e18F85));
    fusePoolDirectory = FusePoolDirectory(0x835482FE0532f169024d5E9410199369aAD5C77E);
    Comptroller tempComptroller = new Comptroller();
    cErc20Delegate = new CErc20Delegate();

    rewardsDistributorDelegate = new RewardsDistributorDelegate();
    rewardsDistributor = RewardsDistributorDelegate(
      address(
        new RewardsDistributorDelegator(address(this), address(rewardsToken), address(rewardsDistributorDelegate))
      )
    );
    MockPriceOracle priceOracle = new MockPriceOracle(10);

    emptyAddresses.push(address(0));
    newUnitroller.push(address(tempComptroller));
    trueBoolArray.push(true);
    falseBoolArray.push(false);

    vm.startPrank(fuseOwner);
    fuseAdmin._editComptrollerImplementationWhitelist(emptyAddresses, newUnitroller, trueBoolArray);
    (uint256 index, address comptrollerAddress) = fusePoolDirectory.deployPool(
      "TestPool",
      address(tempComptroller),
      false,
      0.1e18,
      1.1e18,
      address(priceOracle)
    );

    Unitroller(payable(comptrollerAddress))._acceptAdmin();
    comptroller = Comptroller(comptrollerAddress);

    comptroller._addRewardsDistributor(address(rewardsDistributor));

    newImplementation.push(address(cErc20Delegate));
    fuseAdmin._editCErc20DelegateWhitelist(emptyAddresses, newImplementation, falseBoolArray, trueBoolArray);

    //markets.push(address(cErc20));
    comptroller._deployMarket(
      false,
      abi.encode(
        address(underlyingToken),
        ComptrollerInterface(comptrollerAddress),
        InterestRateModel(address(interestModel)),
        "CUnderlyingToken",
        "CUT",
        address(cErc20Delegate),
        "",
        uint256(1),
        uint256(0)
      ),
      0.9e18
    );

    CToken[] memory allMarkets = comptroller.getAllMarkets();
    cErc20 = CErc20(address(allMarkets[allMarkets.length - 1]));
    vm.stopPrank();

    rewardsDistributor._setCompSupplySpeed(cErc20, supplyRewardPerBlock);
    rewardsDistributor._setCompBorrowSpeed(cErc20, borrowRewardPerBlocK);

    rewardsToken.mint(address(this), depositAmount);
    rewardsToken.mint(address(this), depositAmount);
  }

  function deposit() public {
    underlyingToken.mint(address(this), depositAmount);
    underlyingToken.approve(address(cErc20), depositAmount);
    comptroller.enterMarkets(markets);
    cErc20.mint(depositAmount);
  }

  function testSupplyReward() public {
    deposit();
    rewardsDistributor.claimRewards(address(this));
    assertEq(rewardsToken.balanceOf(address(this)), supplyRewardPerBlock * 20);
  }
}
