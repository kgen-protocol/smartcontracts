import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { Contract, Signer } from "ethers";

describe("KGeN Token", function () {
    let kgen: any;
    let owner: Signer;
    let addr1: Signer;
    let addr2: Signer;
    let addr3: Signer;
    let addr4: Signer;
    let addr5: Signer;
    let ownerAddress: string;
    let addr1Address: string;
    let addr2Address: string;
    let addr3Address: string;
    let addr4Address: string;
    let addr5Address: string;
    
    const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
    const TREASURY_ROLE = ethers.keccak256(ethers.toUtf8Bytes("TREASURY_ROLE"));
    const BURN_VAULT_ROLE = ethers.keccak256(ethers.toUtf8Bytes("BURN_VAULT_ROLE"));
    const UPGRADER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("UPGRADER_ROLE"));
    const MAX_SUPPLY = ethers.parseUnits("1000000000", 8); // 1 billion tokens

    beforeEach(async function () {
        [owner, addr1, addr2, addr3, addr4, addr5] = await ethers.getSigners();
        ownerAddress = await owner.getAddress();
        addr1Address = await addr1.getAddress();
        addr2Address = await addr2.getAddress();
        addr3Address = await addr3.getAddress();
        addr4Address = await addr4.getAddress();
        addr5Address = await addr5.getAddress();
        
        const KGENTokenFactory = await ethers.getContractFactory("KGENToken");
        kgen = await upgrades.deployProxy(KGENTokenFactory, [ownerAddress], {
            initializer: 'initialize',
            kind: 'transparent'
        });
        await kgen.waitForDeployment();
    });

    describe("Deployment & Initialization", function () {
        it("Should set the correct token name and symbol", async function () {
            expect(await kgen.name()).to.equal("KGEN");
            expect(await kgen.symbol()).to.equal("KGEN");
        });

        it("Should set the correct decimals", async function () {
            expect(await kgen.decimals()).to.equal(8);
        });

        it("Should assign all roles to initial admin", async function () {
            expect(await kgen.hasRole(await kgen.DEFAULT_ADMIN_ROLE(), ownerAddress)).to.equal(true);
            expect(await kgen.hasRole(MINTER_ROLE, ownerAddress)).to.equal(true);
            expect(await kgen.hasRole(TREASURY_ROLE, ownerAddress)).to.equal(true);
            expect(await kgen.hasRole(BURN_VAULT_ROLE, ownerAddress)).to.equal(true);
            expect(await kgen.hasRole(UPGRADER_ROLE, ownerAddress)).to.equal(true);
        });

        it("Should not allow re-initialization", async function () {
            await expect(kgen.initialize(addr1Address))
                .to.be.revertedWithCustomError(kgen, "InvalidInitialization");
        });

        it("Should have zero total supply initially", async function () {
            expect(await kgen.totalSupply()).to.equal(0);
        });

        it("Should have correct max supply", async function () {
            expect(await kgen.MAX_SUPPLY()).to.equal(MAX_SUPPLY);
        });
    });

    describe("Admin Management", function () {
        it("Should allow admin to nominate new admin", async function () {
            await kgen.transferAdmin(addr1Address);
            expect(await kgen.getPendingAdmin()).to.equal(addr1Address);
        });

        it("Should not allow admin to nominate self", async function () {
            await expect(kgen.transferAdmin(ownerAddress))
                .to.be.revertedWithCustomError(kgen, "CannotNominateSelf");
        });

        it("Should not allow admin to nominate zero address", async function () {
            await expect(kgen.transferAdmin(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(kgen, "NotValidAddress");
        });

        it("Should not allow non-admin to nominate admin", async function () {
            await expect(kgen.connect(addr1).transferAdmin(addr2Address))
                .to.be.revertedWithCustomError(kgen, "OnlyAdmin");
        });

        it("Should allow nominated admin to accept role", async function () {
            await kgen.transferAdmin(addr1Address);
            await kgen.connect(addr1).acceptAdmin();
            
            expect(await kgen.getAdmin()).to.equal(addr1Address);
            expect(await kgen.getPendingAdmin()).to.equal(ethers.ZeroAddress);
            expect(await kgen.hasRole(await kgen.DEFAULT_ADMIN_ROLE(), addr1Address)).to.equal(true);
            expect(await kgen.hasRole(await kgen.DEFAULT_ADMIN_ROLE(), ownerAddress)).to.equal(false);
        });

        it("Should not allow non-nominated address to accept admin role", async function () {
            await kgen.transferAdmin(addr1Address);
            await expect(kgen.connect(addr2).acceptAdmin())
                .to.be.revertedWithCustomError(kgen, "NotNominated");
        });

        it("Should not allow accepting admin role when no nomination is pending", async function () {
            await expect(kgen.connect(addr1).acceptAdmin())
                .to.be.revertedWithCustomError(kgen, "NotNominated");
        });
    });

    describe("Minter Management", function () {
        it("Should allow admin to add minter", async function () {
            await kgen.addMinter(addr1Address);
            expect(await kgen.hasRole(MINTER_ROLE, addr1Address)).to.equal(true);
        });

        it("Should not allow admin to add zero address as minter", async function () {
            await expect(kgen.addMinter(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(kgen, "NotValidAddress");
        });

        it("Should not allow non-admin to add minter", async function () {
            await expect(kgen.connect(addr1).addMinter(addr2Address))
                .to.be.revertedWithCustomError(kgen, "OnlyAdmin");
        });

        it("Should not allow adding already existing minter", async function () {
            await kgen.addMinter(addr1Address);
            await expect(kgen.addMinter(addr1Address))
                .to.be.revertedWithCustomError(kgen, "AlreadyMinter");
        });

        it("Should allow admin to remove minter", async function () {
            await kgen.addMinter(addr1Address);
            await kgen.removeMinter(addr1Address);
            expect(await kgen.hasRole(MINTER_ROLE, addr1Address)).to.equal(false);
        });

        it("Should not allow non-admin to remove minter", async function () {
            await kgen.addMinter(addr1Address);
            await expect(kgen.connect(addr2).removeMinter(addr1Address))
                .to.be.revertedWithCustomError(kgen, "OnlyAdmin");
        });

        it("Should not allow removing non-existent minter", async function () {
            await expect(kgen.removeMinter(addr1Address))
                .to.be.revertedWithCustomError(kgen, "NotMinter");
        });
    });

    describe("Treasury Management", function () {
        it("Should allow admin to add treasury", async function () {
            await kgen.addTreasury(addr1Address);
            expect(await kgen.hasRole(TREASURY_ROLE, addr1Address)).to.equal(true);
            expect(await kgen.isWhitelistedSender(addr1Address)).to.equal(true);
        });

        it("Should not allow admin to add zero address as treasury", async function () {
            await expect(kgen.addTreasury(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(kgen, "NotValidAddress");
        });

        it("Should not allow non-admin to add treasury", async function () {
            await expect(kgen.connect(addr1).addTreasury(addr2Address))
                .to.be.revertedWithCustomError(kgen, "OnlyAdmin");
        });

        it("Should not allow adding already existing treasury", async function () {
            await kgen.addTreasury(addr1Address);
            await expect(kgen.addTreasury(addr1Address))
                .to.be.revertedWithCustomError(kgen, "AlreadyTreasury");
        });

        it("Should allow admin to remove treasury", async function () {
            await kgen.addTreasury(addr1Address);
            await kgen.removeTreasury(addr1Address);
            expect(await kgen.hasRole(TREASURY_ROLE, addr1Address)).to.equal(false);
        });

        it("Should not allow non-admin to remove treasury", async function () {
            await kgen.addTreasury(addr1Address);
            await expect(kgen.connect(addr2).removeTreasury(addr1Address))
                .to.be.revertedWithCustomError(kgen, "OnlyAdmin");
        });

        it("Should not allow removing non-existent treasury", async function () {
            await expect(kgen.removeTreasury(addr1Address))
                .to.be.revertedWithCustomError(kgen, "NotTreasury");
        });
    });

    describe("Burn Vault Management", function () {
        it("Should allow admin to add burn vault", async function () {
            await kgen.addBurnVault(addr1Address);
            expect(await kgen.hasRole(BURN_VAULT_ROLE, addr1Address)).to.equal(true);
        });

        it("Should not allow admin to add zero address as burn vault", async function () {
            await expect(kgen.addBurnVault(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(kgen, "NotValidAddress");
        });

        it("Should not allow non-admin to add burn vault", async function () {
            await expect(kgen.connect(addr1).addBurnVault(addr2Address))
                .to.be.revertedWithCustomError(kgen, "OnlyAdmin");
        });

        it("Should not allow adding already existing burn vault", async function () {
            await kgen.addBurnVault(addr1Address);
            await expect(kgen.addBurnVault(addr1Address))
                .to.be.revertedWithCustomError(kgen, "AlreadyBurnVault");
        });

        it("Should allow admin to remove burn vault", async function () {
            await kgen.addBurnVault(addr1Address);
            await kgen.removeBurnVault(addr1Address);
            expect(await kgen.hasRole(BURN_VAULT_ROLE, addr1Address)).to.equal(false);
        });

        it("Should not allow non-admin to remove burn vault", async function () {
            await kgen.addBurnVault(addr1Address);
            await expect(kgen.connect(addr2).removeBurnVault(addr1Address))
                .to.be.revertedWithCustomError(kgen, "OnlyAdmin");
        });

        it("Should not allow removing non-existent burn vault", async function () {
            await expect(kgen.removeBurnVault(addr1Address))
                .to.be.revertedWithCustomError(kgen, "NotBurnVault");
        });
    });

    describe("Whitelist Management", function () {
        describe("Sender Whitelist", function () {
            it("Should allow admin to add sender to whitelist", async function () {
                await kgen.addWhitelistSender(addr1Address);
                expect(await kgen.isWhitelistedSender(addr1Address)).to.equal(true);
            });

            it("Should not allow admin to add zero address to sender whitelist", async function () {
                await expect(kgen.addWhitelistSender(ethers.ZeroAddress))
                    .to.be.revertedWithCustomError(kgen, "NotValidAddress");
            });

            it("Should not allow non-admin to add sender to whitelist", async function () {
                await expect(kgen.connect(addr1).addWhitelistSender(addr2Address))
                    .to.be.revertedWithCustomError(kgen, "OnlyAdmin");
            });

            it("Should not allow adding already whitelisted sender", async function () {
                await kgen.addWhitelistSender(addr1Address);
                await expect(kgen.addWhitelistSender(addr1Address))
                    .to.be.revertedWithCustomError(kgen, "AlreadyWhitelistedSender");
            });

            it("Should allow admin to remove sender from whitelist", async function () {
                await kgen.addWhitelistSender(addr1Address);
                await kgen.removeWhitelistSender(addr1Address);
                expect(await kgen.isWhitelistedSender(addr1Address)).to.equal(false);
            });

            it("Should not allow non-admin to remove sender from whitelist", async function () {
                await kgen.addWhitelistSender(addr1Address);
                await expect(kgen.connect(addr2).removeWhitelistSender(addr1Address))
                    .to.be.revertedWithCustomError(kgen, "OnlyAdmin");
            });

            it("Should not allow removing non-whitelisted sender", async function () {
                await expect(kgen.removeWhitelistSender(addr1Address))
                    .to.be.revertedWithCustomError(kgen, "NotWhitelistedSender");
            });

            it("Should not allow removing treasury from sender whitelist", async function () {
                await kgen.addTreasury(addr1Address);
                await expect(kgen.removeWhitelistSender(addr1Address))
                    .to.be.revertedWithCustomError(kgen, "CannotDeleteTreasuryAddress");
            });
        });

        describe("Receiver Whitelist", function () {
            it("Should allow admin to add receiver to whitelist", async function () {
                await kgen.addWhitelistReceiver(addr1Address);
                expect(await kgen.isWhitelistedReceiver(addr1Address)).to.equal(true);
            });

            it("Should not allow admin to add zero address to receiver whitelist", async function () {
                await expect(kgen.addWhitelistReceiver(ethers.ZeroAddress))
                    .to.be.revertedWithCustomError(kgen, "NotValidAddress");
            });

            it("Should not allow non-admin to add receiver to whitelist", async function () {
                await expect(kgen.connect(addr1).addWhitelistReceiver(addr2Address))
                    .to.be.revertedWithCustomError(kgen, "OnlyAdmin");
            });

            it("Should not allow adding already whitelisted receiver", async function () {
                await kgen.addWhitelistReceiver(addr1Address);
                await expect(kgen.addWhitelistReceiver(addr1Address))
                    .to.be.revertedWithCustomError(kgen, "AlreadyWhitelistedReceiver");
            });

            it("Should allow admin to remove receiver from whitelist", async function () {
                await kgen.addWhitelistReceiver(addr1Address);
                await kgen.removeWhitelistReceiver(addr1Address);
                expect(await kgen.isWhitelistedReceiver(addr1Address)).to.equal(false);
            });

            it("Should not allow non-admin to remove receiver from whitelist", async function () {
                await kgen.addWhitelistReceiver(addr1Address);
                await expect(kgen.connect(addr2).removeWhitelistReceiver(addr1Address))
                    .to.be.revertedWithCustomError(kgen, "OnlyAdmin");
            });

            it("Should not allow removing non-whitelisted receiver", async function () {
                await expect(kgen.removeWhitelistReceiver(addr1Address))
                    .to.be.revertedWithCustomError(kgen, "NotWhitelistedReceiver");
            });
        });
    });

    describe("Freeze/Unfreeze Logic", function () {
        it("Should allow admin to freeze accounts", async function () {
            const accounts = [addr1Address, addr2Address];
            const sendingFlags = [true, false];
            const receivingFlags = [false, true];
            
            await kgen.freezeAccounts(accounts, sendingFlags, receivingFlags);
            
            const status1 = await kgen.isFrozen(addr1Address);
            const status2 = await kgen.isFrozen(addr2Address);
            
            expect(status1.sending).to.equal(true);
            expect(status1.receiving).to.equal(false);
            expect(status2.sending).to.equal(false);
            expect(status2.receiving).to.equal(true);
        });

        it("Should not allow non-admin to freeze accounts", async function () {
            const accounts = [addr1Address];
            const sendingFlags = [true];
            const receivingFlags = [false];
            
            await expect(kgen.connect(addr1).freezeAccounts(accounts, sendingFlags, receivingFlags))
                .to.be.revertedWithCustomError(kgen, "OnlyAdmin");
        });

        it("Should revert when array lengths don't match", async function () {
            const accounts = [addr1Address, addr2Address];
            const sendingFlags = [true];
            const receivingFlags = [false, true];
            
            await expect(kgen.freezeAccounts(accounts, sendingFlags, receivingFlags))
                .to.be.revertedWith("ARGUMENT_VECTORS_LENGTH_MISMATCH");
        });

        it("Should allow admin to unfreeze accounts", async function () {
            const accounts = [addr1Address, addr2Address];
            const sendingFlags = [true, true];
            const receivingFlags = [true, true];
            
            await kgen.freezeAccounts(accounts, sendingFlags, receivingFlags);
            
            const unfreezeSending = [true, false];
            const unfreezeReceiving = [false, true];
            
            await kgen.unfreezeAccounts(accounts, unfreezeSending, unfreezeReceiving);
            
            const status1 = await kgen.isFrozen(addr1Address);
            const status2 = await kgen.isFrozen(addr2Address);
            
            expect(status1.sending).to.equal(false);
            expect(status1.receiving).to.equal(true);
            expect(status2.sending).to.equal(true);
            expect(status2.receiving).to.equal(false);
        });

        it("Should not allow non-admin to unfreeze accounts", async function () {
            const accounts = [addr1Address];
            const unfreezeSending = [true];
            const unfreezeReceiving = [false];
            
            await expect(kgen.connect(addr1).unfreezeAccounts(accounts, unfreezeSending, unfreezeReceiving))
                .to.be.revertedWithCustomError(kgen, "OnlyAdmin");
        });

        it("Should revert unfreeze when array lengths don't match", async function () {
            const accounts = [addr1Address, addr2Address];
            const unfreezeSending = [true];
            const unfreezeReceiving = [false, true];
            
            await expect(kgen.unfreezeAccounts(accounts, unfreezeSending, unfreezeReceiving))
                .to.be.revertedWith("ARGUMENT_VECTORS_LENGTH_MISMATCH");
        });
    });

    describe("Minting & Burning", function () {
        beforeEach(async function () {
            await kgen.addTreasury(addr1Address);
            await kgen.addBurnVault(addr2Address);
        });

        describe("Minting", function () {
            it("Should allow minter to mint to treasury", async function () {
                const amount = ethers.parseUnits("1000", 8);
                await kgen.mint(addr1Address, amount);
                expect(await kgen.balanceOf(addr1Address)).to.equal(amount);
            });

            it("Should not allow non-minter to mint", async function () {
                const amount = ethers.parseUnits("1000", 8);
                await expect(kgen.connect(addr3).mint(addr1Address, amount))
                    .to.be.revertedWithCustomError(kgen, "NotMinter");
            });

            it("Should not allow minting to non-treasury", async function () {
                const amount = ethers.parseUnits("1000", 8);
                await expect(kgen.mint(addr3Address, amount))
                    .to.be.revertedWithCustomError(kgen, "NotTreasury");
            });

            it("Should not allow minting zero amount", async function () {
                await expect(kgen.mint(addr1Address, 0))
                    .to.be.revertedWithCustomError(kgen, "InvalidAmount");
            });

            it("Should not allow minting to frozen treasury", async function () {
                await kgen.freezeAccounts([addr1Address], [false], [true]);
                const amount = ethers.parseUnits("1000", 8);
                await expect(kgen.mint(addr1Address, amount))
                    .to.be.revertedWithCustomError(kgen, "AccountIsFrozen");
            });

            it("Should not allow minting beyond max supply", async function () {
                const maxMintAmount = MAX_SUPPLY + ethers.parseUnits("1", 8);
                await expect(kgen.mint(addr1Address, maxMintAmount))
                    .to.be.revertedWithCustomError(kgen, "ExceedsMaxSupply");
            });

            it("Should emit MintedToTreasury event", async function () {
                const amount = ethers.parseUnits("1000", 8);
                await expect(kgen.mint(addr1Address, amount))
                    .to.emit(kgen, "MintedToTreasury")
                    .withArgs(addr1Address, amount);
            });
        });

        describe("Burning", function () {
            beforeEach(async function () {
                await kgen.addBurnVault(addr1Address);
                await kgen.mint(addr1Address, ethers.parseUnits("10000", 8));
            });

            it("Should allow admin to burn from burn vault", async function () {
                const initialBalance = await kgen.balanceOf(addr1Address);
                const burnAmount = ethers.parseUnits("1000", 8);
                
                await kgen.burn(addr1Address, burnAmount);
                
                expect(await kgen.balanceOf(addr1Address)).to.equal(initialBalance - burnAmount);
            });

            it("Should not allow non-admin to burn", async function () {
                const burnAmount = ethers.parseUnits("1000", 8);
                await expect(kgen.connect(addr3).burn(addr1Address, burnAmount))
                    .to.be.revertedWithCustomError(kgen, "OnlyAdmin");
            });

            it("Should not allow burning from non-burn vault", async function () {
                const burnAmount = ethers.parseUnits("1000", 8);
                await expect(kgen.burn(addr3Address, burnAmount))
                    .to.be.revertedWithCustomError(kgen, "NotBurnVault");
            });

            it("Should not allow burning zero amount", async function () {
                await expect(kgen.burn(addr1Address, 0))
                    .to.be.revertedWithCustomError(kgen, "InvalidAmount");
            });

            it("Should not allow burning more than balance", async function () {
                const balance = await kgen.balanceOf(addr1Address);
                const burnAmount = balance + ethers.parseUnits("1", 8);
                await expect(kgen.burn(addr1Address, burnAmount))
                    .to.be.revertedWithCustomError(kgen, "ERC20InsufficientBalance");
            });
        });
    });

    describe("Transfer Functions", function () {
        beforeEach(async function () {
            await kgen.addTreasury(addr1Address);
            await kgen.addWhitelistSender(addr2Address);
            await kgen.addWhitelistReceiver(addr3Address);
            await kgen.mint(addr1Address, ethers.parseUnits("10000", 8));
            // Transfer some tokens to addr2 for testing
            await kgen.connect(addr1).transfer(addr2Address, ethers.parseUnits("10000", 8));
            // Also add addr2 as a treasury so it can receive tokens
            await kgen.addTreasury(addr2Address);
        });

        describe("Standard Transfer", function () {
            it("Should allow transfer when sender is whitelisted", async function () {
                const amount = ethers.parseUnits("100", 8);
                await kgen.connect(addr2).transfer(addr3Address, amount);
                expect(await kgen.balanceOf(addr3Address)).to.equal(amount);
            });

            it("Should allow transfer when receiver is whitelisted", async function () {
                const amount = ethers.parseUnits("100", 8);
                await kgen.connect(addr2).transfer(addr3Address, amount);
                expect(await kgen.balanceOf(addr3Address)).to.equal(amount);
            });

            it("Should not allow transfer when neither sender nor receiver is whitelisted", async function () {
                const amount = ethers.parseUnits("100", 8);
                await expect(kgen.connect(addr4).transfer(addr5Address, amount))
                    .to.be.revertedWithCustomError(kgen, "InvalidReceiverOrSender");
            });

            it("Should not allow transfer from frozen sender", async function () {
                await kgen.freezeAccounts([addr2Address], [true], [false]);
                const amount = ethers.parseUnits("100", 8);
                await expect(kgen.connect(addr2).transfer(addr3Address, amount))
                    .to.be.revertedWithCustomError(kgen, "AccountIsFrozen");
            });

            it("Should not allow transfer to frozen receiver", async function () {
                await kgen.freezeAccounts([addr3Address], [false], [true]);
                const amount = ethers.parseUnits("100", 8);
                await expect(kgen.connect(addr2).transfer(addr3Address, amount))
                    .to.be.revertedWithCustomError(kgen, "AccountIsFrozen");
            });

            it("Should allow transfer to self", async function () {
                const amount = ethers.parseUnits("100", 8);
                const initialBalance = await kgen.balanceOf(addr2Address);
                await kgen.connect(addr2).transfer(addr2Address, amount);
                expect(await kgen.balanceOf(addr2Address)).to.equal(initialBalance);
            });

            it("Should emit Transfer event", async function () {
                const amount = ethers.parseUnits("100", 8);
                await expect(kgen.connect(addr2).transfer(addr3Address, amount))
                    .to.emit(kgen, "Transfer")
                    .withArgs(addr2Address, addr3Address, amount);
            });
        });

        describe("TransferFrom", function () {
            beforeEach(async function () {
                await kgen.connect(addr2).approve(ownerAddress, ethers.parseUnits("1000", 8));
            });

            it("Should allow transferFrom when sender is whitelisted", async function () {
                const amount = ethers.parseUnits("100", 8);
                await kgen.transferFrom(addr2Address, addr3Address, amount);
                expect(await kgen.balanceOf(addr3Address)).to.equal(amount);
            });

            it("Should allow transferFrom when receiver is whitelisted", async function () {
                const amount = ethers.parseUnits("100", 8);
                await kgen.transferFrom(addr2Address, addr3Address, amount);
                expect(await kgen.balanceOf(addr3Address)).to.equal(amount);
            });

            it("Should not allow transferFrom when neither sender nor receiver is whitelisted", async function () {
                await kgen.connect(addr4).approve(ownerAddress, ethers.parseUnits("1000", 8));
                const amount = ethers.parseUnits("100", 8);
                await expect(kgen.transferFrom(addr4Address, addr5Address, amount))
                    .to.be.revertedWithCustomError(kgen, "InvalidReceiverOrSender");
            });

            it("Should not allow transferFrom from frozen sender", async function () {
                await kgen.freezeAccounts([addr2Address], [true], [false]);
                const amount = ethers.parseUnits("100", 8);
                await expect(kgen.transferFrom(addr2Address, addr3Address, amount))
                    .to.be.revertedWithCustomError(kgen, "AccountIsFrozen");
            });

            it("Should not allow transferFrom to frozen receiver", async function () {
                await kgen.freezeAccounts([addr3Address], [false], [true]);
                const amount = ethers.parseUnits("100", 8);
                await expect(kgen.transferFrom(addr2Address, addr3Address, amount))
                    .to.be.revertedWithCustomError(kgen, "AccountIsFrozen");
            });

            it("Should emit Transfer event", async function () {
                const amount = ethers.parseUnits("100", 8);
                await expect(kgen.transferFrom(addr2Address, addr3Address, amount))
                    .to.emit(kgen, "Transfer")
                    .withArgs(addr2Address, addr3Address, amount);
            });
        });

        describe("Admin Transfer", function () {
            it("Should allow admin transfer when sender is frozen", async function () {
                await kgen.freezeAccounts([addr2Address], [true], [false]);
                const amount = ethers.parseUnits("100", 8);
                await kgen.adminTransfer(addr2Address, addr3Address, amount);
                expect(await kgen.balanceOf(addr3Address)).to.equal(amount);
            });

            it("Should allow admin transfer when receiver is frozen", async function () {
                await kgen.freezeAccounts([addr3Address], [false], [true]);
                const amount = ethers.parseUnits("100", 8);
                await kgen.adminTransfer(addr2Address, addr3Address, amount);
                expect(await kgen.balanceOf(addr3Address)).to.equal(amount);
            });

            it("Should not allow admin transfer when neither account is frozen", async function () {
                const amount = ethers.parseUnits("100", 8);
                await expect(kgen.adminTransfer(addr2Address, addr3Address, amount))
                    .to.be.revertedWith("NOT_FROZEN");
            });

            it("Should not allow non-admin to perform admin transfer", async function () {
                await kgen.freezeAccounts([addr2Address], [true], [false]);
                const amount = ethers.parseUnits("100", 8);
                await expect(kgen.connect(addr1).adminTransfer(addr2Address, addr3Address, amount))
                    .to.be.revertedWithCustomError(kgen, "OnlyAdmin");
            });

            it("Should emit Transfer event", async function () {
                await kgen.freezeAccounts([addr2Address], [true], [false]);
                const amount = ethers.parseUnits("100", 8);
                await expect(kgen.adminTransfer(addr2Address, addr3Address, amount))
                    .to.emit(kgen, "Transfer")
                    .withArgs(addr2Address, addr3Address, amount);
            });
        });
    });

    describe("View Functions", function () {
        beforeEach(async function () {
            await kgen.addMinter(addr1Address);
            await kgen.addTreasury(addr2Address);
            await kgen.addBurnVault(addr3Address);
            await kgen.addWhitelistSender(addr4Address);
            await kgen.addWhitelistReceiver(addr5Address);
        });

        it("Should return correct freeze status", async function () {
            await kgen.freezeAccounts([addr1Address], [true], [false]);
            const status = await kgen.isFrozen(addr1Address);
            expect(status.sending).to.equal(true);
            expect(status.receiving).to.equal(false);
        });

        it("Should return correct whitelist status", async function () {
            expect(await kgen.isWhitelistedSender(addr4Address)).to.equal(true);
            expect(await kgen.isWhitelistedReceiver(addr5Address)).to.equal(true);
            expect(await kgen.isWhitelistedSender(addr5Address)).to.equal(false);
            expect(await kgen.isWhitelistedReceiver(addr4Address)).to.equal(false);
        });

        it("Should return correct role status", async function () {
            expect(await kgen.isMinter(addr1Address)).to.equal(true);
            expect(await kgen.isTreasury(addr2Address)).to.equal(true);
            expect(await kgen.isBurnVault(addr3Address)).to.equal(true);
            expect(await kgen.isMinter(addr2Address)).to.equal(false);
        });

        it("Should return correct admin addresses", async function () {
            expect(await kgen.getAdmin()).to.equal(ownerAddress);
            expect(await kgen.getPendingAdmin()).to.equal(ethers.ZeroAddress);
        });

        it("Should return correct role members", async function () {
            const minters = await kgen.getMinters();
            const treasuries = await kgen.getTreasuries();
            const burnVaults = await kgen.getBurnVaults();
            
            expect(minters).to.include(ownerAddress);
            expect(minters).to.include(addr1Address);
            expect(treasuries).to.include(ownerAddress);
            expect(treasuries).to.include(addr2Address);
            expect(burnVaults).to.include(ownerAddress);
            expect(burnVaults).to.include(addr3Address);
        });
    });

    describe("Edge Cases & Error Handling", function () {
        it("Should handle multiple role assignments correctly", async function () {
            await kgen.addMinter(addr1Address);
            await kgen.addTreasury(addr1Address);
            await kgen.addBurnVault(addr1Address);
            
            expect(await kgen.isMinter(addr1Address)).to.equal(true);
            expect(await kgen.isTreasury(addr1Address)).to.equal(true);
            expect(await kgen.isBurnVault(addr1Address)).to.equal(true);
        });

        it("Should handle complex freeze scenarios", async function () {
            await kgen.freezeAccounts([addr1Address], [true], [true]);
            await kgen.unfreezeAccounts([addr1Address], [true], [false]);
            
            const status = await kgen.isFrozen(addr1Address);
            expect(status.sending).to.equal(false);
            expect(status.receiving).to.equal(true);
        });

        it("Should handle supply cap edge cases", async function () {
            await kgen.addTreasury(addr1Address);
            const maxMintable = MAX_SUPPLY - ethers.parseUnits("1", 8);
            await kgen.mint(addr1Address, maxMintable);
            
            await expect(kgen.mint(addr1Address, ethers.parseUnits("2", 8)))
                .to.be.revertedWithCustomError(kgen, "ExceedsMaxSupply");
        });

        it("Should handle zero address validations", async function () {
            await expect(kgen.addMinter(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(kgen, "NotValidAddress");
            await expect(kgen.addTreasury(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(kgen, "NotValidAddress");
            await expect(kgen.addBurnVault(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(kgen, "NotValidAddress");
            await expect(kgen.addWhitelistSender(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(kgen, "NotValidAddress");
            await expect(kgen.addWhitelistReceiver(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(kgen, "NotValidAddress");
        });

        it("Should test all modifier combinations", async function () {
            // Test onlyAdmin modifier
            await expect(kgen.connect(addr1).addMinter(addr2Address))
                .to.be.revertedWithCustomError(kgen, "OnlyAdmin");
            
            // Test onlyMinter modifier
            await expect(kgen.connect(addr1).mint(addr1Address, ethers.parseUnits("1000", 8)))
                .to.be.revertedWithCustomError(kgen, "NotMinter");
            
            // Test onlyTreasury modifier
            await expect(kgen.connect(addr1).mint(addr1Address, ethers.parseUnits("1000", 8)))
                .to.be.revertedWithCustomError(kgen, "NotMinter");
            
            // Test onlyBurnVault modifier
            await expect(kgen.connect(addr1).burn(addr1Address, ethers.parseUnits("1000", 8)))
                .to.be.revertedWithCustomError(kgen, "OnlyAdmin");
            
            // Test validAmount modifier
            await expect(kgen.mint(addr1Address, 0))
                .to.be.revertedWithCustomError(kgen, "InvalidAmount");
            
            // Test validAddress modifier
            await expect(kgen.addMinter(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(kgen, "NotValidAddress");
        });
    });
});
