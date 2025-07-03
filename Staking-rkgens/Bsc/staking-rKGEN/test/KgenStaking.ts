import { expect } from "chai";
import { ethers } from "hardhat";
import { AbiCoder, Signer } from "ethers";
import { deployContracts } from "./helper"; // keep your local helper util
import { keccak256, parseEther } from "ethers";
import { arrayify } from "@ethersproject/bytes";
import { time } from "@nomicfoundation/hardhat-network-helpers";

// -----------------------------------------------------------------------------
//  Helpers & enums
// -----------------------------------------------------------------------------

enum ActionType {
  Stake = 0,
  Harvest = 1,
  Claim = 2,
  Unstake = 3,
  Renew = 4
}

/**
 * Build the exact hash the contract expects:
 * keccak256(user, token, value, nonce, address(this), chainId, action)
 */
async function buildSignature(
  admin: Signer,
  user: string,
  token: string,
  value: bigint,        // amount or stakeId
  nonce: bigint,
  staking: string,
  chainId: bigint,
  action: ActionType
): Promise<string> {
  const encoded = AbiCoder.defaultAbiCoder().encode(
    ["address", "address", "uint256", "uint256", "address", "uint256", "uint8"],
    [user, token, value, nonce, staking, chainId, action]
  );
  const hash = keccak256(encoded);
  return (await admin.signMessage(arrayify(hash)));
}
/** replicate the contract's _earned formula */
function calcEarned(amount: bigint, apy: bigint, delta: bigint): bigint {
  return (amount * apy * delta) / 31_536_000n / 100n / 10_000n; // 365d * 100 * 10_000
}
/**
 * Deploy an ERC-20 that always returns false on transfer/transferFrom so that
 * we can test the TransferFailed error path without juggling balances.
 */
async function deployFailingToken(deployer: Signer) {
  const Failing: any = await ethers.getContractFactory("FailingERC20", deployer);
  return await Failing.deploy();
}

// -----------------------------------------------------------------------------
//  Main test-suite – all happy-paths first (original tests)
// -----------------------------------------------------------------------------

