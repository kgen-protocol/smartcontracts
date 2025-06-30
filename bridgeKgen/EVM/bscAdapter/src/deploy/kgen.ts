import { ethers } from "hardhat";
import {  DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { contractNames } from "../ts/deploy";
import verifyContract from "../utilites/utilites";
const deployContract: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const { deployments } = hre;
  const { deploy, get } = deployments;
  const { KgenOApp, KgenAdapterProxy } = contractNames;
  let KgenOapp: Deployment;
  let kgenProxys: Deployment;

  let [deployer,signer] = await hre.ethers.getSigners();
  const endpointV2 = "0x6EDCE65403992e310A62460808c4b910D972f10f";

  console.table({
    deployer: deployer.address,
  });
  const chainId = await hre.getChainId();
  console.log("chainId: ", chainId);

  // Step-02 Deploy Cruize Implementation Contract
  await deploy(KgenOApp, {
    from: deployer.address,
    args: [endpointV2],
    log: true,
    deterministicDeployment: false,
  });
  KgenOapp = await get(KgenOApp);
  console.log("KgenOapp", KgenOapp.address);

  // Step-03 Deploy  Proxy Contract
  await deploy(KgenAdapterProxy, {
    from: deployer.address,
    args: [KgenOapp.address, deployer.address, "0x"],
    log: true,
    deterministicDeployment: false,
  });
  kgenProxys = await get(KgenAdapterProxy);

  console.table({
    MazeNFTImplementation: KgenOapp.address,
    MazeProxy: kgenProxys.address,
  }); 
//   const MazeModuleProxy = await ethers.getContractAt(
//     "SD2023",
//     kgenProxys.address,
//     deployer
//   );
// const data =  await MazeModuleProxy.connect(signer).initialize(TOKEN_NAME,SYMBOL,CONTRACT_URI,BASE_URI,SUPPLY_CAP,signer.address,signer.address,OPENSEA_PROXY)
// console.log(data)
  // console.log(await MazeNFT.methods.owner().call()) 

  await verifyContract(hre, kgenProxys.address, [
    KgenOapp.address,
    deployer.address,
    "0x",
  ],
  `contracts/proxy/KgenProxy.sol:KgenAdapterProxy`
  );
  await verifyContract(hre, KgenOapp.address, [endpointV2],  `contracts/KgenOapp.sol:${KgenOApp}`);
};

export default deployContract;
