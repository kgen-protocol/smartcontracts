import { ethers } from "hardhat";

import { DeployResult, DeploymentsExtension } from "hardhat-deploy/types";

export const contractNames = {
  KgenOApp: "KgenOApp",
  KgenAdapterProxy: "KgenAdapterProxy",
};

/**
 * The salt used when deterministically deploying smart contracts.
 */
export const SALT = ethers.encodeBytes32String("dev-2");

/**
 * The contract used to deploy contracts deterministically with CREATE2.
 * The address is chosen by the hardhat-deploy library.
 * It is the same in any EVM-based network.
 *
 * https://github.com/Arachnid/deterministic-deployment-proxy
 */
const DEPLOYER_CONTRACT = "0x4e59b44847b379578588920ca78fbf26c0b4956c";

/**
 * Computes the deterministic address at which the contract will be deployed.
 * This address does not depend on which network the contract is deployed to.
 *
 * @param contractName Name of the contract for which to find the address.
 * @param deploymentArguments Extra arguments that are necessary to deploy.
 * @returns The address that is expected to store the deployed code.
 */
export async function deterministicDeploymentAddress(
  contractName: string,
  ...deploymentArguments: unknown[]
): Promise<string> {
  const factory = await ethers.getContractFactory(contractName);
  const deployTransaction = await factory.getDeployTransaction(
    ...deploymentArguments
  );

  return ethers.getCreate2Address(
    DEPLOYER_CONTRACT,
    SALT,
    ethers.keccak256(deployTransaction.data || "0x")
  );
}

/**
 * Print to screen the result of a successful contract deployment.
 *
 * @param deployResult Result of the deployment.
 * @param contractName Name of the deployed contract.
 * @param networkName Name of the network to which the contract is deployed.
 * @param log The logging function.
 */
export async function logResult(
  deployResult: DeployResult,
  contractName: string,
  networkName: string,
  log: DeploymentsExtension["log"]
): Promise<void> {
  if (deployResult.newlyDeployed) {
    // the transaction exists since the contract was just deployed
    /* eslint-disable @typescript-eslint/no-non-null-assertion */
    const transaction = await ethers.provider.getTransaction(
      deployResult.transactionHash!
    );
    if (transaction) {
      // const receipt = deployResult.receipt!;
      /* eslint-enable @typescript-eslint/no-non-null-assertion */
      log(`Deployed contract ${contractName} on network ${networkName}.`);
      log(` - Address: ${deployResult.address}`);
      log(` - Transaction hash: ${deployResult.transactionHash}`);
      // log(
      //   ` - Gas used: ${receipt.gasUsed} @ ${
      //     transaction.gasPrice.toNumber() / 10 ** 9
      //   } GWei`,
      // );
      // log(
      //   ` - Deployment cost: ${ethers.utils.formatEther(
      //     transaction.gasPrice.mul(receipt.gasUsed),
      //   )} ETH`,
      // );
    }
  } else {
    log(
      `Contract ${contractName} was already deployed on network ${networkName}, skipping.`
    );
  }
}
