// Importing necessary modules and functions from the KCash Fungible Asset.
import {
  Account,
  Aptos,
  AptosConfig,
  Ed25519Account,
  Ed25519PrivateKey,
  Ed25519PublicKey,
  AptosSettings,
  Network,
  AptosApiType,
  NetworkToNodeAPI,
  NetworkToFaucetAPI,
  NetworkToIndexerAPI,
  NetworkToNetworkName,
} from "@aptos-labs/ts-sdk";
// Functions for various KCash operations
import {
  transferCoin,
  mintCoin,
  burnCoin,
  freeze,
  unfreeze,
  getFaBalance,
  getMetadata,
  getIs_freez,
  compileAndDeploy,
  getBucketStore,
  bulkMintCoin,
  transferReward3ToReward1ByAdminOnly,
  transferReward3ToReward1ByAdminOnlyInBulk,
  transferReward3ToReward2ByAdminOnly,
  transferReward3ToReward2ByAdminOnlyInBulk,
  transferCoinBulk,
  adminTransfer,
  adminTransferBulk,
  transferFromReward3ToReward3,
  transferFromReward3ToReward3Bulk,
  transferFromBucketToReward3,
  transferFromBucketToReward3Bulk,
  adminTransferWithSignature,
  signMessage,
  transferReward3ToReward1WithSign,
  getNonce,
  transferReward3ToReward1BulkWithSign,
  transferReward3ToReward2WithSign,
  transferReward3ToReward2BulkWithSign,
  addMinterRole,
  getMinterList,
  MessageMoveStruct,
  deductionFromSender,
  additionToRecipient,
  createStructForMsg,
  Uint64,
  createStructForMsgBulk,
  adminTransferWithSignatureBulk,
  MessageMoveStructBulk,
  deductnFromSender1,
  additnToRecipient1,
  additnToRecipient2,
  additnToRecipient3,
  deductnFromSender2,
  deductnFromSender3,
  createStructForAdminTransferSigBulk,
  removeMinterRole,
  getAdminTransferList,
  removeAdminTransferRole,
  getSignersList,
  removeSigner,
} from "../kcash_fungible_asset";

// Importing SHA256 hash function
import sha256 from "fast-sha256";

// Importing utility functions
import { compilePackage, getPackageBytesToPublish } from "../utils";
import { get } from "https";
import fs from "fs";

// Creating a message and calculating its hash
const message = new Uint8Array(Buffer.from("KCash"));
const messageHash = sha256(message);

// Setting up Aptos network configuration
const APTOS_NETWORK: Network = NetworkToNetworkName[Network.DEVNET];
const config = new AptosConfig({ network: APTOS_NETWORK });
const aptos = new Aptos(config);

// Loading owner's and users' key pairs from files
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
const privateKeyuser3 = new Ed25519PrivateKey(signer_kp.privateKey);
const user3 = Account.fromPrivateKey({ privateKey: privateKeyuser3 });

let metadataAddress: string;

// Constants for KCash operations
const decimal_kcash = 1;
const amount_to_mint = 1000 * decimal_kcash;
const amount_To_Burn = 200 * decimal_kcash;
const reward1 = amount_to_mint * 0.1;
const reward2 = amount_to_mint * 0.2;
const reward3 = amount_to_mint * 0.7;

const amount_to_be_transfer = 500 * decimal_kcash;

let amt2 = amount_to_mint / 2;
let amount_ar = [amount_to_mint, amt2];
let receiver_ar = [user1.accountAddress, user2.accountAddress];
let r1_ar = [amount_to_mint * 0.5, amt2 * 0.5];
let r2_ar = [amount_to_mint * 0.3, amt2 * 0.3];
let r3_ar = [amount_to_mint * 0.2, amt2 * 0.2];

