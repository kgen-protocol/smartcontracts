import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";

describe("RKGENAirdrop", function () {
    let airdrop: any;
    let mockToken: any;
    let owner: Signer;
    let rewardSigner: Signer;
    let user1: Signer;
    let user2: Signer;
    let user3: Signer;
    let nominatedAdmin: Signer;
    
    let ownerAddress: string;
    let rewardSignerAddress: string;
    let user1Address: string;
    let user2Address: string;
    let user3Address: string;
    let nominatedAdminAddress: string;
    let mockTokenAddress: string;

    const chainId = 1; // Mainnet
    const ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ADMIN_ROLE"));

    // EIP-712 Domain and Types
    let domain: any;
    let types: any;

    beforeEach(async function () {
        [owner, rewardSigner, user1, user2, user3, nominatedAdmin] = await ethers.getSigners();
        ownerAddress = await owner.getAddress();
        rewardSignerAddress = await rewardSigner.getAddress();
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
        
        // Initialize the contract
        await airdrop.initialize(ownerAddress, rewardSignerAddress, chainId);
        
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

    describe("Deployment and Initialization", function () {
        it("Should set the correct admin", async function () {
            expect(await airdrop.hasRole(await airdrop.DEFAULT_ADMIN_ROLE(), ownerAddress)).to.equal(true);
            expect(await airdrop.hasRole(ADMIN_ROLE, ownerAddress)).to.equal(true);
        });

        it("Should set the correct reward signer", async function () {
            expect(await airdrop.rewardSigner()).to.equal(rewardSignerAddress);
        });

        it("Should set the correct chain ID", async function () {
            expect(await airdrop.chainId()).to.equal(chainId);
        });

        it("Should set up EIP-712 domain separator", async function () {
            const domainSeparator = await airdrop.getDomainSeparator();
            expect(domainSeparator).to.not.equal(ethers.ZeroHash);
        });

        it("Should not allow re-initialization", async function () {
            await expect(
                airdrop.initialize(ownerAddress, rewardSignerAddress, chainId)
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
                ).to.be.revertedWithCustomError(airdrop, "InvalidAdmin");
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
            ).to.be.revertedWithCustomError(airdrop, "InvalidSigner");
        });

        it("Should not allow setting same signer", async function () {
            await expect(
                airdrop.updateSigner(rewardSignerAddress)
            ).to.be.revertedWithCustomError(airdrop, "AlreadyExists");
        });
    });

    describe("Token Management", function () {
        it("Should allow admin to withdraw tokens", async function () {
            const withdrawAmount = ethers.parseEther("1000");
            const initialBalance = await mockToken.balanceOf(ownerAddress);
            
            await airdrop.withdrawTokens(mockTokenAddress, withdrawAmount);
            
            expect(await mockToken.balanceOf(ownerAddress)).to.equal(initialBalance + withdrawAmount);
        });

        it("Should emit TokensWithdrawn event", async function () {
            const withdrawAmount = ethers.parseEther("1000");
            await expect(airdrop.withdrawTokens(mockTokenAddress, withdrawAmount))
                .to.emit(airdrop, "TokensWithdrawn")
                .withArgs(ownerAddress, mockTokenAddress, withdrawAmount);
        });

        it("Should not allow non-admin to withdraw tokens", async function () {
            await expect(
                airdrop.connect(user1).withdrawTokens(mockTokenAddress, ethers.parseEther("1000"))
            ).to.be.revertedWithCustomError(airdrop, "AccessControlUnauthorizedAccount");
        });
    });

    describe("Nonce Management", function () {
        it("Should return zero for new user-token combination", async function () {
            expect(await airdrop.getNonce(user1Address, mockTokenAddress)).to.equal(0);
        });

        it("Should increment nonce after successful claim", async function () {
            const amount = ethers.parseEther("100");
            const nonce = 0;
            
            // Create EIP-712 signature
            const signature = await createEIP712Signature(
                rewardSigner,
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                chainId
            );
            
            await airdrop.connect(user1).claim(mockTokenAddress, amount, nonce, signature);
            
            expect(await airdrop.getNonce(user1Address, mockTokenAddress)).to.equal(1);
        });

        it("Should maintain separate nonces for different tokens", async function () {
            // Deploy second mock token
            const MockToken2Factory = await ethers.getContractFactory("MockERC20");
            const mockToken2 = await MockToken2Factory.deploy("Mock Token 2", "MTK2");
            await mockToken2.waitForDeployment();
            const mockToken2Address = await mockToken2.getAddress();
            
            // Transfer tokens to airdrop contract
            await mockToken2.mint(await airdrop.getAddress(), ethers.parseEther("1000000"));
            
            const amount = ethers.parseEther("100");
                const nonce = 0;
            
            // Create EIP-712 signatures for both tokens
            const signature1 = await createEIP712Signature(
                rewardSigner,
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                chainId
            );
            
            const signature2 = await createEIP712Signature(
                rewardSigner,
                user1Address,
                mockToken2Address,
                amount,
                nonce,
                chainId
            );
            
            // Claim both tokens
            await airdrop.connect(user1).claim(mockTokenAddress, amount, nonce, signature1);
            await airdrop.connect(user1).claim(mockToken2Address, amount, nonce, signature2);
            
            // Check separate nonces
            expect(await airdrop.getNonce(user1Address, mockTokenAddress)).to.equal(1);
            expect(await airdrop.getNonce(user1Address, mockToken2Address)).to.equal(1);
        });
    });

    describe("Claim Functionality", function () {
        const amount = ethers.parseEther("100");
        const nonce = 0;

        it("Should allow valid claim with correct EIP-712 signature", async function () {
            const initialBalance = await mockToken.balanceOf(user1Address);
            
            // Create EIP-712 signature
            const signature = await createEIP712Signature(
                rewardSigner,
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                chainId
            );
            
            await airdrop.connect(user1).claim(mockTokenAddress, amount, nonce, signature);
            
            expect(await mockToken.balanceOf(user1Address)).to.equal(initialBalance + amount);
        });

        it("Should emit Claimed event", async function () {
            const signature = await createEIP712Signature(
                rewardSigner,
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                chainId
            );
            
            await expect(airdrop.connect(user1).claim(mockTokenAddress, amount, nonce, signature))
                .to.emit(airdrop, "Claimed")
                .withArgs(user1Address, mockTokenAddress, amount, nonce);
        });

        it("Should emit SignatureVerified event", async function () {
            const signature = await createEIP712Signature(
                rewardSigner,
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                chainId
            );
            
            await expect(airdrop.connect(user1).claim(mockTokenAddress, amount, nonce, signature))
                .to.emit(airdrop, "SignatureVerified")
                .withArgs(signature, true);
        });

        it("Should reject claim with invalid nonce", async function () {
            const signature = await createEIP712Signature(
                rewardSigner,
                user1Address,
                mockTokenAddress,
                amount,
                1, // Wrong nonce
                chainId
            );
            
            await expect(
                airdrop.connect(user1).claim(mockTokenAddress, amount, 1, signature)
            ).to.be.revertedWithCustomError(airdrop, "InvalidNonce");
        });

        it("Should reject claim with invalid signature", async function () {
            const signature = await createEIP712Signature(
                user1, // Wrong signer
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                chainId
            );
            
            await expect(
                airdrop.connect(user1).claim(mockTokenAddress, amount, nonce, signature)
            ).to.be.revertedWithCustomError(airdrop, "InvalidSignature");
        });

        it("Should reject replay attack", async function () {
            const signature = await createEIP712Signature(
                rewardSigner,
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                chainId
            );
            
            // First claim should succeed
            await airdrop.connect(user1).claim(mockTokenAddress, amount, nonce, signature);
            
            // Second claim with same signature should fail
            await expect(
                airdrop.connect(user1).claim(mockTokenAddress, amount, nonce, signature)
            ).to.be.revertedWithCustomError(airdrop, "InvalidNonce");
        });

        it("Should allow multiple claims with different nonces", async function () {
            const initialBalance = await mockToken.balanceOf(user1Address);
            
            // First claim
            const signature1 = await createEIP712Signature(
                rewardSigner,
                user1Address,
                mockTokenAddress,
                amount,
                0,
                chainId
            );
            
            await airdrop.connect(user1).claim(mockTokenAddress, amount, 0, signature1);
            
            // Second claim
            const signature2 = await createEIP712Signature(
                rewardSigner,
                user1Address,
                mockTokenAddress,
                amount,
                1,
                chainId
            );
            
            await airdrop.connect(user1).claim(mockTokenAddress, amount, 1, signature2);
            
            expect(await mockToken.balanceOf(user1Address)).to.equal(initialBalance + amount * 2n);
        });

        it("Should reject claim with wrong chain ID", async function () {
            const wrongChainId = 999;
            const signature = await createEIP712Signature(
                rewardSigner,
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                wrongChainId
            );
            
            await expect(
                airdrop.connect(user1).claim(mockTokenAddress, amount, nonce, signature)
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
            
            const wrongSignature = await rewardSigner.signTypedData(wrongDomain, types, message);
            
            await expect(
                airdrop.connect(user1).claim(mockTokenAddress, amount, nonce, wrongSignature)
            ).to.be.revertedWithCustomError(airdrop, "InvalidSignature");
        });
    });

    describe("View Functions", function () {
        it("Should return correct nominated admin", async function () {
            await airdrop.nominateAdmin(nominatedAdminAddress);
            expect(await airdrop.getNominatedAdmin()).to.equal(nominatedAdminAddress);
        });

        it("Should return correct reward signer", async function () {
            expect(await airdrop.getRewardSigner()).to.equal(rewardSignerAddress);
        });

        it("Should return correct chain ID", async function () {
            expect(await airdrop.chainId()).to.equal(chainId);
        });

        it("Should return correct domain separator", async function () {
            const domainSeparator = await airdrop.getDomainSeparator();
            expect(domainSeparator).to.not.equal(ethers.ZeroHash);
        });
    });

    describe("Edge Cases", function () {
        it("Should handle zero amount claims", async function () {
            const amount = 0n;
            const nonce = 0;
            
            const signature = await createEIP712Signature(
                rewardSigner,
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                chainId
            );
            
            await airdrop.connect(user1).claim(mockTokenAddress, amount, nonce, signature);
            expect(await airdrop.getNonce(user1Address, mockTokenAddress)).to.equal(1);
        });

        it("Should handle large amounts", async function () {
            const amount = ethers.parseEther("1000000"); // 1 million tokens
            const nonce = 0;
            
            const signature = await createEIP712Signature(
                rewardSigner,
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                chainId
            );
            
            await airdrop.connect(user1).claim(mockTokenAddress, amount, nonce, signature);
            expect(await mockToken.balanceOf(user1Address)).to.equal(amount);
        });

        it("Should handle very large amounts", async function () {
            const amount = ethers.parseEther("1000000000"); // 1 billion tokens
            const nonce = 0;
            
            // Mint enough tokens to the airdrop contract for this test
            await mockToken.mint(await airdrop.getAddress(), amount);
            
            const signature = await createEIP712Signature(
                rewardSigner,
                user1Address,
                mockTokenAddress,
                amount,
                nonce,
                chainId
            );
            
            await airdrop.connect(user1).claim(mockTokenAddress, amount, nonce, signature);
            expect(await mockToken.balanceOf(user1Address)).to.equal(amount);
        });
    });

    describe("EIP-712 Specific Tests", function () {
        it("Should verify EIP-712 domain separator matches contract", async function () {
            const contractDomainSeparator = await airdrop.getDomainSeparator();
            
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
