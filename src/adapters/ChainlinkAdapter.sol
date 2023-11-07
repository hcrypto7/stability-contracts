// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IOracleAdapter.sol";
import "../core/base/Controllable.sol";
import "../integrations/chainlink/IAggregatorV3Interface.sol";

contract ChainlinkAdapter is Controllable, IOracleAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    event NewPriceFeeds(address[] assets, address[] priceFeeds);
    event RemovedPriceFeeds(address[] assets);

    /// @dev Version of ChainlinkAdapter implementation
    string public constant VERSION = '0.1.0';

    mapping(address asset => address priceFeed) public priceFeeds;
    EnumerableSet.AddressSet internal _assets;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint[50 - 3] private __gap;

    function initialize(address platform_) public initializer {
        __Controllable_init(platform_);
    }

    function addPriceFeeds(address[] memory assets_, address[] memory priceFeeds_) external onlyOperator {
        uint len = assets_.length;
        require(len == priceFeeds_.length, "CA: wrong input");

        for (uint i; i < len; ++i) {
            require(_assets.add(assets_[i]), "CA: exist");
            priceFeeds[assets_[i]] = priceFeeds_[i];
        }

        emit NewPriceFeeds(assets_, priceFeeds_);
    }

    function removePriceFeeds(address[] memory assets_) external onlyOperator {
        uint len = assets_.length;
        for (uint i; i < len; ++i) {
            require(_assets.remove(assets_[i]), "CA: not exist");
            priceFeeds[assets_[i]] = address(0);
        }
        emit RemovedPriceFeeds(assets_);
    }

    // USDC/USD 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7
    // USDT/USD 0xf9d5AAC6E5572AEFa6bd64108ff86a222F69B64d
    // ETH/USD 0xF9680D99D6C9589e2a93a78A04A279e509205945
    // MATIC/USD 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
    // BTC/USD 0xc907E116054Ad103354f2D350FD2514433D57F6f

    function getPrice(address asset) external view returns (uint price, uint timestamp) {
        if (!_assets.contains(asset)) {
            return (0,0);
        }
        //slither-disable-next-line unused-return
        (, int answer,, uint updatedAt,) = IAggregatorV3Interface(priceFeeds[asset]).latestRoundData();
        return (uint(answer) * 1e10, updatedAt);
    }

    function getAllPrices() external view returns (address[] memory assets_, uint[] memory prices, uint[] memory timestamps) {
        uint len = _assets.length();
        assets_ = _assets.values();
        prices = new uint[](len);
        timestamps = new uint[](len);
        for (uint i; i < len; ++i) {
            //slither-disable-next-line unused-return
            (, int answer,, uint updatedAt,) = IAggregatorV3Interface(priceFeeds[assets_[i]]).latestRoundData();
            prices[i] = uint(answer) * 1e10;
            timestamps[i] = updatedAt;
        }
    }

    function assets() external view returns(address[] memory) {
        return _assets.values();
    }
}
