import {
  Account,
  AccountAddress,
  Aptos,
  AptosConfig,
  Ed25519Account,
  Network,
  NetworkToNetworkName,
} from "@aptos-labs/ts-sdk";
import fs from "fs";

// Setup the client
const APTOS_NETWORK: Network =
  NetworkToNetworkName[process.env.APTOS_NETWORK] || Network.DEVNET;
const config = new AptosConfig({ network: APTOS_NETWORK });
const aptos = new Aptos(config);

async function createWallet() {
  const alice = Account.generate();
  const data = {
    publicKey: alice.publicKey.toString(),
    accountAddress: alice.accountAddress.toStringLong(),
    privateKey: alice.privateKey.toString(),
  };
  return data;
}

async function fundWallet(alice: AccountAddress) {
  await aptos.fundAccount({
    accountAddress: alice,
    amount: 100_000_000,
  });
}

async function main() {
  let owner = await createWallet();
  fs.writeFileSync("./keys/owner.json", JSON.stringify(owner));
  let user1 = await createWallet();
  fs.writeFileSync("./keys/user.json", JSON.stringify(user1));

  let user2 = await createWallet();
  fs.writeFileSync("./keys/user2.json", JSON.stringify(user2));

  let signer = await createWallet();
  fs.writeFileSync("./keys/signer.json", JSON.stringify(signer));

  let ownerAcc = JSON.parse(fs.readFileSync("./keys/owner.json", "utf8"));
  await fundWallet(ownerAcc.accountAddress);
  console.log("🚀 ~ main ~ own.accountAddress:", ownerAcc.accountAddress);

  let user1Acc = JSON.parse(fs.readFileSync("./keys/user.json", "utf8"));
  await fundWallet(user1Acc.accountAddress);
  console.log("🚀 ~ main ~ use.accountAddress:", user1Acc.accountAddress);

  let user2Acc = JSON.parse(fs.readFileSync("./keys/user2.json", "utf8"));
  await fundWallet(user2Acc.accountAddress);
  console.log("🚀 ~ main ~ se2.accountAddress:", user2Acc.accountAddress);

  let signerAcc = JSON.parse(fs.readFileSync("./keys/signer.json", "utf8"));
  await fundWallet(signerAcc.accountAddress);
  console.log("🚀 ~ main ~ se2.accountAddress:", signerAcc.accountAddress);
}

main();
