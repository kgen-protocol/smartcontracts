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
const APTOS_NETWORK: Network = Network.TESTNET;
const config = new AptosConfig({ network: APTOS_NETWORK });
const aptos = new Aptos(config);

export async function createWallet() {
  const alice = Account.generate();
  const data = {
    publicKey: alice.publicKey.toString(),
    accountAddress: alice.accountAddress.toStringLong(),
    privateKey: alice.privateKey.toString(),
  };
  return data;
}

export async function fundWallet(alice: AccountAddress) {
  await aptos.fundAccount({
    accountAddress: alice,
    amount: 100_000_000,
  });
}

async function createProgrammers() {
  // let deployer = await createWallet();
  // let admin = await createWallet();
  // let treasury1 = await createWallet();
  // let treasury2 = await createWallet();

  // fs.writeFileSync(
  //   "./keys/programmers/deployer.json",
  //   JSON.stringify(deployer)
  // );
  // fs.writeFileSync("./keys/programmers/admin.json", JSON.stringify(admin));
  // fs.writeFileSync(
  //   "./keys/programmers/treasury1.json",
  //   JSON.stringify(treasury1)
  // );
  // fs.writeFileSync(
  //   "./keys/programmers/treasury2.json",
  //   JSON.stringify(treasury2)
  // );

  let depAcc = JSON.parse(
    fs.readFileSync("./keys/programmers/deployer.json", "utf8")
  );
  let adminAcc = JSON.parse(
    fs.readFileSync("./keys/programmers/admin.json", "utf8")
  );
  let t1Acc = JSON.parse(
    fs.readFileSync("./keys/programmers/treasury1.json", "utf8")
  );
  let t2Acc = JSON.parse(
    fs.readFileSync("./keys/programmers/treasury2.json", "utf8")
  );

  await fundWallet(depAcc.accountAddress);
  await fundWallet(adminAcc.accountAddress);
  await fundWallet(t1Acc.accountAddress);
  await fundWallet(t2Acc.accountAddress);

  console.log(
    "🚀 ~ deployer balance:",
    depAcc.accountAddress,
    await aptos.getAccountAPTAmount({ accountAddress: depAcc.accountAddress })
  );
  console.log(
    "🚀 ~ admin balance:",
    adminAcc.accountAddress,
    await aptos.getAccountAPTAmount({ accountAddress: adminAcc.accountAddress })
  );
  console.log(
    "🚀 ~ treasur1 balance:",
    t1Acc.accountAddress,
    await aptos.getAccountAPTAmount({ accountAddress: t1Acc.accountAddress })
  );
  console.log(
    "🚀 ~ treasury2 balance:",
    t2Acc.accountAddress,
    await aptos.getAccountAPTAmount({ accountAddress: t2Acc.accountAddress })
  );
}

// createProgrammers();

async function main() {
  let owner = await createWallet();
  fs.writeFileSync("./keys/owner.json", JSON.stringify(owner));
  let user2 = await createWallet();
  fs.writeFileSync("./keys/user2.json", JSON.stringify(user2));
  let user1 = await createWallet();
  fs.writeFileSync("./keys/user.json", JSON.stringify(user1));

  let ownerAcc = JSON.parse(fs.readFileSync("./keys/owner.json", "utf8"));
  await fundWallet(ownerAcc.accountAddress);
  console.log("🚀 ~ main ~ own.accountAddress:", ownerAcc.accountAddress);

  let user1Acc = JSON.parse(fs.readFileSync("./keys/user.json", "utf8"));
  await fundWallet(user1Acc.accountAddress);
  console.log("🚀 ~ main ~ use.accountAddress:", user1Acc.accountAddress);

  let user2Acc = JSON.parse(fs.readFileSync("./keys/user2.json", "utf8"));
  await fundWallet(user2Acc.accountAddress);
  console.log("🚀 ~ main ~ use2.accountAddress:", user2Acc.accountAddress);
}

// main();
