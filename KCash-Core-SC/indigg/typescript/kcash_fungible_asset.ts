/* eslint-disable no-console */
/* eslint-disable max-len */

import {
  Serializable,
  Serializer,
  Account,
  AccountAddress,
  AnyNumber,
  Aptos,
  AptosConfig,
  InputViewFunctionData,
  Network,
  NetworkToNetworkName,
  Ed25519PrivateKey,
  Ed25519PublicKey,
  Ed25519Signature,
  Ed25519Account,
  // Uint64,
} from "@aptos-labs/ts-sdk";

import { compilePackage, getPackageBytesToPublish } from "./utils";
import fs from "fs";
import sha256 from "fast-sha256";

// Setup the client
const APTOS_NETWORK: Network = NetworkToNetworkName[Network.DEVNET];
console.log("APTOS_NETWORK3000", APTOS_NETWORK);

const config = new AptosConfig({ network: APTOS_NETWORK });
const aptos = new Aptos(config);

const module_path = "move/kcash"; // Path to the package which has the module
const output_file_path = "move/kcash/kcash.json"; // Path to JSON file
const address_name = "KCashAdmin"; // Address name from move.toml
const module_name = "kcash";
const decimal_kcash = 1;
console.log("🚀 ~ decimal_kcash:", decimal_kcash);

export class Uint64 extends Serializable {
  constructor(public value: bigint) {
    super();
  }

  serialize(serializer: Serializer): void {
    serializer.serializeU64(this.value);
  }
}

// Define the MoveStruct class that implements the Serializable interface
export class MessageMoveStruct extends Serializable {
  constructor(
    public from: AccountAddress, // where AccountAddress extends Serializable
    public to: AccountAddress, // where AccountAddress extends Serializable
    public method: string,
    public nonce: Uint64,
    public deductionFromSender: Uint64[],
    public additionToRecipient: Uint64[],
  ) {
    super();
  }

  serialize(serializer: Serializer): void {
    serializer.serialize(this.from); // Composable serialization of another Serializable object
    serializer.serialize(this.to);
    serializer.serializeStr(this.method);
    serializer.serialize(this.nonce);

    serializer.serializeU32AsUleb128(deductionFromSender.length);
    for (const uint64 of this.deductionFromSender) {
      serializer.serialize(uint64);
    }

    serializer.serializeU32AsUleb128(additionToRecipient.length);
    for (const uint64 of this.additionToRecipient) {
      serializer.serialize(uint64);
    }

  }
}

// For user to transfer with sign
class UserMessageStructBulk extends Serializable {
  constructor(
    public from: AccountAddress,
    public to: AccountAddress[],
    public amount: Uint64[],
    public method: string,
    public nonce: Uint64
  ) {
    super();
  }

  serialize(serializer: Serializer): void {
    serializer.serialize(this.from);
    serializer.serializeStr(this.method);
    serializer.serialize(this.nonce);
    // serializer.serializeU32AsUleb128(this.to.length);
    serializer.serializeU32AsUleb128(this.to.length);
    for (let i = 0; i < this.to.length; i++) {
      serializer.serialize(this.to[i]);
    }
    serializer.serializeU32AsUleb128(this.amount.length);
    for (const amt of this.amount) {
      serializer.serialize(amt);
    }
  }
}

export async function createStructForMsgBulk(
  admin: AccountAddress,
  user: AccountAddress[],
  amount: Uint64[],
  method: String,
  nonce: Uint64
) {
  const userStructForSign = new UserMessageStructBulk(
    admin,
    user,
    amount,
    method.toString(),
    nonce
  );
  return userStructForSign;
}
class UserMessageStruct extends Serializable {
  constructor(
    public from: AccountAddress,
    public to: AccountAddress,
    public amount: Uint64,
    public method: string,
    public nonce: Uint64
  ) {
    super();
  }

  serialize(serializer: Serializer): void {
    serializer.serialize(this.from);
    serializer.serialize(this.to);
    serializer.serializeStr(this.method);
    serializer.serialize(this.amount);
    serializer.serialize(this.nonce);
  }
}

export async function createStructForMsg(
  admin: AccountAddress,
  user: AccountAddress,
  amount: Uint64,
  method: String,
  nonce: Uint64
) {
  const userStructForSign = new UserMessageStruct(
    admin,
    user,
    amount,
    method.toString(),
    nonce
  );
  return userStructForSign;
}

export const deductionFromSender = [
  new Uint64(BigInt(10)),
  new Uint64(BigInt(20)),
  new Uint64(BigInt(30)),
];

export const additionToRecipient = [
  new Uint64(BigInt(10)),
  new Uint64(BigInt(20)),
  new Uint64(BigInt(30)),
];

export async function createStructForAdminTransferSig(
  admin: AccountAddress,
  to: AccountAddress,
  deductionFromSender: Uint64[],
  additionToRecipient: Uint64[],
  method: String,
  nonce: Uint64
) {
  const adminStructForSign = new MessageMoveStruct(
    admin,
    to,
    method.toString(),
    nonce,
    deductionFromSender,
    additionToRecipient,
  );
  return adminStructForSign;
}

