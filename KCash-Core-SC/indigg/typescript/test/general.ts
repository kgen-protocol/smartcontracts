
import {
    Account,
    AccountAddress,
    AnyNumber,
    Aptos,
    AptosConfig,
    Network,
    NetworkToNetworkName,
    Ed25519PrivateKey,
    Ed25519Account,
  } from "@aptos-labs/ts-sdk";


describe("general api", () => {
    test("it fetches ledger info", async () => {
      const config = new AptosConfig({ network: Network.DEVNET });
      console.log("config",config);
      
      const aptos = new Aptos(config);
      console.log("aptos",aptos);
      
      const ledgerInfo = await aptos.getLedgerInfo();
      console.log("ledgerInfo",ledgerInfo);
      
      expect(ledgerInfo.chain_id).toBe(128);
    });
  
    test("it fetches chain id", async () => {
      const config = new AptosConfig({ network: Network.LOCAL });
      const aptos = new Aptos(config);
      const chainId = await aptos.getChainId();
      expect(chainId).toBe(4);
    });
});




// import {
//   Account,
//   AccountAddress,
//   AnyNumber,
//   Aptos,
//   AptosConfig,
//   Network,
//   NetworkToNetworkName,
//   Ed25519PrivateKey,
//   Ed25519Account,
// } from "@aptos-labs/ts-sdk";
// import {
//   transferCoin,
//   mintCoin,
//   burnCoin,
//   freeze,
//   unfreeze,
//   getFaBalance,
//   getMetadata,
// } from "../kcash_fungible_asset"; // Replace "your_file_name" with the actual name of your file containing the functions
// //   import {expect, jest, test} from '@jest/globals';



// let privateKeyOwner = new Ed25519PrivateKey(
//   "0xfa5a4197c79ba2ff77e12a70047469effd01cd2a6affdfb9cff6cb2147801f4a"
// );

// let privateKeyBob = new Ed25519PrivateKey(
//   "0xd83ca564b977295831915b57bf67a19b03811d40dabbd03010440f8e383a419e"
// );

// let privateKeyCharlie = new Ed25519PrivateKey(
//   "0x1983c113a674948c187d3132ce0a8718b4e63eb1e2ca49bb132a291dc88bdf4c"
// );

// let owner = Account.fromPrivateKey({ privateKey: privateKeyOwner });
// let bob = Account.fromPrivateKey({ privateKey: privateKeyBob });
// let charlie = Account.fromPrivateKey({ privateKey: privateKeyCharlie });

// let metadataAddress: string


// //  let result =  mintCoin(owner, bob, 100000000000000000);
// //  console.log("result", result);


// // Mocking aptos object for testing purposes
// jest.mock('@aptos-labs/ts-sdk', () => ({
// Aptos: jest.fn().mockImplementation(() => ({
//   transaction: {
//     build: {
//       simple: jest.fn().mockResolvedValue({}),
//     },
//     sign: jest.fn().mockResolvedValue({}),
//     submit: {
//       simple: jest.fn().mockResolvedValue({ hash: 'transactionHash' }),
//     },
//   },
// })),
// }));




// describe("Testing Aptos Blockchain Functions", () => {

//   beforeEach(async () => {
//     // Get metadata address
//      metadataAddress = await getMetadata(owner);
//     console.log("metadataAddress", metadataAddress);
//   }, 20000);
  
//   test("Get Metadata", async () => {
//       try {
//           // Test getting metadata
//       console.log("Testing getMetadata...");
//       const metadata = await getMetadata(owner);
//       expect(metadata).toBeDefined();
//       console.log("Metadata:", metadata); 
//       } catch (error) {
//         console.log("error",error);
          
//       }
     
//   });

//   test("Get FA Balance", async () => {
//       try {
//          // Test getting FA balance
//       console.log("Testing getFaBalance...");
//       const balance = await getFaBalance(owner, metadataAddress);
//       expect(balance).toBeDefined();
//       console.log("Balance:", balance);  
//       } catch (error) {
//        console.log("error",error);
          
//       }
     
//   });
  

//   test("Mint Coins", async () => {
//     // Assuming Alice wants to mint some coins for herself
//     try {
//       console.log("startminting....73");
//     metadataAddress = await getMetadata(owner);
//     console.log("metadata172",metadataAddress);
    
//     let initialBalanceowner = await getFaBalance(owner, metadataAddress);
//     console.log("initialBalanceAlice180",initialBalanceowner);
//     let amountToMint = 10000000000000000; // Adjust as necessary
//     console.log("owner18444",owner);
//   //   let result = await mintCoin(owner, owner, 100000000000000000);
//     let mintCoinTransactionHash = await mintCoin(owner, owner, 100000000000000000);
//     console.log("result", mintCoinTransactionHash);
//     const finalBalanceAlice = await getFaBalance(owner, metadataAddress);
//     expect(finalBalanceAlice).toBe(initialBalanceowner + 100000000000000000);
//     console.log("initialBalanceAlice180",initialBalanceowner);
//     console.log("finalBalanceAlice1888",finalBalanceAlice);
//     } catch (error) {
//       console.log("error",error);
//     }
//   });


