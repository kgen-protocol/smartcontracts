import {
  Aptos,
  AptosConfig,
  AptosSettings,
  Network,
  AptosApiType,
  NetworkToNodeAPI,
  NetworkToFaucetAPI,
  NetworkToIndexerAPI,
  NetworkToNetworkName,
  AccountAddress,
  Account,
} from "@aptos-labs/ts-sdk";
import {
  address_name,
  admin,
  compilePackage,
  deployer,
  getPackageBytesToPublish,
  module_file_name,
  multisig,
  output_file_path,
  receiver,
  sender,
  treasury,
} from "../utils";
import { compileAndDeployModule } from "../rKGEN";
import {
  addTreasuryAddress,
  addWhitelistReceiver,
  addWhitelistSender,
  getAdmin,
  getMetadata,
  getMinter,
  getRKBalance,
  getTreasuryAddress,
  getWhitelistedReceiver,
  getWhitelistedSender,
  removeTreasuryAddress,
  removeWhitelistReceiver,
  removeWhitelistSender,
  transferFromWhitelistSender,
  transferToWhitelistReceiver,
  updateAdmin,
  updateMinter,
} from "../rKGenFunctions";
import { createMultisig3o5 } from "../multiSig";

const APTOS_NETWORK: Network = NetworkToNetworkName[Network.TESTNET];
const config = new AptosConfig({ network: APTOS_NETWORK });
const aptos = new Aptos(config);

