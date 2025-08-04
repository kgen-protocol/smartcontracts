import { ethers, upgrades } from "hardhat";

async function main() {
  console.log("Starting KGEN deployment on BSC Testnet...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", await deployer.getAddress());
  console.log("Account balance:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)));

  // Deploy the proxy
  console.log("\nDeploying KGEN with Transparent Proxy...");
  const KGENFactory = await ethers.getContractFactory("KGEN");
  
  const kgen = await upgrades.deployProxy(KGENFactory, [deployer.address], {
    initializer: 'initialize',
    kind: 'transparent'
  });

  await kgen.waitForDeployment();
  const kgenAddress = await kgen.getAddress();

  console.log("✅ KGEN deployed to:", kgenAddress);
  console.log("Proxy Admin:", await upgrades.erc1967.getAdminAddress(kgenAddress));
  console.log("Implementation:", await upgrades.erc1967.getImplementationAddress(kgenAddress));

  // Verify deployment
  console.log("\nVerifying deployment...");
  
  // Check token details
  const name = await kgen.name();
  const symbol = await kgen.symbol();
  const decimals = await kgen.decimals();
  const totalSupply = await kgen.totalSupply();
  const maxSupply = await kgen.MAX_SUPPLY();
  
  console.log("Token Name:", name);
  console.log("Token Symbol:", symbol);
  console.log("Decimals:", decimals);
  console.log("Initial Total Supply:", ethers.formatUnits(totalSupply, decimals));
  console.log("Max Supply:", ethers.formatUnits(maxSupply, decimals));

  // Check roles
  const adminRole = await kgen.DEFAULT_ADMIN_ROLE();
  const minterRole = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const treasuryRole = ethers.keccak256(ethers.toUtf8Bytes("TREASURY_ROLE"));
  const burnVaultRole = ethers.keccak256(ethers.toUtf8Bytes("BURN_VAULT_ROLE"));
  const upgraderRole = ethers.keccak256(ethers.toUtf8Bytes("UPGRADER_ROLE"));

  console.log("\nRole Assignments:");
  console.log("Admin Role:", await kgen.hasRole(adminRole, deployer.address));
  console.log("Minter Role:", await kgen.hasRole(minterRole, deployer.address));
  console.log("Treasury Role:", await kgen.hasRole(treasuryRole, deployer.address));
  console.log("Burn Vault Role:", await kgen.hasRole(burnVaultRole, deployer.address));
  console.log("Upgrader Role:", await kgen.hasRole(upgraderRole, deployer.address));

  // Add deployer to whitelist for testing
  console.log("\nSetting up initial configuration...");
  await kgen.addWhitelistSender(deployer.address);
  await kgen.addWhitelistReceiver(deployer.address);
  console.log("✅ Deployer added to sender and receiver whitelists");

  // Mint some initial tokens for testing
  const initialMintAmount = ethers.parseUnits("1000000", 8); // 1 million tokens
  await kgen.mint(deployer.address, initialMintAmount);
  console.log("✅ Initial tokens minted:", ethers.formatUnits(initialMintAmount, decimals));

    console.log("\n🎉 KGEN deployment completed successfully!");
  console.log("\nContract Addresses:");
  console.log("KGEN (Proxy):", kgenAddress);
  console.log("Proxy Admin:", await upgrades.erc1967.getAdminAddress(kgenAddress));
  console.log("Implementation:", await upgrades.erc1967.getImplementationAddress(kgenAddress));
  
  console.log("\nNext Steps:");
  console.log("1. Verify the contract on BSCScan");
  console.log("2. Test the contract functions");
  console.log("3. Configure additional roles and whitelists as needed");

  return {
    kgenAddress,
    proxyAdmin: await upgrades.erc1967.getAdminAddress(kgenAddress),
    implementation: await upgrades.erc1967.getImplementationAddress(kgenAddress)
  };
}

main()
  .then((result) => {
    console.log("\nDeployment result:", result);
    process.exit(0);
  })
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  }); 