import { AccountAddress } from "@aptos-labs/ts-sdk";
import {
  address_name,
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
  console.log(
    "Admin address: ",
    await getAdmin(),
    "\nAdmin verification: ",
    (await getAdmin()) === deployer.accountAddress.toString()
  );
  console.log("Minter address: ", await getMinter());
  console.log(
    "Treasury address: ",
    await getTreasuryAddress(),
    "\nTreasury verification: ",
    (await getTreasuryAddress()).includes(sender.accountAddress.toString())
  );
  console.log("Whitelist sender address: ", await getWhitelistedSender());
  console.log("Whitelist Receiver address: ", await getWhitelistedReceiver());

  // console.log("\n---------Updating Admin --------");
  // await updateAdmin(deployer, admin.accountAddress);
  // console.log("New admin address: ", await getAdmin());

  // console.log(
  //   "\n---------Added addresses in whitelist sender and receiver and treasury --------"
  // );
  // await addTreasuryAddress(deployer, sender.accountAddress);
  // await addWhitelistSender(admin, treasury.accountAddress);
  // await addWhitelistReceiver(admin, receiver.accountAddress);
  // console.log("New treasury address: ", await getTreasuryAddress());
  // console.log("New sender address: ", await getWhitelistedSender());
  // console.log("New receiver address: ", await getWhitelistedReceiver());

  console.log(
    "Balance in treasury: ",
    await getRKBalance(treasury.accountAddress, metadataAddress)
  );

  console.log(
    "Balance in treasury After: ",
    await getRKBalance(treasury.accountAddress, metadataAddress)
  );
  console.log(
    "Balance in sender address: ",
    await getRKBalance(sender.accountAddress, metadataAddress)
  );
  //   console.log(
  //     "Transfer from sender whitelist: ",
  //     await transferFromWhitelistSender(
  //       sender,
  //       AccountAddress.fromStringStrict(
  //         "0x23930e74f6a9c85b5c4be215994152d5922587ed926b13f26f9f2b5e0e461419"
  //       ),
  //       1000000000
  //     )
  //   );

  console.log(
    "Balance in treasury address: ",
    await getRKBalance(treasury.accountAddress, metadataAddress)
  );

  //   await mint(treasury.accountAddress, 10000);
  //   console.log(
  //     "Balance in treasury address after mint: ",
  //     await getRKBalance(treasury.accountAddress, metadataAddress)
  //   );
};

main();
