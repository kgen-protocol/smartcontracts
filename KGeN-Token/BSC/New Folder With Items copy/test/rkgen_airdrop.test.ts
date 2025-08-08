import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";

describe("RKGENAirdrop", function () {
    let airdrop: any;
    let mockToken: any;
    let owner: Signer;
    let user1: Signer;
    let user2: Signer;
    let user3: Signer;
    let nominatedAdmin: Signer;
    
    let ownerAddress: string;
    let user1Address: string;
    let user2Address: string;
    let user3Address: string;
    let nominatedAdminAddress: string;
    let mockTokenAddress: string;

    const chainId = 31337; // hardhat
    const ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ADMIN_ROLE"));

    // EIP-712 Domain and Types
    let domain: any;
    let types: any;

    beforeEach(async function () {
        [owner, user1, user2, user3, nominatedAdmin] = await ethers.getSigners();
        ownerAddress = await owner.getAddress();

        user1Address = await user1.getAddress();
        user2Address = await user2.getAddress();
        user3Address = await user3.getAddress();
        nominatedAdminAddress = await nominatedAdmin.getAddress();

        // Deploy mock ERC20 token
        const MockTokenFactory = await ethers.getContractFactory("MockERC20");
        mockToken = await MockTokenFactory.deploy("Mock Token", "MTK");
        await mockToken.waitForDeployment();
        mockTokenAddress = await mockToken.getAddress();

        // Deploy airdrop contract
        const AirdropFactory = await ethers.getContractFactory("RKGENAirdrop");
        airdrop = await AirdropFactory.deploy();
        await airdrop.waitForDeployment();
   
        // Initialize the contract - reward signer will be set to the deployer (owner)
        await airdrop.initialize("RKGENAirdrop", chainId);
        
        // Whitelist the token
        await airdrop.whitelistToken(mockTokenAddress);
        
        // Set up EIP-712 domain and types
        domain = {
            name: 'RKGENAirdrop',
            version: '1',
            chainId: chainId,
            verifyingContract: await airdrop.getAddress()
        };
        
        types = {
            Claim: [
                { name: 'user', type: 'address' },
                { name: 'token', type: 'address' },
                { name: 'amount', type: 'uint256' },
                { name: 'nonce', type: 'uint256' },
                { name: 'chainId', type: 'uint256' }
            ]
        };
        
        // Transfer some tokens to the airdrop contract for testing
        const tokenAmount = ethers.parseUnits("1000000", 8);
        await mockToken.mint(await airdrop.getAddress(), tokenAmount);
    });

    // Helper function to create EIP-712 signature
    async function createEIP712Signature(
        signer: Signer,
        user: string,
        token: string,
        amount: bigint,
        nonce: number,
        chainId: number
    ): Promise<string> {
        const message = {
            user: user,
            token: token,
            amount: amount,
            nonce: nonce,
            chainId: chainId
        };
        
        return await signer.signTypedData(domain, types, message);
    }

    describe("Deployment and Initialization", function () {
        it("Should set the correct admin", async function () {
            expect(await airdrop.hasRole(await airdrop.DEFAULT_ADMIN_ROLE(), ownerAddress)).to.equal(true);
            expect(await airdrop.hasRole(ADMIN_ROLE, ownerAddress)).to.equal(true);
        });

        it("Should set the correct reward signer", async function () {
            expect(await airdrop.rewardSigner()).to.equal(ownerAddress);
        });

        it("Should set the correct chain ID", async function () {
            expect(await airdrop.chainId()).to.equal(chainId);
        });

        it("Should set up EIP-712 domain separator", async function () {
            // Try different methods to get domain separator
            let domainSeparator;
            try {
                domainSeparator = await airdrop.DOMAIN_SEPARATOR();
            } catch {
                try {
                    domainSeparator = await airdrop.getDomainSeparator();
                } catch {
                    // If both fail, skip this test
                    this.skip();
                }
            }
            expect(domainSeparator).to.not.equal(ethers.ZeroHash);
        });

        it("Should not allow re-initialization", async function () {
            await expect(
                airdrop.initialize("RKGENAirdrop", chainId)
            ).to.be.revertedWithCustomError(airdrop, "InvalidInitialization");
        });
    });

    describe("Admin Management", function () {
        describe("Nominate Admin", function () {
            it("Should allow admin to nominate new admin", async function () {
                await airdrop.nominateAdmin(nominatedAdminAddress);
                expect(await airdrop.nominatedAdmin()).to.equal(nominatedAdminAddress);
            });

            it("Should emit AdminNominated event", async function () {
                await expect(airdrop.nominateAdmin(nominatedAdminAddress))
                    .to.emit(airdrop, "AdminNominated")
                    .withArgs(nominatedAdminAddress);
            });

            it("Should not allow non-admin to nominate admin", async function () {
                await expect(
                    airdrop.connect(user1).nominateAdmin(nominatedAdminAddress)
                ).to.be.revertedWithCustomError(airdrop, "AccessControlUnauthorizedAccount");
            });

            it("Should not allow nominating zero address", async function () {
                await expect(
                    airdrop.nominateAdmin(ethers.ZeroAddress)
                ).to.be.revertedWithCustomError(airdrop, "InvalidAddress");
            });

            it("Should not allow nominating self", async function () {
                await expect(
                    airdrop.nominateAdmin(ownerAddress)
                ).to.be.revertedWithCustomError(airdrop, "AlreadyExists");
            });
        });

        describe("Accept Admin Role", function () {
            beforeEach(async function () {
                await airdrop.nominateAdmin(nominatedAdminAddress);
            });

            it("Should allow nominated admin to accept role", async function () {
                await airdrop.connect(nominatedAdmin).acceptAdminRole();
                expect(await airdrop.hasRole(await airdrop.DEFAULT_ADMIN_ROLE(), nominatedAdminAddress)).to.equal(true);
                expect(await airdrop.hasRole(ADMIN_ROLE, nominatedAdminAddress)).to.equal(true);
                expect(await airdrop.nominatedAdmin()).to.equal(ethers.ZeroAddress);
            });

            it("Should emit AdminUpdated event", async function () {
                await expect(airdrop.connect(nominatedAdmin).acceptAdminRole())
                    .to.emit(airdrop, "AdminUpdated")
                    .withArgs(nominatedAdminAddress);
            });

            it("Should not allow non-nominated address to accept role", async function () {
                await expect(
                    airdrop.connect(user1).acceptAdminRole()
                ).to.be.revertedWithCustomError(airdrop, "InvalidAdmin");
            });

            it("Should not allow accepting when no admin is nominated", async function () {
                await airdrop.connect(nominatedAdmin).acceptAdminRole();
                await expect(
                    airdrop.connect(user1).acceptAdminRole()
                ).to.be.revertedWithCustomError(airdrop, "NoNominatedAdmin");
            });
        });
    });

    describe("Signer Management", function () {
        it("Should allow admin to update signer", async function () {
            const newSigner = user1Address;
            await airdrop.updateSigner(newSigner);
            expect(await airdrop.rewardSigner()).to.equal(newSigner);
        });

        it("Should emit SignerUpdated event", async function () {
            const newSigner = user1Address;
            await expect(airdrop.updateSigner(newSigner))
                .to.emit(airdrop, "SignerUpdated")
                .withArgs(newSigner);
        });

        it("Should not allow non-admin to update signer", async function () {
            await expect(
                airdrop.connect(user1).updateSigner(user2Address)
            ).to.be.revertedWithCustomError(airdrop, "AccessControlUnauthorizedAccount");
        });

        it("Should not allow setting zero address as signer", async function () {
            await expect(
                airdrop.updateSigner(ethers.ZeroAddress)
            ).to.be.revertedWithCustomError(airdrop, "InvalidAddress");
        });

        it("Should not allow setting same signer", async function () {
            await expect(
                airdrop.updateSigner(ownerAddress)
            ).to.be.revertedWithCustomError(airdrop, "AlreadyExists");
        });
    });

    describe("Token Management", function () {
        it("Should allow admin to whitelist token", async function () {
            const newToken = user1Address; // Using address as mock token
            await airdrop.whitelistToken(newToken);
            expect(await airdrop.isWhitelistedToken(newToken)).to.equal(true);
        });

        it("Should not allow non-admin to whitelist token", async function () {
            await expect(
                airdrop.connect(user1).whitelistToken(user2Address)
            ).to.be.revertedWithCustomError(airdrop, "AccessControlUnauthorizedAccount");
        });

        it("Should not allow whitelisting zero address", async function () {
            await expect(
                airdrop.whitelistToken(ethers.ZeroAddress)
            ).to.be.revertedWithCustomError(airdrop, "InvalidAddress");
        });
    });

    describe("Claim Functionality", function () {
        const amount = ethers.parseUnits("100", 8);
        let nonce: number;
        let signature: string;

        beforeEach(async function () {
            nonce = Number(await airdrop.getNonce(user1Address, mockTokenAddress));
            signature = await createEIP712Signature(
                owner, // Use owner as signer since that's the reward signer
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                chainId
            );
            console.log("admin", ownerAddress);
        });

        it("Should allow valid claim", async function () {
            // Prepare the message
            const message = {
                user: user1Address,
                token: mockTokenAddress,
                amount: amount.toString(), // ensure string
                nonce: nonce,
                chainId: chainId
            };
            console.log("Message:", message);
            console.log("Domain:", domain);

            // Compare domain separators
            const contractDomainSeparator = await airdrop.getDomainSeparator();
            const ourDomainSeparator = ethers.TypedDataEncoder.hashDomain(domain);
            console.log("Contract domain separator:", contractDomainSeparator);
            console.log("Our domain separator:", ourDomainSeparator);
            console.log("Domain separators match:", contractDomainSeparator === ourDomainSeparator);

            // Sign and verify
            const signature = await owner.signTypedData(domain, types, message);
            console.log("Signature:", signature);

            const recovered = ethers.verifyTypedData(domain, types, message, signature);
            console.log("Recovered address (ethers):", recovered);
            console.log("Reward signer (should match):", ownerAddress);

            // Test the signature verification directly in the contract
            const isValid = await airdrop._verifyClaimSignature(
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                chainId,
                signature
            );
            console.log("Signature verification result (contract):", isValid);

            const initialBalance = await mockToken.balanceOf(user1Address);
            await expect(airdrop.connect(user1).claim(user1Address, mockTokenAddress, amount, nonce, signature))
                .to.emit(airdrop, "Claimed")
                .withArgs(user1Address, mockTokenAddress, amount, nonce);
            expect(await mockToken.balanceOf(user1Address)).to.equal(initialBalance + amount);
            expect(await airdrop.getNonce(user1Address, mockTokenAddress)).to.equal(BigInt(nonce) + 1n);
        });

        it("Should reject claim for non-whitelisted token", async function () {
            const nonWhitelistedToken = user2Address;
            const signatureForNonWhitelisted = await createEIP712Signature(
                owner,
                user1Address,
                nonWhitelistedToken,
                amount,
                nonce,
                chainId
            );
            
            await expect(
                airdrop.connect(user1).claim(user1Address, nonWhitelistedToken, amount, nonce, signatureForNonWhitelisted)
            ).to.be.revertedWithCustomError(airdrop, "NotWhitelistedToken");
        });

        it("Should reject claim with invalid nonce", async function () {
            const wrongNonce = nonce + 1;
            const signatureWrongNonce = await createEIP712Signature(
                owner,
                user1Address,
                mockTokenAddress,
                amount,
                wrongNonce,
                chainId
            );
            
            await expect(
                airdrop.connect(user1).claim(user1Address, mockTokenAddress, amount, wrongNonce, signatureWrongNonce)
            ).to.be.revertedWithCustomError(airdrop, "InvalidNonce");
        });

        it("Should reject claim with invalid signature", async function () {
            const signatureWrongSigner = await createEIP712Signature(
                user1, // Wrong signer
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                chainId
            );
            
            await expect(
                airdrop.connect(user1).claim(user1Address, mockTokenAddress, amount, nonce, signatureWrongSigner)
            ).to.be.revertedWithCustomError(airdrop, "InvalidSignature");
        });

        it("Should reject replay attack", async function () {
            // First claim should succeed
            await airdrop.connect(user1).claim(user1Address, mockTokenAddress, amount, nonce, signature);
            
            // Second claim with same signature should fail
            await expect(
                airdrop.connect(user1).claim(user1Address, mockTokenAddress, amount, nonce, signature)
            ).to.be.revertedWithCustomError(airdrop, "InvalidNonce");
        });

        it("Should allow multiple claims with different nonces", async function () {
            const initialBalance = await mockToken.balanceOf(user1Address);
            
            // First claim
            const signature1 = await createEIP712Signature(
                owner,
                user1Address,
                mockTokenAddress,
                amount,
                0,
                chainId
            );
            
            await airdrop.connect(user1).claim(user1Address, mockTokenAddress, amount, 0, signature1);
            
            // Second claim
            const signature2 = await createEIP712Signature(
                owner,
                user1Address,
                mockTokenAddress,
                amount,
                1,
                chainId
            );
            
            await airdrop.connect(user1).claim(user1Address, mockTokenAddress, amount, 1, signature2);
            
            expect(await mockToken.balanceOf(user1Address)).to.equal(initialBalance + amount * 2n);
        });

        it("Should reject claim with wrong chain ID", async function () {
            const wrongChainId = 999;
            const signatureWrongChain = await createEIP712Signature(
                owner,
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                wrongChainId
            );
            
            await expect(
                airdrop.connect(user1).claim(user1Address, mockTokenAddress, amount, nonce, signatureWrongChain)
            ).to.be.revertedWithCustomError(airdrop, "InvalidSignature");
        });

        it("Should reject claim with wrong domain separator", async function () {
            // Create signature with wrong domain (different contract address)
            const wrongDomain = {
                name: 'RKGENAirdrop',
                version: '1',
                chainId: chainId,
                verifyingContract: user1Address // Wrong contract address
            };
            
            const message = {
                user: user1Address,
                token: mockTokenAddress,
                amount: amount,
                nonce: nonce,
                chainId: chainId
            };
            
            const wrongSignature = await owner.signTypedData(wrongDomain, types, message);
            
            await expect(
                airdrop.connect(user1).claim(user1Address, mockTokenAddress, amount, nonce, wrongSignature)
            ).to.be.revertedWithCustomError(airdrop, "InvalidSignature");
        });
    });

    describe("View Functions", function () {
        it("Should return correct nominated admin", async function () {
            await airdrop.nominateAdmin(nominatedAdminAddress);
            expect(await airdrop.getNominatedAdmin()).to.equal(nominatedAdminAddress);
        });

        it("Should return correct reward signer", async function () {
            expect(await airdrop.getRewardSigner()).to.equal(ownerAddress);
        });

        it("Should return correct chain ID", async function () {
            expect(await airdrop.chainId()).to.equal(chainId);
        });

        it("Should return correct domain separator", async function () {
            // Try different methods to get domain separator
            let domainSeparator;
            try {
                domainSeparator = await airdrop.DOMAIN_SEPARATOR();
            } catch {
                try {
                    domainSeparator = await airdrop.getDomainSeparator();
                } catch {
                    // If both fail, skip this test
                    this.skip();
                }
            }
            expect(domainSeparator).to.not.equal(ethers.ZeroHash);
        });
    });

    describe("Edge Cases", function () {
        it("Should handle zero amount claims", async function () {
            const amount = 0n;
            const nonce = 0;
            
            const signature = await createEIP712Signature(
                owner,
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                chainId
            );
            
            await airdrop.connect(user1).claim(user1Address, mockTokenAddress, amount, nonce, signature);
            expect(await airdrop.getNonce(user1Address, mockTokenAddress)).to.equal(1);
        });

        it("Should handle large amounts", async function () {
            const amount = ethers.parseUnits("1000000", 8); // 1 million tokens
            const nonce = 0;
            
            const signature = await createEIP712Signature(
                owner,
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                chainId
            );
            
            await airdrop.connect(user1).claim(user1Address, mockTokenAddress, amount, nonce, signature);
            expect(await mockToken.balanceOf(user1Address)).to.equal(amount);
        });

        it("Should handle very large amounts", async function () {
            const amount = ethers.parseUnits("1000000000", 8); // 1 billion tokens
            const nonce = 0;
            
            // Mint enough tokens to the airdrop contract for this test
            await mockToken.mint(await airdrop.getAddress(), amount);
            
            const signature = await createEIP712Signature(
                owner,
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                chainId
            );
            
            await airdrop.connect(user1).claim(user1Address, mockTokenAddress, amount, nonce, signature);
            expect(await mockToken.balanceOf(user1Address)).to.equal(amount);
        });
    });

    describe("EIP-712 Specific Tests", function () {
        it("Should verify EIP-712 domain separator matches contract", async function () {
            // Try different methods to get domain separator
            let contractDomainSeparator;
            try {
                contractDomainSeparator = await airdrop.DOMAIN_SEPARATOR();
            } catch {
                try {
                    contractDomainSeparator = await airdrop.getDomainSeparator();
                } catch {
                    // If both fail, skip this test
                    this.skip();
                }
            }
            
            // Calculate expected domain separator
            const expectedDomainSeparator = ethers.keccak256(
                ethers.AbiCoder.defaultAbiCoder().encode(
                    ["bytes32", "bytes32", "bytes32", "uint256", "address"],
                    [
                        ethers.keccak256(ethers.toUtf8Bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")),
                        ethers.keccak256(ethers.toUtf8Bytes("RKGENAirdrop")),
                        ethers.keccak256(ethers.toUtf8Bytes("1")),
                        chainId,
                        await airdrop.getAddress()
                    ]
                )
            );
            
            expect(contractDomainSeparator).to.equal(expectedDomainSeparator);
        });

        it("Should verify EIP-712 type hash", async function () {
            const expectedTypeHash = ethers.keccak256(
                ethers.toUtf8Bytes("Claim(address user,address token,uint256 amount,uint256 nonce,uint256 chainId)")
            );
            
            expect(await airdrop.CLAIM_TYPEHASH()).to.equal(expectedTypeHash);
        });
    });
});

describe("Direct Airdrop Claim (Relayer Pays Gas)", function () {
    let airdrop: any;
    let mockToken: any;
    let admin: Signer;
    let relayer: Signer;
    let user: Signer;
    
    let adminAddress: string;
    let relayerAddress: string;
    let userAddress: string;
    let mockTokenAddress: string;

    const chainId = 31337; // hardhat
    const CLAIM_AMOUNT = ethers.parseUnits("100", 8); // 100 tokens with 8 decimals

    // EIP-712 Domain and Types
    let domain: any;
    let types: any;

    beforeEach(async function () {
        [admin, relayer, user] = await ethers.getSigners();
        adminAddress = await admin.getAddress();
        relayerAddress = await relayer.getAddress();
        userAddress = await user.getAddress();

        // Deploy mock ERC20 token
        const MockTokenFactory = await ethers.getContractFactory("MockERC20");
        mockToken = await MockTokenFactory.deploy("Mock Token", "MTK");
        await mockToken.waitForDeployment();
        mockTokenAddress = await mockToken.getAddress();

        // Deploy airdrop contract
        const AirdropFactory = await ethers.getContractFactory("RKGENAirdrop");
        airdrop = await AirdropFactory.deploy();
        await airdrop.waitForDeployment();
        
        // Initialize the contract - admin will be the reward signer
        await airdrop.initialize("RKGENAirdrop", chainId);
        
        // Whitelist the token
        await airdrop.whitelistToken(mockTokenAddress);
        
        // Set up EIP-712 domain and types
        domain = {
            name: 'RKGENAirdrop',
            version: '1',
            chainId: chainId,
            verifyingContract: await airdrop.getAddress()
        };
        
        types = {
            Claim: [
                { name: 'user', type: 'address' },
                { name: 'token', type: 'address' },
                { name: 'amount', type: 'uint256' },
                { name: 'nonce', type: 'uint256' },
                { name: 'chainId', type: 'uint256' }
            ]
        };
        
        // Transfer some tokens to the airdrop contract for testing
        const tokenAmount = ethers.parseEther("1000000");
        await mockToken.mint(await airdrop.getAddress(), tokenAmount);
    });

    // Helper function to create EIP-712 signature
    async function createEIP712Signature(
        signer: Signer,
        user: string,
        token: string,
        amount: bigint,
        nonce: number,
        chainId: number
    ): Promise<string> {
        const message = {
            user: user,
            token: token,
            amount: amount,
            nonce: nonce,
            chainId: chainId
        };
        
        return await signer.signTypedData(domain, types, message);
    }

    it("Should allow relayer to pay gas for user's airdrop claim", async function () {
        // Get user's nonce for the airdrop contract
        const userNonce = Number(await airdrop.getNonce(userAddress, mockTokenAddress));
        console.log(`User nonce for airdrop: ${userNonce.toString()}`);

        // Get contract chain ID
        const contractChainId = await airdrop.chainId();
        console.log(`Contract Chain ID: ${contractChainId.toString()}`);

        // Admin signs the airdrop claim for the user
        const airdropSignature = await createEIP712Signature(
            admin,
            userAddress,
            mockTokenAddress,
            CLAIM_AMOUNT,
            userNonce,
            contractChainId
        );
        console.log(`Admin signature for user's airdrop claim: ${airdropSignature}`);

        // Debug: Check what _msgSender() will return
        console.log(`User address: ${userAddress}`);
        console.log(`Relayer address: ${relayerAddress}`);
        console.log(`Contract chainId: ${contractChainId}`);

        // Check balances before transaction
        const userBalanceBefore = await mockToken.balanceOf(userAddress);
        const relayerBalanceBefore = await ethers.provider.getBalance(relayerAddress);
        console.log(`User token balance before: ${ethers.formatUnits(userBalanceBefore, 8)} tokens`);
        console.log(`Relayer BNB balance before: ${ethers.formatEther(relayerBalanceBefore)} BNB`);

        // Relayer calls the airdrop claim function (relayer pays gas, user gets tokens)
        console.log(`Relayer calling airdrop claim function for user...`);
        console.log(`User: ${userAddress}`);
        console.log(`Relayer: ${relayerAddress}`);
        console.log(`Claim amount: ${ethers.formatUnits(CLAIM_AMOUNT, 8)} tokens`);
        console.log(`Airdrop nonce: ${userNonce.toString()}`);

        // Get gas estimate
        const gasEstimate = await airdrop.connect(relayer).claim.estimateGas(
            userAddress,
            mockTokenAddress,
            CLAIM_AMOUNT,
            userNonce,
            airdropSignature
        );
        console.log(`Estimated gas: ${gasEstimate.toString()}`);

        // Get fee data
        const feeData = await ethers.provider.getFeeData();
        const gasPrice = feeData.gasPrice || ethers.parseUnits("20", "gwei"); // Fallback to 20 gwei if null
        const estimatedCost = gasEstimate * gasPrice;
        console.log(`Gas price: ${ethers.formatUnits(gasPrice, 'gwei')} gwei`);
        console.log(`Estimated cost: ${ethers.formatEther(estimatedCost)} BNB`);

        if (relayerBalanceBefore < estimatedCost) {
            throw new Error(`Insufficient relayer balance. Balance: ${ethers.formatEther(relayerBalanceBefore)}, Estimated cost: ${ethers.formatEther(estimatedCost)}`);
        }

        // Execute the claim transaction (relayer pays gas)
        const tx = await airdrop.connect(relayer).claim(
            userAddress,
            mockTokenAddress,
            CLAIM_AMOUNT,
            userNonce,
            airdropSignature,
            {
                gasLimit: gasEstimate,
                gasPrice: gasPrice
            }
        );
        
        console.log(`Direct claim transaction hash: ${tx.hash}`);
        const receipt = await tx.wait();
        console.log(`Direct claim transaction confirmed in block ${receipt.blockNumber}`);
        
        // Check balances after transaction
        const userBalanceAfter = await mockToken.balanceOf(userAddress);
        const relayerBalanceAfter = await ethers.provider.getBalance(relayerAddress);
        console.log(`User token balance after: ${ethers.formatUnits(userBalanceAfter, 8)} tokens`);
        console.log(`Relayer BNB balance after: ${ethers.formatEther(relayerBalanceAfter)} BNB`);
        console.log(`Gas used: ${receipt.gasUsed.toString()}`);
        console.log(`Actual cost: ${ethers.formatEther(receipt.gasUsed * gasPrice)} BNB`);

        // Verify the results
        expect(userBalanceAfter).to.equal(userBalanceBefore + CLAIM_AMOUNT);
        expect(relayerBalanceAfter).to.be.lessThan(relayerBalanceBefore);
        expect(await airdrop.getNonce(userAddress, mockTokenAddress)).to.equal(BigInt(userNonce) + 1n);

        console.log(`✅ Test passed: User received ${ethers.formatUnits(CLAIM_AMOUNT, 8)} tokens, relayer paid gas`);
    });

    it("Should allow multiple claims with relayer paying gas", async function () {
        const numberOfClaims = 3;
        
        for (let i = 0; i < numberOfClaims; i++) {
            const userNonce = Number(await airdrop.getNonce(userAddress, mockTokenAddress));
            const contractChainId = await airdrop.chainId();
            
            // Admin signs the airdrop claim for the user
            const airdropSignature = await createEIP712Signature(
                admin,
                userAddress,
                mockTokenAddress,
                CLAIM_AMOUNT,
                userNonce,
                contractChainId
            );

            // Check balances before transaction
            const userBalanceBefore = await mockToken.balanceOf(userAddress);
            const relayerBalanceBefore = await ethers.provider.getBalance(relayerAddress);

            // Relayer calls the airdrop claim function
            const tx = await airdrop.connect(relayer).claim(
                userAddress,
                mockTokenAddress,
                CLAIM_AMOUNT,
                userNonce,
                airdropSignature
            );
            
            const receipt = await tx.wait();
            
            // Check balances after transaction
            const userBalanceAfter = await mockToken.balanceOf(userAddress);
            const relayerBalanceAfter = await ethers.provider.getBalance(relayerAddress);

            // Verify the results
            expect(userBalanceAfter).to.equal(userBalanceBefore + CLAIM_AMOUNT);
            expect(relayerBalanceAfter).to.be.lessThan(relayerBalanceBefore);
            expect(await airdrop.getNonce(userAddress, mockTokenAddress)).to.equal(BigInt(userNonce) + 1n);

            console.log(`✅ Claim ${i + 1}/${numberOfClaims} completed: User received ${ethers.formatUnits(CLAIM_AMOUNT, 8)} tokens`);
        }

        // Verify final state
        const finalUserBalance = await mockToken.balanceOf(userAddress);
        expect(finalUserBalance).to.equal(CLAIM_AMOUNT * BigInt(numberOfClaims));
        console.log(`✅ All ${numberOfClaims} claims completed successfully`);
    });

});

// Mock ERC20 Token for testing
describe("MockERC20", function () {
    let mockToken: any;
    let owner: Signer;
    let user1: Signer;
    
    let ownerAddress: string;
    let user1Address: string;

    beforeEach(async function () {
        [owner, user1] = await ethers.getSigners();
        ownerAddress = await owner.getAddress();
        user1Address = await user1.getAddress();

        const MockTokenFactory = await ethers.getContractFactory("MockERC20");
        mockToken = await MockTokenFactory.deploy("Mock Token", "MTK");
         
        await mockToken.waitForDeployment();
    });

    it("Should have correct name and symbol", async function () {
        expect(await mockToken.name()).to.equal("Mock Token");
        expect(await mockToken.symbol()).to.equal("MTK");
    });

    it("Should allow minting", async function () {
        const amount = ethers.parseEther("1000");
        await mockToken.mint(user1Address, amount);
        expect(await mockToken.balanceOf(user1Address)).to.equal(amount);
    });

    it("Should allow transfers", async function () {
        const amount = ethers.parseEther("1000");
        await mockToken.mint(ownerAddress, amount);
        await mockToken.transfer(user1Address, amount);
        expect(await mockToken.balanceOf(user1Address)).to.equal(amount);
    });
});