export class MessageMoveStructBulk extends Serializable {
  constructor(
    public from: AccountAddress, // where AccountAddress extends Serializable
    public to: AccountAddress[],
    public deductnFromSender1: Uint64[],
    public deductnFromSender2: Uint64[],
    public deductnFromSender3: Uint64[],
    public additnToRecipient1: Uint64[],
    public additnToRecipient2: Uint64[],
    public additnToRecipient3: Uint64[],
    public method: string,
    public nonce: Uint64
  ) {
    super();
  }

  serialize(serializer: Serializer): void {
    serializer.serialize(this.from); // Composable serialization of another Serializable object
    serializer.serializeU32AsUleb128(this.to.length);
    for (const address of this.to) {
      serializer.serialize(address);
    }
    serializer.serializeStr(this.method);
    serializer.serialize(this.nonce);
    serializer.serializeU32AsUleb128(deductnFromSender1.length);
    for (const uint64 of this.deductnFromSender1) {
      serializer.serialize(uint64);
    }
    serializer.serializeU32AsUleb128(deductnFromSender2.length);
    for (const uint64 of this.deductnFromSender2) {
      serializer.serialize(uint64);
    }
    serializer.serializeU32AsUleb128(deductnFromSender3.length);
    for (const uint64 of this.deductnFromSender3) {
      serializer.serialize(uint64);
    }
    serializer.serializeU32AsUleb128(additnToRecipient1.length);
    for (const uint64 of this.additnToRecipient1) {
      serializer.serialize(uint64);
    }
    serializer.serializeU32AsUleb128(additnToRecipient2.length);
    for (const uint64 of this.additnToRecipient2) {
      serializer.serialize(uint64);
    }
    serializer.serializeU32AsUleb128(additnToRecipient3.length);
    for (const uint64 of this.additnToRecipient3) {
      serializer.serialize(uint64);
    }
  }
}

export const deductnFromSender1 = [
  new Uint64(BigInt(10)),
  new Uint64(BigInt(20)),
  new Uint64(BigInt(30)),
];
export const deductnFromSender2 = [
  new Uint64(BigInt(5)),
  new Uint64(BigInt(15)),
  new Uint64(BigInt(25)),
];
export const deductnFromSender3 = [
  new Uint64(BigInt(100)),
  new Uint64(BigInt(200)),
  new Uint64(BigInt(300)),
];
export const additnToRecipient1 = [
  new Uint64(BigInt(10)),
  new Uint64(BigInt(20)),
  new Uint64(BigInt(30)),
];
export const additnToRecipient2 = [
  new Uint64(BigInt(5)),
  new Uint64(BigInt(15)),
  new Uint64(BigInt(25)),
];
export const additnToRecipient3 = [
  new Uint64(BigInt(100)),
  new Uint64(BigInt(200)),
  new Uint64(BigInt(300)),
];

export async function createStructForAdminTransferSigBulk(
  admin: AccountAddress,
  to: AccountAddress[],
  deductnFromSender1: Uint64[],
  deductnFromSender2: Uint64[],
  deductnFromSender3: Uint64[],
  additnToRecipient1: Uint64[],
  additnToRecipient2: Uint64[],
  additnToRecipient3: Uint64[],
  method: String,
  nonce: Uint64
) {
  const adminStructForSignBulk = new MessageMoveStructBulk(
    admin,
    to,
    deductnFromSender1,
    deductnFromSender2,
    deductnFromSender3,
    additnToRecipient1,
    additnToRecipient2,
    additnToRecipient3,
    method.toString(),
    nonce
  );
  return adminStructForSignBulk;
}

// const owner_amount_to_mint = 1000*decimal_kcash;
// const amount_to_mint = 10000000000;
// const amount_to_withdraw = 65000000000;

let owner_kp = JSON.parse(fs.readFileSync("./keys/owner.json", "utf8"));
const privateKeyOwner = new Ed25519PrivateKey(owner_kp.privateKey);
const publicKeyOwner = new Ed25519PublicKey(owner_kp.publicKey);
const owner = Account.fromPrivateKey({ privateKey: privateKeyOwner });

let user_kp = JSON.parse(fs.readFileSync("./keys/user.json", "utf8"));
const privateKeyuser1 = new Ed25519PrivateKey(user_kp.privateKey);
const user1 = Account.fromPrivateKey({ privateKey: privateKeyuser1 });

let user2_kp = JSON.parse(fs.readFileSync("./keys/user2.json", "utf8"));
const privateKeyuser2 = new Ed25519PrivateKey(user2_kp.privateKey);
const user2 = Account.fromPrivateKey({ privateKey: privateKeyuser2 });

