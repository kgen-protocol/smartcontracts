import {
  Account,
  AccountAddress,
  AnyNumber,
  Aptos,
  AptosConfig,
  Ed25519PrivateKey,
  InputViewFunctionData,
  Network,
  NetworkToNetworkName,
} from "@aptos-labs/ts-sdk";
import fs from "fs";
import { compilePackage, getPackageBytesToPublish } from "./utils";

// Setup the client
const APTOS_NETWORK: Network =
  NetworkToNetworkName[process.env.APTOS_NETWORK] || Network.DEVNET;
const config = new AptosConfig({ network: APTOS_NETWORK });
const aptos = new Aptos(config);

const module_name = "move/counter"; // Path to the package which has the module
const output_file_path = "move/counter/counter.json"; // Path to JSON file
const address_name = "CAddr"; // Address name from move.toml

let owner_kp = JSON.parse(fs.readFileSync("./keys/owner.json", "utf8"));
const privateKeyOwner = new Ed25519PrivateKey(owner_kp.privateKey);
const owner = Account.fromPrivateKey({ privateKey: privateKeyOwner });

async function compileModule(
  moduleName: string,
  outputFile: string,
  addressName: string,
  address: AccountAddress
) {
  compilePackage(moduleName, outputFile, [
    { name: addressName, address: address },
  ]);
}

async function deployModule(owner: Account, metadataBytes: any, byteCode: any) {
  try {
    const transaction = await aptos.publishPackageTransaction({
      account: owner.accountAddress,
      metadataBytes,
      moduleBytecode: byteCode,
    });
    const response = await aptos.signAndSubmitTransaction({
      signer: owner,
      transaction,
    });

    await aptos.waitForTransaction({
      transactionHash: response.hash,
    });
    return response.hash;
  } catch (error) {
    console.log("🚀 ~ deployModule ~ error:", error);
  }
}

/** Admin mint the newly created coin to the specified receiver address */
async function increaseCounter(admin: Account): Promise<string> {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::demo_counter::increment`,
      functionArguments: [owner.accountAddress],
    },
  });

  const senderAuthenticator = aptos.transaction.sign({
    signer: admin,
    transaction,
  });
  const pendingTxn = await aptos.transaction.submit.simple({
    transaction,
    senderAuthenticator,
  });

  await aptos.waitForTransaction({
    transactionHash: pendingTxn.hash,
  });
  return pendingTxn.hash;
}
/** Admin mint the newly created coin to the specified receiver address */
async function publishCounter(admin: Account, i: AnyNumber): Promise<string> {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::demo_counter::publish`,
      functionArguments: [i],
    },
  });

  const senderAuthenticator = aptos.transaction.sign({
    signer: admin,
    transaction,
  });
  const pendingTxn = await aptos.transaction.submit.simple({
    transaction,
    senderAuthenticator,
  });

  await aptos.waitForTransaction({
    transactionHash: pendingTxn.hash,
  });
  return pendingTxn.hash;
}

// get counter
async function getCounter(admin: AccountAddress): Promise<string> {
  const payload: InputViewFunctionData = {
    function: `${owner.accountAddress}::demo_counter::get_count`,
    functionArguments: [admin],
  };
  const res = (await aptos.view({ payload }))[0];
  console.log("🚀 ~ getCounter ~ res:", res);
  return res.toString();
}

async function main() {
  let user_kp = JSON.parse(fs.readFileSync("./keys/user.json", "utf8"));
  const privateKeyUser1 = new Ed25519PrivateKey(user_kp.privateKey);
  const user1 = Account.fromPrivateKey({ privateKey: privateKeyUser1 });

  // console.log("\n=== Compiling KCash package locally ===");
  // await compileModule(
  //   module_name,
  //   output_file_path,
  //   address_name,
  //   owner.accountAddress
  // );

  // const { metadataBytes, byteCode } =
  //   getPackageBytesToPublish(output_file_path);

  // console.log("===Publishing KCash package===");

  // let txHash = await deployModule(owner, metadataBytes, byteCode);

  // console.log(`Transaction hash2: ${txHash}`);

  // let publishTx = await publishCounter(owner, 1);
  // console.log("🚀 ~ main ~ publishTx:", publishTx);

  let countTx = await getCounter(owner.accountAddress);
  console.log("🚀 ~ main ~ countTx:", countTx);

  let inc = await increaseCounter(user1);
  console.log("🚀 ~ main ~ inc:", inc);

  let new_countTx = await getCounter(owner.accountAddress);
  console.log("🚀 ~ main ~ new_countTx:", new_countTx);
}

main();
