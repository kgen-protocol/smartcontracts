import { AccountAddress } from "@aptos-labs/ts-sdk";
import {
  address_name,
  admin,
  aptos,
  compilePackage,
  deployer,
  getPackageBytesToPublish,
  is_deployed,
  module_file_name,
  output_file_path,
  sender,
  treasury,
} from "./utils";
import {
  addTreasuryAddress,
  getAdmin,
  getMetadata,
  getMinter,
  getRKBalance,
  getTreasuryAddress,
  getWhitelistedReceiver,
  getWhitelistedSender,
  mint,
  updateAdmin,
  updateMinter,
} from "./rKGenFunctions";

export async function compileAndDeployModule(
  moduleName: string,
  outputFile: string,
  addressName: string,
  address: AccountAddress
) {
  compilePackage(moduleName, outputFile, [
    { name: addressName, address: address },
  ]);
  console.log("Compiled successfully");

  try {
    const { metadataBytes, byteCode } =
      getPackageBytesToPublish(output_file_path);
    const transaction = await aptos.publishPackageTransaction({
      account: deployer.accountAddress,
      metadataBytes,
      moduleBytecode: byteCode,
    });

    const response = await aptos.signAndSubmitTransaction({
      signer: deployer,
      transaction: transaction,
    });

    await aptos.waitForTransaction({
      transactionHash: response.hash,
    });
    return response.hash;
  } catch (error) {
    console.log("🚀 ~ deployModule ~ error:", error);
  }
}

const main = async () => {
  console.log("START******");
  console.log(
    "🚀 ~ main ~ deployer.accountAddress:",
    deployer.accountAddress.toString()
  );
  if (!is_deployed) {
    console.log("\n=== Compiling rKGEN package locally ===");
    let tx = await compileAndDeployModule(
      module_file_name,
      output_file_path,
      address_name,
      deployer.accountAddress
    );
    console.log("Module is deployed at:", tx);
  }

  const metadataAddress = await getMetadata();
  console.log("metadata address:", metadataAddress);

  console.log("\n=== List of all resources in rKGEN package ===");
  console.log("Admin address: ", await getAdmin());
  console.log("Minter address: ", await getMinter());
  console.log(
    "Treasury address: ",
    await getTreasuryAddress(),
    "\nTreasury verification: ",
    (await getTreasuryAddress()).includes(sender.accountAddress.toString())
  );
  console.log("Whitelist sender address: ", await getWhitelistedSender());
  console.log("Whitelist Receiver address: ", await getWhitelistedReceiver());

  console.log("\n---------Updating Admin --------");
  await updateAdmin(deployer, admin.accountAddress);
  console.log("New admin address: ", await getAdmin());

  await updateMinter(admin, admin.accountAddress);
  console.log("New minter address: ", await getMinter());

  console.log(
    "\n---------Added addresses in whitelist sender and receiver and treasury --------"
  );
  (await getTreasuryAddress()).includes(admin.accountAddress.toString())
    ? await addTreasuryAddress(admin, admin.accountAddress)
    : "";

  console.log(
    "Balance in treasury: ",
    await getRKBalance(treasury.accountAddress, metadataAddress)
  );
};

// main();
