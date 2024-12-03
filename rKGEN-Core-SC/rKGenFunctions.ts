import {
  Account,
  AccountAddress,
  AnyNumber,
  generateRawTransaction,
  generateTransactionPayload,
  InputViewFunctionData,
  SimpleTransaction,
  TransactionPayloadMultiSig,
} from "@aptos-labs/ts-sdk"; // Import relevant classes and types from the Aptos SDK
import {
  deployer,
  module_name,
  aptos,
  config,
  multisig,
  m1Ac,
  m2Ac,
} from "./utils";
import { error } from "console";

/**
 * Fetches the admin address from the Move smart contract.
 * @param admin - The account object containing the address of the module owner.
 * @returns The admin address as a string.
 */
export async function getAdmin() {
  const payload: InputViewFunctionData = {
    function: `${deployer.accountAddress}::${module_name}::get_admin`, // Specify the view function
    functionArguments: [], // No arguments required for this function
  };
  const res = await aptos.view({ payload });
  return res.toString();
}

/**
 * Fetches the minter address from the Move smart contract.
 * @param admin - The account object containing the address of the module owner.
 * @returns The minter address as a string.
 */
export async function getMinter() {
  const payload: InputViewFunctionData = {
    function: `${deployer.accountAddress}::${module_name}::get_minter`, // Specify the view function
    functionArguments: [], // No arguments required for this function
  };
  const res = await aptos.view({ payload });
  return res.toString();
}

/**
 * Fetches the treasury addresses from the Move smart contract.
 * @param admin - The account object containing the address of the module owner.
 * @returns An array of treasury addresses.
 */
export async function getTreasuryAddress() {
  const payload: InputViewFunctionData = {
    function: `${deployer.accountAddress}::${module_name}::get_treasury_address`, // Specify the view function
    functionArguments: [], // No arguments required for this function
  };
  const res = (await aptos.view({ payload })).flat().map(String);
  return res;
}

/**
 * Fetches the list of whitelisted senders from the Move smart contract.
 * @param admin - The account object containing the address of the module owner.
 * @returns An array of whitelisted sender addresses.
 */
export async function getWhitelistedSender() {
  const payload: InputViewFunctionData = {
    function: `${deployer.accountAddress}::${module_name}::get_whitelisted_sender`, // Specify the view function
    functionArguments: [], // No arguments required for this function
  };
  const res = (await aptos.view({ payload })).flat().map(String);
  return res;
}

/**
 * Fetches the list of whitelisted receivers from the Move smart contract.
 * @param admin - The account object containing the address of the module owner.
 * @returns An array of whitelisted receiver addresses.
 */
export async function getWhitelistedReceiver() {
  const payload: InputViewFunctionData = {
    function: `${deployer.accountAddress}::${module_name}::get_whitelisted_receiver`, // Specify the view function
    functionArguments: [], // No arguments required for this function
  };
  const res = (await aptos.view({ payload })).flat().map(String);
  return res;
}

/**
 * Fetches metadata from the Move smart contract.
 * @param admin - The account object containing the address of the module owner.
 * @returns The metadata object.
 */
export async function getMetadata() {
  const payload: InputViewFunctionData = {
    function: `${deployer.accountAddress}::${module_name}::get_metadata`, // Specify the view function
    functionArguments: [], // No arguments required for this function
  };
  const res = (await aptos.view<[{ inner: string }]>({ payload }))[0];
  return res.inner;
}

