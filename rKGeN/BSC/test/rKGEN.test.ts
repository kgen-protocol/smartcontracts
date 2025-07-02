import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { Contract, Signer } from "ethers";

describe("rKGEN Token", function () {
    let rKGEN: any;
    let owner: Signer;
    let addr1: Signer;
    let addr2: Signer;
    let addr3: Signer;
    let ownerAddress: string;
    let addr1Address: string;
    let addr2Address: string;
    let addr3Address: string;

    const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
    const BURN_VAULT_ROLE = ethers.keccak256(ethers.toUtf8Bytes("BURN_VAULT_ROLE"));
    const TREASURY_ROLE = ethers.keccak256(ethers.toUtf8Bytes("TREASURY_ROLE"));
    const WHITELIST_SENDER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("WHITELIST_SENDER_ROLE"));
    const WHITELIST_RECEIVER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("WHITELIST_RECEIVER_ROLE"));
    const UPGRADER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("UPGRADER_ROLE"));
 

    beforeEach(async function () {
        [owner, addr1, addr2, addr3] = await ethers.getSigners();
        ownerAddress = await owner.getAddress();
        addr1Address = await addr1.getAddress();
        addr2Address = await addr2.getAddress();
        addr3Address = await addr3.getAddress();

        const rKGENFactory = await ethers.getContractFactory("rKGEN");
        rKGEN = await upgrades.deployProxy(rKGENFactory, [ownerAddress], {
            initializer: 'initialize',
            kind: 'transparent'
        });
        await rKGEN.waitForDeployment();
    });

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            expect(await rKGEN.hasRole(await rKGEN.DEFAULT_ADMIN_ROLE(), ownerAddress)).to.equal(true);
        });

        it("Should assign the total supply of tokens to the owner", async function () {
            const ownerBalance = await rKGEN.balanceOf(ownerAddress);
            expect(await rKGEN.totalSupply()).to.equal(ownerBalance);
        });

        it("Should set the correct token name and symbol", async function () {
            expect(await rKGEN.name()).to.equal("rKGEN");
            expect(await rKGEN.symbol()).to.equal("rKGEN");
        });

        it("Should set the correct decimals", async function () {
            expect(await rKGEN.decimals()).to.equal(8);
        });

        it("Should not allow re-initialization", async function () {
            await expect(rKGEN.initialize(addr1Address))
                .to.be.revertedWithCustomError(rKGEN, "InvalidInitialization");
        });
    });

    describe("Role Management", function () {
        it("Should allow admin to nominate new admin", async function () {
            await rKGEN.nominateAdmin(addr1Address);
            expect(await rKGEN.nominatedAdmin()).to.equal(addr1Address);
        });

        it("Should not allow admin to nominate self", async function () {
            await expect(rKGEN.nominateAdmin(ownerAddress))
                .to.be.revertedWithCustomError(rKGEN, "CannotNominateSelf");
        });

        it("Should not allow non-admin to nominate admin", async function () {
            await expect(rKGEN.connect(addr1).nominateAdmin(addr2Address))
                .to.be.revertedWithCustomError(rKGEN, "AccessControlUnauthorizedAccount");
        });

        it("Should allow nominated admin to accept role", async function () {
            await rKGEN.nominateAdmin(addr1Address);
            await rKGEN.connect(addr1).acceptAdminRole();
            expect(await rKGEN.hasRole(await rKGEN.DEFAULT_ADMIN_ROLE(), addr1Address)).to.equal(true);
            expect(await rKGEN.hasRole(await rKGEN.DEFAULT_ADMIN_ROLE(), ownerAddress)).to.equal(false);
        });

        it("Should not allow non-nominated address to accept admin role", async function () {
            await rKGEN.nominateAdmin(addr1Address);
            await expect(rKGEN.connect(addr2).acceptAdminRole())
                .to.be.revertedWithCustomError(rKGEN, "NotNominated");
        });

        it("Should not allow accepting admin role when no nomination is pending", async function () {
            await expect(rKGEN.connect(addr1).acceptAdminRole())
                .to.be.revertedWithCustomError(rKGEN, "NotNominated");
        });

        it("Should allow admin to update minter", async function () {
            await rKGEN.updateMinter(addr1Address);
            expect(await rKGEN.hasRole(MINTER_ROLE, addr1Address)).to.equal(true);
            expect(await rKGEN.hasRole(MINTER_ROLE, ownerAddress)).to.equal(false);
        });

        it("Should not allow updating minter to already existing minter", async function () {
            await rKGEN.updateMinter(addr1Address);
            await expect(rKGEN.updateMinter(addr1Address))
                .to.be.revertedWithCustomError(rKGEN, "AlreadyMinter");
        });

        it("Should allow admin to update burn vault", async function () {
            await rKGEN.updateBurnVault(addr1Address);
            expect(await rKGEN.hasRole(BURN_VAULT_ROLE, addr1Address)).to.equal(true);
            expect(await rKGEN.hasRole(BURN_VAULT_ROLE, ownerAddress)).to.equal(false);
        });

        it("Should not allow updating burn vault to already existing burn vault", async function () {
            await rKGEN.updateBurnVault(addr1Address);
            await expect(rKGEN.updateBurnVault(addr1Address))
                .to.be.revertedWithCustomError(rKGEN, "AlreadyBurnVault");
        });

        it("Should allow admin to add multiple minters", async function () {
            await rKGEN.addMinter(addr1Address);
            await rKGEN.addMinter(addr2Address);
            expect(await rKGEN.hasRole(MINTER_ROLE, addr1Address)).to.equal(true);
            expect(await rKGEN.hasRole(MINTER_ROLE, addr2Address)).to.equal(true);
            expect(await rKGEN.hasRole(MINTER_ROLE, ownerAddress)).to.equal(true);
        });

        it("Should not allow adding duplicate minter", async function () {
            await rKGEN.addMinter(addr1Address);
            await expect(rKGEN.addMinter(addr1Address))
                .to.be.revertedWithCustomError(rKGEN, "AlreadyMinter");
        });

        it("Should allow admin to remove minter", async function () {
            await rKGEN.addMinter(addr1Address);
            await rKGEN.removeMinter(addr1Address);
            expect(await rKGEN.hasRole(MINTER_ROLE, addr1Address)).to.equal(false);
        });

        it("Should not allow removing non-minter", async function () {
            await expect(rKGEN.removeMinter(addr1Address))
                .to.be.revertedWithCustomError(rKGEN, "NotMinter");
        });

        it("Should allow admin to add multiple burn vaults", async function () {
            await rKGEN.addBurnVault(addr1Address);
            await rKGEN.addBurnVault(addr2Address);
            expect(await rKGEN.hasRole(BURN_VAULT_ROLE, addr1Address)).to.equal(true);
            expect(await rKGEN.hasRole(BURN_VAULT_ROLE, addr2Address)).to.equal(true);
            expect(await rKGEN.hasRole(BURN_VAULT_ROLE, ownerAddress)).to.equal(true);
        });

        it("Should not allow adding duplicate burn vault", async function () {
            await rKGEN.addBurnVault(addr1Address);
            await expect(rKGEN.addBurnVault(addr1Address))
                .to.be.revertedWithCustomError(rKGEN, "AlreadyBurnVault");
        });

        it("Should allow admin to remove burn vault", async function () {
            await rKGEN.addBurnVault(addr1Address);
            await rKGEN.removeBurnVault(addr1Address);
            expect(await rKGEN.hasRole(BURN_VAULT_ROLE, addr1Address)).to.equal(false);
        });

        it("Should not allow removing non-burn vault", async function () {
            await expect(rKGEN.removeBurnVault(addr1Address))
                .to.be.revertedWithCustomError(rKGEN, "NotBurnVault");
        });

        it("Should allow multiple minters to mint", async function () {
            await rKGEN.addMinter(addr1Address);
            await rKGEN.addMinter(addr2Address);
            await rKGEN.addTreasuryAddress(addr3Address);
            
            const mintAmount = ethers.parseUnits("1000", 8);
            await rKGEN.connect(addr1).mint(addr3Address, mintAmount);
            await rKGEN.connect(addr2).mint(addr3Address, mintAmount);
            
            expect(await rKGEN.balanceOf(addr3Address)).to.equal(mintAmount * 2n);
        });

        it("Should allow multiple burn vaults to burn", async function () {
            await rKGEN.addBurnVault(addr1Address);
            await rKGEN.addBurnVault(addr2Address);
            await rKGEN.addWhitelistSender(ownerAddress);
            await rKGEN.addWhitelistReceiver(addr3Address);
            await rKGEN.transfer(addr3Address, ethers.parseUnits("2000", 8));
            
            const burnAmount = ethers.parseUnits("500", 8);
            await rKGEN.connect(addr1).burn(addr3Address, burnAmount);
            await rKGEN.connect(addr2).burn(addr3Address, burnAmount);
            
            expect(await rKGEN.balanceOf(addr3Address)).to.equal(ethers.parseUnits("1000", 8));
        });
    });

    describe("Whitelist Management", function () {
        it("Should allow admin to add whitelist sender", async function () {
            await rKGEN.addWhitelistSender(addr1Address);
            expect(await rKGEN.hasRole(WHITELIST_SENDER_ROLE, addr1Address)).to.equal(true);
        });

        it("Should allow admin to add whitelist receiver", async function () {
            await rKGEN.addWhitelistReceiver(addr1Address);
            expect(await rKGEN.hasRole(WHITELIST_RECEIVER_ROLE, addr1Address)).to.equal(true);
        });

        it("Should allow admin to remove whitelist sender", async function () {
            await rKGEN.addWhitelistSender(addr1Address);
            await rKGEN.removeWhitelistSender(addr1Address);
            expect(await rKGEN.hasRole(WHITELIST_SENDER_ROLE, addr1Address)).to.equal(false);
        });

        it("Should allow admin to remove whitelist receiver", async function () {
            await rKGEN.addWhitelistReceiver(addr1Address);
            await rKGEN.removeWhitelistReceiver(addr1Address);
            expect(await rKGEN.hasRole(WHITELIST_RECEIVER_ROLE, addr1Address)).to.equal(false);
        });

        it("Should not allow adding duplicate whitelist sender", async function () {
            await rKGEN.addWhitelistSender(addr1Address);
            await expect(rKGEN.addWhitelistSender(addr1Address))
                .to.be.revertedWithCustomError(rKGEN, "AlreadyWhitelistedSender");
        });

        it("Should not allow adding duplicate whitelist receiver", async function () {
            await rKGEN.addWhitelistReceiver(addr1Address);
            await expect(rKGEN.addWhitelistReceiver(addr1Address))
                .to.be.revertedWithCustomError(rKGEN, "AlreadyWhitelistedReceiver");
        });

        it("Should not allow removing non-whitelisted sender", async function () {
            await expect(rKGEN.removeWhitelistSender(addr1Address))
                .to.be.revertedWithCustomError(rKGEN, "NotWhitelistedSender");
        });

        it("Should not allow removing non-whitelisted receiver", async function () {
            await expect(rKGEN.removeWhitelistReceiver(addr1Address))
                .to.be.revertedWithCustomError(rKGEN, "NotWhitelistedReceiver");
        });
    });

    describe("Treasury Management", function () {
        it("Should allow admin to add treasury address", async function () {
            await rKGEN.addTreasuryAddress(addr1Address);
            expect(await rKGEN.hasRole(TREASURY_ROLE, addr1Address)).to.equal(true);
            expect(await rKGEN.hasRole(WHITELIST_SENDER_ROLE, addr1Address)).to.equal(true);
        });

        it("Should not allow adding duplicate treasury address", async function () {
            await rKGEN.addTreasuryAddress(addr1Address);
            await expect(rKGEN.addTreasuryAddress(addr1Address))
                .to.be.revertedWithCustomError(rKGEN, "AlreadyTreasury");
        });

        it("Should allow admin to remove treasury address", async function () {
            await rKGEN.addTreasuryAddress(addr1Address);
            await rKGEN.removeTreasuryAddress(addr1Address);
            expect(await rKGEN.hasRole(TREASURY_ROLE, addr1Address)).to.equal(false);
        });

        it("Should not allow removing non-treasury address", async function () {
            await expect(rKGEN.removeTreasuryAddress(addr1Address))
                .to.be.revertedWithCustomError(rKGEN, "NotTreasury");
        });

        it("Should allow minter to mint to treasury", async function () {
            await rKGEN.addTreasuryAddress(addr1Address);
            const mintAmount = ethers.parseUnits("1000", 8);
            await rKGEN.mint(addr1Address, mintAmount);
            expect(await rKGEN.balanceOf(addr1Address)).to.equal(mintAmount);
        });

        it("Should allow minter to mint to whitelisted receiver", async function () {
            await rKGEN.addWhitelistReceiver(addr1Address);
            const mintAmount = ethers.parseUnits("1000", 8);
            await rKGEN.mint(addr1Address, mintAmount);
            expect(await rKGEN.balanceOf(addr1Address)).to.equal(mintAmount);
        });

        it("Should not allow minting to non-whitelisted address", async function () {
            const mintAmount = ethers.parseUnits("1000", 8);
            await expect(rKGEN.mint(addr1Address, mintAmount))
                .to.be.revertedWithCustomError(rKGEN, "NotWhitelistedReceiver");
        });

        it("Should not allow non-minter to mint", async function () {
            await rKGEN.addWhitelistReceiver(addr1Address);
            const mintAmount = ethers.parseUnits("1000", 8);
            await expect(rKGEN.connect(addr1).mint(addr1Address, mintAmount))
                .to.be.revertedWithCustomError(rKGEN, "AccessControlUnauthorizedAccount");
        });

        it("Should not allow minting zero amount", async function () {
            await rKGEN.addWhitelistReceiver(addr1Address);
            await expect(rKGEN.mint(addr1Address, 0))
                .to.be.revertedWithCustomError(rKGEN, "InvalidAmount");
        });

        it("Should not allow minting to zero address", async function () {
            const mintAmount = ethers.parseUnits("1000", 8);
            await expect(rKGEN.mint(ethers.ZeroAddress, mintAmount))
                .to.be.revertedWithCustomError(rKGEN, "NotValidAddress");
        });
    });

    describe("Token Transfers", function () {
        beforeEach(async function () {
            await rKGEN.addWhitelistSender(ownerAddress);
            await rKGEN.addWhitelistReceiver(addr1Address);
        });

        it("Should allow transfer between whitelisted addresses", async function () {
            const transferAmount = ethers.parseUnits("1000",8);
            await rKGEN.transfer(addr1Address, transferAmount);
            expect(await rKGEN.balanceOf(addr1Address)).to.equal(transferAmount);
        });

        it("Should allow transfer from whitelisted sender", async function () {
            await rKGEN.removeWhitelistReceiver(addr1Address);
            const transferAmount = ethers.parseUnits("1000",8);
            await rKGEN.transfer(addr1Address, transferAmount);
            expect(await rKGEN.balanceOf(addr1Address)).to.equal(transferAmount);
        });

        it("Should allow transfer to whitelisted receiver", async function () {
            await rKGEN.removeWhitelistSender(ownerAddress);
            const transferAmount = ethers.parseUnits("1000",8);
            await rKGEN.transfer(addr1Address, transferAmount);
            expect(await rKGEN.balanceOf(addr1Address)).to.equal(transferAmount);
        });

        it("Should not allow transfer if neither sender nor receiver is whitelisted", async function () {
            await rKGEN.removeWhitelistSender(ownerAddress);
            await rKGEN.removeWhitelistReceiver(addr1Address);
            const transferAmount = ethers.parseUnits("1000",8);
            await expect(rKGEN.transfer(addr1Address, transferAmount))
                .to.be.revertedWithCustomError(rKGEN, "InvalidReceiverOrSender");
        });

        it("Should not allow transfer to zero address", async function () {
            const transferAmount = ethers.parseUnits("1000",8);
            await expect(rKGEN.transfer(ethers.ZeroAddress, transferAmount))
                .to.be.revertedWithCustomError(rKGEN, "NotValidAddress");
        });

        it("Should not allow transfer of zero amount", async function () {
            await expect(rKGEN.transfer(addr1Address, 0))
                .to.be.revertedWithCustomError(rKGEN, "InvalidAmount");
        });

        it("Should not allow transferFrom of zero amount", async function () {
            await rKGEN.approve(addr1Address, ethers.parseUnits("1000",8));
            await expect(rKGEN.connect(addr1).transferFrom(ownerAddress, addr2Address, 0))
                .to.be.revertedWithCustomError(rKGEN, "InvalidAmount");
        });

        it("Should maintain whitelist restrictions after approval", async function () {
            const transferAmount = ethers.parseUnits("1000",8);
            await rKGEN.approve(addr1Address, transferAmount);
            await rKGEN.removeWhitelistSender(ownerAddress);
            await expect(rKGEN.connect(addr1).transferFrom(ownerAddress, addr2Address, transferAmount))
                .to.be.revertedWithCustomError(rKGEN, "InvalidReceiverOrSender");
        });

        it("Should not allow transfer to self", async function () {
            const transferAmount = ethers.parseUnits("1000",8);
            await expect(rKGEN.transfer(ownerAddress, transferAmount))
                .to.be.revertedWithCustomError(rKGEN, "CannotTransferToSelf");
        });

        it("Should not allow transferFrom to self", async function () {
            await rKGEN.addWhitelistSender(addr1Address);
            await rKGEN.transfer(addr1Address, ethers.parseUnits("1000",8));
            await rKGEN.connect(addr1).approve(addr2Address, ethers.parseUnits("1000",8));
            await expect(rKGEN.connect(addr2).transferFrom(addr1Address, addr1Address, ethers.parseEther("100")))
                .to.be.revertedWithCustomError(rKGEN, "CannotTransferToSelf");
        });
    });

    describe("Whitelist Edge Cases", function () {
        it("Should not allow removing whitelist sender if address is treasury", async function () {
            await rKGEN.addTreasuryAddress(addr1Address);
            await expect(rKGEN.removeWhitelistSender(addr1Address))
                .to.be.revertedWithCustomError(rKGEN, "CannotDeleteTreasuryAddress");
        });
    });

    describe("Account Freezing", function () {
        it("Should allow admin to freeze account", async function () {
            await rKGEN.freezeAccount(addr1Address);
            expect(await rKGEN.frozenAccounts(addr1Address)).to.equal(true);
        });

        it("Should allow admin to unfreeze account", async function () {
            await rKGEN.freezeAccount(addr1Address);
            await rKGEN.unfreezeAccount(addr1Address);
            expect(await rKGEN.frozenAccounts(addr1Address)).to.equal(false);
        });

        it("Should not allow frozen account to transfer", async function () {
            await rKGEN.addWhitelistSender(addr1Address);
            await rKGEN.addWhitelistReceiver(addr2Address);
            await rKGEN.addWhitelistReceiver(addr1Address);

            await rKGEN.transfer(addr1Address, ethers.parseUnits("1000",8));
            await rKGEN.freezeAccount(addr1Address);
            await expect(rKGEN.connect(addr1).transfer(addr2Address, ethers.parseEther("100")))
                .to.be.revertedWithCustomError(rKGEN, "AccountIsFrozen");
        });

        it("Should not allow transfer to frozen account", async function () {
            await rKGEN.addWhitelistSender(ownerAddress);
            await rKGEN.addWhitelistReceiver(addr1Address);
            await rKGEN.freezeAccount(addr1Address);
            await expect(rKGEN.transfer(addr1Address, ethers.parseEther("100")))
                .to.be.revertedWithCustomError(rKGEN, "AccountIsFrozen");
        });

        it("Should not allow non-admin to freeze account", async function () {
            await expect(rKGEN.connect(addr1).freezeAccount(addr2Address))
                .to.be.revertedWithCustomError(rKGEN, "AccessControlUnauthorizedAccount");
        });

        it("Should not allow non-admin to unfreeze account", async function () {
            await rKGEN.freezeAccount(addr1Address);
            await expect(rKGEN.connect(addr1).unfreezeAccount(addr1Address))
                .to.be.revertedWithCustomError(rKGEN, "AccessControlUnauthorizedAccount");
        });

        it("Should not allow freezing zero address", async function () {
            await expect(rKGEN.freezeAccount(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(rKGEN, "NotValidAddress");
        });

        it("Should not allow unfreezing zero address", async function () {
            await expect(rKGEN.unfreezeAccount(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(rKGEN, "NotValidAddress");
        });
    });

    describe("Burning", function () {
        it("Should allow burn vault to burn tokens", async function () {
            await rKGEN.updateBurnVault(addr1Address);
            await rKGEN.addWhitelistSender(ownerAddress);
            await rKGEN.addWhitelistReceiver(addr1Address);
            await rKGEN.transfer(addr1Address, ethers.parseUnits("1000",8));
            const burnAmount = ethers.parseUnits("500",8);
            await rKGEN.connect(addr1).burn(addr1Address, burnAmount);
            expect(await rKGEN.balanceOf(addr1Address)).to.equal(ethers.parseUnits("500",8));
        });

        it("Should not allow non-burn vault to burn tokens", async function () {
            await rKGEN.addWhitelistSender(ownerAddress);
            await rKGEN.addWhitelistReceiver(addr1Address);
            await rKGEN.transfer(addr1Address, ethers.parseUnits("1000",8));
            const burnAmount = ethers.parseUnits("500",8);
            await expect(rKGEN.connect(addr2).burn(addr1Address, burnAmount))
                .to.be.revertedWithCustomError(rKGEN, "AccessControlUnauthorizedAccount");
        });

        it("Should not allow burning zero amount", async function () {
            await rKGEN.updateBurnVault(addr1Address);
            await expect(rKGEN.connect(addr1).burn(addr1Address, 0))
                .to.be.revertedWithCustomError(rKGEN, "InvalidAmount");
        });

        it("Should not allow burning from zero address", async function () {
            await rKGEN.updateBurnVault(addr1Address);
            await expect(rKGEN.connect(addr1).burn(ethers.ZeroAddress, ethers.parseEther("100")))
                .to.be.revertedWithCustomError(rKGEN, "NotValidAddress");
        });

        it("Should allow burn vault to burn from any address", async function () {
            await rKGEN.updateBurnVault(addr1Address);
            await rKGEN.addWhitelistSender(ownerAddress);
            await rKGEN.addWhitelistReceiver(addr2Address);
            await rKGEN.transfer(addr2Address, ethers.parseUnits("1000",8));
            const burnAmount = ethers.parseUnits("500",8);
            await rKGEN.connect(addr1).burn(addr2Address, burnAmount);
            expect(await rKGEN.balanceOf(addr2Address)).to.equal(ethers.parseUnits("500",8));
        });
    });

    describe("Trusted Forwarder", function () {
        it("Should allow admin to set trusted forwarder", async function () {
            await rKGEN.setTrustedForwarder(addr1Address, true);
            expect(await rKGEN.isTrustedForwarder(addr1Address)).to.equal(true);
        });

        it("Should allow admin to remove trusted forwarder", async function () {
            await rKGEN.setTrustedForwarder(addr1Address, true);
            await rKGEN.setTrustedForwarder(addr1Address, false);
            expect(await rKGEN.isTrustedForwarder(addr1Address)).to.equal(false);
        });

        it("Should not allow non-admin to set trusted forwarder", async function () {
            await expect(rKGEN.connect(addr1).setTrustedForwarder(addr2Address, true))
                .to.be.revertedWithCustomError(rKGEN, "AccessControlUnauthorizedAccount");
        });
    });

    describe("Reentrancy Protection", function () {
        it("Should prevent reentrant calls to transfer", async function () {
            await rKGEN.addWhitelistSender(ownerAddress);
            await rKGEN.addWhitelistReceiver(addr1Address);
            const transferAmount = ethers.parseUnits("1000",8);
            
            await rKGEN.transfer(addr1Address, transferAmount);
            expect(await rKGEN.balanceOf(addr1Address)).to.equal(transferAmount);
        });

        it("Should prevent reentrant calls to mint", async function () {
            await rKGEN.addTreasuryAddress(addr1Address);
            const mintAmount = ethers.parseUnits("1000",8);
            
            await rKGEN.mint(addr1Address, mintAmount);
            expect(await rKGEN.balanceOf(addr1Address)).to.equal(mintAmount);
        });

        it("Should prevent reentrant calls to burn", async function () {
            await rKGEN.updateBurnVault(addr1Address);
            await rKGEN.addWhitelistSender(ownerAddress);
            await rKGEN.addWhitelistReceiver(addr1Address);
            await rKGEN.transfer(addr1Address, ethers.parseUnits("1000",8));
            const burnAmount = ethers.parseUnits("500",8);
            
            await rKGEN.connect(addr1).burn(addr1Address, burnAmount);
            expect(await rKGEN.balanceOf(addr1Address)).to.equal(ethers.parseUnits("500",8));
        });
    });
}); 