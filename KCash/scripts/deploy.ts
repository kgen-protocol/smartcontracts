import { ethers, upgrades } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  const ownerAddress = process.env.OWNER_ADDRESS || deployer.address;
  const designatedSigner = process.env.DESIGNATED_SIGNER_ADDRESS;

  if (!designatedSigner) {
    throw new Error(
      "DESIGNATED_SIGNER_ADDRESS environment variable is required"
    );
  }

  console.log("Deploying KCash with account:", deployer.address);
  console.log("Owner address:", ownerAddress);
  console.log("Designated signer:", designatedSigner);

  const KCash = await ethers.getContractFactory("KCash");

  const kcash = await upgrades.deployProxy(KCash, [ownerAddress, designatedSigner], {
    initializer: "initialize",
    kind: "transparent",
  });

  await kcash.waitForDeployment();

  const proxyAddress = await kcash.getAddress();
  const implementationAddress =
    await upgrades.erc1967.getImplementationAddress(proxyAddress);

  console.log("KCash proxy deployed to:", proxyAddress);
  console.log("KCash implementation deployed to:", implementationAddress);
  console.log("\nTo verify on block explorer:");
  console.log(
    `npx hardhat verify --network <network> ${implementationAddress}`
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
