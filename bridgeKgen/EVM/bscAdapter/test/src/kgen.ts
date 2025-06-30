import { Signer } from "ethers";

import { ethers }   from "hardhat";
import hre from "hardhat";

describe("KGEN TESTING STAKING", () => {
  let signer: Signer;
  let deployer: Signer;
  let mainContract: any
  before(async () => {
    [signer, deployer] = await ethers.getSigners();
    const implementationFactory = await ethers.getContractFactory(
      "KgenOApp",
      deployer
    );
    const kgenStakingProxy = await ethers.getContractFactory(
      "KgenAdapterProxy",
      deployer
    );
    console.log(deployer.address)
    const contract = await implementationFactory.deploy("0x6EDCE65403992e310A62460808c4b910D972f10f")
    console.log("KGEN STAKING PROXY DEPLOYED", contract.target);
    const kgenStakingProxyContract = await kgenStakingProxy.deploy(
      "0xc39B5E1820e2e63F037D9740506aAA3aCA74974d",
      '0x82F168ff5896D97Fe0D09a0904E59D9e9BBa4378',
      "0x"
    );
    console.log("KGEN STAKING PROXY DEPLOYED", contract.target);
    console.log("kgenStakingProxyContract.target", kgenStakingProxyContract.target);
    hre.tracer.nameTags["0xc39B5E1820e2e63F037D9740506aAA3aCA74974d"] = "KgenStakingLogic";
    // hre.tracer.nameTags[.address] = "Cruizesafe";
    hre.tracer.nameTags["0xF65a78Ca764E643cBc1e3F6B48030bA1025354F8"] = "KgenProxyContract";
    console.log(
      "KGEN STAKING PROXY CONTRACT DEPLOYED",
      kgenStakingProxyContract.target
    );
    mainContract = await ethers.getContractAt(
      "KgenOApp",
      kgenStakingProxyContract.target
    );


  });
  it("should  init ", async () => {
    await mainContract.connect(deployer).Initialize()
    console.log("KGEN STAKING TESTING");
  });
});