let signer_kp = JSON.parse(fs.readFileSync("./keys/signer.json", "utf8"));
const signer_pk = new Ed25519PrivateKey(signer_kp.privateKey);
const signer_public = new Ed25519PublicKey(signer_kp.publicKey);
const signer = Account.fromPrivateKey({ privateKey: signer_pk });

// Message & Hash
const message = new Uint8Array(Buffer.from("KCash"));
const messageHash = sha256(message);
//const messageHash1 = sha256(msgBytes);

// Signature Method : Sign a message through PrivateKey
export async function signMessage(
  privateKey: Ed25519PrivateKey,
  messageHash: Uint8Array
): Promise<Ed25519Signature> {
  const signature = await privateKey.sign(messageHash);
  return signature;
}

// TO COMPILE AND DEPLOY THE SMART CONTRACT
export async function compileAndDeploy() {
  console.log("*** Compiling KCash package ***");
  compilePackage(module_path, output_file_path, [
    { name: address_name, address: owner.accountAddress },
  ]);

  const { metadataBytes, byteCode } =
    getPackageBytesToPublish(output_file_path);

  console.log("\n *** Publishing KCash package ***");
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
  console.log(`Transaction hash: ${response.hash}`);
  return response.hash;
}

/*   ----- Functions for view data from modules ----- */

// To get Nonce of the owner
export async function getNonce(admin: Account) {
  const payload: InputViewFunctionData = {
    function: `${owner.accountAddress}::${module_name}::get_nonce`,
    functionArguments: [admin.accountAddress],
  };
  const res = (await aptos.view<[AnyNumber]>({ payload }))[0];
  return res;
}
// To get the metadata address
export async function getMetadata(admin: Account) {
  // console.log(`Request for metadata for admin account ${admin} received.`);

  const payload: InputViewFunctionData = {
    function: `${owner.accountAddress}::${module_name}::get_metadata`,
    functionArguments: [],
  };
  const res = (await aptos.view<[{ inner: Account }]>({ payload }))[0];
  console.log("🚀 ~ getMetadata ~ res:", res);
  return res.inner;
}
// To get the kcash balance
export const getFaBalance = async (
  owner: Account,
  assetType: string
): Promise<number> => {
  // console.log(`Request for balance of asset type ${owner} for owner ${assetType} received.`);

  try {
    const data = await aptos.getCurrentFungibleAssetBalances({
      options: {
        where: {
          owner_address: { _eq: owner.accountAddress.toStringLong() },
          asset_type: { _eq: assetType },
        },
      },
    });

    // console.log(`Successfully retrieved balance data:`, data);
    return data[0]?.amount ?? 0;
  } catch (error) {
    // console.log(`Error while retrieving balance data:`, error);
    return 0;
  }
};
/** Return the address of the managed fungible asset that's created when this module is deployed */
export const getIs_freez = async (
  owner: Account,
  assetType: string
): Promise<boolean> => {
  // console.log(`Request for balance of asset type ${owner} for owner ${assetType} received.`);

  try {
    const data = await aptos.getCurrentFungibleAssetBalances({
      options: {
        where: {
          owner_address: { _eq: owner.accountAddress.toStringLong() },
          asset_type: { _eq: assetType },
        },
      },
    });

    console.log("data ---", data);
    // console.log(`Successfully retrieved balance data:`, data);

    return data[0]?.is_frozen ?? false;
  } catch (error) {
    // console.log(`Error while retrieving balance data:`, error);
    return false;
  }
};
// To get the list of the list of addresses with minter role
export async function getAdminTransferList() {
  // console.log(`Request for metadata for admin account ${admin} received.`);

  const payload: InputViewFunctionData = {
    function: `${owner.accountAddress}::${module_name}::get_admin_transfer`,
    functionArguments: [],
  };
  const res = await aptos.view({ payload });
  console.log("🚀 ~ getAdminTransfer ~ res:", res);

  return res.toString();
}
// To get the list of the list of addresses with minter role
export async function getSignersList() {
  const payload: InputViewFunctionData = {
    function: `${owner.accountAddress}::${module_name}::get_signers`,
    functionArguments: [],
  };
  const res = await aptos.view({ payload });
  console.log("🚀 ~ getSignerList ~ res:", res);

  return res.toString();
}
// To get the list of the list of addresses with minter role
export async function getMinterList() {
  // console.log(`Request for metadata for admin account ${admin} received.`);

  const payload: InputViewFunctionData = {
    function: `${owner.accountAddress}::${module_name}::get_minter`,
    functionArguments: [],
  };
  const res = await aptos.view({ payload });
  console.log("🚀 ~ getMinterList ~ res:", res);

  return res.toString();
}
// Check if user has bucket store or not
export async function hasBucket(admin: AccountAddress) {
  const payload: InputViewFunctionData = {
    function: `${owner.accountAddress}::${module_name}::has_bucket_store`, //
    functionArguments: [admin],
  };
  const res = (await aptos.view({ payload }))[0];
  console.log("🚀 ~ hasBucket ~ res:", res);
  return res;
}
// To get the bucket store of the user
export async function getBucketStore(admin: Account) {
  const payload: InputViewFunctionData = {
    function: `${owner.accountAddress}::${module_name}::get_bucket_store`,
    functionArguments: [admin.accountAddress],
  };
  const res = await aptos.view({ payload });

  return res.map((num) => parseInt(num.toString()) / decimal_kcash);
}

