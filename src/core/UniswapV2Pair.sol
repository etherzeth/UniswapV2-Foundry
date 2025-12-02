pragma solidity ^0.8.18;

import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol";
import {UniswapV2ERC20} from "./UniswapV2ERC20.sol";
import {UniswapV2Factory} from "./UniswapV2Factory.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Callee} from "./interfaces/IUniswapV2Callee.sol";
import {Math} from "./libraries/Math.sol";

contract UniswapV2Pair is UniswapV2ERC20, IUniswapV2Pair {
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimeStampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    
    uint256 public kLast;

    uint256 private unlocked = 1;

    modifier lock() {
        require(unlocked == 1, "UniswapV2:Locked");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimeStampLast) {
        return (reserve0, reserve1, blockTimeStampLast);
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "UniswapV2:Transfer_Failed");
    }

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "UniswapV2:FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }

    // it's a function that update reserve
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 < type(uint112).max, "UniswapV2:OVERFLOW");
        uint32 blockTimeStamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimeStamp - blockTimeStampLast;

        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            price0CumulativeLast = ((reserve0 *  1e18) / reserve0) * timeElapsed;
            price1CumulativeLast = ((reserve1 * 1e18) / reserve1) * timeElapsed;
        }

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimeStampLast = blockTimeStamp;
        emit Sync(reserve0, reserve1);
    }

    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast; // to save Gas
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(uint256(_reserve0) * uint256(_reserve1));
                uint256 rootKLast = Math.sqrt(_kLast);

                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply * (rootK - rootKLast);
                    uint256 denominator = (rootK * 5) + rootKLast;

                    uint256 liquidity = numerator / denominator;

                    if (liquidity > 0) {
                        _mint(feeTo, liquidity);
                    }
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }
    
    function mint(address to) external lock returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0 = balance0 - _reserve0;
        uint256 amount0 = balance1 - _reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee

        if (_totalSupply == 0) {
            liquidity = Math.sqrt((amount0 * amount1) - MINIMUM_LIQUIDITY);

            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min((amount0 * _totalSupply) / _reserve0, (amount1 * _totalSupply) / _reserve1);
        }

        require(liquidity > 0, "UniswapV2:Insufficient_Liquidity_Minted");
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);

        if (feeOn) {
            kLast = uint256(reserve0) * uint256(reserve1);
        }
        emit Mint(msg.sender, amount0, amount1);

    }   
}