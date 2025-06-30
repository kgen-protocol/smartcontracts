import { Address } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
const verifyContract = async (
  hre: HardhatRuntimeEnvironment,
  contractAddress: Address,
  constructorArgsParams: unknown[],
  contracts:string
) => {
  try {
    await hre.run("verify", {
      address: contractAddress,
      constructorArgsParams: constructorArgsParams,
      contract:contracts
    });
  } catch (error) {
    console.log(error);
    console.log(
      `Smart contract at address ${contractAddress} is already verified`
    );
  }
};
export default verifyContract;