describe("Kcash Test", () => {
  beforeAll(async () => {
    // Get metadata address
    let deployedTx = await compileAndDeploy();
    console.log("🚀 ~ main ~ deployedTx:", deployedTx);
    let metadataAddress = await getMetadata(owner);
    console.log("metadataAddress611", metadataAddress);
    // const contract = await compileAndDeploy()
  }, 20000);

  describe("fromPrivateKeyAndAddress", () => {
    it("derives the correct account from a  ed25519 private key", () => {
      let privateKeyOwner = new Ed25519PrivateKey(owner_kp.privateKey);
      let owner = Account.fromPrivateKey({ privateKey: privateKeyOwner });
      expect(owner).toBeInstanceOf(Ed25519Account);
      expect(owner.publicKey).toBeInstanceOf(Ed25519PublicKey);
      expect(owner.privateKey).toBeInstanceOf(Ed25519PrivateKey);
      expect(owner.privateKey.toString()).toEqual(privateKeyOwner.toString());
    });
  });

  describe("aptos config", () => {
    it("it should set urls based on a devnet network", () => {
      const settings: AptosSettings = {
        network: Network.DEVNET,
      };
      const aptosConfig = new AptosConfig(settings);
      expect(aptosConfig.network).toEqual("devnet");
      expect(aptosConfig.getRequestUrl(AptosApiType.FULLNODE)).toBe(
        NetworkToNodeAPI[Network.DEVNET]
      );
      expect(aptosConfig.getRequestUrl(AptosApiType.FAUCET)).toBe(
        NetworkToFaucetAPI[Network.DEVNET]
      );
      expect(aptosConfig.getRequestUrl(AptosApiType.INDEXER)).toBe(
        NetworkToIndexerAPI[Network.DEVNET]
      );
    });

    test("it should set urls based on mainnet", async () => {
      const settings: AptosSettings = {
        network: Network.MAINNET,
      };
      const aptosConfig = new AptosConfig(settings);
      expect(aptosConfig.network).toEqual("mainnet");
      expect(aptosConfig.getRequestUrl(AptosApiType.FULLNODE)).toBe(
        NetworkToNodeAPI[Network.MAINNET]
      );
      expect(aptosConfig.getRequestUrl(AptosApiType.FAUCET)).toBe(
        NetworkToFaucetAPI[Network.MAINNET]
      );
      expect(aptosConfig.getRequestUrl(AptosApiType.INDEXER)).toBe(
        NetworkToIndexerAPI[Network.MAINNET]
      );
    });
  });

  describe("KCash Package Compilation and Publishing and deploy", () => {
    it("should compile and publish KCash package", async () => {
      // Define mock implementations for compilePackage and publishPackageTransaction
      const { metadataBytes, byteCode } = getPackageBytesToPublish(
        "/move/facoin/facoin.json"
      );
      // Logging to indicate the start of the publishing process
      console.log("\n===Publishing KCash package===");
      const transaction = await aptos.publishPackageTransaction({
        account: owner.accountAddress,
        metadataBytes,
        moduleBytecode: byteCode,
      });

      // Signing and submitting the transaction
      const response = await aptos.signAndSubmitTransaction({
        signer: owner,
        transaction,
      });
      // Waiting for the transaction to be confirmed
      await aptos.waitForTransaction({
        transactionHash: response.hash,
      });
      // Logging the transaction hash for reference
      console.log(`Transaction hash28000: ${response.hash}`);
      // Expecting the transaction hash to be defined
      expect(response.hash).toBeDefined();
    });
  });

  describe("check blance of account and get metadata", () => {
    it("get metadata", async () => {
      try {
        // Test getting metadata
        console.log("Testing getMetadata...");
        // Retrieve metadata
        const metadata = await getMetadata(owner);
        expect(metadata).toBeDefined();
        console.log("Metadata:", metadata);
      } catch (error) {
        console.log("error", error);
      }
    });

    it("get Fa_blance", async () => {
      try {
        // Test getting FA balance
        console.log("Testing getFaBalance...");
        const metadataAddress = await getMetadata(owner);
        console.log("metadataAddress276", metadataAddress);
        const balance = await getFaBalance(owner, metadataAddress.toString());
        expect(balance).toBeDefined();
        console.log("Balance:", balance);
      } catch (error) {
        console.log("error", error);
      }
    });
  });

  describe("minting-burning-coin", () => {
    it("Mint Coins", async () => {
      try {
        // Get the metadata address associated with the owner
        let metadataAddress = await getMetadata(owner);

        // Get the initial balance of the owner before minting
        let initialBalanceowner = await getFaBalance(
          owner,
          metadataAddress.toString()
        );

        // Get the bucket store associated with the owner
        const bucketStore = await getBucketStore(owner);

        // Mint coins with specified parameters and receive transaction hash
        let mintCoinTransactionHash = await mintCoin(
          owner,
          owner.accountAddress,
          amount_to_mint,
          reward1,
          reward2,
          reward3
        );

        // Log the transaction hash
        console.log("result", mintCoinTransactionHash);

        // Get the final balance of the owner after minting
        const finalBalanceoner = await getFaBalance(
          owner,
          metadataAddress.toString()
        );

        // Get the bucket store associated with the owner after minting
        const bucketStore_after_minting = await getBucketStore(owner);

        // Check if the final balance is equal to the initial balance plus the minted amount
        expect(finalBalanceoner).toBe(initialBalanceowner + amount_to_mint);
      } catch (error) {
        // Log any errors that occur during the process
        console.log("error", error);
      }
    }, 7000);

    it("Bulk Mint Coins", async () => {
      try {
        console.log("Start bulk minting....");

        // Retrieve initial balances
        const metadata = await getMetadata(owner);
        const initialBalanceOwner = await getFaBalance(
          user1,
          metadata.toString()
        );
        const initialUser1Balance = await getFaBalance(
          user1,
          metadata.toString()
        );
        const initialUser2Balance = await getFaBalance(
          user2,
          metadata.toString()
        );
        let amt2 = amount_to_mint / 2;
        let amount_ar = [amount_to_mint, amt2];
        let mint_amount = amount_to_mint + amt2;
        if (initialBalanceOwner < mint_amount) {
          let mintCoinTransactionHash = await mintCoin(
            owner,
            owner.accountAddress,
            amount_to_mint,
            reward1,
            reward2,
            reward3
          );
          console.log("mintCoinTransactionHash", mintCoinTransactionHash);
        }

        // Perform bulk minting
        const bulkMintTx = await bulkMintCoin(
          owner,
          receiver_ar,
          amount_ar,
          r1_ar,
          r2_ar,
          r3_ar
        );
        console.log("Bulk Mint Transaction:", bulkMintTx);

        // Retrieve balances after minting
        const user1BalanceAfter = await getFaBalance(
          user1,
          metadata.toString()
        );
        const user2BalanceAfter = await getFaBalance(
          user2,
          metadata.toString()
        );

        // Assertions
        expect(user1BalanceAfter).toEqual(initialUser1Balance + amount_to_mint); // User1's balance should increase by amount_to_mint
        expect(user2BalanceAfter).toEqual(
          initialUser2Balance + amount_to_mint / 2
        ); // User2's balance should increase by half of amount_to_mint
      } catch (error) {
        console.log("Error occurred during bulk minting:", error);
      }
    }, 10000);

    it("Burn Coin", async () => {
      try {
        // Starting the process of burning coins
        console.log("Start burning coins...");

        // Get the initial balance of the user
        const metadata = await getMetadata(owner);
        const initialBalanceUser = await getFaBalance(
          user1,
          metadata.toString()
        );
        const initialBalanceUser2 = await getFaBalance(
          user2,
          metadata.toString()
        );

        if (initialBalanceUser2 < amount_To_Burn) {
          let mintCoinTransactionHash = await mintCoin(
            owner,
            user2.accountAddress,
            amount_to_mint,
            reward1,
            reward2,
            reward3
          );
          console.log("mintCoinTransactionHash", mintCoinTransactionHash);
        }

        // Burn coins from the user's account
        const burnCoinTransactionHash = await burnCoin(
          owner,
          user2.accountAddress,
          amount_To_Burn
        );

        // Get the final balance of the user after burning coins
        const finalBalanceUser = await getFaBalance(user1, metadata.toString());

        // Assert that the final balance is decreased by the amount burned
        expect(finalBalanceUser).toBe(initialBalanceUser - amount_To_Burn);
      } catch (error) {
        // Catch any errors that occur during the process
        console.log("Error occurred during burning coins:", error);
      }
    });
  });

  describe("kcash-transfer-coin", () => {
    it("Transfer Coins from user account to user account", async () => {
      try {
        console.log("Starting testing transfer coin");

        // Retrieve metadata address
        const metadataAddress = await getMetadata(owner);

        // Retrieve initial balances of users
        const initialBalanceuser1 = await getFaBalance(
          user1,
          metadataAddress.toString()
        );
        const initialBalanceuser2 = await getFaBalance(
          user2,
          metadataAddress.toString()
        );
        //check balance

        if (initialBalanceuser1 < amount_to_be_transfer) {
          const mintUser = await mintCoin(
            owner,
            user1.accountAddress,
            amount_to_mint,
            reward1,
            reward2,
            reward3
          );
          console.log("mithash", mintUser);
        }

        // Retrieve initial balances of users
        const initialBalanceuser11 = await getFaBalance(
          user1,
          metadataAddress.toString()
        );

        // Perform the transfer
        const transactionHash = await transferCoin(
          user1,
          user2.accountAddress,
          amount_to_be_transfer
        );
        console.log("Transaction hash:", transactionHash);

        // Retrieve final balances after the transfer
        const finalBalanceuser1 = await getFaBalance(
          user1,
          metadataAddress.toString()
        );
        const finalBalanceuser2 = await getFaBalance(
          user2,
          metadataAddress.toString()
        );

        // Assertions
        expect(transactionHash).toBeDefined();
        expect(typeof transactionHash).toBe("string");

        // Check if the balances changed correctly after the transfer
        expect(finalBalanceuser1).toBe(
          initialBalanceuser11 - amount_to_be_transfer
        );
        expect(finalBalanceuser2).toBe(
          initialBalanceuser2 + amount_to_be_transfer
        );
      } catch (error) {
        // Catch any errors that occur during the process
        console.log("Error while transferring coins:", error);
      }
    }, 10000);

    it("bulk transfer coin", async () => {
      try {
        console.log("Starting testing bulk transfer coin");

        // Retrieve metadata address
        const metadataAddress = await getMetadata(owner);

        // Retrieve initial balances for owner, user1, and user2
        const initialBalanceOwner1 = await getFaBalance(
          owner,
          metadataAddress.toString()
        );

        const initialBalanceUser1 = await getFaBalance(
          user1,
          metadataAddress.toString()
        );

        const initialBalanceUser2 = await getFaBalance(
          user2,
          metadataAddress.toString()
        );

        // Define the amount to be transferred in bulk
        const user_arr = [owner.accountAddress, user2.accountAddress];
        let amount_to_transfer_user1 = 100 * decimal_kcash;
        let amount_to_transfer_user2 = amount_to_transfer_user1 / 2;
        let amount_ar1 = [amount_to_transfer_user1, amount_to_transfer_user2];
        let amount_to_transfer =
          amount_to_transfer_user1 + amount_to_transfer_user2;

        if (initialBalanceUser1 < amount_to_transfer) {
          const mintUser = await mintCoin(
            owner,
            user1.accountAddress,
            amount_to_mint,
            reward1,
            reward2,
            reward3
          );
          console.log("mithash", mintUser);
        }

        // Retrieve initial balances for owner, user1, and user2
        const initialBalanceuser = await getFaBalance(
          user1,
          metadataAddress.toString()
        );

        // Perform the bulk transfer from user1 to user2 and user3
        const transactionHash = await transferCoinBulk(
          user1,
          user_arr, // Array of receiver addresses
          amount_ar1 // Amount to transfer to each receiver
        );

        // Retrieve final balances for owner, user1, and user2
        const finalBalanceOwner = await getFaBalance(
          owner,
          metadataAddress.toString()
        );
        const finalBalanceUser1 = await getFaBalance(
          user1,
          metadataAddress.toString()
        );
        const finalBalanceUser2 = await getFaBalance(
          user2,
          metadataAddress.toString()
        );

        const amount = amount_to_transfer_user1 + amount_to_transfer_user2;

        // Assertions
        // Check if the balances changed correctly after the bulk transfer
        expect(finalBalanceUser1).toBe(initialBalanceuser - amount_to_transfer); // 2 receivers, so deduct 2 * amountBulk from user1
        expect(finalBalanceOwner).toBe(
          initialBalanceOwner1 + amount_to_transfer_user1
        ); // Owner's balance should decrease by amountBulk
        expect(finalBalanceUser2).toBe(
          initialBalanceUser2 + amount_to_transfer_user2
        ); // User2's balance should increase by amountBulk
      } catch (error) {
        // Catch any errors that occur during the process
        console.log("Error while performing bulk transfer coin:", error);
      }
    }, 10000);
  });

  describe("admin- transfer", () => {
    it("admin Transfer from his buckets to user buckets", async () => {
      // Logging initial bucket store values for owner and user1
      console.log("owner bucket store :", await getBucketStore(owner));
      console.log("User1 bucket store :", await getBucketStore(user1));

      // Getting initial bucket store values for owner and user1
      let [ownerA, ownerB, ownerC] = await getBucketStore(owner);
      let [user1A, user1B, user1C] = await getBucketStore(user1);

      // Getting metadata and owner's KCash balance
      const metadata = await getMetadata(owner);
      let ownerBalance = await getFaBalance(owner, metadata.toString());

      // Define the total transfer amount
      let transfer_amount = 1 + 2 + 3;

      // Check if owner's KCash balance is sufficient for the transfer
      if (ownerBalance < transfer_amount) {
        // If owner's KCash balance is less than the transfer amount, mint KCash for the owner
        const mintUser = await mintCoin(
          owner,
          owner.accountAddress,
          amount_to_mint,
          reward1,
          reward2,
          reward3
        );
        console.log("Minted KCash for owner:", mintUser);
      }

      // Getting updated bucket store values for owner after minting
      let [owner1A, owner1B, owner1C] = await getBucketStore(owner);

      // Performing admin transfer
      const txt = await adminTransfer(
        owner,
        user1.accountAddress,
        [1, 2, 3], // Amounts to transfer from owner to user1's buckets
        [3, 1, 2] // Indexes of buckets for transfer (1, 2, 3) -> (Reward1, Reward2, Reward3)
      );
      console.log("Transaction hash of admin transfer:", txt);

      // Logging bucket store values after admin transfer for user1 and owner
      console.log("User1 bucket store :", await getBucketStore(user1));
      console.log("owner bucket store :", await getBucketStore(owner));

      // Getting bucket store values after admin transfer for user1 and owner
      let [ownerA1, ownerB1, ownerC1] = await getBucketStore(owner);
      let [user1A1, user1B1, user1C1] = await getBucketStore(user1);

      // Assertions
      expect(ownerA1).toBe(owner1A - 1); // Owner's Reward1 bucket should decrease by 1
      expect(ownerB1).toBe(owner1B - 2); // Owner's Reward2 bucket should decrease by 2
      expect(ownerC1).toBe(owner1C - 3); // Owner's Reward3 bucket should decrease by 3

      expect(user1A1).toBe(user1A + 3); // User1's Reward1 bucket should increase by 3
      expect(user1B1).toBe(user1B + 1); // User1's Reward2 bucket should increase by 1
      expect(user1C1).toBe(user1C + 2); // User1's Reward3 bucket should increase by 2
    }, 10000); // Timeout set to 10 seconds

    it("admin Transfer his bucket to users bucket  Bulk", async () => {
      // Retrieve initial bucket store balances
      const [initialOwnerA, initialOwnerB, initialOwnerC] =
        await getBucketStore(owner);
      const [initialUser1A, initialUser1B, initialUser1C] =
        await getBucketStore(user1);
      const [initialUser2A, initialUser2B, initialUser2C] =
        await getBucketStore(user2);
      const metadata = await getMetadata(owner);
      // Get owner's KCash balance
      let ownerBalance = await getFaBalance(owner, metadata.toString());

      // Define the total transfer amount
      let transfer_amount = 5 + 7 + 6;

      // Check if owner's KCash balance is sufficient for the transfer
      if (ownerBalance < transfer_amount) {
        // If owner's KCash balance is less than the transfer amount, mint KCash for the owner
        const mintUser = await mintCoin(
          owner,
          owner.accountAddress,
          amount_to_mint,
          reward1,
          reward2,
          reward3
        );
        console.log("Minted KCash for owner:", mintUser);
      }

      // Retrieve updated bucket store values for owner after minting
      const [initialOwner1A, initialOwner1B, initialOwner1C] =
        await getBucketStore(owner);

      // Performing admin bulk transfer
      const txt = await adminTransferBulk(
        owner,
        [user1.accountAddress, user2.accountAddress], // Array of receiver addresses
        [
          [1, 2, 3], // Amounts to transfer from owner to user1's buckets
          [4, 5, 3], // Amounts to transfer from owner to user2's buckets
        ],
        [
          [3, 1, 2], // Indexes of buckets for transfer to user1 (1, 2, 3) -> (Reward1, Reward2, Reward3)
          [6, 0, 6], // Indexes of buckets for transfer to user2 (1, 2, 3) -> (Reward1, Reward2, Reward3)
        ]
      );
      console.log("Transaction hash of admin bulk transfer:", txt);

      // Retrieve final bucket store balances
      const [finalOwnerA, finalOwnerB, finalOwnerC] =
        await getBucketStore(owner);
      const [finalUser1A, finalUser1B, finalUser1C] =
        await getBucketStore(user1);
      const [finalUser2A, finalUser2B, finalUser2C] =
        await getBucketStore(user2);

      // Assertions
      expect(finalOwnerA).toBe(initialOwner1A - (1 + 4)); // Owner's buckets should decrease by transferred amounts to user1 and user2
      expect(finalOwnerB).toBe(initialOwner1B - (2 + 5));
      expect(finalOwnerC).toBe(initialOwner1C - (3 + 3));

      expect(finalUser1A).toBe(initialUser1A + 3); // User1's buckets should increase by transferred amounts
      expect(finalUser1B).toBe(initialUser1B + 1);
      expect(finalUser1C).toBe(initialUser1C + 2);

      expect(finalUser2A).toBe(initialUser2A + 6); // User2's buckets should increase by transferred amounts
      expect(finalUser2B).toBe(initialUser2B + 0);
      expect(finalUser2C).toBe(initialUser2C + 6);
    }, 10000); // Timeout set to 10 seconds
  });

  describe("freeze and unfreeze functions", () => {
    it("should freeze the specified account and return the transaction hash", async () => {
      try {
        // Test freezing an account
        console.log("Testing freeze...");

        // Retrieve metadata address
        const metadata = await getMetadata(owner);

        // Retrieve the freeze status of the account before freezing
        const is_freeze_before = await getIs_freez(user1, metadata.toString());
        console.log("is_freeze_before", is_freeze_before);

        // Freeze the specified account
        const freezeTransactionHash = await freeze(owner, user1.accountAddress);

        // Retrieve the freeze status of the account after freezing
        const is_freeze_after = await getIs_freez(user1, metadata.toString());
        console.log("is_freeze_after", is_freeze_after);

        // Assertions
        expect(is_freeze_after).toBe(true); // Check if the account is frozen after the transaction
        expect(freezeTransactionHash).toBeDefined(); // Check if the transaction hash is defined
        expect(typeof freezeTransactionHash).toBe("string"); // Check if the transaction hash is a string
      } catch (error) {
        console.log("Error while freezing account:", error);
      }
    }, 10000);

    it("should unfreeze the specified account and return the transaction hash", async () => {
      try {
        // Test unfreezing an account
        console.log("Testing unfreeze...");

        // Retrieve metadata address
        const metadata = await getMetadata(owner);

        // Retrieve the freeze status of the account before unfreezing
        const is_freeze_before = await getIs_freez(user1, metadata.toString());
        console.log("is_freeze_before", is_freeze_before);

        // Unfreeze the specified account
        const unfreezeTransactionHash = await unfreeze(
          owner,
          user1.accountAddress
        );
        console.log("Unfreeze transaction hash:", unfreezeTransactionHash);

        // Retrieve the freeze status of the account after unfreezing
        const is_freeze_after = await getIs_freez(user1, metadata.toString());
        console.log("is_freeze_after", is_freeze_after);

        // Assertions
        expect(is_freeze_after).toBe(false); // Check if the account is unfrozen after the transaction
        expect(unfreezeTransactionHash).toBeDefined(); // Check if the transaction hash is defined
        expect(typeof unfreezeTransactionHash).toBe("string"); // Check if the transaction hash is a string
      } catch (error) {
        console.log("Error while unfreezing account:", error);
      }
    }, 10000);
  });

  describe("bucket-transfer three to one", () => {
    it("admin Transfer KCash From his Reward3 to user Reward1", async () => {
      // Retrieve initial bucket store balances for owner and user1
      let [ownerA, ownerB, ownerC] = await getBucketStore(owner);
      let [user1A, user1B, user1C] = await getBucketStore(user1);

      // Define the amount to transfer
      const transferKcash = 10 * decimal_kcash;

      // Check if owner's reward3 balance is sufficient for the transfer
      if (ownerC < transferKcash) {
        // If owner's reward3 balance is less than the transfer amount, mint KCash for the owner
        const mintUser = await mintCoin(
          owner,
          owner.accountAddress,
          amount_to_mint,
          reward1,
          reward2,
          reward3
        );
        console.log("Minted KCash for owner:", mintUser);
      }

      // Get owner's bucket store details before the transfer
      let [owner1A, owner1B, owner1C] = await getBucketStore(owner);

      // Perform the transfer of rewards from owner's reward3 to user1's reward1
      let rew2Tx = await transferReward3ToReward1ByAdminOnly(
        owner,
        user1.accountAddress,
        transferKcash
      );
      console.log("Transaction hash of the transfer:", rew2Tx);

      // Validate bucket stores after transfer
      let [ownerA1, ownerB1, ownerC1] = await getBucketStore(owner);
      let [user1A1, user1B2, user1C3] = await getBucketStore(user1);

      // Assert the changes in bucket stores
      expect(ownerC1).toEqual(owner1C - 10 * decimal_kcash); // Owner's reward3 balance should decrease by transferKcash
      expect(user1A1).toEqual(user1A + 10 * decimal_kcash); // User1's reward1 balance should increase by transferKcash
      expect(rew2Tx).toBeDefined(); // Check if the transaction hash is defined, indicating a successful transfer
    }, 20000);

    it("admin Transfer KCash From his Reward3 to user Reward1 in bulk", async () => {
      // Retrieve initial bucket store balances for owner, user1, and user2
      let [ownerA, ownerB, ownerC] = await getBucketStore(owner);
      let [user1A, user1B, user1C] = await getBucketStore(user1);
      let [user2A, user2B, user2C] = await getBucketStore(user2);

      // Define the amounts to transfer to each user
      const transferKcash1 = 10 * decimal_kcash;
      const transferKcash2 = 20 * decimal_kcash;
      const amountbulk_arr = [transferKcash1, transferKcash2];
      const amount_transfer = transferKcash1 + transferKcash2;

      // Check if owner's reward3 balance is sufficient for the transfer
      if (ownerC < amount_transfer) {
        // If owner's reward3 balance is less than the total transfer amount, mint KCash for the owner
        const mintUser = await mintCoin(
          owner,
          owner.accountAddress,
          amount_to_mint,
          reward1,
          reward2,
          reward3
        );
        console.log("Minted KCash for owner:", mintUser);
      }

      // Get owner's bucket store details before the transfer
      let [owner1A, owner1B, owner1C] = await getBucketStore(owner);

      // Perform the transfer of rewards from owner's reward3 to user1 and user2's reward1 in bulk
      let rew2Tx = await transferReward3ToReward1ByAdminOnlyInBulk(
        owner,
        receiver_ar,
        amountbulk_arr
      );
      console.log("Transaction hash of the transfer:", rew2Tx);

      // Validate bucket stores after transfer
      console.log("Bucket store for owner:", await getBucketStore(owner));
      console.log("Bucket store for user1:", await getBucketStore(user1));
      console.log("Bucket store for user2:", await getBucketStore(user2));

      // Get bucket store details after the transfer
      let [ownerA1, ownerB1, ownerC1] = await getBucketStore(owner);
      let [user1A2, user1B2, user1C3] = await getBucketStore(user1);
      let [user2A3, user2B3, user2C3] = await getBucketStore(user2);

      // Assert the changes in bucket stores
      const ownerExpected = ownerC - 30 * decimal_kcash;
      expect(ownerC1).toEqual(owner1C - 30 * decimal_kcash); // Owner's reward3 balance should decrease by the total transfer amount
      expect(user1A2).toEqual(user1A + 10); // User1's reward1 balance should increase by transferKcash1
      expect(user2A3).toEqual(user2A + 20 * decimal_kcash); // User2's reward1 balance should increase by transferKcash2
      expect(rew2Tx).toBeDefined(); // Check if the transaction hash is defined, indicating a successful transfer
    }, 20000);
  });

  describe("bucket-transfer three to two", () => {
    it("admin Transfer KCash From his Reward3 to user Reward2 ", async () => {
      // Retrieve initial bucket store balances for owner and user1
      let [ownerA, ownerB, ownerC] = await getBucketStore(owner);
      let [user1A, user1B, user1C] = await getBucketStore(user1);

      // Define the amount of KCash to transfer
      const transferKcash = 10 * decimal_kcash;

      // Check if owner's reward3 balance is sufficient for the transfer
      if (ownerC < transferKcash) {
        // If owner's reward3 balance is less than the transfer amount, mint KCash for the owner
        const mintUser = await mintCoin(
          owner,
          owner.accountAddress,
          amount_to_mint,
          reward1,
          reward2,
          reward3
        );
        console.log("Minted KCash for owner:", mintUser);
      }

      // Get owner's bucket store details before the transfer
      let [owner1A, owner1B, owner1C] = await getBucketStore(owner);

      // Perform the transfer of rewards from owner's reward3 to user1's reward2
      let rew2Tx = await transferReward3ToReward2ByAdminOnly(
        owner,
        user1.accountAddress,
        transferKcash
      );
      console.log("Transaction hash of the transfer:", rew2Tx);

      // Validate bucket stores after transfer
      let [ownerA1, ownerB1, ownerC1] = await getBucketStore(owner);
      let [user1A1, user1B2, user1C3] = await getBucketStore(user1);

      // Assert the changes in bucket stores
      expect(owner1C - 10 * decimal_kcash).toEqual(ownerC1); // Owner's reward3 balance should decrease by transferKcash
      expect(user1B + 10 * decimal_kcash).toEqual(user1B2); // User1's reward2 balance should increase by transferKcash
      expect(rew2Tx).toBeDefined(); // Check if the transaction hash is defined, indicating a successful transfer
    }, 10000);

    it("admin Transfer KCash From his Reward3 to user Reward2 in bulk", async () => {
      // Retrieve initial bucket store balances for owner, user1, and user2
      let [ownerA, ownerB, ownerC] = await getBucketStore(owner);
      let [user1A, user1B, user1C] = await getBucketStore(user1);
      let [user2A, user2B, user2C] = await getBucketStore(user2);

      // Define the amounts to transfer to each user
      const transferKcash1 = 10 * decimal_kcash;
      const transferKcash2 = 20 * decimal_kcash;
      const amountbulk_arr = [transferKcash1, transferKcash2];
      const amount_transfer = transferKcash1 + transferKcash2;

      // Check if owner's reward3 balance is sufficient for the transfer
      if (ownerC < amount_transfer) {
        // If owner's reward3 balance is less than the total transfer amount, mint KCash for the owner
        const mintUser = await mintCoin(
          owner,
          owner.accountAddress,
          amount_to_mint,
          reward1,
          reward2,
          reward3
        );
        console.log("Minted KCash for owner:", mintUser);
      }

      // Get owner's bucket store details before the transfer after minting
      let [owner1A, owner1B, owner1C] = await getBucketStore(owner);

      // Perform the transfer of rewards from owner's reward3 to user1 and user2's reward2 in bulk
      let rew2Tx = await transferReward3ToReward2ByAdminOnlyInBulk(
        owner,
        [user1.accountAddress, user2.accountAddress], // Array of receiver addresses
        amountbulk_arr // Amount to transfer to each receiver
      );
      console.log("Transaction hash of the transfer:", rew2Tx);

      // Validate bucket stores after transfer
      let [ownerA1, ownerB1, ownerC1] = await getBucketStore(owner);
      let [user1A1, user1B1, user1C1] = await getBucketStore(user1);
      let [user2A1, user2B1, user2C1] = await getBucketStore(user2);

      // Assertions
      const ownerExpected = transferKcash1 + transferKcash2;
      const expectedUser1B = user1B + transferKcash1;
      const expectedUser2B = user2B + transferKcash2;

      // Assert the changes in bucket stores
      expect(ownerC1).toEqual(owner1C - ownerExpected); // Owner's reward3 balance should decrease by the total transfer amount
      expect(user1B1).toEqual(expectedUser1B); // User1's reward2 balance should increase by transferKcash1
      expect(user2B1).toEqual(expectedUser2B); // User2's reward2 balance should increase by transferKcash2
      expect(rew2Tx).toBeDefined(); // Check if the transaction hash is defined, indicating a successful transfer
    }, 10000);
  });

  describe("bucket-transfer three to three", () => {
    it("admin Transfer KCash From user Reward3 to user Reward3", async () => {
      // Get initial bucket store values for user1 and user2
      let [user1A, user1B, user1C] = await getBucketStore(user1);
      console.log(
        "Initial bucket store for user1:",
        await getBucketStore(user1)
      );
      let [user2A, user2B, user2C] = await getBucketStore(user2);

      // Get metadata
      const metadata = await getMetadata(owner);

      // Get user1's KCash balance and bucket store details
      const user1balance = await getFaBalance(user1, metadata.toString());
      console.log("User1's KCash balance:", user1balance);
      console.log("User1's bucket store:", await getBucketStore(user1));

      // Define transfer amount
      const transferKcash = 10 * decimal_kcash;

      // Check if user1 has enough KCash in bucket 3 for transfer
      if (user1C < transferKcash) {
        // If user1's bucket 3 balance is not sufficient, mint KCash
        const mintUser = await mintCoin(
          owner,
          user1.accountAddress,
          amount_to_mint,
          reward1,
          reward2,
          reward3
        );
        console.log("Minted KCash for user1:", mintUser);
      }

      // Get user1's bucket store details after potential minting
      let [user1A2, user1B2, user1C2] = await getBucketStore(user1);

      // Perform the transfer from user1's Reward3 to user2's Reward3
      let rew2Tx = await transferFromReward3ToReward3(
        user1,
        user2.accountAddress,
        transferKcash
      );
      console.log("Transaction hash of the transfer:", rew2Tx);
      expect(rew2Tx).toBeDefined();

      // Validate bucket stores after transfer
      let [user1A1, user1B1, user1C1] = await getBucketStore(user1);
      console.log(
        "Updated bucket store for user1:",
        await getBucketStore(user1)
      );

      let [user2A1, user2B1, user2C1] = await getBucketStore(user2);

      // Assert the changes in bucket stores
      expect(user1C1).toEqual(user1C2 - transferKcash); // User1's bucket 3 should decrease by transferKcash
      expect(user2C1).toEqual(user2C + transferKcash); // User2's bucket 3 should increase by transferKcash
    }, 10000);

    it("transfer from user1's reward3 to multiple users' reward3, bulk", async () => {
      // Retrieve initial bucket store balances for user1, owner, and user2
      let [user1A, user1B, user1C] = await getBucketStore(user1);
      let [ownerA, ownerB, ownerC] = await getBucketStore(owner);
      let [user2A, user2B, user2C] = await getBucketStore(user2);

      // Define the total amount of KCash to transfer
      const transferKcash = 10 + 2;

      // Check if user1 has enough KCash in reward3 bucket
      if (user1C < transferKcash) {
        // If user1's reward3 balance is less than the total transfer amount, mint KCash
        const mintUser = await mintCoin(
          owner,
          user1.accountAddress,
          amount_to_mint,
          reward1,
          reward2,
          reward3
        );
        console.log("Minted KCash for user1:", mintUser);
      }

      // Get user1's bucket store details before the transfer
      let [user11A, user11B, user11C] = await getBucketStore(user1);

      // Transfer rewards from user1's reward3 to multiple users' reward3 in bulk
      let rew3Tx = await transferFromReward3ToReward3Bulk(
        user1,
        [owner.accountAddress, user2.accountAddress], // Array of receiver addresses
        [10, 2] // Amount to transfer to each receiver
      );
      console.log("Transaction hash of the transfer:", rew3Tx);

      // Validate bucket stores after transfer
      let [user1A1, user1B1, user1C1] = await getBucketStore(user1);
      let [ownerA1, ownerB1, ownerC1] = await getBucketStore(owner);
      let [user2A1, user2B1, user2C1] = await getBucketStore(user2);

      // Assert the changes in bucket stores
      expect(user11C - (10 + 2)).toEqual(user1C1); // User1's reward3 bucket should decrease by 10 + 2
      expect(ownerC + 10).toEqual(ownerC1); // Owner's reward3 bucket should increase by 10
      expect(user2C + 2).toEqual(user2C1); // User2's reward3 bucket should increase by 2
      expect(rew3Tx).toBeDefined(); // Check if the transaction hash is defined, indicating a successful transfer
    }, 10000);
  });

  describe("transfer From Bucket To Reward", () => {
    it("transfer From user Bucket To user Reward3", async () => {
      // Retrieve initial bucket store balances for user1 and user2
      let [user1A, user1B, user1C] = await getBucketStore(user1);
      let [user2A, user2B, user2C] = await getBucketStore(user2);

      // Define the total amount of KCash to transfer
      let transferKcash = 10 + 10 + 5;

      // Check if user1 has enough KCash in buckets
      let totalAvailable = user1A + user1B + user1C;

      // If the total available KCash in user1's buckets is less than the transfer amount, mint the required amount
      if (totalAvailable < transferKcash) {
        const mintUser = await mintCoin(
          owner,
          user1.accountAddress,
          amount_to_mint,
          reward1,
          reward2,
          reward3
        );
      }

      // Retrieve the bucket store balances again after potential minting
      let [user11A, user11B, user11C] = await getBucketStore(user1);
      let [user22A, user22B, user22C] = await getBucketStore(user2);

      // Perform the transfer from bucket to Reward3 for user1 to user2
      let tb3Tx = await transferFromBucketToReward3(
        user1,
        user2.accountAddress,
        [10, 10, 5] // Amounts to transfer from each bucket
      );

      // Retrieve final bucket store balances after the transfer
      let [user1A1, user1B1, user1C1] = await getBucketStore(user1);
      let [user2A1, user2B1, user2C1] = await getBucketStore(user2);

      // Assertions
      expect(user1A1).toBe(user11A - 10); // Check if 10 is deducted from user1A
      expect(user1B1).toBe(user11B - 10); // Check if 10 is deducted from user1B
      expect(user1C1).toBe(user11C - 5); // Check if 5 is deducted from user1C
      expect(user2C1).toBe(user22C + 25); // Check if the total amount (10+10+5) is added to user2C
    });

    it("transfer From user1 Bucket to other users bucket Reward3 Bulk", async () => {
      // Retrieve initial bucket store balances for user1, owner, and user2
      let [user1A, user1B, user1C] = await getBucketStore(user1);
      let [ownerA, ownerB, ownerC] = await getBucketStore(owner);
      let [user2A, user2B, user2C] = await getBucketStore(user2);

      // Define transfer amounts for each bucket
      let transferAmounts = [
        [1, 10, 5], // Amounts to transfer from user1's buckets to owner and user2
        [10, 1, 5], // Amounts to transfer from user1's buckets to owner and user2
      ];

      // Check if user1 has enough KCash in buckets
      let totalAvailable = user1A + user1B + user1C;

      // Define the total amount of KCash to transfer
      let transferKcash = 11 + 11 + 10;

      // If the total available KCash in user1's buckets is less than the transfer amount, mint the required amount
      if (totalAvailable < transferKcash) {
        const mintUser = await mintCoin(
          owner,
          user1.accountAddress,
          amount_to_mint,
          reward1,
          reward2,
          reward3
        );
      }

      // Retrieve the bucket store balances again after potential minting
      let [user11A, user11B, user11C] = await getBucketStore(user1);
      let [owner1A, owner1B, owner1C] = await getBucketStore(owner);
      let [user22A, user22B, user22C] = await getBucketStore(user2);

      // Perform the bulk transfer from bucket to Reward3 for user1 to owner and user2
      let tb3Tx = await transferFromBucketToReward3Bulk(
        user1,
        [owner.accountAddress, user2.accountAddress],
        transferAmounts
      );

      // Retrieve final bucket store balances after the transfer
      let [user1A1, user1B1, user1C1] = await getBucketStore(user1);
      let [ownerA1, ownerB1, ownerC1] = await getBucketStore(owner);
      let [user2A1, user2B1, user2C1] = await getBucketStore(user2);

      // Assertions
      expect(user1A1).toBe(user11A - (10 + 1)); // Check if 10 is deducted from user1A
      expect(user1B1).toBe(user11B - (1 + 10)); // Check if 10 is deducted from user1B
      expect(user1C1).toBe(user11C - (5 + 5)); // Check if 5 is deducted from user1C
      expect(ownerC1).toBe(owner1C + 16); // Check if the total amount (1+10+5) is added to owner's C bucket
      expect(user2C1).toBe(user22C + 16); // Check if the total amount (10+1+5) is added to user2's C bucket
    }, 10000);
  });

  describe("admin Transer With Signature", () => {
    it("adminTransferWithSignature", async () => {
      let nonce = await getNonce(owner);

      // Create a message and calculate its hash
      const moveStruct = new MessageMoveStruct(
        owner.accountAddress,
        user2.accountAddress,
        deductionFromSender,
        additionToRecipient,
        "admin_transfer_with_signature",
        new Uint64(BigInt(nonce))
      );

      // Construct a MoveStruct
      const moveStructBytes = moveStruct.bcsToBytes();
      const messageMoveStructHash = sha256(moveStructBytes);

      // Sign the message hash using the owner's private key
      const signature = await signMessage(
        privateKeyOwner,
        messageMoveStructHash
      );
      // console.log("signature", signature);

      // Retrieve initial bucket store balances
      console.log("owner", await getBucketStore(owner));
      console.log("user2", await getBucketStore(user2));
      let [ownerA, ownerB, ownerC] = await getBucketStore(owner);
      let [user2A, user2B, user2C] = await getBucketStore(user2);

      // Call adminTransferWithSignature function
      let adminSignatureTx = await adminTransferWithSignature(
        owner,
        user2.accountAddress,
        [10, 20, 30],
        [10, 20, 30],
        signature
      );
      console.log("🚀 ~ adminSignatureTx:", adminSignatureTx);

      // Retrieve final bucket store balances
      let [ownerA1, ownerB1, ownerC1] = await getBucketStore(owner);
      let [user2A2, user2B2, user2C2] = await getBucketStore(user2);
      console.log("owner", await getBucketStore(owner));
      console.log("user2", await getBucketStore(user2));

      // Assertions
      expect(ownerA1).toEqual(ownerA - 10); // Check if 1 is deducted from ownerA
      expect(ownerB1).toEqual(ownerB - 20); // Check if 2 is deducted from ownerB
      expect(ownerC1).toEqual(ownerC - 30); // Check if 3 is deducted from ownerC

      expect(user2A2).toEqual(user2A + 10); // Check if 3 is added to user2A
      expect(user2B2).toEqual(user2B + 20); // Check if 1 is added to user2B
      expect(user2C2).toEqual(user2C + 30); // Check if 2 is added to user2C
    }, 10000);

    it("admin Transfer With Signature bulk", async () => {
      console.log("starding........");

      let nonceForBulk = await getNonce(owner);

      let msgStruct = await createStructForAdminTransferSigBulk(
        owner.accountAddress,
        [user1.accountAddress, user2.accountAddress, user3.accountAddress],
        [new Uint64(BigInt(1)), new Uint64(BigInt(1)), new Uint64(BigInt(1))],
        [new Uint64(BigInt(1)), new Uint64(BigInt(1)), new Uint64(BigInt(1))],
        [new Uint64(BigInt(1)), new Uint64(BigInt(1)), new Uint64(BigInt(1))],
        [new Uint64(BigInt(1)), new Uint64(BigInt(1)), new Uint64(BigInt(1))],
        [new Uint64(BigInt(1)), new Uint64(BigInt(1)), new Uint64(BigInt(1))],
        [new Uint64(BigInt(1)), new Uint64(BigInt(1)), new Uint64(BigInt(1))],
        "admin_transfer_with_signature_bulk",
        new Uint64(BigInt(nonceForBulk))
      );

      let msgBytes = msgStruct.bcsToBytes();
      let msgHash = sha256(msgBytes);
      let sign = await signMessage(privateKeyOwner, msgHash);

      let [owner_initial_r1, owner_initial_r2, owner_initial_r3] =
        await getBucketStore(owner);
      let [user1_initial_r1, user1_initial_r2, user1_initial_r3] =
        await getBucketStore(user1);
      let [user2_initial_r1, user2_initial_r2, user2_initial_r3] =
        await getBucketStore(user2);
      let [user3_initial_r1, user3_initial_r2, user3_initial_r3] =
        await getBucketStore(user3);

      let [to_mint1, to_mint2, to_mint3] = [0, 0, 0];

      if (owner_initial_r1 < 3) {
        to_mint1 = 3 - owner_initial_r1;
      }
      if (owner_initial_r2 < 3) {
        to_mint2 = 3 - owner_initial_r2;
      }
      if (owner_initial_r3 < 3) {
        to_mint3 = 3 - owner_initial_r3;
      }

      if (to_mint1 + to_mint2 + to_mint3 > 0) {
        await mintCoin(
          owner,
          owner.accountAddress,
          to_mint1 + to_mint2 + to_mint3,
          to_mint1,
          to_mint2,
          to_mint3
        );
        [owner_initial_r1, owner_initial_r2, owner_initial_r3] =
          await getBucketStore(owner);
      }

      let tx = await adminTransferWithSignatureBulk(
        owner,
        [user1.accountAddress, user2.accountAddress, user3.accountAddress],
        [1, 1, 1],
        [1, 1, 1],
        [1, 1, 1],
        [1, 1, 1],
        [1, 1, 1],
        [1, 1, 1],
        sign
      );
      console.log("transaction: ", tx);

      let [owner_final_r1, owner_final_r2, owner_final_r3] =
        await getBucketStore(owner);
      let [user1_final_r1, user1_final_r2, user1_final_r3] =
        await getBucketStore(user1);
      let [user2_final_r1, user2_final_r2, user2_final_r3] =
        await getBucketStore(user2);
      let [user3_final_r1, user3_final_r2, user3_final_r3] =
        await getBucketStore(user3);

      // Assertions
      expect(owner_final_r1).toEqual(owner_initial_r1 - 3); // Check if 1 is deducted from owner
      expect(owner_final_r2).toEqual(owner_initial_r2 - 3); // Check if 1 is deducted from owner
      expect(owner_final_r3).toEqual(owner_initial_r3 - 3); // Check if 1 is deducted from owner

      expect(user1_final_r1).toEqual(user1_initial_r1 + 1); // Check if 1 is added to user1
      expect(user1_final_r2).toEqual(user1_initial_r2 + 1); // Check if 1 is added to user1
      expect(user1_final_r3).toEqual(user1_initial_r3 + 1); // Check if 1 is added to user1

      expect(user2_final_r1).toEqual(user2_initial_r1 + 1); // Check if 1 is added to user2
      expect(user2_final_r2).toEqual(user2_initial_r2 + 1); // Check if 1 is added to user2
      expect(user2_final_r3).toEqual(user2_initial_r3 + 1); // Check if 1 is added to user2

      expect(user3_final_r1).toEqual(user3_initial_r1 + 1); // Check if 1 is added to user3
      expect(user3_final_r2).toEqual(user3_initial_r2 + 1); // Check if 1 is added to user3
      expect(user3_final_r3).toEqual(user3_initial_r3 + 1); // Check if 1 is added to user3
    }, 20000);

    it("transfer user Reward3 To  Reward1 With Sign", async () => {
      try {
        // Get the nonce for user1
        let nonce = await getNonce(user1);

        // Create the message struct for the transfer operation
        let userMoveStruct = await createStructForMsg(
          user1.accountAddress, // Sender address
          user2.accountAddress, // Receiver address
          new Uint64(BigInt(10)), // Amount to transfer
          "transfer_reward3_to_reward1", // Operation type
          new Uint64(BigInt(nonce)) // Nonce
        );

        // Convert the message struct to bytes and hash it
        const userMoveStructBytes = userMoveStruct.bcsToBytes();
        const usermsghash = sha256(userMoveStructBytes);

        // Sign the hashed message with user1's private key
        let signForUser = await signMessage(privateKeyOwner, usermsghash);

        // Get the current bucket store values for user1 and user2 before transfer
        let [user1A, user1B, user1C] = await getBucketStore(user1);
        console.log("User1 initial bucket store:", await getBucketStore(user1));
        let [user2A, user2B, user2C] = await getBucketStore(user2);
        console.log("User2 initial bucket store:", await getBucketStore(user2));

        // If user1's reward3 balance is less than 10, mint more coins
        if (user1C < 10) {
          const mintUser = await mintCoin(
            owner,
            user1.accountAddress,
            amount_to_mint,
            reward1,
            reward2,
            reward3
          );
        }

        // Transfer reward3 to reward1 with signature
        let tx = await transferReward3ToReward1WithSign(
          user1,
          user2.accountAddress,
          10,
          signForUser
        );

        // Get the updated bucket store values for user1 and user2 after transfer
        let [user1A2, user1B2, user1C2] = await getBucketStore(user1);
        let [user2A3, user2B3, user2C3] = await getBucketStore(user2);

        // Assert that the balances are updated correctly
        expect(user1C2).toEqual(user1C - 10); // User1's reward3 balance decreased by 10
        expect(user2A3).toEqual(user2A + 10); // User2's reward1 balance increased by 10
      } catch (error) {
        // Log any errors that occur during the process
        console.log("error", error);
      }
    }, 10000);

    it("transfer Reward3 To Reward1 Bulk With Sign", async () => {
      try {
        // Get the nonce for user1
        let nonce2 = await getNonce(user1);

        // Define the amount vector for the bulk transfer
        let amount_vec = [new Uint64(BigInt(1)), new Uint64(BigInt(2))];

        // Create the message struct for the bulk transfer operation
        let userMoveStructBulk = await createStructForMsgBulk(
          user1.accountAddress,
          [user2.accountAddress, owner.accountAddress], // Pass the recipient addresses in an array
          amount_vec,
          "transfer_reward3_to_reward1_bulk",
          new Uint64(BigInt(nonce2))
        );
        console.log("🚀 ~ userMoveStruct:", userMoveStructBulk);

        // Convert the message struct to bytes and hash it
        let userMsgBytesBulk = userMoveStructBulk.bcsToBytes();
        const msghash = sha256(userMsgBytesBulk);

        // Sign the hashed message with owner's private key
        const signBulk = await signMessage(privateKeyOwner, msghash);

        // Get the initial bucket store values for user1, user2, and owner
        let [user1A, user1B, user1C] = await getBucketStore(user1);
        console.log(
          "User1 initial bucket store :",
          await getBucketStore(user1)
        );

        let [user2A, user2B, user2C] = await getBucketStore(user2);
        console.log(
          "User2 initial bucket store :",
          await getBucketStore(user2)
        );

        let [ownerA, ownerB, ownerC] = await getBucketStore(owner);
        console.log(
          "Owner initial bucket store :",
          await getBucketStore(owner)
        );

        // Calculate the total amount to transfer
        let transferKcash = 1 + 2;

        // If user1's reward3 balance is less than the total transfer amount, mint more coins
        if (user1C < transferKcash) {
          const mintUser = await mintCoin(
            owner,
            user1.accountAddress,
            amount_to_mint,
            reward1,
            reward2,
            reward3
          );
          console.log("mithash", mintUser);
        }

        // Get the initial bucket store values after possible minting
        let [user11A, user11B, user11C] = await getBucketStore(user1);
        console.log(
          "User1 initial bucket store after possible minting :",
          await getBucketStore(user1)
        );

        let [user22A, user22B, user22C] = await getBucketStore(user2);
        console.log(
          "User2 initial bucket store after possible minting :",
          await getBucketStore(user2)
        );

        let [owner1A, owner1B, owner1C] = await getBucketStore(owner);
        console.log(
          "Owner initial bucket store after possible minting :",
          await getBucketStore(owner)
        );

        // Perform the bulk transfer of reward3 to reward1 with signature
        let tx1_bulk = await transferReward3ToReward1BulkWithSign(
          user1,
          [user2.accountAddress, owner.accountAddress],
          [1, 2], // Pass the amounts to transfer in an array
          signBulk
        );
        console.log("🚀 ~ tx1_bulk:", tx1_bulk);

        // Get the updated bucket store values for user1, user2, and owner after the transfer
        let [user1A1, user1B1, user1C1] = await getBucketStore(user1);
        console.log(
          "User1 after transfer bucket store :",
          await getBucketStore(user1)
        );

        let [user2A3, user23B, user2C3] = await getBucketStore(user2);
        console.log(
          "User2 after transfer bucket store :",
          await getBucketStore(user2)
        );

        let [ownerA2, ownerB2, ownerC2] = await getBucketStore(owner);
        console.log(
          "Owner after transfer bucket store :",
          await getBucketStore(owner)
        );

        // Assert that the balances are updated correctly
        expect(user1C1).toEqual(user11C - (1 + 2)); // User1's reward3 balance decreased by the total transfer amount
        expect(user2A3).toEqual(user22A + 1); // User2's reward1 balance increased by the first transfer amount
        expect(ownerA2).toEqual(owner1A + 2); // Owner's reward1 balance increased by the second transfer amount
      } catch (error) {
        // Log any errors that occur during the process
        console.log("error", error);
      }
    }, 30000);

    it("transfer Reward3 To Reward2 With Sign", async () => {
      try {
        // Get the nonce for user1
        let nonce = await getNonce(user1);

        // Create the message struct for the transfer operation
        let userMoveStruct = await createStructForMsg(
          user1.accountAddress,
          user2.accountAddress,
          new Uint64(BigInt(10)), // Specify the amount to transfer
          "transfer_reward3_to_reward2",
          new Uint64(BigInt(nonce))
        );

        // Convert the message struct to bytes and hash it
        const userMoveStructBytes = userMoveStruct.bcsToBytes();
        const usermsghash = sha256(userMoveStructBytes);

        // Sign the hashed message with owner's private key
        let signForUser = await signMessage(privateKeyOwner, usermsghash);

        // Get the initial bucket store values for user1 and user2
        let [user1A, user1B, user1C] = await getBucketStore(user1);
        console.log(
          "User1 initial bucket store :",
          await getBucketStore(user1)
        );

        let [user2A, user2B, user2C] = await getBucketStore(user2);
        console.log(
          "User2 initial bucket store :",
          await getBucketStore(user2)
        );

        // If user1's reward3 balance is less than the transfer amount, mint more coins
        if (user1C < 10) {
          const mintUser = await mintCoin(
            owner,
            user1.accountAddress,
            amount_to_mint,
            reward1,
            reward2,
            reward3
          );
        }

        // Get the initial bucket store values after possible minting
        let [user11A, user11B, user11C] = await getBucketStore(user1);
        console.log(
          "User1 initial bucket store after possible minting :",
          await getBucketStore(user1)
        );

        let [user22A, user22B, user22C] = await getBucketStore(user2);
        console.log(
          "User2 initial bucket store after possible minting :",
          await getBucketStore(user2)
        );

        // Perform the transfer of reward3 to reward2 with signature
        let tx2 = await transferReward3ToReward2WithSign(
          user1,
          user2.accountAddress,
          10, // Specify the amount to transfer
          signForUser
        );
        console.log("🚀 ~ tx:", tx2);

        // Get the updated bucket store values for user1 and user2 after the transfer
        let [user1A1, user1B1, user1C1] = await getBucketStore(user1);
        console.log(
          "User1 after transfer bucket store :",
          await getBucketStore(user1)
        );

        let [user2A3, user23B, user2C3] = await getBucketStore(user2);
        console.log(
          "User2 after transfer bucket store :",
          await getBucketStore(user2)
        );

        // Assert that the balances are updated correctly
        expect(user1C1).toEqual(user11C - 10); // User1's reward3 balance decreased by the transfer amount
        expect(user23B).toEqual(user22B + 10); // User2's reward2 balance increased by the transfer amount
      } catch (error) {
        // Log any errors that occur during the process
        console.log("error", error);
      }
    }, 10000);

    it("transfer Reward3 To Reward2 Bulk With Sign", async () => {
      try {
        // Get the nonce for user1
        let nonce2 = await getNonce(user1);

        // Specify the amounts to transfer for each recipient
        let amount_vec = [new Uint64(BigInt(1)), new Uint64(BigInt(2))];

        // Create the message struct for the bulk transfer operation
        let userMoveStructBulk = await createStructForMsgBulk(
          user1.accountAddress,
          [user2.accountAddress, owner.accountAddress], // Specify the recipient addresses
          amount_vec, // Specify the amounts to transfer for each recipient
          "transfer_reward3_to_reward2_bulk", // Specify the function name
          new Uint64(BigInt(nonce2)) // Specify the nonce
        );

        // Convert the message struct to bytes and hash it
        let userMsgBytesBulk = userMoveStructBulk.bcsToBytes();
        const msghash = sha256(userMsgBytesBulk);

        // Sign the hashed message with owner's private key
        const signBulk = await signMessage(privateKeyOwner, msghash);

        // Get the initial bucket store values for user1, user2, and owner
        let [user1A, user1B, user1C] = await getBucketStore(user1);
        console.log(
          "User1 initial bucket store :",
          await getBucketStore(user1)
        );

        let [user2A, user2B, user2C] = await getBucketStore(user2);
        console.log(
          "User2 initial bucket store :",
          await getBucketStore(user2)
        );

        let [ownerA, ownerB, ownerC] = await getBucketStore(owner);
        console.log(
          "Owner initial bucket store :",
          await getBucketStore(owner)
        );

        let transferKcash = 1 + 2;

        // If user1's reward3 balance is less than the total transfer amount, mint more coins
        if (user1C < transferKcash) {
          const mintUser = await mintCoin(
            owner,
            user1.accountAddress,
            amount_to_mint,
            reward1,
            reward2,
            reward3
          );
          console.log("mithash", mintUser);
        }

        // Get the updated bucket store values for user1, user2, and owner after possible minting
        let [user11A, user11B, user11C] = await getBucketStore(user1);
        console.log(
          "User1 initial bucket store after possible minting :",
          await getBucketStore(user1)
        );

        let [user22A, user22B, user22C] = await getBucketStore(user2);
        console.log(
          "User2 initial bucket store after possible minting :",
          await getBucketStore(user2)
        );

        let [ownerA1, ownerB1, ownerC1] = await getBucketStore(owner);
        console.log(
          "Owner initial bucket store after possible minting :",
          await getBucketStore(owner)
        );

        // Perform the bulk transfer of reward3 to reward2 with signature
        let tx2_bulk = await transferReward3ToReward2BulkWithSign(
          user1,
          [user2.accountAddress, owner.accountAddress], // Specify the recipient addresses
          [1, 2], // Specify the amounts to transfer for each recipient
          signBulk // Specify the signature
        );

        // Get the updated bucket store values for user1, user2, and owner after the bulk transfer
        let [user1A1, user1B1, user1C1] = await getBucketStore(user1);
        console.log(
          "User1 after transfer bucket store :",
          await getBucketStore(user1)
        );

        let [user2A3, user23B, user2C3] = await getBucketStore(user2);
        console.log(
          "User2 after transfer bucket store :",
          await getBucketStore(user2)
        );

        let [ownerA2, ownerB2, ownerC2] = await getBucketStore(owner);
        console.log(
          "Owner after transfer bucket store :",
          await getBucketStore(owner)
        );

        // Assert that the balances are updated correctly
        expect(user1C1).toEqual(user11C - (1 + 2)); // User1's reward3 balance decreased by the total transfer amount
        expect(user23B).toEqual(user22B + 1); // User2's reward2 balance increased by the first transfer amount
        expect(ownerB2).toEqual(ownerB1 + 2); // Owner's reward2 balance increased by the second transfer amount
      } catch (error) {
        // Log any errors that occur during the process
        console.log("error", error);
      }
    }, 30000);
  });

  describe("add Minter Role", () => {
    it("add Minter Role", async () => {
      try {
        // Get the current minter list before adding the new minter role
        const get_minter_list = await getMinterList();

        // Add minter role to user2 and receive transaction result
        let adMint = await addMinterRole(owner, user2.accountAddress);

        // Get the minter list after adding the new minter role
        const get_minter_list_after = await getMinterList();

        // Assert that the transaction result is defined, indicating a successful transaction
        expect(adMint).toBeDefined();
      } catch (error) {
        // Log any errors that occur during the process
        // console.log("error", error);
      }
    });
  });

  describe("remove roles", () => {
    it("remove the signer role of an address", async () => {
      try {
        let flag = false;
        let signers = (await getSignersList()).split(",");
        console.log("Signers: ", signers);

        for (let i = 0; i < signers.length; i++) {
          const usr = signers[i];

          if (usr == user1.publicKey.toString()) {
            flag = true;
            console.log("Removing the signer role of user1: ");
            let removeUser1 = await removeSigner(
              owner,
              user1.publicKey.toUint8Array()
            );
            console.log(
              "Signer list after removing an acount: ",
              await getSignersList()
            );
            expect(removeUser1).toBeDefined();
          }
        }
        !flag ? console.log("User1 is not a signer") : "";
      } catch (error) {
        console.log("🚀 ~ it ~ error:", error);
      }
    });
    it("remove the admin transfer role of an address", async () => {
      try {
        let flag = false;
        let adminTransfer = (await getAdminTransferList()).split(",");
        console.log("🚀 adminTransfer List:", adminTransfer);
        for (let i = 0; i < adminTransfer.length; i++) {
          const usr = adminTransfer[i];

          if (usr == user1.accountAddress.toString()) {
            flag = true;
            console.log("Removing the transfer role of user1: ");
            let removeUser1 = await removeAdminTransferRole(
              owner,
              user1.accountAddress
            );
            console.log(
              "Admin transfer list after removing an acount: ",
              await getAdminTransferList()
            );
            expect(removeUser1).toBeDefined();
          }
        }
        !flag ? console.log("User1 is not asssigned with a transfer role") : "";
      } catch (error) {
        console.log("🚀 ~ it ~ error:", error);
      }
    });
    it("remove the minter role of an address", async () => {
      try {
        let flag = false;
        let minters = (await getMinterList()).split(",");
        console.log("🚀  minters list :", minters);
        for (let i = 0; i < minters.length; i++) {
          const element = minters[i];

          if (element == user1.accountAddress.toString()) {
            flag = true;
            console.log("Removing the minter role of user1: ");
            let removeUser1 = await removeMinterRole(
              owner,
              user1.accountAddress
            );
            console.log(
              "Minter list after removing an acount: ",
              await getMinterList()
            );
            expect(removeUser1).toBeDefined();
          }
        }
        !flag ? console.log("User1 is not a minter") : "";
      } catch (error) {
        console.log("🚀 ~ it ~ error:", error);
      }
    });
  });
});