describe("rKGEN Test Suite", () => {
  beforeAll(async () => {
    try {
      const deployedTx = await compileAndDeployModule(
        module_file_name,
        output_file_path,
        address_name,
        deployer.accountAddress
      );
      console.log("🚀 Deployed Transaction:", deployedTx);

      const metadataAddress = await getMetadata();
      console.log("Metadata Address:", metadataAddress);
    } catch (error) {
      console.error("Error in beforeAll:", error);
    }
  }, 20000);

  describe("Aptos Config Tests", () => {
    it("should set URLs based on testnet configuration", async () => {
      const settings: AptosSettings = { network: Network.TESTNET };
      const aptosConfig = new AptosConfig(settings);

      expect(aptosConfig.network).toEqual("testnet");
      expect(aptosConfig.getRequestUrl(AptosApiType.FULLNODE)).toBe(
        NetworkToNodeAPI[Network.TESTNET]
      );
      expect(aptosConfig.getRequestUrl(AptosApiType.FAUCET)).toBe(
        NetworkToFaucetAPI[Network.TESTNET]
      );
      expect(aptosConfig.getRequestUrl(AptosApiType.INDEXER)).toBe(
        NetworkToIndexerAPI[Network.TESTNET]
      );
    });

    it("should set URLs based on mainnet configuration", async () => {
      const settings: AptosSettings = { network: Network.MAINNET };
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

  describe("rKGEN Package Deployment Tests", () => {
    it("should compile and publish the rKGEN package", async () => {
      try {
        const { metadataBytes, byteCode } = await getPackageBytesToPublish(
          output_file_path
        );

        console.log("\n=== Publishing rKGEN package ===");
        const transaction = await aptos.publishPackageTransaction({
          account: deployer.accountAddress,
          metadataBytes,
          moduleBytecode: byteCode,
        });

        const response = await aptos.signAndSubmitTransaction({
          signer: deployer,
          transaction,
        });

        await aptos.waitForTransaction({ transactionHash: response.hash });

        // console.log(`Transaction Hash: ${response.hash}`);
        expect(response.hash).toBeDefined();
      } catch (error) {
        console.error("Error during package publishing:", error);
        expect(error).toBeUndefined();
      }
    });
  });

  describe("Metadata and Balance Tests", () => {
    it("should retrieve metadata", async () => {
      try {
        const metadata = await getMetadata();
        expect(metadata).toBeDefined();
        console.log("Metadata Retrieved:", metadata);
      } catch (error) {
        console.error("Error retrieving metadata:", error);
        expect(error).toBeUndefined();
      }
    });

    it("should retrieve rKGEN balance", async () => {
      try {
        const metadataAddress = await getMetadata();
        const balance = await getRKBalance(
          deployer.accountAddress,
          metadataAddress.toString()
        );
        expect(balance).toBeDefined();
        console.log("rKGEN Balance:", balance);
      } catch (error) {
        console.error("Error retrieving balance:", error);
        expect(error).toBeUndefined();
      }
    });
  });

  describe("updateAdmin Function Tests", () => {
    let currentAdmin: Account;
    let newAdminAddress: AccountAddress;

    beforeAll(async () => {
      // Initialize accounts for the test
      currentAdmin = deployer; // Mock or use actual account creation
      newAdminAddress = admin.accountAddress; // Mock a new admin address
    });

    it("should update the admin address successfully", async () => {
      try {
        // Call the updateAdmin function
        await updateAdmin(currentAdmin, newAdminAddress);

        // Retrieve the updated admin address using getAdmin
        const updatedAdmin = await getAdmin();

        // Verify the admin address was updated
        expect(updatedAdmin).toBe(newAdminAddress);
      } catch (error) {
        console.error("Error in updating admin:", error);
        expect(error).toBeUndefined(); // Fail the test if any error occurs
      }
    });

    it("should fail if current admin is not authorized", async () => {
      const unauthorizedAdmin = treasury; // Create an unauthorized admin

      await expect(
        updateAdmin(unauthorizedAdmin, newAdminAddress)
      ).rejects.toThrow("Unauthorized admin");
    });
  });

  describe("updateMinter Function Tests", () => {
    let currentAdmin: Account;
    let newMinterAddress: AccountAddress;

    beforeAll(async () => {
      // Initialize accounts for the test
      currentAdmin = admin; // Admin account
      newMinterAddress = await createMultisig3o5(); // New minter's address
    });

    it("should update the minter address successfully", async () => {
      try {
        // Call the updateMinter function
        await updateMinter(currentAdmin, newMinterAddress);

        // Retrieve the updated minter address using getMinter
        const updatedMinter = await getMinter();

        // Verify the minter address was updated
        expect(updatedMinter).toBe(newMinterAddress);
      } catch (error) {
        console.error("Error in updating minter:", error);
        expect(error).toBeUndefined(); // Fail the test if any error occurs
      }
    });

    it("should fail if current admin is not authorized", async () => {
      const unauthorizedAdmin = treasury; // Unauthorized admin

      await expect(
        updateMinter(unauthorizedAdmin, newMinterAddress)
      ).rejects.toThrow("Unauthorized admin");
    });
  });

  describe("addTreasuryAddress Function Tests", () => {
    let currentAdmin: Account;
    let newTreasuryAddress: AccountAddress;

    beforeAll(async () => {
      // Initialize accounts for the test
      currentAdmin = admin; // Admin account
      newTreasuryAddress = treasury.accountAddress; // New treasury's address
    });

    it("should add a new treasury address successfully", async () => {
      try {
        // Call the addTreasuryAddress function
        await addTreasuryAddress(currentAdmin, newTreasuryAddress);

        // Retrieve the treasury address using getTreasuryAddress
        const treasuryAddress = await getTreasuryAddress();

        // Verify the treasury address was added
        expect(treasuryAddress).toContain(newTreasuryAddress);
      } catch (error) {
        console.error("Error in adding treasury address:", error);
        expect(error).toBeUndefined(); // Fail the test if any error occurs
      }
    });

    it("should fail if current admin is not authorized", async () => {
      const unauthorizedAdmin = treasury; // Unauthorized admin

      await expect(
        addTreasuryAddress(unauthorizedAdmin, newTreasuryAddress)
      ).rejects.toThrow("Unauthorized admin");
    });
  });

  describe("removeTreasuryAddress Function Tests", () => {
    let currentAdmin: Account;
    let treasuryAddressToRemove: AccountAddress;

    beforeAll(async () => {
      currentAdmin = admin; // Admin account
      treasuryAddressToRemove = treasury.accountAddress; // Treasury address to remove
      await addTreasuryAddress(currentAdmin, treasuryAddressToRemove); // Ensure address exists
    });

    it("should remove a treasury address successfully", async () => {
      try {
        // Call the removeTreasuryAddress function
        await removeTreasuryAddress(currentAdmin, treasuryAddressToRemove);

        // Retrieve the treasury addresses using getTreasuryAddress
        const treasuryAddresses = await getTreasuryAddress();

        // Verify the treasury address was removed
        expect(treasuryAddresses).not.toContain(treasuryAddressToRemove);
      } catch (error) {
        console.error("Error in removing treasury address:", error);
        expect(error).toBeUndefined(); // Fail the test if any error occurs
      }
    });

    it("should fail if current admin is not authorized", async () => {
      const unauthorizedAdmin = treasury; // Unauthorized admin

      await expect(
        removeTreasuryAddress(unauthorizedAdmin, treasuryAddressToRemove)
      ).rejects.toThrow("Unauthorized admin");
    });
  });

  describe("addWhitelistSender Function Tests", () => {
    let currentAdmin: Account;
    let senderAddress: AccountAddress;

    beforeAll(async () => {
      currentAdmin = admin; // Admin account
      senderAddress = sender.accountAddress; // Sender address to whitelist
    });

    it("should add a new sender to the whitelist successfully", async () => {
      try {
        await addWhitelistSender(currentAdmin, senderAddress);

        const whitelistedSenders = await getWhitelistedSender();

        expect(whitelistedSenders).toContain(senderAddress);
      } catch (error) {
        console.error("Error in adding whitelist sender:", error);
        expect(error).toBeUndefined();
      }
    });

    it("should fail if current admin is not authorized", async () => {
      const unauthorizedAdmin = treasury; // Unauthorized admin

      await expect(
        addWhitelistSender(unauthorizedAdmin, senderAddress)
      ).rejects.toThrow("Unauthorized admin");
    });
  });

  describe("removeWhitelistSender Function Tests", () => {
    let currentAdmin: Account;
    let senderAddress: AccountAddress;

    beforeAll(async () => {
      currentAdmin = admin; // Admin account
      senderAddress = sender.accountAddress; // Sender address to remove
      await addWhitelistSender(currentAdmin, senderAddress); // Ensure address exists
    });

    it("should remove a sender from the whitelist successfully", async () => {
      try {
        await removeWhitelistSender(currentAdmin, senderAddress);

        const whitelistedSenders = await getWhitelistedSender();

        expect(whitelistedSenders).not.toContain(senderAddress);
      } catch (error) {
        console.error("Error in removing whitelist sender:", error);
        expect(error).toBeUndefined();
      }
    });

    it("should fail if current admin is not authorized", async () => {
      const unauthorizedAdmin = treasury; // Unauthorized admin

      await expect(
        removeWhitelistSender(unauthorizedAdmin, senderAddress)
      ).rejects.toThrow("Unauthorized admin");
    });
  });

  describe("addWhitelistReceiver Function Tests", () => {
    let currentAdmin: Account;
    let receiverAddress: AccountAddress;

    beforeAll(async () => {
      currentAdmin = admin; // Admin account
      receiverAddress = receiver.accountAddress; // Receiver address to whitelist
    });

    it("should add a new receiver to the whitelist successfully", async () => {
      try {
        await addWhitelistReceiver(currentAdmin, receiverAddress);

        const whitelistedReceivers = await getWhitelistedReceiver();

        expect(whitelistedReceivers).toContain(receiverAddress);
      } catch (error) {
        console.error("Error in adding whitelist receiver:", error);
        expect(error).toBeUndefined();
      }
    });

    it("should fail if current admin is not authorized", async () => {
      const unauthorizedAdmin = treasury; // Unauthorized admin

      await expect(
        addWhitelistReceiver(unauthorizedAdmin, receiverAddress)
      ).rejects.toThrow("Unauthorized admin");
    });
  });

  describe("removeWhitelistReceiver Function Tests", () => {
    let currentAdmin: Account;
    let receiverAddress: AccountAddress;

    beforeAll(async () => {
      currentAdmin = admin; // Admin account
      receiverAddress = receiver.accountAddress; // Receiver address to remove
      await addWhitelistReceiver(currentAdmin, receiverAddress); // Ensure address exists
    });

    it("should remove a receiver from the whitelist successfully", async () => {
      try {
        await removeWhitelistReceiver(currentAdmin, receiverAddress);

        const whitelistedReceivers = await getWhitelistedReceiver();

        expect(whitelistedReceivers).not.toContain(receiverAddress);
      } catch (error) {
        console.error("Error in removing whitelist receiver:", error);
        expect(error).toBeUndefined();
      }
    });

    it("should fail if current admin is not authorized", async () => {
      const unauthorizedAdmin = treasury; // Unauthorized admin

      await expect(
        removeWhitelistReceiver(unauthorizedAdmin, receiverAddress)
      ).rejects.toThrow("Unauthorized admin");
    });
  });

  describe("transferFromWhitelistSender Function Tests", () => {
    let whitelistedSender: Account;
    let nonWhitelistedSender: Account;
    let receiverAddress: AccountAddress;
    const transferAmount = 500;

    beforeAll(async () => {
      // Initialize accounts for the test
      whitelistedSender = sender; // Whitelisted sender account
      nonWhitelistedSender = admin; // Non-whitelisted sender account
      receiverAddress = receiver.accountAddress; // Receiver's address

      // Add sender to the whitelist for setup
      await addWhitelistSender(admin, whitelistedSender.accountAddress);
    });

    it("should transfer tokens successfully from a whitelisted sender", async () => {
      try {
        // Call the transferFromWhitelistSender function
        await transferFromWhitelistSender(
          whitelistedSender,
          receiverAddress,
          transferAmount
        );
        const metadataAddress = await getMetadata();

        // Retrieve the receiver's balance
        const receiverBalance = await getRKBalance(
          receiverAddress,
          metadataAddress
        );

        // Verify that the receiver's balance increased by the transfer amount
        expect(receiverBalance).toBeGreaterThanOrEqual(transferAmount);
      } catch (error) {
        console.error("Error in transferring tokens:", error);
        expect(error).toBeUndefined(); // Fail the test if any error occurs
      }
    });

    it("should fail if sender is not in the whitelist", async () => {
      await expect(
        transferFromWhitelistSender(
          nonWhitelistedSender,
          receiverAddress,
          transferAmount
        )
      ).rejects.toThrow("Sender is not whitelisted");
    });

    it("should fail if the transfer amount is zero or negative", async () => {
      const zeroAmount = 0;
      const negativeAmount = -300;

      await expect(
        transferFromWhitelistSender(
          whitelistedSender,
          receiverAddress,
          zeroAmount
        )
      ).rejects.toThrow("Invalid transfer amount");

      await expect(
        transferFromWhitelistSender(
          whitelistedSender,
          receiverAddress,
          negativeAmount
        )
      ).rejects.toThrow("Invalid transfer amount");
    });

    it("should deduct tokens from the sender's balance", async () => {
      const metadataAddress = await getMetadata();

      const initialSenderBalance = await getRKBalance(
        whitelistedSender.accountAddress,
        metadataAddress
      );

      // Perform the transfer
      await transferFromWhitelistSender(
        whitelistedSender,
        receiverAddress,
        transferAmount
      );

      // Get updated sender's balance
      const finalSenderBalance = await getRKBalance(
        whitelistedSender.accountAddress,
        metadataAddress
      );

      // Verify that the sender's balance decreased by the transfer amount
      expect(finalSenderBalance).toEqual(initialSenderBalance - transferAmount);
    });
  });

  describe("transferToWhitelistReceiver Function Tests", () => {
    let sender: Account;
    let whitelistedReceiver: AccountAddress;
    let nonWhitelistedReceiver: AccountAddress;
    const transferAmount = 500;

    beforeAll(async () => {
      // Initialize accounts for the test
      sender = sender; // Sender's account
      whitelistedReceiver = receiver.accountAddress; // Whitelisted receiver
      nonWhitelistedReceiver = admin.accountAddress; // Non-whitelisted receiver

      // Add receiver to the whitelist for setup
      await addWhitelistReceiver(admin, whitelistedReceiver);
    });

    it("should transfer tokens successfully to a whitelisted receiver", async () => {
      try {
        // Call the transferToWhitelistReceiver function
        await transferToWhitelistReceiver(
          sender,
          whitelistedReceiver,
          transferAmount
        );
        const metadata = await getMetadata();

        // Retrieve the whitelisted receiver's balance
        const receiverBalance = await getRKBalance(
          whitelistedReceiver,
          metadata
        );

        // Verify that the receiver's balance increased by the transfer amount
        expect(receiverBalance).toBeGreaterThanOrEqual(transferAmount);
      } catch (error) {
        console.error("Error in transferring tokens:", error);
        expect(error).toBeUndefined(); // Fail the test if any error occurs
      }
    });

    it("should fail if receiver is not in the whitelist", async () => {
      await expect(
        transferToWhitelistReceiver(
          sender,
          nonWhitelistedReceiver,
          transferAmount
        )
      ).rejects.toThrow("Receiver is not whitelisted");
    });

    it("should fail if the transfer amount is zero or negative", async () => {
      const zeroAmount = 0;
      const negativeAmount = -300;

      await expect(
        transferToWhitelistReceiver(sender, whitelistedReceiver, zeroAmount)
      ).rejects.toThrow("Invalid transfer amount");

      await expect(
        transferToWhitelistReceiver(sender, whitelistedReceiver, negativeAmount)
      ).rejects.toThrow("Invalid transfer amount");
    });

    it("should fail if the sender's address is invalid", async () => {
      const invalidSender = admin; // Invalid sender account

      await expect(
        transferToWhitelistReceiver(
          invalidSender,
          whitelistedReceiver,
          transferAmount
        )
      ).rejects.toThrow("Invalid sender address");
    });

    it("should deduct tokens from the sender's balance", async () => {
      const metadata = await getMetadata();

      const initialSenderBalance = await getRKBalance(
        sender.accountAddress,
        metadata
      );

      // Perform the transfer
      await transferToWhitelistReceiver(
        sender,
        whitelistedReceiver,
        transferAmount
      );

      // Get updated sender's balance
      const finalSenderBalance = await getRKBalance(
        sender.accountAddress,
        metadata
      );

      // Verify that the sender's balance decreased by the transfer amount
      expect(finalSenderBalance).toEqual(initialSenderBalance - transferAmount);
    });
  });
});
