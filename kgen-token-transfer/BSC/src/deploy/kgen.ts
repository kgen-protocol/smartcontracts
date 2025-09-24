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
  const { KgenStaking, KgenStakingProxy } = contractNames;
  let KgenOapp: Deployment;
  let kgenProxys: Deployment;

  let [deployer,signer] = await hre.ethers.getSigners();
  console.table({
    deployer: deployer.address,
  });
  const chainId = await hre.getChainId();
  console.log("chainId: ", chainId);

  // Step-02 Deploy Cruize Implementation Contract
  await deploy(KgenStaking, {
    from: deployer.address,
    args: [],
    log: true,
    deterministicDeployment: false,
  });
  KgenOapp = await get(KgenStaking);
  console.log("KgenOapp", KgenOapp.address);

  // Step-03 Deploy  Proxy Contract
  // await deploy(KgenStakingProxy, {
  //   from: deployer.address,
  //   args: [KgenOapp.address, deployer.address, "0x"],
  //   log: true,
  //   deterministicDeployment: false,
  // });
  // kgenProxys = await get(KgenStakingProxy);

  // console.table({
  //   MazeNFTImplementation: KgenOapp.address,
  //   MazeProxy: kgenProxys.address,
  // }); 
//   const MazeModuleProxy = await ethers.getContractAt(
//     "SD2023",
//     kgenProxys.address,
//     deployer
//   );
// const data =  await MazeModuleProxy.connect(signer).initialize(TOKEN_NAME,SYMBOL,CONTRACT_URI,BASE_URI,SUPPLY_CAP,signer.address,signer.address,OPENSEA_PROXY)
// console.log(data)
  // console.log(await MazeNFT.methods.owner().call()) 

  // await verifyContract(hre, kgenProxys.address, [
  //   KgenOapp.address,
  //   deployer.address,
  //   "0x",
  // ],
  // `contracts/Proxy.sol:${KgenStakingProxy}`
  // );
  await verifyContract(hre, KgenOapp.address, [],  `contracts/KgenTokenWrapper.sol:${KgenStaking}`);
};

export default deployContract;
