import { execSync } from "child_process";
import path from "path";
import fs from "fs";
import {
  Account,
  AccountAddress,
  Aptos,
  AptosConfig,
  Ed25519PrivateKey,
  Network,
  TransactionPayloadMultiSig,
} from "@aptos-labs/ts-sdk";

/* eslint-disable no-console */
/* eslint-disable max-len */

/**
 * A convenience function to compile a package locally with the CLI
 * @param packageDir
 * @param outputFile
 * @param namedAddresses
 */
export function compilePackage(
  packageDir: string,
  outputFile: string,
  namedAddresses: Array<{ name: string; address: AccountAddress }>
) {
  console.log(
    "In order to run compilation, you must have the `aptos` CLI installed."
  );
  try {
    execSync("aptos --version");
  } catch (e) {
    console.log(
      "aptos is not installed. Please install it from the instructions on aptos.dev"
    );
  }

  const addressArg = namedAddresses
    .map(({ name, address }) => `${name}=${address}`)
    .join(" ");

  // Assume-yes automatically overwrites the previous compiled version, only do this if you are sure you want to overwrite the previous version.
  const compileCommand = `aptos move build-publish-payload --json-output-file ${outputFile} --package-dir ${packageDir} --named-addresses ${addressArg} --assume-yes --skip-fetch-latest-git-deps`;
  console.log(
    "Running the compilation locally, in a real situation you may want to compile this ahead of time."
  );
  console.log(compileCommand);
  execSync(compileCommand);
}

/**
 * A convenience function to get the compiled package metadataBytes and byteCode
 * @param packageDir
 * @param outputFile
 * @param namedAddresses
 */
export function getPackageBytesToPublish(filePath: string) {
  // current working directory - the root folder of this repo
  const cwd = process.cwd();
  // target directory - current working directory + filePath (filePath json file is generated with the prevoius, compilePackage, cli command)
  const modulePath = path.join(cwd, filePath);

  const jsonData = JSON.parse(fs.readFileSync(modulePath, "utf8"));

  const metadataBytes = jsonData.args[0].value;
  const byteCode = jsonData.args[1].value;

  return { metadataBytes, byteCode };
}

// CONSTANTS
// Setup the client
export const APTOS_NETWORK: Network = Network.TESTNET;
export const config = new AptosConfig({ network: APTOS_NETWORK });
export const aptos = new Aptos(config);

export const module_file_name = "rKGEN"; // Path to the package which has the module
export const module_name = "rKGEN";
export const output_file_path = "rKGEN/rKGen.json"; // Path to JSON file
export const address_name = "rKGenAdmin"; // Address name from move.toml
export const is_deployed = true; // If module is not already deployed, make this

export const multisig = AccountAddress.fromStringStrict(
  "0x2bc8963bd2eaca881ab5cffa0c3db3e9fe7ad8062260900fac5d0829ef1b7b9d"
);
export let transactionPayload: TransactionPayloadMultiSig;

let treasury_kp = JSON.parse(
  fs.readFileSync("./keys/programmers/treasury1.json", "utf8")
);
const privateKeyTreasury = new Ed25519PrivateKey(treasury_kp.privateKey);
export const treasury = Account.fromPrivateKey({
  privateKey: privateKeyTreasury,
});

let sender_kp = JSON.parse(
  fs.readFileSync("./keys/programmers/treasury2.json", "utf8")
);
const privateKeySender = new Ed25519PrivateKey(sender_kp.privateKey);
export const sender = Account.fromPrivateKey({ privateKey: privateKeySender });

let receiver_kp = JSON.parse(
  fs.readFileSync("./keys/programmers/treasury1.json", "utf8")
);
const privateKeyReceiver = new Ed25519PrivateKey(receiver_kp.privateKey);
export const receiver = Account.fromPrivateKey({
  privateKey: privateKeyReceiver,
});

let admin_kp = JSON.parse(
  fs.readFileSync("./keys/programmers/admin.json", "utf8")
);
const privateKeyAdmin = new Ed25519PrivateKey(admin_kp.privateKey);
export const admin = Account.fromPrivateKey({ privateKey: privateKeyAdmin });

let deployer_kp = JSON.parse(
  fs.readFileSync("./keys/programmers/deployer.json", "utf8")
);
const privateKeyDeployer = new Ed25519PrivateKey(deployer_kp.privateKey);
export const deployer = Account.fromPrivateKey({
  privateKey: privateKeyDeployer,
});

//Multisig Address owner
const mpath1 = "./keys/m1.json";
let m1Ac_kp = JSON.parse(fs.readFileSync(mpath1, "utf8"));
export const m1Ac = Account.fromPrivateKey({
  privateKey: new Ed25519PrivateKey(m1Ac_kp.privateKey),
});

const mpath2 = "./keys/m2.json";
let m2Ac_kp = JSON.parse(fs.readFileSync(mpath2, "utf8"));
export const m2Ac = Account.fromPrivateKey({
  privateKey: new Ed25519PrivateKey(m2Ac_kp.privateKey),
});
const mpath3 = "./keys/m3.json";
let m3Ac_kp = JSON.parse(fs.readFileSync(mpath3, "utf8"));
export const m3Ac = Account.fromPrivateKey({
  privateKey: new Ed25519PrivateKey(m3Ac_kp.privateKey),
});

const mpath4 = "./keys/m4.json";
let m4Ac_kp = JSON.parse(fs.readFileSync(mpath4, "utf8"));
export const m4Ac = Account.fromPrivateKey({
  privateKey: new Ed25519PrivateKey(m4Ac_kp.privateKey),
});
const mpath5 = "./keys/m5.json";
let m5Ac_kp = JSON.parse(fs.readFileSync(mpath5, "utf8"));
export const m5Ac = Account.fromPrivateKey({
  privateKey: new Ed25519PrivateKey(m5Ac_kp.privateKey),
});