/* ENTRY LEVEL FUNCTIONS */
/* Only admin can invoke these functions */
// Add minter role to an account
export async function addMinterRole(admin: Account, minter: AccountAddress) {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::add_minter`,
      functionArguments: [minter],
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

  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });

  return pendingTxn.hash;
}
// Remove minter role to an account
export async function removeMinterRole(admin: Account, minter: AccountAddress) {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::remove_minter_role`,
      functionArguments: [minter],
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

  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });

  return pendingTxn.hash;
}
// Add admin transfer role to an account
export async function addSigner(admin: Account, admin_transfer: Uint8Array) {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::add_signer_pkey`,
      functionArguments: [admin_transfer],
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

  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });

  return pendingTxn.hash;
}
// Add admin transfer role to an account
export async function removeSigner(admin: Account, admin_transfer: Uint8Array) {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::remove_signer_role`,
      functionArguments: [admin_transfer],
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

  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });

  return pendingTxn.hash;
}
// Add admin transfer role to an account
export async function addAdminTransferRole(
  admin: Account,
  admin_transfer: AccountAddress
) {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::add_admin_transfer`,
      functionArguments: [admin_transfer],
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

  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });

  return pendingTxn.hash;
}
// Add admin transfer role to an account
export async function removeAdminTransferRole(
  admin: Account,
  admin_transfer: AccountAddress
) {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::remove_admin_transfer_role`,
      functionArguments: [admin_transfer],
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

  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });

  return pendingTxn.hash;
}
/** Admin mint the newly created coin to the specified receiver address */
export async function mintCoin(
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
      function: `${owner.accountAddress}::${module_name}::mint`,
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

  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });

  return pendingTxn.hash;
}
/** Admin mint the newly created coin to the bulk of the specified receiver address */
export async function bulkMintCoin(
  admin: Account,
  receiver: AccountAddress[],
  amount: AnyNumber[],
  reward1: AnyNumber[],
  reward2: AnyNumber[],
  reward3: AnyNumber[]
): Promise<string> {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::bulk_mint`,
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
  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
  return pendingTxn.hash;
}
// Admin can transfer to any account's any reward filed
export async function adminTransfer(
  admin: Account,
  to: AccountAddress,
  deductionFromSender: AnyNumber[],
  additionToRecipient: AnyNumber[]
) {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::admin_transfer`,
      functionArguments: [to, deductionFromSender, additionToRecipient],
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
  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });

  return pendingTxn.hash;
}
// Admin can transfer to any account's multiple user's reward field
export async function adminTransferBulk(
  admin: Account,
  to: AccountAddress[],
  deductionFromSender: AnyNumber[][],
  additionToRecipient: AnyNumber[][]
) {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::admin_transfer_bulk`,
      functionArguments: [to, deductionFromSender, additionToRecipient],
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
  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });

  return pendingTxn.hash;
}
// Transfer Methods : Admin transfer from reward3 to reward one of a user.
export async function transferReward3ToReward1ByAdminOnly(
  admin: Account,
  user: AccountAddress,
  amount: AnyNumber
) {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::admin_transfer_reward3_to_user_bucket1`,
      functionArguments: [user, amount],
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
  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
  return pendingTxn.hash;
}
// Transfer Methods : Admin transfer from reward3 to reward one of multiple users.
export async function transferReward3ToReward1ByAdminOnlyInBulk(
  admin: Account,
  user: AccountAddress[],
  amount: AnyNumber[]
) {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::admin_transfer_reward3_to_user_bucket1_bulk`,
      functionArguments: [user, amount],
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
  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
  return pendingTxn.hash;
}
// Transfer Methods : Admin transfer from reward3 to reward two.
export async function transferReward3ToReward2ByAdminOnly(
  admin: Account,
  user: AccountAddress,
  amount: AnyNumber
) {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::admin_transfer_reward3_to_user_bucket2`,
      functionArguments: [user, amount],
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
  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
  return pendingTxn.hash;
}
// Transfer Methods : Admin transfer from reward3 to reward two of multiple users.
export async function transferReward3ToReward2ByAdminOnlyInBulk(
  admin: Account,
  user: AccountAddress[],
  amount: AnyNumber[]
) {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::admin_transfer_reward3_to_user_bucket2_bulk`,
      functionArguments: [user, amount],
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
  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
  return pendingTxn.hash;
}
export async function burnCoin(
  admin: Account,
  fromAddress: AccountAddress,
  amount: AnyNumber
): Promise<string> {
  try {
    const transaction = await aptos.transaction.build.simple({
      sender: admin.accountAddress,
      data: {
        function: `${owner.accountAddress}::${module_name}::burn`,
        functionArguments: [fromAddress, amount],
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
    await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
    return pendingTxn.hash;
  } catch (error) {
    console.log("Error while burning coins:", error);
    throw error; // Rethrow the error to handle it at the caller's level if needed
  }
}
/** Admin freezes the primary fungible store of the specified account */
export async function freeze(
  admin: Account,
  targetAddress: AccountAddress
): Promise<string> {
  try {
    // console.log("Request received to freeze account:", targetAddress);
    const transaction = await aptos.transaction.build.simple({
      sender: admin.accountAddress,
      data: {
        function: `${owner.accountAddress}::${module_name}::freeze_account`,
        functionArguments: [targetAddress],
      },
    });

    // console.log("Transaction built for freezing account:", transaction);

    const senderAuthenticator = await aptos.transaction.sign({
      signer: admin,
      transaction,
    });
    // console.log("Transaction signed successfully.");

    const pendingTxn = await aptos.transaction.submit.simple({
      transaction,
      senderAuthenticator,
    });
    // console.log("Transaction submitted successfully.");
    return pendingTxn.hash;
  } catch (error) {
    console.error("Error occurred while freezing account:", error);
    throw error; // Re-throw the error for handling in the caller function
  }
}
/** Admin unfreezes the primary fungible store of the specified account */
export async function unfreeze(
  admin: Account,
  targetAddress: AccountAddress
): Promise<string> {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::unfreeze_account`,
      functionArguments: [targetAddress],
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

  return pendingTxn.hash;
}

