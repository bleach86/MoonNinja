const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MoonNinja", function () {
  let moonNinja,
    MoonNinja,
    MoonNinjaToken,
    owner,
    addr1,
    addr2,
    moonNinjaToken,
    tokenAddress;

  before(async () => {
    [owner, addr1, addr2] = await ethers.getSigners();

    // Deploy MoonNinjaToken first
    MoonNinjaToken = await ethers.getContractFactory("MoonNinjaToken");
    moonNinjaToken = await MoonNinjaToken.deploy();

    // Now deploy MoonNinja contract and pass the token address
    MoonNinja = await ethers.getContractFactory("MoonNinja");
    moonNinja = await MoonNinja.deploy(moonNinjaToken.target);
  });

  describe("Deployment", function () {
    it("Should deploy MoonNinja contract", async function () {
      expect(await moonNinja.getAddress()).to.properAddress;
    });
  });

  describe("Creating a MoonNinjaToken", function () {
    it("Should create a MoonNinjaToken and show event details", async function () {
      const tx = await moonNinja.createToken(
        "MemeToken",
        "MEME",
        "A fun token",
        "ipfs://image",
        "@twitter",
        "@telegram",
        "https://website.com"
      );

      const receipt = await tx.wait();

      const event = receipt.logs
        .map((log) => {
          try {
            return moonNinja.interface.parseLog(log);
          } catch {
            return null;
          }
        })
        .find((e) => e && e.name === "TokenCreated");

      if (!event) throw new Error("❌ TokenCreated event not found.");

      tokenAddress = event.args.tokenAddress;
    });

    it("Should store deployed token addresses", async function () {
      const deployedTokens = await moonNinja.getDeployedTokens();
      expect(deployedTokens.length).to.equal(1);
      expect(deployedTokens[0]).to.equal(tokenAddress);
    });
  });

  describe("MoonNinjaToken Interaction", function () {
    let moonNinjaToken;
    let iters = 125;
    let feeAddressBalanceStart;

    before(async () => {
      moonNinjaToken = await ethers.getContractAt(
        "MoonNinjaToken",
        tokenAddress
      );
      feeAddressBalanceStart = await ethers.provider.getBalance(owner.address);
    });

    it("Should have a max supply of 1,000,000 MEME tokens", async function () {
      const totalSupply = await moonNinjaToken.totalSupply();
      expect(totalSupply).to.equal(ethers.parseUnits("1000000", 18));
    });

    it("Should allow users to buy tokens", async function () {
      const ethToSend = ethers.parseUnits("1", "ether");
      await moonNinjaToken.connect(addr1).buyTokens({ value: ethToSend });
      const balance = await moonNinjaToken.balanceOf(addr1.address);
      expect(balance).to.be.greaterThan(0);
    });

    it("Should allow users to sell tokens", async function () {
      const tokenAmountToSell = await moonNinjaToken.balanceOf(addr1.address);
      await moonNinjaToken
        .connect(addr1)
        .approve(await moonNinjaToken.getAddress(), tokenAmountToSell);
      const initialEthBalance = await ethers.provider.getBalance(addr1.address);
      await moonNinjaToken.connect(addr1).sellTokens(tokenAmountToSell);
      const finalEthBalance = await ethers.provider.getBalance(addr1.address);
      expect(finalEthBalance).to.be.gt(initialEthBalance);
    });

    it("Should not allow buying with less than 1 wei", async function () {
      await expect(
        moonNinjaToken.connect(addr2).buyTokens({ value: 1 })
      ).to.be.revertedWith("send some ETH");
    });

    it("Should not allow selling more tokens than owned", async function () {
      await expect(
        moonNinjaToken.connect(addr2).sellTokens(ethers.parseUnits("100", 18))
      ).to.be.revertedWith("too poor");
    });

    it("Should allow users to pump", async function () {
      const ethToSend = ethers.parseUnits("1", "ether");
      for (let i = 0; i < iters; i++) {
        await moonNinjaToken.connect(addr1).buyTokens({ value: ethToSend });
      }
      const balance = await moonNinjaToken.balanceOf(addr1.address);
      expect(balance).to.be.greaterThan(0);
    });

    it("Should allow users to dump", async function () {
      const initialBalance = await moonNinjaToken.balanceOf(addr1.address);

      const tokenAmountToSell = ethers.parseEther(
        `${parseInt(parseInt(initialBalance) / iters)}`
      );

      for (let i = 0; i < iters; i++) {
        await moonNinjaToken
          .connect(addr1)
          .approve(await moonNinjaToken.getAddress(), tokenAmountToSell);
        await moonNinjaToken.connect(addr1).sellTokens(tokenAmountToSell);
      }
      const finalBalance = await moonNinjaToken.balanceOf(addr1.address);
    });

    it("Should allow users to get trade history", async function () {
      const tradeHistory = await moonNinjaToken.getUserTradeHistory(
        addr1.address
      );
      expect(tradeHistory.length).to.be.greaterThan(0);
    });

    it("Should allow users to get token details", async function () {
      const tokenDetails = await moonNinjaToken.getTokenDetails();

      expect(tokenDetails.name).to.equal("MemeToken");
      expect(tokenDetails.symbol).to.equal("MEME");
      expect(tokenDetails.developer).to.equal(owner.address);
      expect(tokenDetails.maxSupply).to.equal(ethers.parseUnits("1000000", 18));
      expect(tokenDetails.description).to.equal("A fun token");
      expect(tokenDetails.image).to.equal("ipfs://image");
      expect(tokenDetails.twitter).to.equal("@twitter");
      expect(tokenDetails.telegram).to.equal("@telegram");
      expect(tokenDetails.website).to.equal("https://website.com");
    });

    it("Should allow users to get platform trade history", async function () {
      const tradeHistory = await moonNinja.getLast250Trades();
      const expected = Math.min(iters * 2 + 2, 250);

      expect(tradeHistory.length).to.equal(expected);
    });

    it("Should allow users to get platform trade totals", async function () {
      const tradeTotals = await moonNinja.getTradeTotals();
      expect(tradeTotals[0]).to.be.eq(iters * 2 + 2);
      expect(tradeTotals[1]).to.be.eq(iters + 1);
      expect(tradeTotals[2]).to.be.eq(iters + 1);
    });

    it("Should not allow users to execute tradeEvent", async function () {
      await expect(
        moonNinja.tradeEvent(true, addr1.address, 1, 1)
      ).to.be.revertedWith("Caller must be a valid MoonNinja token");
    });

    it("Should collect fees correctly", async function () {
      const feeAddressBalanceEnd = await ethers.provider.getBalance(
        owner.address
      );
      const feeAddressBalanceDiff =
        feeAddressBalanceEnd - feeAddressBalanceStart;
      expect(feeAddressBalanceDiff).to.be.gt(0);
    });
  });
});
