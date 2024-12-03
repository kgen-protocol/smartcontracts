/* eslint-disable no-console */

/**
 * This examples demonstrate the new multisig account module (MultiSig V2) and transaction execution flow
 * where in that module, there is no offchain signature aggregation step.
 * Each owner sends its transactions to the chain on its own, and so the "voting" process occurs onchain.
 * {@link https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-framework/sources/multisig_account.move}
 *
 * This example demonstrates different interaction with the module
 * - create a multi sig account
 * - create a multi sig transaction
 * - approve a multi sig transaction
 * - reject a multi sig transaction
 * - execute a multi sig transaction
 * - fetch multi sig account info
 *
 */
import {
  Account,
  Aptos,
  AptosConfig,
  Network,
  MoveString,
  AccountAddress,
  InputViewFunctionData,
  Ed25519PrivateKey,
} from "@aptos-labs/ts-sdk";
import fs from "fs";
import { createWallet, fundWallet } from "./createNewkeys";

// Default to devnet, but allow for overriding
const APTOS_NETWORK: Network = Network.TESTNET;

// Setup the client
const config = new AptosConfig({ network: APTOS_NETWORK });
const aptos = new Aptos(config);

//Wallet paths
const mpath1 = "./keys/m1.json";
const mpath2 = "./keys/m2.json";
const mpath3 = "./keys/m3.json";
const mpath4 = "./keys/m4.json";
const mpath5 = "./keys/m5.json";

async function readFiles() {
  let m1Ac_kp = JSON.parse(fs.readFileSync(mpath1, "utf8"));
  let m2Ac_kp = JSON.parse(fs.readFileSync(mpath2, "utf8"));
  let m3Ac_kp = JSON.parse(fs.readFileSync(mpath3, "utf8"));
  let m4Ac_kp = JSON.parse(fs.readFileSync(mpath4, "utf8"));
  let m5Ac_kp = JSON.parse(fs.readFileSync(mpath5, "utf8"));
  const m1Ac = Account.fromPrivateKey({
    privateKey: new Ed25519PrivateKey(m1Ac_kp.privateKey),
  });

  const m2Ac = Account.fromPrivateKey({
    privateKey: new Ed25519PrivateKey(m2Ac_kp.privateKey),
  });
  const m3Ac = Account.fromPrivateKey({
    privateKey: new Ed25519PrivateKey(m3Ac_kp.privateKey),
  });
  const m4Ac = Account.fromPrivateKey({
    privateKey: new Ed25519PrivateKey(m4Ac_kp.privateKey),
  });
  const m5Ac = Account.fromPrivateKey({
    privateKey: new Ed25519PrivateKey(m5Ac_kp.privateKey),
  });

  return [m1Ac, m2Ac, m3Ac, m4Ac, m5Ac];
}

// Create and fund balance to addresses involved in multisig
const creatAndFund = async () => {
  fs.writeFileSync(mpath1, JSON.stringify(await createWallet()));
  fs.writeFileSync(mpath2, JSON.stringify(await createWallet()));
  fs.writeFileSync(mpath3, JSON.stringify(await createWallet()));
  fs.writeFileSync(mpath4, JSON.stringify(await createWallet()));
  fs.writeFileSync(mpath5, JSON.stringify(await createWallet()));

  let [m1Ac, m2Ac, m3Ac, m4Ac, m5Ac] = await readFiles();

  await fundWallet(m1Ac.accountAddress);
  // 0x7c158ff408eab7e61fce74c8e8a01a4c7f28a3e243633323f78bd7fe940ab196
  console.log(
    "🚀 ~ m1 balance:",
    m1Ac.accountAddress,
    await aptos.getAccountAPTAmount({ accountAddress: m1Ac.accountAddress })
  );
  await fundWallet(m2Ac.accountAddress);
  console.log(
    "🚀 ~ m2 balance:",
    m2Ac.accountAddress,
    await aptos.getAccountAPTAmount({ accountAddress: m2Ac.accountAddress })
  );
  await fundWallet(m3Ac.accountAddress);
  console.log(
    "🚀 ~ m3 balance:",
    m3Ac.accountAddress,
    await aptos.getAccountAPTAmount({ accountAddress: m3Ac.accountAddress })
  );
  await fundWallet(m4Ac.accountAddress);
  console.log(
    "🚀 ~ m4 balance:",
    m4Ac.accountAddress,
    await aptos.getAccountAPTAmount({ accountAddress: m4Ac.accountAddress })
  );
  await fundWallet(m5Ac.accountAddress);
  console.log(
    "🚀 ~ m5 balance:",
    m5Ac.accountAddress,
    await aptos.getAccountAPTAmount({ accountAddress: m5Ac.accountAddress })
  );
};