export const getRKBalance = async (
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

const verifyAdmin = async (admin: string) => {
  return (await getAdmin()) === admin;
};

const verifyMinter = async (minter: string) => {
  return (await getMinter()) === minter;
};

const verifyTreas = async (minter: string) => {
  return (await getMinter()) === minter;
};

/**---------------------- ENTRY FUNCTIONS -------------------------------------- */
type MoveString = `${string}::${string}::${string}`;

/** Update the admin of the module */
export const updateAdmin = async (admin: Account, newAdmin: AccountAddress) => {
  let onchai_admin = await getAdmin();
  if (admin.accountAddress.toString() != onchai_admin) {
    throw error;
  }
  return executeTransaction(
    admin,
    `${deployer.accountAddress}::${module_name}::update_admin` as MoveString,
    [newAdmin]
  );
};

/** Update the minter of the module */
export const updateMinter = async (
  admin: Account,
  newMinter: AccountAddress
) => {
  let onchai_admin = await getAdmin();

  if (admin.accountAddress.toString() != onchai_admin) {
    throw error;
  }
  return executeTransaction(
    admin,
    `${deployer.accountAddress}::${module_name}::update_minter` as MoveString,
    [newMinter]
  );
};

/** Add a new treasury address to the treasury vector */
export const addTreasuryAddress = async (
  admin: Account,
  newAddress: AccountAddress
) => {
  let onchai_admin = await getAdmin();

  if (admin.accountAddress.toString() != onchai_admin) {
    throw error;
  }
  return executeTransaction(
    admin,
    `${deployer.accountAddress}::${module_name}::add_treasury_address` as MoveString,
    [newAddress]
  );
};

/** Remove an address from the treasury vector */
export const removeTreasuryAddress = async (
  admin: Account,
  address: AccountAddress
) => {
  let onchai_admin = await getAdmin();

  if (admin.accountAddress.toString() != onchai_admin) {
    throw error;
  }
  return executeTransaction(
    admin,
    `${deployer.accountAddress}::${module_name}::remove_treasury_address` as MoveString,
    [address]
  );
};

/** Remove a whitelist receiver */
export const removeWhitelistReceiver = async (
  admin: Account,
  receiverAddress: AccountAddress
) => {
  let onchai_admin = await getAdmin();

  if (admin.accountAddress.toString() != onchai_admin) {
    throw error;
  }
  return executeTransaction(
    admin,
    `${deployer.accountAddress}::${module_name}::remove_whitelist_receiver` as MoveString,
    [receiverAddress]
  );
};

/** Add a whitelist receiver */
export const addWhitelistReceiver = async (
  admin: Account,
  receiverAddress: AccountAddress
) => {
  let onchai_admin = await getAdmin();

  if (admin.accountAddress.toString() != onchai_admin) {
    throw error;
  }
  return executeTransaction(
    admin,
    `${deployer.accountAddress}::${module_name}::add_whitelist_receiver` as MoveString,
    [receiverAddress]
  );
};

/** Remove a whitelist sender */
export const removeWhitelistSender = async (
  admin: Account,
  senderAddress: AccountAddress
) => {
  let onchai_admin = await getAdmin();

  if (admin.accountAddress.toString() != onchai_admin) {
    throw error;
  }
  return executeTransaction(
    admin,
    `${deployer.accountAddress}::${module_name}::remove_whitelist_sender` as MoveString,
    [senderAddress]
  );
};

/** Add a whitelist sender */
export const addWhitelistSender = async (
  admin: Account,
  senderAddress: AccountAddress
) => {
  let onchai_admin = await getAdmin();

  if (admin.accountAddress.toString() != onchai_admin) {
    throw error;
  }
  return executeTransaction(
    admin,
    `${deployer.accountAddress}::${module_name}::add_whitelist_sender` as MoveString,
    [senderAddress]
  );
};

/** Burn tokens from a specific address */
export const burnTokens = async (
  admin: Account,
  from: AccountAddress,
  amount: AnyNumber
) => {
  let onchai_admin = await getAdmin();

  if (admin.accountAddress.toString() != onchai_admin) {
    throw error;
  }
  return executeTransaction(
    admin,
    `${deployer.accountAddress}::${module_name}::burn` as MoveString,
    [from, amount]
  );
};

/** Transfer tokens from a whitelist sender to a receiver */
export const transferFromWhitelistSender = async (
  senderAddress: Account,
  receiver: AccountAddress,
  amount: AnyNumber
) => {
  return executeTransaction(
    senderAddress,
    `${deployer.accountAddress}::${module_name}::transfer_from_whitelist_sender` as MoveString,
    [receiver, amount]
  );
};

/** Transfer tokens to a whitelist receiver */
export const transferToWhitelistReceiver = async (
  senderAddress: Account,
  receiver: AccountAddress,
  amount: AnyNumber
) => {
  return executeTransaction(
    senderAddress,
    `${deployer.accountAddress}::${module_name}::transfer_to_whitelist_receiver` as MoveString,
    [receiver, amount]
  );
};

/** Freeze a specific account */
export const freezeAccount = async (
  admin: Account,
  account: AccountAddress
) => {
  return executeTransaction(
    admin,
    `${deployer.accountAddress}::${module_name}::freeze_account` as MoveString,
    [account]
  );
};

/** Unfreeze a specific account */
export const unfreezeAccount = async (
  admin: Account,
  account: AccountAddress
) => {
  return executeTransaction(
    admin,
    `${deployer.accountAddress}::${module_name}::unfreeze_account` as MoveString,
    [account]
  );
};

/** Generic function to execute a transaction */
const executeTransaction = async (
  sender: Account,
  functionPath: MoveString,
  functionArguments: (AccountAddress | AnyNumber)[]
) => {
  // Build the transaction
  const transaction = await aptos.transaction.build.simple({
    sender: sender.accountAddress,
    data: {
      function: functionPath,
      functionArguments: functionArguments,
    },
  });

  // Sign the transaction
  const senderAuthenticator = await aptos.transaction.sign({
    signer: sender,
    transaction,
  });

  // Submit the transaction
  const pendingTxn = await aptos.transaction.submit.simple({
    transaction,
    senderAuthenticator,
  });

  // Wait for transaction to complete
  await aptos.waitForTransaction({
    transactionHash: pendingTxn.hash,
  });

  return pendingTxn.hash; // Return the transaction hash
};

/* ---------------- MINTING PROCESS THROUGH MULTISIG -------------- */

let transactionPayload: TransactionPayloadMultiSig;

export const mint = async (receiver: AccountAddress, amount: AnyNumber) => {
  await createMintTransaction(receiver, amount);

  let lastSeqNo = await getLastSeqNo();
  let txId = parseInt(`${lastSeqNo}`) + 1;

  // 1st and 3rd Approves the transaction
  await approveMultisigTx(m1Ac, txId);
  await approveMultisigTx(m2Ac, txId);

  console.log(
    "\nCan be execute the mint transaction as it already has 2 approvals."
  );

  const rawTransaction = await generateRawTransaction({
    aptosConfig: config,
    sender: m1Ac.accountAddress,
    payload: transactionPayload,
  });

  const final_transaction = new SimpleTransaction(rawTransaction);

  const senderAuthenticator = aptos.transaction.sign({
    signer: m1Ac,
    transaction: final_transaction,
  });
  const transferTransactionReponse = await aptos.transaction.submit.simple({
    senderAuthenticator: senderAuthenticator,
    transaction: final_transaction,
  });
  await aptos.waitForTransaction({
    transactionHash: transferTransactionReponse.hash,
  });
  console.log(
    "🚀 ~ mint ~ transactionHash:",
    transferTransactionReponse.hash,
    "\n"
  );
};

// Helper functions

/** Return the address of the managed fungible asset that's created when this module is deployed */
async function getPendingTx() {
  const payload: InputViewFunctionData = {
    function: `0x1::multisig_account::get_pending_transactions`,
    functionArguments: [multisig],
  };
  const res = await aptos.view<[]>({ payload });
  return res;
}

/** Return the address of the managed fungible asset that's created when this module is deployed */
async function getLastSeqNo() {
  const payload: InputViewFunctionData = {
    function: `0x1::multisig_account::last_resolved_sequence_number`,
    functionArguments: [multisig],
  };
  const res = (await aptos.view({ payload }))[0];
  return res;
}

/** Return the address of the managed fungible asset that's created when this module is deployed */
async function getNextSeqNo() {
  const payload: InputViewFunctionData = {
    function: `0x1::multisig_account::next_sequence_number`,
    functionArguments: [multisig],
  };
  const res = (await aptos.view<[{ inner: string }]>({ payload }))[0];
  return res;
}

async function createMintTransaction(
  receiver: AccountAddress,
  amount: AnyNumber
) {
  console.log("Creating a multisig transaction to mint rKGen...");
  transactionPayload = await generateTransactionPayload({
    multisigAddress: multisig,
    function: `${deployer.accountAddress}::${module_name}::mint`,
    functionArguments: [receiver, amount],
    aptosConfig: config,
  });

  // Simulate the transfer transaction to make sure it passes
  const transactionToSimulate = await generateRawTransaction({
    aptosConfig: config,
    sender: m1Ac.accountAddress,
    payload: transactionPayload,
  });

  const simulateMultisigTx = await aptos.transaction.simulate.simple({
    signerPublicKey: m1Ac.publicKey,
    transaction: new SimpleTransaction(transactionToSimulate),
  });

  // Build create_transaction transaction
  const mintMultisigTx = await aptos.transaction.build.simple({
    sender: m1Ac.accountAddress,
    data: {
      function: "0x1::multisig_account::create_transaction",
      functionArguments: [
        multisig,
        transactionPayload.multiSig.transaction_payload?.bcsToBytes(),
      ],
    },
  });

  // Owner 3 signs the transaction
  const createMultisigTxAuthenticator = aptos.transaction.sign({
    signer: m1Ac,
    transaction: mintMultisigTx,
  });

  // Submit the transaction to chain
  const createMultisigTxResponse = await aptos.transaction.submit.simple({
    senderAuthenticator: createMultisigTxAuthenticator,
    transaction: mintMultisigTx,
  });
  await aptos.waitForTransaction({
    transactionHash: createMultisigTxResponse.hash,
  });
}

async function approveMultisigTx(signer: Account, txId: number) {
  const approveTx = await aptos.transaction.build.simple({
    sender: signer.accountAddress,
    data: {
      function: "0x1::multisig_account::approve_transaction",
      functionArguments: [multisig, txId],
    },
  });

  const approveSenderAuthenticator = aptos.transaction.sign({
    signer: signer,
    transaction: approveTx,
  });
  const approveTxResponse = await aptos.transaction.submit.simple({
    senderAuthenticator: approveSenderAuthenticator,
    transaction: approveTx,
  });
  await aptos.waitForTransaction({ transactionHash: approveTxResponse.hash });

  console.log("Transaction approved by: ", signer.accountAddress.toString());
}