//   test("Burn Coins", async () => {
//       try {
//           // Assuming Alice wants to burn some coins from her account
//       console.log("start burning coins...");
      
//       // Get the initial balance of the owner
//       const initialBalanceOwner = await getFaBalance(owner, metadataAddress);
      
//       // Define the amount of coins to burn
//       const amountToBurn = 100000000000000000; // Adjust as necessary
      
//       // Burn coins from the owner's account
//       const burnCoinTransactionHash = await burnCoin(owner, owner.accountAddress, amountToBurn);
//       console.log("Burn coin transaction hash:", burnCoinTransactionHash);
      
//       // Get the final balance of the owner after burning coins
//       const finalBalanceOwner = await getFaBalance(owner, metadataAddress);
      
//       // Assert that the final balance is decreased by the amount burned
//       expect(finalBalanceOwner).toBe(initialBalanceOwner - amountToBurn);
      
//       console.log("Initial balance of owner:", initialBalanceOwner);
//       console.log("Final balance of owner:", finalBalanceOwner);
//       } catch (error) {
//          console.log("error",error);
//       }
      
//     });
    
//   //   test("Freeze Account", async () => {
//   //     try {
//   //         // Test freezing an account
//   //         console.log("Testing freeze...");
//   //         const freezeTransactionHash = await freeze(owner, bob.accountAddress);
//   //         console.log("Freeze transaction hash:", freezeTransactionHash);
//   //         // You can add more assertions here if needed
//   //         expect(freezeTransactionHash).toBe(true); 
//   //         expect(freezeTransactionHash).toHaveBeenCalled()
//   //     } catch (error) {
//   //         console.log("Error while freezing account:", error);
//   //     }
//   // });
  
//   // test("Unfreeze Account", async () => {
//   //     try {
//   //         // Test unfreezing an account
//   //         console.log("Testing unfreeze...");
//   //         const unfreezeTransactionHash = await unfreeze(owner, bob.accountAddress);
//   //         console.log("Unfreeze transaction hash:", unfreezeTransactionHash);
//   //         // You can add more assertions here if needed
//   //     } catch (error) {
//   //         console.log("Error while unfreezing account:", error);
//   //     }
//   // });
  
//   // test("Unfreeze Account", async () => {
//   //     try {
//   //         // Test unfreezing an account
//   //         console.log("Testing unfreeze...");
          
//   //         // Get the initial frozen status of the account
//   //         const isFrozenBefore = await freeze(owner, bob.accountAddress);
//   //         console.log("Is account frozen before unfreezing:", isFrozenBefore);
          
//   //         // Unfreeze the account
//   //         const unfreezeTxnHash = await unfreeze(owner, bob.accountAddress);
//   //         console.log("Unfreeze transaction hash:", unfreezeTxnHash);
          
//   //         // Get the frozen status of the account after unfreezing
//   //         const isFrozenAfter = await freeze(owner, bob.accountAddress);
//   //         console.log("Is account frozen after unfreezing:", isFrozenAfter);
          
//   //         // Add assertions to verify the unfreezing process
//   //         expect(isFrozenBefore).toBe(true); // Account should be frozen before unfreezing
//   //         expect(isFrozenAfter).toBe(false); // Account should not be frozen after unfreezing
//   //     } catch (error) {
//   //         console.log("Error while unfreezing account:", error);
//   //     }
//   // });
  




//   test("Freeze Account", async () => {
//       // Call the freeze function
//       const transactionHash = await freeze(owner, bob.accountAddress);

//       // Expect the transaction hash to be returned
//       expect(transactionHash).toEqual("mockTransactionHash");

//       // Expect aptos methods to be called with correct arguments
//       expect(Aptos.prototype.transaction.build.simple).toHaveBeenCalledWith({
//         sender: owner.accountAddress,
//         data: {
//           function: `${owner.accountAddress}::fa_coin::freeze_account`,
//           functionArguments: [bob.accountAddress],
//         },
//       });
//       expect(Aptos.prototype.transaction.sign).toHaveBeenCalled();
//       expect(Aptos.prototype.transaction.submit.simple).toHaveBeenCalled();
//   });

//   // test("Unfreeze Account", async () => {
//   //     // Call the unfreeze function
//   //     const transactionHash = await unfreeze(owner, bob.accountAddress);

//   //     // Expect the transaction hash to be returned
//   //     expect(transactionHash).toEqual("mockTransactionHash");

//   //     // Expect aptos methods to be called with correct arguments
//   //     expect(aptos.transaction.build.simple).toHaveBeenCalledWith({
//   //         sender: owner.accountAddress,
//   //         data: {
//   //             function: `${owner.accountAddress}::fa_coin::unfreeze_account`,
//   //             functionArguments: [bob.accountAddress],
//   //         },
//   //     });
//   //     expect(aptos.transaction.sign).toHaveBeenCalled();
//   //     expect(aptos.transaction.submit.simple).toHaveBeenCalled();
//   // });
 
// });