describe("KgenStaking (token + chainId)", () => {
  let deployer: Signer;
  let user: Signer;
  let userAddr: string;
  let staking: any;
  let token: any;
  let chainId: bigint;
  const DURATION = 1; // 1-day lock in tests

  before(async () => {
    [deployer, user] = await ethers.getSigners();
    userAddr = await user.getAddress();
    chainId = BigInt((await ethers.provider.getNetwork()).chainId);

    // ── Deploy mock ERC-20 ──
    const Token = await ethers.getContractFactory("MockERC20", deployer);
    token = await Token.deploy("MockToken", "MTK", 18);
    await token.connect(user).mint(parseEther("1000000"));

    // ── Deploy staking (UUPS helper) ──
    const impl = await deployContracts("KgenStaking", deployer);
    const Proxy = await ethers.getContractFactory("KgenStakingProxy", deployer);
    const proxy = await Proxy.deploy(impl.target, await deployer.getAddress(), "0x");
    staking = await ethers.getContractAt("KgenStaking", proxy.target, deployer);

    await staking.initialize();

    // ── Configure ──
    await staking.addWhitelistedToken(true, token.target);
    await staking.addAPYRange(DURATION, parseEther("1"), parseEther("10000"), 800);

    await token.connect(user).approve(staking.target, parseEther("100000"));
    await token.connect(user).transfer(staking.target, parseEther("100"));
  });

  /* Helper to sign an action for current nonce */
  async function sign(action: ActionType, value: bigint): Promise<string> {
    const nonce = (await staking.nonce(userAddr)) as bigint;
    return buildSignature(deployer, userAddr, token.target, value, nonce, staking.target, chainId, action);
  }

  // ---------------------------------------------------------------------------
  //  ✅ Happy paths already provided
  // ---------------------------------------------------------------------------

  it("stakes successfully with admin signature", async () => {
    const amount = parseEther("100");
    const sig = await sign(ActionType.Stake, amount);
    await expect(staking.connect(user).addStake(amount, DURATION, token.target, sig)).to.emit(staking, "Staked");
  });

  it("reverts on amount zero", async () => {
    const sig = await sign(ActionType.Stake, 0n);
    await expect(staking.connect(user).addStake(0, DURATION, token.target, sig)).to.be.revertedWithCustomError(staking, "AmountZero");
  });

  it("reverts on non-whitelisted token", async () => {
    const Fake: any = await (await ethers.getContractFactory("MockERC20", deployer)).deploy("F", "F", 18);
    await Fake.connect(user).mint(parseEther("10"));
    await Fake.connect(user).approve(staking.target, parseEther("10"));

    const amount = parseEther("10");
    const nonce = (await staking.nonce(userAddr)) as bigint;
    const fakeSig = await buildSignature(deployer, userAddr, Fake.target, amount, nonce, staking.target, chainId, ActionType.Stake);

    await expect(staking.connect(user).addStake(amount, DURATION, Fake.target, fakeSig)).to.be.revertedWithCustomError(staking, "TokenNotWhitelisted");
  });

  it("harvests after 1 day", async () => {
    const stakeId = 1n; // first stake
    await time.increase(86400);
    const sig = await sign(ActionType.Harvest, stakeId);
    await expect(staking.connect(user).harvestStake(token.target, stakeId, sig)).to.emit(staking, "Harvested");
  });

  it("reverts harvest too soon", async () => {
    const stakeId = 1n;
    const sig = await sign(ActionType.Harvest, stakeId);
    await expect(staking.connect(user).harvestStake(token.target, stakeId, sig)).to.be.revertedWithCustomError(staking, "HarvestTooSoon");
  });

  it("claims after maturity", async () => {
    const stakeId = 1n;
    await time.increase(86400);
    const sig = await sign(ActionType.Claim, stakeId);
    await expect(staking.connect(user).claimStake(token.target, stakeId, sig)).to.emit(staking, "Claimed");
  });

  it("unstakes early", async () => {
    const amt = parseEther("50");
    const sigS = await sign(ActionType.Stake, amt);
    await staking.connect(user).addStake(amt, DURATION, token.target, sigS);
    const stakeId = 2n;
    await time.increase(60);
    const sigU = await sign(ActionType.Unstake, stakeId);
    await expect(staking.connect(user).unstake(token.target, stakeId, sigU)).to.emit(staking, "Unstaked");
  });

  it("admin auto-renews after maturity", async () => {
    const amt = parseEther("75");
    const sigS = await sign(ActionType.Stake, amt);
    await staking.connect(user).addStake(amt, DURATION, token.target, sigS);
    const stakeId = 3n;

    await time.increase(2 * 86400);
    await expect(staking.autoRenewStake(userAddr, stakeId)).to.emit(staking, "Staked");
  });

  // ---------------------------------------------------------------------------
  //  ⛔️ Edge-case reverts for full coverage
  // ---------------------------------------------------------------------------

  describe("edge-case reverts", () => {
    it("cannot stake with an unconfigured duration", async () => {
      const sig = await sign(ActionType.Stake, parseEther("10"));
      await expect(
        staking.connect(user).addStake(parseEther("10"), 30, token.target, sig)   // 30-day duration never added
      ).to.be.revertedWithCustomError(staking, "InvalidDuration");
    });

    it("reverts when no APY range matches the amount", async () => {
      const amt = parseEther("20000");               // above max 10 000
      const sig = await sign(ActionType.Stake, amt);
      await expect(
        staking.connect(user).addStake(amt, DURATION, token.target, sig)
      ).to.be.revertedWithCustomError(staking, "NoAPY");
    });


    it("claim fails before maturity", async () => {
      const amt = parseEther("20");
      const sigS = await sign(ActionType.Stake, amt);
      await staking.connect(user).addStake(amt, DURATION, token.target, sigS);
      const stakeId = 4n;
      const sigC = await sign(ActionType.Claim, stakeId);
      await expect(
        staking.connect(user).claimStake(token.target, stakeId, sigC)
      ).to.be.revertedWithCustomError(staking, "NotMatured");
    });
    it("harvest fails if called with the wrong token", async () => {
      await time.increase(86400);                      // allow harvest
      const sig = await sign(ActionType.Harvest, 1n);
      await expect(
        staking.connect(user).harvestStake(ethers.ZeroAddress, 1, sig)
      ).to.be.revertedWithCustomError(staking, "TokenNotWhitelisted");
    });
    it("auto-renew fails if stake not yet mature", async () => {
      const amt = parseEther("40");
      const sigS = await sign(ActionType.Stake, amt);
      await staking.connect(user).addStake(amt, DURATION, token.target, sigS);
      const stakeId = 6n;
      await expect(
        staking.autoRenewStake(userAddr, stakeId)
      ).to.be.revertedWithCustomError(staking, "NotMatured");
    });
    it("unstake fails after maturity", async () => {
      const amt = parseEther("30");
      const sigS = await sign(ActionType.Stake, amt);
      await staking.connect(user).addStake(amt, DURATION, token.target, sigS);
      const stakeId = 5n;
      await time.increase(2 * 86400);                 // past maturity
      const sigU = await sign(ActionType.Unstake, stakeId);
      await expect(
        staking.connect(user).unstake(token.target, stakeId, sigU)
      ).to.be.revertedWithCustomError(staking, "CanNotUnstakeAfterMaturity");
    });
    it("auto‑renew fails if not mature", async () => {
      const amt = parseEther("40");
      const sigS = await sign(ActionType.Stake, amt);
      await staking.connect(user).addStake(amt, DURATION, token.target, sigS);
      const stakeId = 8n;
      await expect(staking.autoRenewStake(userAddr, stakeId))
        .to.be.revertedWithCustomError(staking, "NotMatured");
    });

    it("updateAPYRangeByBounds reverts when bounds not found", async () => {
      await expect(
        staking.updateAPYRangeByBounds(
          DURATION,
          parseEther("2"),
          parseEther("3"),
          0,
          0,
          500
        )
      ).to.be.revertedWithCustomError(staking, "APYRangeNotFound");
    });

    it("non-admin cannot add APY ranges", async () => {
      await expect(
        staking.connect(user).addAPYRange(7, 1, 2, 300)
      ).to.be.revertedWithCustomError(staking, "AccessControlUnauthorizedAccount");
    });

    it("TransferFailed is surfaced when token returns false", async () => {
      const bad: any = await deployFailingToken(deployer);
      await staking.addWhitelistedToken(true, bad.target);

      // sign for a normal stake but with the bad token
      const sig = await buildSignature(
        deployer,
        userAddr,
        bad.target,
        parseEther("1"),
        await staking.nonce(userAddr),
        staking.target,
        chainId,
        ActionType.Stake
      );

      await expect(
        staking.connect(user).addStake(parseEther("1"), DURATION, bad.target, sig)
      ).to.be.revertedWithCustomError(staking, "TransferFailed");
    });
  });
  it("non‑admin cannot add APY ranges", async () => {
    await expect(staking.connect(user).addAPYRange(7, 1, 2, 300))
      .to.be.revertedWithCustomError(staking, "AccessControlUnauthorizedAccount");
  });
  it("updateAPYRangeByBounds reverts when bounds not found", async () => {
    await expect(staking.updateAPYRangeByBounds(DURATION, parseEther("2"), parseEther("3"), 0, 0, 500))
      .to.be.revertedWithCustomError(staking, "APYRangeNotFound");
  });
    it("cannot stake with an unconfigured duration", async () => {
      const sig = await sign(ActionType.Stake, parseEther("10"));
      await expect(staking.connect(user).addStake(parseEther("10"), 30, token.target, sig))
        .to.be.revertedWithCustomError(staking, "InvalidDuration");
    });
describe("KgenStaking – accounting flows", () => {
  const DAY = 86_400; // seconds
  const APY = 800n;   // 8 ‰ as per contract scaling (0.08 % per year)

  /* sign helper for *current* nonce */
  async function sign(action: ActionType, value: bigint) {
    const n = (await staking.nonce(userAddr)) as bigint;
    return buildSignature(deployer, userAddr, token.target, value, n, staking.target, chainId, action);
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  1. Harvest → reward & APY correctness
  // ───────────────────────────────────────────────────────────────────────────

  // it("Harvest emits correct APY and reward", async () => {
  //   const amount = parseEther("100");
  //   const sigS   = await sign(ActionType.Stake, amount);
  //   await staking.connect(user).addStake(amount, DURATION, token.target, sigS); // 2‑day lock
  //   const stakeId = await staking.userStakeCount(userAddr);

  //   // fetch startTime from storage to compute expected reward
  //   const details = await staking.userStakes(userAddr, stakeId);
  //   const start   = BigInt(details.startTime);

  //   await time.increase(DAY);
  //   const delta   = BigInt(DAY);

  //   const expectedReward = calcEarned(amount, APY, delta);

  //   const sigH = await sign(ActionType.Harvest, stakeId);
  //   const tx   = await staking.connect(user).harvestStake(token.target, stakeId, sigH);
  //   const rc   = await tx.wait();

  //   // pull Harvested event
  //   const iface = staking.interface;
  //   const log   = rc.logs.find(l => l.topics[0] === iface.getEventTopic("Harvested"));
  //   const evt   = iface.parseLog(log!);

  //   expect(evt.args.apy).to.equal(APY);
  //   expect(evt.args.reward).to.equal(expectedReward);
  // });

  // ───────────────────────────────────────────────────────────────────────────
  // 2. Unstake refund == principal – harvestedReward
  // ───────────────────────────────────────────────────────────────────────────

  // it("Unstake refunds principal minus harvested reward", async () => {
  //   const amount = parseEther("50");
  //   const sigS   = await sign(ActionType.Stake, amount);
  //   await staking.connect(user).addStake(amount, DURATION, token.target, sigS);
  //   const stakeId = await staking.userStakeCount(userAddr);

  //   await time.increase(DAY); // halfway → harvest
  //   const delta   = BigInt(DAY);
  //   const reward1 = calcEarned(amount, APY, delta);
  //   const sigH    = await sign(ActionType.Harvest, stakeId);
  //   await staking.connect(user).harvestStake(token.target, stakeId, sigH);

  //   // now early‑unstake before maturity
  //   const sigU = await sign(ActionType.Unstake, stakeId);
  //   const tx   = await staking.connect(user).unstake(token.target, stakeId, sigU);
  //   const rc   = await tx.wait();
  //   const evt  = staking.interface.parseLog(rc.logs.find(l => l.topics[0] === staking.interface.getEventTopic("Unstaked"))!);

  //   const expectedRefund = amount - reward1;
  //   expect(evt.args.amount).to.equal(expectedRefund);
  // });

  // ───────────────────────────────────────────────────────────────────────────
  // 3. Claim pays remaining reward only (principal already in param 1)
  // ───────────────────────────────────────────────────────────────────────────

  // it("Claim after harvest pays remaining reward only", async () => {
  //   const amount = parseEther("75");
  //   const sigS   = await sign(ActionType.Stake, amount);
  //   await staking.connect(user).addStake(amount, DURATION, token.target, sigS);
  //   const stakeId = await staking.userStakeCount(userAddr);

  //   await time.increase(DAY);
  //   const reward1 = calcEarned(amount, APY, BigInt(DAY));
  //   const sigH    = await sign(ActionType.Harvest, stakeId);
  //   await staking.connect(user).harvestStake(token.target, stakeId, sigH);

  //   // advance to full maturity (second day)
  //   await time.increase(DAY);
  //   const totalEarned = calcEarned(amount, APY, 2n * BigInt(DAY));
  //   const reward2     = totalEarned - reward1;

  //   const sigC  = await sign(ActionType.Claim, stakeId);
  //   const tx    = await staking.connect(user).claimStake(token.target, stakeId, sigC);
  //   const rc    = await tx.wait();
  //   const evt   = staking.interface.parseLog(rc.logs.find(l => l.topics[0] === staking.interface.getEventTopic("Claimed"))!);

  //   expect(evt.args.principal).to.equal(amount);
  //   expect(evt.args.rewards).to.equal(reward2);
  //   expect(evt.args.totalClaimed).to.equal(amount + reward2);
  // });
});

 
});
