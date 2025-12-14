// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test,console2} from "forge-std/Test.sol";
import {DeployUniswapV2} from "../../script/core/DeployUniswapV2.s.sol";
import {UniswapV2Factory} from "../../src/core/UniswapV2Factory.sol";
import {UniswapV2Pair} from "../../src/core/UniswapV2Pair.sol";
import {TestMockERC20} from "../mocks/TestERC20Mock.t.sol";


contract UniswapV2UnitTest is Test {
    DeployUniswapV2 deploy;
    UniswapV2Factory factory;
    TestMockERC20 ETH;
    TestMockERC20 USDC;
    UniswapV2Pair pair;
    address deployer;

    function setUp() public {
        deploy = new DeployUniswapV2();
        deploy.run();

        factory = deploy.factory();
        ETH = deploy.tokenA();
        USDC = deploy.tokenB();
        pair = UniswapV2Pair(deploy.pair());
        deployer = deploy.deployer();
    }

    function test_ETHMetaData() public view {
        assertEq(ETH.name(), "EthereumToken");
        assertEq(ETH.symbol(), "ETH");
        assertEq(ETH.decimals(), 18);
    }

    function test_USDCMetaData() public view {
        assertEq(USDC.name(), "DollarToken");
        assertEq(USDC.symbol(), "USDC");
        assertEq(USDC.decimals(), 18);
    }

    function test_ETHInitialSupply() public view {
        assertEq(ETH.totalSupply(), 100000 ether);
        assertEq(ETH.balanceOf(deployer), 100000 ether);
    }

    function test_USDCInitialSupply() public view {
        assertEq(USDC.totalSupply(), 100000 ether);
        assertEq(USDC.balanceOf(deployer), 100000 ether);
    }

    function test_FactoryFeeSetter() public view {
       assertEq(factory.feeToSetter(), deployer);
       assertEq(factory.feeTo(), address(0));
       assertEq(factory.allPairs(0), address(pair));
       assertEq(factory.allPairsLength(), 1);
    }

    function test_GetPairAfterCreation() public view {
        address pair1 = factory.getPair(address(ETH), address(USDC));
        address pair2 = factory.getPair(address(USDC), address(ETH));

        assertEq(pair1, address(pair));
        assertEq(pair2, address(pair));
    }

    function test_PairInitialVariables() public view {
        assertEq(pair.factory(), address(factory));
        assertEq(pair.token0(), address(USDC));
        assertEq(pair.token1(), address(ETH));
        assertEq(pair.MINIMUM_LIQUIDITY(), 1000);
    }
}