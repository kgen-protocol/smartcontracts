import { ethers, upgrades } from "hardhat";
import hre from "hardhat";

async function main() {
  // Replace with your deployed contract address
  const KGEN_PROXY_ADDRESS = "YOUR_DEPLOYED_PROXY_ADDRESS_HERE";
  
  if (KGEN_PROXY_ADDRESS === "YOUR_DEPLOYED_PROXY_ADDRESS_HERE") {
    console.error("❌ Please update the KGEN_PROXY_ADDRESS in this script with your deployed contract address");
    process.exit(1);
  }

  console.log("Verifying KGeN Token on BSCScan...");
  console.log("Proxy Address:", KGEN_PROXY_ADDRESS);

  try {
    // Get implementation address
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(KGEN_PROXY_ADDRESS);
    console.log("Implementation Address:", implementationAddress);

    // Get proxy admin address
    const proxyAdminAddress = await upgrades.erc1967.getAdminAddress(KGEN_PROXY_ADDRESS);
    console.log("Proxy Admin Address:", proxyAdminAddress);

    // Verify the implementation contract
    console.log("\nVerifying implementation contract...");
    await hre.run("verify:verify", {
      address: implementationAddress,
      constructorArguments: [],
    });

    console.log("✅ Implementation contract verified successfully!");

    // Note: Proxy admin contract verification might not be needed for transparent proxies
    // as it's a standard OpenZeppelin contract

    console.log("\n🎉 Verification completed!");
    console.log("\nContract URLs:");
    console.log(`Proxy: https://testnet.bscscan.com/address/${KGEN_PROXY_ADDRESS}`);
    console.log(`Implementation: https://testnet.bscscan.com/address/${implementationAddress}`);
    console.log(`Proxy Admin: https://testnet.bscscan.com/address/${proxyAdminAddress}`);

  } catch (error) {
    console.error("❌ Verification failed:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 