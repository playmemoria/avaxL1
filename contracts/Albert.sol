// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IAlbert.sol";
contract Albert is IAlbert, ERC20, Ownable {
    // Countermeasures
    uint256 public antiSnipeDuration;
    uint256 public antiWhaleDuration;
    uint256 public maxGasPrice;
    uint256 public earlyBuyLimit;
    uint256 public whaleBuyLimit;

    mapping(address => bool) private _countermeasuresOverride;
    mapping(address => uint256) private _amountBought;
    mapping(address => uint256) private _lastBuyBlock;

    // Trading status
    bool public tradingEnabled;
    uint256 public launchBlock;

    constructor(
        uint256 _supply,
        string memory _name,
        string memory _symbol,
        address owner_,
        CountermeasuresConfig memory _config
    ) ERC20(_name, _symbol) Ownable(owner_) {
        _countermeasuresOverride[msg.sender] = true;
        _countermeasuresOverride[owner_] = true;
        _mint(msg.sender, _supply);

        tradingEnabled = false;
        launchBlock = 0;

        earlyBuyLimit = _config.earlyBuyLimit;
        whaleBuyLimit = _config.whaleBuyLimit;
        maxGasPrice = _config.maxGasPrice;
        antiSnipeDuration = _config.antiSnipeDuration;
        antiWhaleDuration = _config.antiWhaleDuration;
    }

    modifier antiSnipeRules(
        address from,
        address to,
        uint256 amount
    ) {
        if (
            !_countermeasuresOverride[from] &&
            !_countermeasuresOverride[to] &&
            _snipingCountermeasuresActive()
        ) {
            require(block.number > launchBlock + 2, "Sniping attempt detected");
            require(tx.gasprice <= maxGasPrice, "Gas price too high");
            require(
                (amount + _amountBought[to]) < earlyBuyLimit,
                "Buy amount exceeds limit"
            );
            // Prevent rapid buys
            require(
                _lastBuyBlock[to] == 0 || block.number > _lastBuyBlock[to] + 1,
                "Buy attempt too soon"
            );

            _lastBuyBlock[to] = block.number;
        }
        _;
    }

    modifier antiWhaleRules(
        address from,
        address to,
        uint256 amount
    ) {
        if (
            !_countermeasuresOverride[from] &&
            !_countermeasuresOverride[to] &&
            _antiWhaleCountermeasuresActive()
        ) {
            require(
                amount + _amountBought[to] <= whaleBuyLimit,
                "Buy amount exceeds whale limit"
            );
        }
        _;
    }

    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "Trading already enabled");
        tradingEnabled = true;
        launchBlock = block.number;
        emit TradingEnabled(launchBlock);
    }

    function _snipingCountermeasuresActive() internal view returns (bool) {
        if (launchBlock == 0 || !tradingEnabled) {
            return true;
        }

        return block.number <= launchBlock + antiSnipeDuration;
    }

    function _antiWhaleCountermeasuresActive() internal view returns (bool) {
        if (launchBlock == 0 || !tradingEnabled) {
            return true;
        }

        return block.number <= launchBlock + antiWhaleDuration;
    }

    function _update(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override
        antiSnipeRules(from, to, amount)
        antiWhaleRules(from, to, amount)
    {
        super._update(from, to, amount);
    }
}