// HELPER FUNCTIONS //

const getNumberOfOwners = async (multisigAddress: string): Promise<void> => {
  const multisigAccountResource = await aptos.getAccountResource<{
    owners: Array<string>;
  }>({
    accountAddress: multisigAddress,
    resourceType: "0x1::multisig_account::MultisigAccount",
  });
  console.log("Number of Owners:", multisigAccountResource.owners.length);
};

const getSignatureThreshold = async (
  multisigAddress: string
): Promise<void> => {
  const multisigAccountResource = await aptos.getAccountResource<{
    num_signatures_required: number;
  }>({
    accountAddress: multisigAddress,
    resourceType: "0x1::multisig_account::MultisigAccount",
  });
  console.log(
    "Signature Threshold:",
    multisigAccountResource.num_signatures_required
  );
};

const settingUpMultiSigAccount = async () => {
  console.log("Setting up a 3-of-5 multisig account...");

  // Step 1: Setup a 3-of-5 multisig account
  // ===========================================================================================
  // Get the next multisig account address. This will be the same as the account address of the multisig account we'll
  // be creating.

  let [m1Ac, m2Ac, m3Ac, m4Ac, m5Ac] = await readFiles();

  const payload: InputViewFunctionData = {
    function: "0x1::multisig_account::get_next_multisig_account_address",
    functionArguments: [m1Ac.accountAddress.toString()],
  };
  let [multisigAddress] = await aptos.view<[string]>({ payload });
  console.log(
    "🚀 ~ settingUpMultiSigAccount ~ multisigAddress:",
    multisigAddress
  );

  // Create the multisig account with 3 owners and a signature threshold of 2.
  const createMultisig = await aptos.transaction.build.simple({
    sender: m1Ac.accountAddress,
    data: {
      function: "0x1::multisig_account::create_with_owners",
      functionArguments: [
        [
          m2Ac.accountAddress,
          m3Ac.accountAddress,
          m4Ac.accountAddress,
          m5Ac.accountAddress,
        ],
        3,
        ["Example"],
        [new MoveString("SDK").bcsToBytes()],
      ],
    },
  });
  console.log(
    "🚀 ~ settingUpMultiSigAccount ~ createMultisig:",
    createMultisig
  );
  const owner1Authenticator = aptos.transaction.sign({
    signer: m1Ac,
    transaction: createMultisig,
  });
  console.log(
    "🚀 ~ settingUpMultiSigAccount ~ owner1Authenticator:",
    owner1Authenticator
  );
  const res = await aptos.transaction.submit.simple({
    senderAuthenticator: owner1Authenticator,
    transaction: createMultisig,
  });
  await aptos.waitForTransaction({ transactionHash: res.hash });

  console.log("Multisig Account Address:", multisigAddress);

  // should be 2
  await getSignatureThreshold(multisigAddress);

  // should be 3
  await getNumberOfOwners(multisigAddress);

  await fundWallet(AccountAddress.fromString(multisigAddress));
  console.log(
    "🚀 ~ m1 balance:",
    await aptos.getAccountAPTAmount({
      accountAddress: AccountAddress.fromString(multisigAddress),
    })
  );
  return AccountAddress.fromString(multisigAddress);
};

export async function createMultisig3o5() {
  await creatAndFund();
  let multisigAddress = await settingUpMultiSigAccount();
  return multisigAddress;
}
createMultisig3o5()