/* Admin can invoke these functions With signature */
// ----- SIGNATURE REQUIRED ----

// Admin Transfer with Signature
export async function adminTransferWithSignature(
  admin: Account,
  toAddress: AccountAddress,
  deductionFromSender: AnyNumber[],
  additionToRecipient: AnyNumber[],
  signature: Ed25519Signature
): Promise<string> {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::admin_transfer_with_signature`,
      functionArguments: [
        toAddress,
        deductionFromSender,
        additionToRecipient,
        signature.toUint8Array(),
      ],
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
  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
  return pendingTxn.hash;
}
// Admin can transfer to any account's multiple user's reward field
export async function adminTransferWithSignatureBulk(
  admin: Account,
  to: AccountAddress[],
  deductnFromSender1: AnyNumber[],
  deductnFromSender2: AnyNumber[],
  deductnFromSender3: AnyNumber[],
  additnToRecipient1: AnyNumber[],
  additnToRecipient2: AnyNumber[],
  additnToRecipient3: AnyNumber[],
  signature: Ed25519Signature
) {
  const transaction = await aptos.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::admin_transfer_with_signature_bulk`,
      functionArguments: [
        to,
        deductnFromSender1,
        deductnFromSender2,
        deductnFromSender3,
        additnToRecipient1,
        additnToRecipient2,
        additnToRecipient3,
        signature.toUint8Array(),
      ],
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
  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });

  return pendingTxn.hash;
}

