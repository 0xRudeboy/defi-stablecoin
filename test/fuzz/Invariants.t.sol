// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

// What are our invariants?
// 1. The total supply of DSC must be less than the total value of all collateral
// 2. Getter view functions should never revert <- evergreen invariant

import {Test, console2} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    Handler handler;

    address weth;
    address wbtc;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        handler = new Handler(engine, dsc);
        targetContract(address(handler));
        // targetContract(address(engine));

        // hey don't call redeemCollateral() unless there is collateral to redeem (using the invariant handler)
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // get the value of all the collateral
        // compare it to all the debt (DSC)
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(engine));

        uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = engine.getUsdValue(wbtc, totalWbtcDeposited);

        uint256 totalCollateralValue = wethValue + wbtcValue;

        console2.log("wethValue", wethValue);
        console2.log("wbtcValue", wbtcValue);
        console2.log("totalSupply", totalSupply);
        console2.log("times Mint Is Called", handler.timesMintIsCalled());

        assert(totalCollateralValue >= totalSupply);
    }

    function invariant_gettersShouldNotRevert() public view {
        engine.getAccountInformation(msg.sender);
        engine.getCollateralBalanceOfUser(msg.sender, weth);
        engine.getCollateralBalanceOfUser(msg.sender, wbtc);
        engine.getUsdValue(weth, 1e18);
        engine.getUsdValue(wbtc, 1e18);
        engine.getDSCMinted(msg.sender);
        engine.getAccountCollateralValueInUsd(msg.sender);
        engine.calculateHealthFactor(engine.getDSCMinted(msg.sender), engine.getAccountCollateralValueInUsd(msg.sender));
        engine.getCollateralTokens();
    }
}
