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

const module_file_name = "move/facoinKcash"; // Path to the package which has the module
const module_name = "fa_coin_kcash";
const output_file_path = "move/facoinKcash/facoin.json"; // Path to JSON file
const address_name = "FACoinAddr"; // Address name from move.toml

let owner_kp = JSON.parse(fs.readFileSync("./keys/owner.json", "utf8"));
const privateKeyOwner = new Ed25519PrivateKey(owner_kp.privateKey);
const owner = Account.fromPrivateKey({ privateKey: privateKeyOwner });

let user_kp = JSON.parse(fs.readFileSync("./keys/owner.json", "utf8"));
const privateKeyUser = new Ed25519PrivateKey(user_kp.privateKey);
const user = Account.fromPrivateKey({ privateKey: privateKeyUser });

async function compileAndDeployModule(
  moduleName: string,
  outputFile: string,
  addressName: string,
  address: AccountAddress
) {
  compilePackage(moduleName, outputFile, [
    { name: addressName, address: address },
  ]);

  try {
    const { metadataBytes, byteCode } =
      getPackageBytesToPublish(output_file_path);
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
async function mintCoin(
  admin: Account,
  receiver: AccountAddress,
  amount: AnyNumber,
  reward1: AnyNumber,
  reward2: AnyNumber,
  reward3: AnyNumber
): Promise<string> {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${admin.accountAddress}::${module_name}::mint`,
      functionArguments: [receiver, amount, reward1, reward2, reward3],
    },
  });

  const senderAuthenticator = await aptos.transaction.sign({
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

const getFaBalance = async (
  owner: AccountAddress,
  assetType: string
): Promise<number> => {
  const data = await aptos.getCurrentFungibleAssetBalances({
    options: {
      where: {
        owner_address: { _eq: owner.toStringLong() },
        asset_type: { _eq: assetType },
      },
    },
  });

  return data[0]?.amount ?? 0;
};

/** Return the address of the managed fungible asset that's created when this module is deployed */
async function getMetadata(admin: Account): Promise<string> {
  const payload: InputViewFunctionData = {
    function: `${admin.accountAddress}::${module_name}::get_metadata`,
    functionArguments: [],
  };
  const res = (await aptos.view<[{ inner: string }]>({ payload }))[0];
  return res.inner;
}

async function getBucketValues(admin: Account) {
  try {
    const payload: InputViewFunctionData = {
      function: `${admin.accountAddress}::${module_name}::length`,
      functionArguments: [admin.accountAddress.toString()],
    };
    const res = (await aptos.view<[{data: []}]>({ payload }))[0];
    console.log("🚀 ~ getBucketValues ~ res:", res.data);
    return res.toString();
  } catch (error) {
    console.log("🚀 ~ error:", error);
  }
}

async function main() {
  console.log("\n=== Compiling KCash package locally ===");
  let tx = await compileAndDeployModule(
    module_file_name,
    output_file_path,
    address_name,
    owner.accountAddress
  );
  console.log("🚀 ~ main ~ tx:", tx);

  const metadataAddress = await getMetadata(owner);
  console.log("metadata address:", metadataAddress);

  let user_balance = await getFaBalance(owner.accountAddress, metadataAddress);
  console.log("🚀 ~ main ~ user_balance:", user_balance);

  let mintTx = await mintCoin(
    owner,
    user.accountAddress,
    100000000000000000n,
    50000000000000000n,
    30000000000000000n,
    20000000000000000n
  );
  console.log("🚀 ~ main ~ mintTx:", mintTx);

  let user_balance2 = await getFaBalance(user.accountAddress, metadataAddress);
  console.log("🚀 ~ main ~ user_balance:", user_balance2);
  
  let bucketValues = await getBucketValues(owner);
  console.log("🚀 ~ main ~ bucketValues:", bucketValues);
}

main();
