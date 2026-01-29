import { ethers } from "hardhat";
import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import verifyContract from "../utilites/utilites";

const deployContract: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const { deployments } = hre;
  const { deploy } = deployments;

  let [deployer] = await hre.ethers.getSigners();
  console.table({
    deployer: deployer.address,
  });
  const chainId = await hre.getChainId();
  console.log("chainId: ", chainId);

  // Already deployed B2b contract address
  const B2B_CONTRACT_ADDRESS = "0x1Fcfa7866Eb4361E322aFbcBcB426B27a29d90Bd";
  
  // Deploy B2BSettlementV2 Contract
  const settlementDeployment = await deploy("B2BSettlementV2", {
    from: deployer.address,
    args: [
      B2B_CONTRACT_ADDRESS,  // _revenueContract (B2b contract)
      deployer.address,      // _superAdmin
      deployer.address       // _admin
    ],
    log: true,
    deterministicDeployment: false,
  });

  console.table({
    B2BSettlementV2: settlementDeployment.address,
    B2BContract: B2B_CONTRACT_ADDRESS,
  });

  // Verify contract
  await verifyContract(
    hre, 
    settlementDeployment.address, 
    [B2B_CONTRACT_ADDRESS, deployer.address, deployer.address],
    "contracts/B2BSettlementV2.sol:B2BSettlementV2"
  );

  console.log(" Deployment of B2BSettlementV2 completed.");
};

deployContract.tags = ["b2bSettlement"];

export default deployContract;