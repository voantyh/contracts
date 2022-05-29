// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

import { ERC4626 } from "../../utils/ERC4626.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";

struct UserInfo {
  uint256 amount;
  int256 rewardDebt;
}

interface IMiniChefV2 {
  function userInfo(uint256 pid, address user) external view returns (UserInfo memory);

  function deposit(
    uint256 pid,
    uint256 amount,
    address to
  ) external;

  function withdrawAndHarvest(
    uint256 pid,
    uint256 amount,
    address to
  ) external;
}

/**
 * @title Kinesis ERC4626 Contract
 * @notice ERC4626 wrapper for Kinesis
 * @author RedVeil
 *
 * Wraps https://github.com/kinesis-labs/kinesis-contract/blob/main/contracts/rewards/MiniChefV2.sol
 *
 */
contract KinesisERC4626 is ERC4626 {
  using SafeTransferLib for ERC20;
  using FixedPointMathLib for uint256;

  /* ========== STATE VARIABLES ========== */
  uint256 public immutable poolId;
  IMiniChefV2 public immutable miniChef;
  FlywheelCore public immutable flywheel;

  /* ========== CONSTRUCTOR ========== */

  /**
     @notice Creates a new Vault that accepts a specific underlying token.
     @param _asset The ERC20 compliant token the Vault should accept.
     @param _flywheel Flywheel to pull AUTO rewards
     @param _poolId The poolId in AutofarmV2
     @param _miniChef Kenisis MiniChefV2 contract
    */
  constructor(
    ERC20 _asset,
    FlywheelCore _flywheel,
    uint256 _poolId,
    IMiniChefV2 _miniChef
  )
    ERC4626(
      _asset,
      string(abi.encodePacked("Midas ", _asset.name(), " Vault")),
      string(abi.encodePacked("mv", _asset.symbol()))
    )
  {
    poolId = _poolId;
    miniChef = _miniChef;
    flywheel = _flywheel;

    asset.approve(address(miniChef), type(uint256).max);
    flywheel.rewardToken().approve(address(flywheel.flywheelRewards()), type(uint256).max);
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    return miniChef.userInfo(poolId, address(this)).amount;
  }

  /// @notice Calculates the total amount of underlying tokens the user holds.
  /// @return The total amount of underlying tokens the user holds.
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf[account]);
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256) internal override {
    miniChef.deposit(poolId, amount, address(this));
  }

  /// @notice withdraws specified amount of underlying token if possible
  function beforeWithdraw(uint256 amount, uint256) internal override {
    miniChef.withdrawAndHarvest(poolId, amount, address(this));
  }
}