/* Any user can invoke these functions */
/** Admin forcefully transfers the newly created coin to the specified receiver address */
export async function transferCoin(
  from: Account,
  toAddress: AccountAddress,
  amount: AnyNumber
): Promise<string> {
  const transaction = await aptos.transaction.build.simple({
    sender: from.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::transfer`,
      functionArguments: [toAddress, amount],
    },
  });

  const senderAuthenticator = await aptos.transaction.sign({
    signer: from,
    transaction,
  });
  const pendingTxn = await aptos.transaction.submit.simple({
    transaction,
    senderAuthenticator,
  });
  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
  return pendingTxn.hash;
}
//Admin bulk transfers the newly created coin to the specified receivers address
export async function transferCoinBulk(
  from: Account,
  toAddress: AccountAddress[],
  amount: AnyNumber[]
): Promise<string> {
  try {
    const transaction = await aptos.transaction.build.simple({
      sender: from.accountAddress,
      data: {
        function: `${owner.accountAddress}::${module_name}::bulk_transfer`,
        functionArguments: [toAddress, amount],
      },
    });

    const senderAuthenticator = await aptos.transaction.sign({
      signer: from,
      transaction,
    });
    const pendingTxn = await aptos.transaction.submit.simple({
      transaction,
      senderAuthenticator,
    });
    await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
    return pendingTxn.hash;
  } catch (error) {
    console.log("error", error);
  }
}
// User can transfer different assets from the bucket to receiver's bucket reward 3
export async function transferFromBucketToReward3(
  from: Account,
  to: AccountAddress,
  bucket: AnyNumber[]
) {
  const transaction = await aptos.transaction.build.simple({
    sender: from.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::transfer_to_reward3`,
      functionArguments: [to, bucket],
    },
  });

  const senderAuthenticator = await aptos.transaction.sign({
    signer: from,
    transaction,
  });
  const pendingTxn = await aptos.transaction.submit.simple({
    transaction,
    senderAuthenticator,
  });
  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
  return pendingTxn.hash;
}
// User can transfer different assets from the bucket to multiple receiver's bucket reward 3
// transfer_to_reward3_bulk
export async function transferFromBucketToReward3Bulk(
  from: Account,
  to: AccountAddress[],
  bucket: AnyNumber[][]
) {
  const transaction = await aptos.transaction.build.simple({
    sender: from.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::transfer_to_reward3_bulk`,
      functionArguments: [to, bucket],
    },
  });

  const senderAuthenticator = await aptos.transaction.sign({
    signer: from,
    transaction,
  });
  const pendingTxn = await aptos.transaction.submit.simple({
    transaction,
    senderAuthenticator,
  });
  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
  return pendingTxn.hash;
}
// User can transfer reward3 from the bucket to a receiver's bucket reward 3
export async function transferFromReward3ToReward3(
  from: Account,
  to: AccountAddress,
  amount: AnyNumber
) {
  const transaction = await aptos.transaction.build.simple({
    sender: from.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::transfer_reward3_to_reward3`,
      functionArguments: [to, amount],
    },
  });

  const senderAuthenticator = await aptos.transaction.sign({
    signer: from,
    transaction,
  });
  const pendingTxn = await aptos.transaction.submit.simple({
    transaction,
    senderAuthenticator,
  });
  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
  return pendingTxn.hash;
}
// User can transfer reward3 from the bucket to multiple receiver's bucket reward 3
export async function transferFromReward3ToReward3Bulk(
  from: Account,
  to: AccountAddress[],
  amount: AnyNumber[]
) {
  const transaction = await aptos.transaction.build.simple({
    sender: from.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::transfer_reward3_to_reward3_bulk`,
      functionArguments: [to, amount],
    },
  });

  const senderAuthenticator = await aptos.transaction.sign({
    signer: from,
    transaction,
  });
  const pendingTxn = await aptos.transaction.submit.simple({
    transaction,
    senderAuthenticator,
  });
  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
  return pendingTxn.hash;
}
// User transfer the funds
export async function nativeTransfer(
  sender: Account,
  metadata: AccountAddress,
  receiver: AccountAddress,
  amount: AnyNumber
) {
  try {
    let tx = await aptos.transferFungibleAsset({
      sender: sender,
      fungibleAssetMetadataAddress: metadata,
      recipient: receiver,
      amount: amount,
    });

    const senderAuthenticator = await aptos.transaction.sign({
      signer: sender,
      transaction: tx,
    });

    const transferTx = await aptos.transaction.submit.simple({
      transaction: tx,
      senderAuthenticator,
    });
    await aptos.waitForTransaction({
      transactionHash: transferTx.hash,
    });
    console.log("🚀 ~ transferTx:", transferTx.hash);

    return transferTx.hash;
  } catch (error) {
    // console.log("🚀 ~ error:", error);
    return false;
  }
}

/* *** Methods that requires signature *** */

// User can transfer from reward3 to receiver's reward1 bucket
export async function transferReward3ToReward1WithSign(
  from: Account,
  to: AccountAddress,
  amount: AnyNumber,
  signature: Ed25519Signature
) {
  const transaction = await aptos.transaction.build.simple({
    sender: from.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::transfer_reward3_to_reward1`,
      functionArguments: [to, amount, signature.toUint8Array()],
    },
  });
  const senderAuthenticator = await aptos.transaction.sign({
    signer: from,
    transaction,
  });
  const pendingTxn = await aptos.transaction.submit.simple({
    transaction,
    senderAuthenticator,
  });

  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });

  return pendingTxn.hash;
}
// User can transfer from reward3 to multiple receivers' reward1 buckets
export async function transferReward3ToReward1BulkWithSign(
  from: Account,
  to: AccountAddress[],
  amount: AnyNumber[],
  signature: Ed25519Signature
) {
  const transaction = await aptos.transaction.build.simple({
    sender: from.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::transfer_reward3_to_reward1_bulk`,
      functionArguments: [to, amount, signature.toUint8Array()],
    },
  });
  const senderAuthenticator = await aptos.transaction.sign({
    signer: from,
    transaction,
  });
  const pendingTxn = await aptos.transaction.submit.simple({
    transaction,
    senderAuthenticator,
  });

  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });

  return pendingTxn.hash;
}
// User can transfer from reward3 to receiver's reward1 bucket
export async function transferReward3ToReward2WithSign(
  from: Account,
  to: AccountAddress,
  amount: AnyNumber,
  signature: Ed25519Signature
) {
  const transaction = await aptos.transaction.build.simple({
    sender: from.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::transfer_reward3_to_reward2`,
      functionArguments: [to, amount, signature.toUint8Array()],
    },
  });
  const senderAuthenticator = await aptos.transaction.sign({
    signer: from,
    transaction,
  });
  const pendingTxn = await aptos.transaction.submit.simple({
    transaction,
    senderAuthenticator,
  });

  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });

  return pendingTxn.hash;
}
// User can transfer from reward3 to receiver's reward1 bucket
export async function transferReward3ToReward2BulkWithSign(
  from: Account,
  to: AccountAddress[],
  amount: AnyNumber[],
  signature: Ed25519Signature
) {
  const transaction = await aptos.transaction.build.simple({
    sender: from.accountAddress,
    data: {
      function: `${owner.accountAddress}::${module_name}::transfer_reward3_to_reward2_bulk`,
      functionArguments: [to, amount, signature.toUint8Array()],
    },
  });
  const senderAuthenticator = await aptos.transaction.sign({
    signer: from,
    transaction,
  });
  const pendingTxn = await aptos.transaction.submit.simple({
    transaction,
    senderAuthenticator,
  });

  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });

  return pendingTxn.hash;
}

