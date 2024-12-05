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
  mint,
  removeTreasuryAddress,
  removeWhitelistReceiver,
  removeWhitelistSender,
  transferFromWhitelistSender,
  transferToWhitelistReceiver,
  updateAdmin,
  updateMinter,
} from "../rKGenFunctions";
import { createMultisig3o5 } from "../multiSig";
import { aw } from "@aptos-labs/ts-sdk/dist/common/accountAddress-BHsGaOsa";

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

    const updatAdminTest = async (admin: Account, newAdmin: AccountAddress) => {
      try {
        await updateAdmin(admin, newAdmin);
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(/EALREADY_EXIST/);
          expect(error.message).toMatch(/ENOT_ADMIN/);
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
    };

    it("should update the admin address successfully", async () => {
      try {
        // Call the updateAdmin function
        await updatAdminTest(currentAdmin, newAdminAddress);

        // Retrieve the updated admin address using getAdmin
        const updatedAdmin = await getAdmin();

        // Verify the admin address was updated
        expect(updatedAdmin).toBe(newAdminAddress.toString());
      } catch (error) {
        console.log("Error in updating admin:", error);
      }
    });

    it("should fail if current admin is not authorized", async () => {
      const unauthorizedAdmin = treasury; // Create an unauthorized admin

      try {
        await updatAdminTest(unauthorizedAdmin, newAdminAddress);
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(/EALREADY_EXIST/);
          expect(error.message).toMatch(/ENOT_ADMIN/);
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
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
        expect(treasuryAddress).toContain(newTreasuryAddress.toString());
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(
            /EALREADY_EXIST|ENOT_ADMIN|ENOT_TREASURY_ADDRESS/
          );
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
    });

    it("should fail if current admin is not authorized", async () => {
      const unauthorizedAdmin = treasury; // Unauthorized admin

      try {
        await addTreasuryAddress(unauthorizedAdmin, newTreasuryAddress);
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(/EALREADY_EXIST|ENOT_ADMIN/);
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
    });
  });

  describe("removeTreasuryAddress Function Tests", () => {
    let currentAdmin: Account;
    let treasuryAddressToRemove: AccountAddress;

    beforeAll(async () => {
      currentAdmin = admin; // Admin account
      treasuryAddressToRemove = treasury.accountAddress; // Treasury address to remove
      try {
        await addTreasuryAddress(currentAdmin, treasuryAddressToRemove);
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(/EALREADY_EXIST|ENOT_ADMIN/);
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
    });

    it("should remove a treasury address successfully", async () => {
      try {
        // Call the removeTreasuryAddress function
        await removeTreasuryAddress(currentAdmin, treasuryAddressToRemove);

        // Retrieve the treasury addresses using getTreasuryAddress
        const treasuryAddresses = await getTreasuryAddress();

        // Verify the treasury address was removed
        expect(treasuryAddresses).not.toContain(treasuryAddressToRemove);
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(
            /EALREADY_EXIST|ENOT_ADMIN|ENOT_TREASURY_ADDRESS/
          );
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
    });

    it("should fail if current admin is not authorized", async () => {
      const unauthorizedAdmin = treasury; // Unauthorized admin
      try {
        await removeTreasuryAddress(unauthorizedAdmin, treasuryAddressToRemove);
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(
            /EALREADY_EXIST|ENOT_ADMIN|ENOT_TREASURY_ADDRESS/
          );
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
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

        expect(whitelistedSenders).toContain(senderAddress.toString());
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(
            /EALREADY_EXIST|ENOT_ADMIN|ENOT_WHITELIST_SENDER/
          );
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
    });

    it("should fail if current admin is not authorized", async () => {
      const unauthorizedAdmin = treasury; // Unauthorized admin

      try {
        await addWhitelistSender(unauthorizedAdmin, senderAddress);
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(/EALREADY_EXIST|ENOT_ADMIN/);
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
    });
  });

  describe("removeWhitelistSender Function Tests", () => {
    let currentAdmin: Account;
    let senderAddress: AccountAddress;

    beforeAll(async () => {
      currentAdmin = admin; // Admin account
      senderAddress = sender.accountAddress; // Sender address to remove
      try {
        await addWhitelistSender(currentAdmin, senderAddress);
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(
            /EALREADY_EXIST|ENOT_ADMIN|ENOT_WHITELIST_SENDER/
          );
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
    });

    it("should remove a sender from the whitelist successfully", async () => {
      try {
        await removeWhitelistSender(currentAdmin, senderAddress);

        const whitelistedSenders = await getWhitelistedSender();

        expect(whitelistedSenders).not.toContain(senderAddress.toString());
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(
            /EALREADY_EXIST|ENOT_ADMIN|ENOT_WHITELIST_SENDER/
          );
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
    });

    it("should fail if current admin is not authorized", async () => {
      const unauthorizedAdmin = treasury; // Unauthorized admin
      try {
        await removeWhitelistSender(unauthorizedAdmin, senderAddress);
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(
            /EALREADY_EXIST|ENOT_ADMIN|ENOT_WHITELIST_SENDER/
          );
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
    });
  });

  describe("addWhitelistReceiver Function Tests", () => {
    let currentAdmin: Account;
    let receiverAddress: AccountAddress;

    beforeAll(async () => {
      currentAdmin = admin; // Admin account
      receiverAddress = receiver.accountAddress; // Sender address to whitelist
    });

    it("should add a new sender to the whitelist successfully", async () => {
      try {
        await addWhitelistReceiver(currentAdmin, receiverAddress);

        const whitelistedReceivers = await getWhitelistedReceiver();

        expect(whitelistedReceivers).toContain(receiverAddress.toString());
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(
            /EALREADY_EXIST|ENOT_ADMIN|ENOT_WHITELIST_RECEIVER/
          );
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
    });

    it("should fail if current admin is not authorized", async () => {
      const unauthorizedAdmin = treasury; // Unauthorized admin

      try {
        await addWhitelistReceiver(unauthorizedAdmin, receiverAddress);
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(
            /EALREADY_EXIST|ENOT_ADMIN|ENOT_WHITELIST_RECEIVER/
          );
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
    });
  });

  describe("removeWhitelistReceiver Function Tests", () => {
    let currentAdmin: Account;
    let receiverAddress: AccountAddress;

    beforeAll(async () => {
      currentAdmin = admin; // Admin account
      receiverAddress = sender.accountAddress; // Sender address to remove
      try {
        await addWhitelistReceiver(currentAdmin, receiverAddress);
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(
            /EALREADY_EXIST|ENOT_ADMIN|ENOT_WHITELIST_RECEIVER/
          );
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
    });

    it("should remove a receiver from the whitelist successfully", async () => {
      try {
        await removeWhitelistReceiver(currentAdmin, receiverAddress);

        const whitelistedReceiver = await getWhitelistedReceiver();

        expect(whitelistedReceiver).not.toContain(receiverAddress.toString());
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(
            /EALREADY_EXIST|ENOT_ADMIN|ENOT_WHITELIST_RECEIVER/
          );
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
    });

    it("should fail if current admin is not authorized", async () => {
      const unauthorizedAdmin = treasury; // Unauthorized admin
      try {
        await removeWhitelistReceiver(unauthorizedAdmin, receiverAddress);
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(
            /EALREADY_EXIST|ENOT_ADMIN|ENOT_WHITELIST_RECEIVER/
          );
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
    });
  });

  describe("updateMinter Function Tests", () => {
    let currentAdmin: Account;
    let neMinterAddress: AccountAddress;

    beforeAll(async () => {
      // Initialize accounts for the test
      currentAdmin = admin; // Mock or use actual account creation
      neMinterAddress = deployer.accountAddress; // Mock a new admin address
    });

    const updatMinterTest = async (
      admin: Account,
      newMinter: AccountAddress
    ) => {
      try {
        await updateMinter(admin, newMinter);
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(/EALREADY_EXIST|ENOT_ADMIN/);
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
    };

    it("should update the minter address successfully", async () => {
      try {
        // Call the updateAdmin function
        await updatMinterTest(currentAdmin, neMinterAddress);

        // Retrieve the updated admin address using getAdmin
        const updatedMinter = await getMinter();
        console.log("🚀 ~ it ~ updatedMinter:", updatedMinter);

        // Verify the admin address was updated
        expect(updatedMinter).toBe(neMinterAddress.toString());
      } catch (error) {
        console.log("Error in updating admin:", error);
      }
    });

    it("should fail if current admin is not authorized", async () => {
      const unauthorizedAdmin = treasury; // Create an unauthorized admin

      try {
        await updatMinterTest(unauthorizedAdmin, neMinterAddress);
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(/EALREADY_EXIST/);
          expect(error.message).toMatch(/ENOT_ADMIN/);
        } else {
          // If error is not an instance of Error, fail the test
          fail("Expected error to be an instance of Error");
        }
      }
    });
  });

  describe("Mint through multisig wallet", () => {
    const updatMinterTest = async (
      admin: Account,
      newMinter: AccountAddress
    ) => {
      try {
        await updateMinter(admin, newMinter);
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        if (error instanceof Error) {
          // Check if the error message contains 'EALREADY_EXIST'
          expect(error.message).toMatch(/EALREADY_EXIST|ENOT_ADMIN/);
          // expect(error.message).toMatch(/ENOT_ADMIN/);
        } else {
          console.log("🚀 ~ describe ~ error:", error);
        }
      }
    };
    let currentAdmin: Account;
    let neMinterAddress: AccountAddress;
    let newTreasuryAddress: AccountAddress;
    beforeAll(async () => {
      // Initialize accounts for the test
      currentAdmin = deployer; // Mock or use actual account creation
      neMinterAddress = multisig; // Mock a new admin address
      newTreasuryAddress = admin.accountAddress;

      await updatMinterTest(currentAdmin, neMinterAddress);
      console.log("Minter: ", await getMinter());

      //Adding treasury address
      try {
        // Call the addTreasuryAddress function
        await addTreasuryAddress(currentAdmin, newTreasuryAddress);

        // Retrieve the treasury address using getTreasuryAddress
        const treasuryAddress = await getTreasuryAddress();
        console.log("🚀 ~ beforeAll ~ treasuryAddress:", treasuryAddress);
      } catch (error: unknown) {
        // Narrow the type of error to an instance of Error to safely access message
        error instanceof Error
          ? expect(error.message).toMatch(/EALREADY_EXIST|ENOT_ADMIN/)
          : // If error is not an instance of Error, fail the test
            "";
      }
    });
    it("mint token to treasury address", async () => {
      try {
        console.log("🚀 ~ it ~ multiSig:", multisig);

        await mint(newTreasuryAddress, 1000000000);
        console.log(
          "Treasury balance: ",
          await getRKBalance(newTreasuryAddress, await getMetadata())
        );
      } catch (error) {
        console.log("🚀 ~ it ~ error:", error);
      }
    }, 500000);
  });

  afterAll(async () => {
    // Clean up resources like database connections or network requests
    jest.useFakeTimers();
    jest.clearAllTimers();
  });
});
