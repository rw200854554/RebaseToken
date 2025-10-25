// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@chainlink/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@chainlink/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "@chainlink/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@chainlink/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
contract CrossChainTest is Test {

    address owner = makeAddr("OWNER");
    address user = makeAddr("USER");
    uint256 sepoliaFork;
    uint256 arbSepoliaFork;
    uint256 SEND_VALUE = 1e5;

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;
    Vault vault;
    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;
    RebaseTokenPool sepoliaTokenPool;
    RebaseTokenPool arbSepoliaTokenPool;
    

    function setUp() public {
        address[] memory allowlist = new address[](0);
        sepoliaFork = vm.createFork("sepolia-eth");
        arbSepoliaFork = vm.createFork("arb-sepolia");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));
        vm.selectFork(sepoliaFork);
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);


        //Deploy on sepolia
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        console.log("sepoliaNetworkDetails.rmnProxyAddress", sepoliaNetworkDetails.rmnProxyAddress);
        console.log("sepoliaNetworkDetails.routerAddress", sepoliaNetworkDetails.routerAddress);
        console.log("chainId", block.chainid);
        sepoliaTokenPool = new RebaseTokenPool(IERC20(address(sepoliaToken)), allowlist, sepoliaNetworkDetails.rmnProxyAddress, sepoliaNetworkDetails.routerAddress);
        
        sepoliaToken.grantMintAndBurnRole(address(vault));
        sepoliaToken.grantMintAndBurnRole(address(sepoliaTokenPool));
        //sepoliaNetworkDetails.addPool(address(sepoliaTokenPool));
        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(address(sepoliaToken), address(sepoliaTokenPool));

        vm.stopPrank();

        vm.selectFork(arbSepoliaFork);

        //Deploy on arbSepolia
        vm.startPrank(owner);
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        arbSepoliaToken = new RebaseToken();
        arbSepoliaTokenPool = new RebaseTokenPool(IERC20(address(arbSepoliaToken)), new address[](0), arbSepoliaNetworkDetails.rmnProxyAddress, arbSepoliaNetworkDetails.routerAddress);
        arbSepoliaToken.grantMintAndBurnRole(address(vault));
        RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(address(arbSepoliaToken), address(arbSepoliaTokenPool));
        configureTokenPools(sepoliaFork, address(sepoliaTokenPool), arbSepoliaNetworkDetails.chainSelector, address(arbSepoliaTokenPool), address(arbSepoliaToken));
        configureTokenPools(arbSepoliaFork, address(arbSepoliaTokenPool), sepoliaNetworkDetails.chainSelector, address(sepoliaTokenPool), address(sepoliaToken));
        vm.stopPrank();
    }

    function configureTokenPools(uint256 fork, address localPool, uint64 remoteChainSelector, address remotePool, address remoteToken) public {
        vm.selectFork(fork);
        vm.startPrank(owner);
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePool);

        chainsToAdd[0] = TokenPool.ChainUpdate({

            remoteChainSelector: remoteChainSelector,
            remotePoolAddress: remotePoolAddresses[0],
            remoteTokenAddress: abi.encode(remoteToken),
            allowed: true,
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            })
        });
        TokenPool(localPool).applyChainUpdates(chainsToAdd);
        vm.stopPrank();
    }

    function bridgeTokens(uint256 amountToBridge, 
    uint256 localFork, 
    uint256 remoteFork, 
    Register.NetworkDetails memory localNetworkDetails, 
    Register.NetworkDetails memory remoteNetworkDetails, 
    RebaseToken localToken, 
    RebaseToken remoteToken) public {
    vm.selectFork(localFork);
    vm.startPrank(user);
    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
    tokenAmounts[0] = Client.EVMTokenAmount({
        token: address(localToken),
        amount: amountToBridge
    });
    Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
        receiver: abi.encode(user),
        data: "",
        tokenAmounts: tokenAmounts,
        extraArgs: "",
        feeToken: localNetworkDetails.linkAddress
    });
    vm.stopPrank();

    uint256 fee = IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message);
    ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee);
    vm.startPrank(user);
    IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fee);

    IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);
    uint256 localBalanceBefore = IERC20(address(localToken)).balanceOf(user);

    IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);
    uint256 localBalanceAfter = IERC20(address(localToken)).balanceOf(user);

    assertEq(localBalanceAfter, localBalanceBefore - amountToBridge);
    vm.stopPrank();
    //uint256 localUserInterestRate = localToken.getUserInterestRate(user);

    vm.selectFork(remoteFork);
    vm.warp(block.timestamp + 20 minutes);
    //vm.roll(block.number + 1);
    uint256 remoteBalanceBefore = IERC20(address(remoteToken)).balanceOf(user);
    console.log("remoteBalanceBefore", remoteBalanceBefore);
    vm.selectFork(localFork);
    ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);
    vm.selectFork(remoteFork);
    uint256 remoteBalanceAfter = IERC20(address(remoteToken)).balanceOf(user);
    console.log("remoteBalanceAfter", remoteBalanceAfter);
    assertEq(remoteBalanceAfter, remoteBalanceBefore + amountToBridge); 
    //uint256 remoteUserInterestRate = remoteToken.getUserInterestRate(user);
    //assertEq(remoteUserInterestRate, localUserInterestRate);
    }

    function testBridgeAllTokens() public {
        vm.selectFork(sepoliaFork);
        vm.deal(user, SEND_VALUE);
        vm.prank(user);
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        assertEq(sepoliaToken.balanceOf(user), SEND_VALUE);
        bridgeTokens(SEND_VALUE, sepoliaFork, arbSepoliaFork, sepoliaNetworkDetails, arbSepoliaNetworkDetails, sepoliaToken, arbSepoliaToken);
    }

}