async function printVal(metadataAddress: string) {
  console.log(
    "Owner's kcash balance: ",
    await getFaBalance(owner, metadataAddress)
  );
  console.log(
    "user1's kcash balance: ",
    await getFaBalance(user1, metadataAddress)
  );
  console.log(
    "user2's kcash balance: ",
    await getFaBalance(user2, metadataAddress)
  );

  console.log("Owner's bucketstore: ", await getBucketStore(owner));
  console.log("user1's bucketstore: ", await getBucketStore(user1));
  console.log("user2's bucketstore: ", await getBucketStore(user2));
}

async function main_1() {
  // await aptos.fundAccount({
  //   accountAddress: owner.accountAddress,
  //   amount: 100000000,
  // });
  // console.log("🚀 ~ messageHash1:", messageHash.toString());

  console.log("\n=== Addresses ===");
  console.log(`Owner: ${owner.accountAddress.toString()}`);
  console.log(`User1: ${user1.accountAddress.toString()}`);
  console.log(`User2: ${user2.accountAddress.toString()}`);

  let deployedTx = await compileAndDeploy();
  console.log("🚀 ~ main ~ deployedTx:", deployedTx);

  /*   ----- Functions for view data from modules ----- */

  const metadata = await getMetadata(owner);
  let metadataAddress = metadata.toString();
  console.log("metadata address:", metadataAddress);

  console.log("Minter List: ", await getMinterList());
  console.log("Admin transfer List: ", await getAdminTransferList());

  /* Only admin can invoke these functions */

  console.log(
    "\nOwner mints the 1000 kcash in own account: ",
    await mintCoin(owner, owner.accountAddress, 1000, 300, 300, 400)
  );

  console.log("\nOwner mints the 500 kcash in bulk of accounts: ");
  console.log("300 kcash in user1's account and 200 kcash in user2's account");
  await bulkMintCoin(
    owner,
    [user1.accountAddress, user2.accountAddress],
    [300, 200],
    [100, 70],
    [100, 70],
    [100, 60]
  );

  await printVal(metadataAddress);

  console.log(
    "\nOwner transfer 10 kcash to user1 according to value provided: ",
    await adminTransfer(owner, user1.accountAddress, [2, 2, 6], [3, 3, 4])
  );
  console.log("\nOwner transfer the 20 kcash in bulk of accounts: ");
  console.log("10 kcash in user1's account and 10 kcash in user2's account");
  await adminTransferBulk(
    owner,
    [user1.accountAddress, user2.accountAddress],
    [
      [2, 4, 4],
      [4, 3, 3],
    ],
    [
      [2, 3, 5],
      [5, 5, 0],
    ]
  );
  await printVal(metadataAddress);

  console.log(
    "Adding new account as admint trasnfer role: ",
    await addAdminTransferRole(owner, user1.accountAddress)
  );
  console.log(
    "Admin transfer List updated, user1 now has transfer role: ",
    await getAdminTransferList()
  );

  console.log(
    "User1 can transfer 1 kcash from its reward3 to user2's reward1 as an admin: ",
    await transferReward3ToReward1ByAdminOnly(user1, user2.accountAddress, 1)
  );
  await printVal(metadataAddress);

  console.log("\n*** Admint transfer with signature ***");
  let o_nonce = await getNonce(owner);
  console.log("Owner :", o_nonce);

  let t_msg = await createStructForAdminTransferSig(
    owner.accountAddress,
    user1.accountAddress,
    [new Uint64(BigInt(1)), new Uint64(BigInt(1)), new Uint64(BigInt(1))],
    [new Uint64(BigInt(1)), new Uint64(BigInt(1)), new Uint64(BigInt(1))],
    "admin_transfer_with_signature",
    new Uint64(BigInt(o_nonce))
  );

  let t_msg_bytes = t_msg.bcsToBytes();
  let t_msg_hash = sha256(t_msg_bytes);
  let sign = await signMessage(privateKeyOwner, t_msg_hash);

  await adminTransferWithSignature(
    owner,
    user1.accountAddress,
    [1, 1, 1],
    [1, 1, 1],
    sign
  );
  await printVal(metadataAddress);

  console.log(
    "Add new signer now, signer_kp is a new signer: ",
    await addSigner(owner, signer_public.toUint8Array())
  );

  console.log("\nNow user1 transfer the funds in bulk with signature");
  let u_nonce = await getNonce(user1);

  let t_msgB = await createStructForAdminTransferSigBulk(
    user1.accountAddress,
    [user2.accountAddress, owner.accountAddress, signer.accountAddress],
    [new Uint64(BigInt(1)), new Uint64(BigInt(1)), new Uint64(BigInt(1))],
    [new Uint64(BigInt(1)), new Uint64(BigInt(1)), new Uint64(BigInt(1))],
    [new Uint64(BigInt(1)), new Uint64(BigInt(1)), new Uint64(BigInt(1))],
    [new Uint64(BigInt(1)), new Uint64(BigInt(1)), new Uint64(BigInt(1))],
    [new Uint64(BigInt(1)), new Uint64(BigInt(1)), new Uint64(BigInt(1))],
    [new Uint64(BigInt(1)), new Uint64(BigInt(1)), new Uint64(BigInt(1))],
    "admin_transfer_with_signature_bulk",
    new Uint64(BigInt(u_nonce))
  );

  let t_msgB_bytes = t_msgB.bcsToBytes();
  let t_msgBHash = sha256(t_msgB_bytes);
  let sign2 = await signMessage(signer_pk, t_msgBHash);
  console.log("🚀 ~ main_1 ~ sign2:", sign2);

  let e = await adminTransferWithSignatureBulk(
    user1,
    [user2.accountAddress, owner.accountAddress, signer.accountAddress],
    [1, 1, 1],
    [1, 1, 1],
    [1, 1, 1],
    [1, 1, 1],
    [1, 1, 1],
    [1, 1, 1],
    sign2
  );
  console.log("e: ", e);

  await printVal(metadataAddress);

  /* Any user can invoke these functions */
  console.log("user2 transfer 2 kcash to user1's bucket 3");
  await transferCoin(user2, user1.accountAddress, 2);

  await printVal(metadataAddress);

  console.log(
    "user2 transfer 3 kcash to user1's bucket 3 and 1 in signer's bucket 3"
  );
  await transferCoinBulk(
    user2,
    [user1.accountAddress, signer.accountAddress],
    [3, 1]
  );
  await printVal(metadataAddress);

  console.log(
    "User1 transfer 4 kcash from its bucket3 in bulk to the three diffeent account's bucket3"
  );
  await transferFromReward3ToReward3Bulk(
    user1,
    [user2.accountAddress, owner.accountAddress, signer.accountAddress],
    [2, 1, 1]
  );
  await printVal(metadataAddress);

  /* *** Methods that requires signature *** */

  console.log(
    "User2 will transfer from bucket3 to users bucket1 using signature (BULK METHOD)"
  );
  let u_nonce1 = await getNonce(user2);
  console.log("🚀 ~ main_1 ~ u_nonce1:", u_nonce1);

  let msg1 = await createStructForMsgBulk(
    user2.accountAddress,
    [user1.accountAddress, owner.accountAddress],
    [new Uint64(BigInt(2)), new Uint64(BigInt(3))],
    "transfer_reward3_to_reward1_bulk",
    new Uint64(BigInt(u_nonce1))
  );

  let msg1Bytes = msg1.bcsToBytes();
  let msg1Hash = sha256(msg1Bytes);
  console.log("🚀 ~ main_1 ~ msg1Hash:", msg1Hash);
  let sig1 = await signMessage(privateKeyOwner, msg1Hash);

  let tx = await transferReward3ToReward1BulkWithSign(
    user2,
    [user1.accountAddress, owner.accountAddress],
    [2, 3],
    sig1
  );
  console.log("🚀 ~ main_1 ~ tx:", tx);

  await printVal(metadataAddress);

  console.log(
    "Assigning minter role to user 1",
    await addMinterRole(owner, user1.accountAddress)
  );

  /* Remove admin transfer ability from user1 */
  console.log("Minter list: ", await getMinterList());
  console.log(
    "Removing the minter role of user1: ",
    await removeMinterRole(owner, user1.accountAddress)
  );
  console.log("Minter list after removing an acount: ", await getMinterList());

  // /* Remove admin transfer ability from user1 */
  console.log("Adimin transfer list: ", await getAdminTransferList());
  console.log(
    "Removing the admin transfer role of user1: ",
    await removeAdminTransferRole(owner, user1.accountAddress)
  );
  console.log(
    "Admin transfer list after removing an acount: ",
    await getAdminTransferList()
  );

  // /* Remove admin transfer ability from user1 */
  console.log("Signers list: ", await getSignersList());
  console.log(
    "Removing the signer role of signer: ",
    await removeSigner(owner, signer.publicKey.toUint8Array())
  );
  console.log(
    "Signer list after removing an acount: ",
    await getAdminTransferList()
  );
}

main_1();
