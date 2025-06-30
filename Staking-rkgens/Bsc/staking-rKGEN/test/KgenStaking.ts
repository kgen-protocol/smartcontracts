import { expect } from "chai";
import { ethers } from "hardhat";
import { AbiCoder, Contract, Signer } from "ethers";
import { deployContracts } from "./helper";
import { keccak256, parseEther } from "ethers";
import { arrayify } from "@ethersproject/bytes";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import hre from "hardhat";

enum ActionType {
  Stake = 0,
  Harvest = 1,
  Claim = 2,
  Unstake = 3,
  Renew = 4
}

describe("KGEN TESTING STAKING", () => {
  let signer: Signer;
  let deployer: Signer;
  let adminAddress: string;
  let userAddress: string;
  let staking: any;
  let token: any;
  const stakingDuration = 1; // 1-day lock for tests

  before(async () => {
    [signer, deployer] = await ethers.getSigners();
    adminAddress = await deployer.getAddress();
    userAddress = await signer.getAddress();

    /* -------------------------------------------------------------------------- */
    /*                                Deploy mocks                                */
    /* -------------------------------------------------------------------------- */

    const Token = await ethers.getContractFactory("MockERC20", deployer);
    token = await Token.deploy("MockToken", "MTK", 18);

    await token.connect(signer).mint(parseEther("1000000"));

    /* -------------------------------------------------------------------------- */
    /*                               Deploy Staking                               */
    /* -------------------------------------------------------------------------- */

    const implementation = await deployContracts("KgenStaking", deployer);
    const Proxy = await ethers.getContractFactory("KgenStakingProxy", deployer);
    const proxy = await Proxy.deploy(implementation.target, adminAddress, "0x");

    staking = await ethers.getContractAt("KgenStaking", proxy.target, deployer);

    await staking.initialize();

    hre.tracer.nameTags[await implementation.getAddress()] = "KgenStakingLogic";
    hre.tracer.nameTags[await proxy.getAddress()] = "KgenProxyContract";
    hre.tracer.nameTags[await token.getAddress()] = "RKGEN";

    /* -------------------------------------------------------------------------- */
    /*                              Whitelist + APY                               */
    /* -------------------------------------------------------------------------- */

    await staking.connect(deployer).addWhitelistedToken(token.target);

    await staking.connect(deployer).addAPYRange(
      token.target,
      stakingDuration,
      parseEther("1"),
      parseEther("10000"),
      800 // 8% APY
    );

    /* -------------------------------------------------------------------------- */
    /*                              User approvals                                */
    /* -------------------------------------------------------------------------- */

    await token.connect(signer).approve(staking.target, parseEther("1000"));
    await token.connect(signer).transfer(staking.target, parseEther("100"));
  });

  /* -------------------------------------------------------------------------- */
  /*                                  Helpers                                   */
  /* -------------------------------------------------------------------------- */

  function signAction(
    action: ActionType,
    amountOrStakeId: bigint,
    nonce: bigint,
    tokenAddr: string
  ) {
    const encoded = AbiCoder.defaultAbiCoder().encode(
      ["address", "address", "uint256", "uint256", "address", "uint8"],
      [userAddress, tokenAddr, amountOrStakeId, nonce, staking.target, action]
    );
    const message = keccak256(encoded);
    return deployer.signMessage(arrayify(message));
  }

  /* -------------------------------------------------------------------------- */
  /*                                   Tests                                    */
  /* -------------------------------------------------------------------------- */

  it("should allow user to stake with valid admin signature", async () => {
    const amount = parseEther("100");
    const nonce = await staking.nonce(userAddress);
    const signature = await signAction(ActionType.Stake, amount, nonce, token.target);

    const beforeNonce = await staking.nonce(userAddress);

    await expect(
      staking.connect(signer).addStake(token.target, amount, stakingDuration, signature)
    ).to.emit(staking, "Staked");

    const afterNonce = await staking.nonce(userAddress);
    expect(afterNonce).to.equal(beforeNonce + 1n);
  });

  it("should revert if user tries to stake with a non-whitelisted duration", async () => {
    const amount = parseEther("100");
    const invalidDuration = 9999;
    const nonce = await staking.nonce(userAddress);
    const signature = await signAction(ActionType.Stake, amount, nonce, token.target);

    await expect(
      staking.connect(signer).addStake(token.target, amount, invalidDuration, signature)
    ).to.be.revertedWithCustomError(staking, "InvalidDuration");
  });

  it("should allow user to stake again (second stake)", async () => {
    const amount = parseEther("100");
    const nonce = await staking.nonce(userAddress);
    const signature = await signAction(ActionType.Stake, amount, nonce, token.target);

    await expect(
      staking.connect(signer).addStake(token.target, amount, stakingDuration, signature)
    ).to.emit(staking, "Staked");
  });

  it("should revert if user tries to stake with a non-whitelisted token", async () => {
    const amount = parseEther("100");

    const Token = await ethers.getContractFactory("MockERC20", deployer);
    const otherToken = await Token.deploy("FakeToken", "FAKE", 18);
    await otherToken.connect(signer).mint(parseEther("1000"));
    await otherToken.connect(signer).approve(staking.target, parseEther("1000"));

    const nonce = await staking.nonce(userAddress);
    const signature = await signAction(ActionType.Stake, amount, nonce, await otherToken.getAddress());

    await expect(
      staking.connect(signer).addStake(otherToken.target, amount, stakingDuration, signature)
    ).to.be.revertedWithCustomError(staking, "TokenNotWhitelisted");
  });

  it("should revert if user tries to stake 0 tokens", async () => {
    const amount = parseEther("0");
    const nonce = await staking.nonce(userAddress);
    const signature = await signAction(ActionType.Stake, amount, nonce, token.target);

    await expect(
      staking.connect(signer).addStake(token.target, amount, stakingDuration, signature)
    ).to.be.revertedWithCustomError(staking, "AmountZero");
  });

  it("should revert if signature is not from an admin", async () => {
    const amount = parseEther("100");
    const nonce = await staking.nonce(userAddress);

    const encoded = AbiCoder.defaultAbiCoder().encode(
      ["address", "address", "uint256", "uint256", "address", "uint8"],
      [userAddress, token.target, amount, nonce, staking.target, ActionType.Stake]
    );
    const message = keccak256(encoded);
    const badSignature = await signer.signMessage(arrayify(message));

    await expect(
      staking.connect(signer).addStake(token.target, amount, stakingDuration, badSignature)
    ).to.be.revertedWithCustomError(staking, "InvalidAdminSignature");
  });

  it("should revert if stake amount is outside all APY ranges", async () => {
    const amount = parseEther("0.5"); // below min
    const nonce = await staking.nonce(userAddress);
    const signature = await signAction(ActionType.Stake, amount, nonce, token.target);

    await expect(
      staking.connect(signer).addStake(token.target, amount, stakingDuration, signature)
    ).to.be.revertedWithCustomError(staking, "NoAPY");
  });

  it("should allow valid harvest after one day", async () => {
    const stakeId = 2; // second stake created above
    await time.increase(86400);
    const nonce = await staking.nonce(userAddress);
    const signature = await signAction(ActionType.Harvest, BigInt(stakeId), nonce, token.target);

    await expect(
      staking.connect(signer).harvestStake(token.target, stakeId, signature)
    ).to.emit(staking, "Harvested");
  });

  it("should revert if harvest called too soon", async () => {
    const stakeId = 2;
    const nonce = await staking.nonce(userAddress);
    const signature = await signAction(ActionType.Harvest, BigInt(stakeId), nonce, token.target);

    await expect(
      staking.connect(signer).harvestStake(token.target, stakeId, signature)
    ).to.be.revertedWithCustomError(staking, "HarvestTooSoon");
  });

  it("should allow user to claim after stake is matured", async () => {
    const stakeId = 2;
    await time.increase(2 * 86400);

    const nonce = await staking.nonce(userAddress);
    const signature = await signAction(ActionType.Claim, BigInt(stakeId), nonce, token.target);

    await expect(
      staking.connect(signer).claimStake(token.target, stakeId, signature)
    ).to.emit(staking, "Claimed");
  });

  it("should revert if signature is not from admin during claim", async () => {
    const stakeId = 2;
    await time.increase(86400);

    const nonce = await staking.nonce(userAddress);
    const encoded = AbiCoder.defaultAbiCoder().encode(
      ["address", "address", "uint256", "uint256", "address", "uint8"],
      [userAddress, token.target, stakeId, nonce, staking.target, ActionType.Claim]
    );
    const message = keccak256(encoded);
    const badSignature = await signer.signMessage(arrayify(message));

    await expect(
      staking.connect(signer).claimStake(token.target, stakeId, badSignature)
    ).to.be.revertedWithCustomError(staking, "InvalidAdminSignature");
  });

  it("should revert if token is not whitelisted during claim", async () => {
    const stakeId = 2;
    await time.increase(86400);
    await staking.connect(deployer).removeWhitelistedToken(token.target);

    const nonce = await staking.nonce(userAddress);
    const signature = await signAction(ActionType.Claim, BigInt(stakeId), nonce, token.target);

    await expect(
      staking.connect(signer).claimStake(token.target, stakeId, signature)
    ).to.be.revertedWithCustomError(staking, "TokenNotWhitelisted");

    // Re-whitelist for subsequent tests
    await staking.connect(deployer).addWhitelistedToken(token.target);
  });

  it("should allow user to unstake before maturity and receive correct refund", async () => {
    const amount = parseEther("100");
    const nonceStake = await staking.nonce(userAddress);
    const sigStake = await signAction(ActionType.Stake, amount, nonceStake, token.target);

    await staking.connect(signer).addStake(token.target, amount, stakingDuration, sigStake);
    const stakeId = 3;

    await time.increase(60); // 1 minute

    const nonceUnstake = await staking.nonce(userAddress);
    const sigUnstake = await signAction(ActionType.Unstake, BigInt(stakeId), nonceUnstake, token.target);

    await expect(
      staking.connect(signer).unstake(token.target, stakeId, sigUnstake)
    ).to.emit(staking, "Unstaked");
  });

  it("should auto-renew a matured stake and reinvest rewards", async () => {
    const amount = parseEther("100");
    const nonceStake = await staking.nonce(userAddress);
    const sigStake = await signAction(ActionType.Stake, amount, nonceStake, token.target);

    await staking.connect(signer).addStake(token.target, amount, stakingDuration, sigStake);
    const stakeId = 4;

    // First attempt (premature) – expect NotMatured
    await expect(
      staking.connect(deployer).autoRenewStake(userAddress, token.target, stakeId)
    ).to.be.revertedWithCustomError(staking, "NotMatured");

    await time.increase(stakingDuration * 86400 + 10);

    // Now it should succeed
    await staking.connect(deployer).autoRenewStake(userAddress, token.target, stakeId);
  });

  it("should revert autoRenewStake if stakeId does not exist", async () => {
    const invalidStakeId = 9999;
    await expect(
      staking.connect(deployer).autoRenewStake(userAddress, token.target, invalidStakeId)
    ).to.be.revertedWithCustomError(staking, "StakeNotFound");
  });

  it("should revert if non-admin tries to call autoRenewStake", async () => {
    const stakeId = 1;
    await expect(
      staking.connect(signer).autoRenewStake(userAddress, token.target, stakeId)
    ).to.be.reverted; // AccessControl revert
  });
});
