import {  Signer } from "ethers";
import {ethers} from "hardhat";
export const deployContracts = async (contractName: string, signer: Signer) => {
  const contract = await ethers.getContractFactory(contractName, signer);
  const deployedContract = await contract.deploy();
  return deployedContract;
};

