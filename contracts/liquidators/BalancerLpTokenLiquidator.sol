// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./IRedemptionStrategy.sol";
import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "../external/balancer/IBalancerPool.sol";
import "../external/balancer/IBalancerVault.sol";

contract BalancerLpTokenLiquidator is IRedemptionStrategy {
  function redeem(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    bytes memory strategyData
  ) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
    IBalancerPool pool = IBalancerPool(address(inputToken));
    IBalancerVault vault = pool.getVault();
    bytes32 poolId = pool.getPoolId();
    (IERC20Upgradeable[] memory tokens, , ) = vault.getPoolTokens(poolId);
    uint256[] memory minAmountsOut = new uint256[](tokens.length);

    uint256 outputTokenIndex = abi.decode(strategyData, (uint256));
    minAmountsOut[outputTokenIndex] = 1;

    bytes memory userData = abi.encode(
      IBalancerVault.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
      inputAmount,
      outputTokenIndex
    );

    IBalancerVault.ExitPoolRequest memory request = IBalancerVault.ExitPoolRequest(
      tokens,
      minAmountsOut,
      userData,
      false //toInternalBalance
    );
    vault.exitPool(poolId, address(this), payable(address(this)), request);
  }
}
