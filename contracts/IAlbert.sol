import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IAlbert is IERC20 {
    struct CountermeasuresConfig {
        uint256 maxGasPrice;
        uint256 earlyBuyLimit;
        uint256 whaleBuyLimit;
        uint256 antiSnipeDuration;
        uint256 antiWhaleDuration;
    }

    event TradingEnabled(uint256 launchBlock);

    function enableTrading() external;

    function maxGasPrice() external view returns (uint256);
    function earlyBuyLimit() external view returns (uint256);
    function tradingEnabled() external view returns (bool);
    function launchBlock() external view returns (uint256);
    function antiSnipeDuration() external view returns (uint256);
    function antiWhaleDuration() external view returns (uint256);
    function whaleBuyLimit() external view returns (uint256);
}
