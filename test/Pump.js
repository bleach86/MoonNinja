const { expect } = require("chai");
const { ethers } = require("hardhat");
const helpers = require("@nomicfoundation/hardhat-network-helpers");
const fs = require("fs");

describe("MoonNinja", function () {
  let moonNinja,
    MoonNinja,
    MoonNinjaToken,
    owner,
    addr1,
    addr2,
    moonNinjaToken,
    tokenAddress,
    WETH,
    liquidityManager,
    decimals;

  before(async () => {
    [owner, addr1, addr2] = await ethers.getSigners();

    // Deploy WETH contract

    const WETH_CONTRACT = await ethers.getContractFactory("WETH9");
    const weth = await WETH_CONTRACT.deploy();
    WETH = weth;
    decimals = 18;

    // deploy Liquidity manager

    const LiquidityManager = await ethers.getContractFactory(
      "MNLiquidityManager"
    );
    liquidityManager = await LiquidityManager.deploy();

    // Deploy MoonNinjaToken first
    MoonNinjaToken = await ethers.getContractFactory("MoonNinjaToken");
    moonNinjaToken = await MoonNinjaToken.deploy();

    moonNinjaToken.get;

    // Now deploy MoonNinja contract and pass the token address
    MoonNinja = await ethers.getContractFactory("MoonNinja");
    moonNinja = await MoonNinja.deploy(
      moonNinjaToken.target,
      WETH.target,
      liquidityManager.target
    );
  });

  describe("Deployment", function () {
    it("gives a test account 100k ETH", async () => {
      const newBalance = ethers.parseEther("10000000");
      const halfBalance = ethers.parseEther("50000");
      await helpers.setBalance(addr1.address, newBalance);
      await helpers.setBalance(owner.address, newBalance);
      const balance = await ethers.provider.getBalance(addr1.address);

      await WETH.connect(addr1).deposit({ value: halfBalance });
      await WETH.deposit({ value: halfBalance });

      expect(balance).to.equal(newBalance);
      expect(await WETH.balanceOf(addr1.address)).to.equal(halfBalance);
    });

    it("Should deploy MoonNinja contract", async function () {
      expect(await moonNinja.getAddress()).to.properAddress;
    });
  });

  describe("Creating a MoonNinjaToken", function () {
    it("Should create a MoonNinjaToken and show event details", async function () {
      WETH.approve(moonNinja.target, ethers.parseEther("20"));

      const tx = await moonNinja.createToken(
        {
          name: "MemeToken",
          symbol: "MEME",
          decimals: decimals,
          maxSupply: ethers.parseUnits("1000000000", decimals),
          description: "A fun token",
          image: "ipfs://image",
          twitter: "@twitter",
          telegram: "@telegram",
          discord: "@discord",
          website: "https://website.com",
          developer: owner.address,
          bondingFeeAddress: owner.address,
          connectorWeight: 200000,
          fees: {
            buyFee: 0,
            sellFee: 0,
            transferFee: 10,
            developerFee: 50,
            burnFee: 50,
          },
          antiWhale: true,
          maxAntiWhaleAmount: 0,
          liquidityManagerAddress: liquidityManager.target,
        },
        ethers.parseEther("20")
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

    before(async () => {
      moonNinjaToken = await ethers.getContractAt(
        "MoonNinjaToken",
        tokenAddress
      );
    });

    it("Should allow users to buy tokens", async function () {
      // Generate a random number between 0.5 and 350
      const randomEth = 0.5 + Math.random() * (350 - 0.5);
      const ethToSend = ethers.parseUnits(randomEth.toFixed(6), "ether");

      //console.log(`Sending ${randomEth.toFixed(6)} ETH to buy tokens`);

      await moonNinjaToken.connect(addr1).buyTokens(0, { value: ethToSend });

      const balance = await moonNinjaToken.balanceOf(addr1.address);
      //console.log("The balance is", ethers.formatEther(balance));
      expect(balance).to.be.greaterThan(0n);
    });

    it("Should allow users to sell tokens", async function () {
      const tokenAmountToSell = await moonNinjaToken.balanceOf(addr1.address);
      // await moonNinjaToken
      //   .connect(addr1)
      //   .approve(await moonNinjaToken.getAddress(), tokenAmountToSell);
      const initialEthBalance = await ethers.provider.getBalance(addr1.address);
      await moonNinjaToken.connect(addr1).sellTokens(tokenAmountToSell);
      const finalEthBalance = await ethers.provider.getBalance(addr1.address);
      expect(finalEthBalance).to.be.gt(initialEthBalance);
      const tokenBalance = await moonNinjaToken.balanceOf(addr1.address);
      expect(tokenBalance).to.equal(0);
    });

    it("Should allow users to buy tokens with WETH", async function () {
      // Generate a random number between 0.5 and 350
      const randomEth = 0.5 + Math.random() * (350 - 0.5);
      const ethToSend = ethers.parseUnits(randomEth.toFixed(6), "ether");

      //console.log(`Sending ${randomEth.toFixed(6)} ETH to buy tokens`);

      await WETH.connect(addr1).approve(moonNinjaToken.target, ethToSend);
      await moonNinjaToken.connect(addr1).buyTokens(ethToSend);

      const balance = await moonNinjaToken.balanceOf(addr1.address);
      //console.log("The balance is", ethers.formatEther(balance));
      expect(balance).to.be.greaterThan(0n);
    });

    it("Should allow users to buy with direct ETH transfer", async function () {
      // Generate a random number between 0.5 and 350
      const randomEth = 0.5 + Math.random() * (350 - 0.5);
      const ethToSend = ethers.parseUnits(randomEth.toFixed(6), "ether");

      const initialEthBalance = await moonNinjaToken.balanceOf(addr1.address);

      //console.log(`Sending ${randomEth.toFixed(6)} ETH to buy tokens`);
      await addr1.sendTransaction({
        to: moonNinjaToken.target,
        value: ethToSend,
      });

      const balance = await moonNinjaToken.balanceOf(addr1.address);
      //console.log("The balance is", ethers.formatEther(balance));
      expect(balance).to.be.greaterThan(initialEthBalance);
    });

    it("Should not allow buying with less than 1 wei", async function () {
      await expect(
        moonNinjaToken.connect(addr2).buyTokens(0, { value: 1 })
      ).to.be.revertedWith("send some ETH");
    });

    it("Should not allow selling more tokens than owned", async function () {
      await expect(
        moonNinjaToken
          .connect(addr2)
          .sellTokens(ethers.parseUnits("100", decimals))
      ).to.be.revertedWith("too poor");
    });

    it("Should allow users to pump", async function () {
      let tx;
      for (let i = 0; i < iters; i++) {
        const price = await moonNinjaToken.getCurrentPrice();
        const randomEth = 0.5 + Math.random() * (350 - 0.5);
        const ethToSend = ethers.parseUnits(randomEth.toFixed(6), "ether");

        //console.log("Price:", ethers.formatEther(price));

        tx = await moonNinjaToken
          .connect(addr1)
          .buyTokens(0, { value: ethToSend });

        const receipt = await tx.wait();

        //console.log("Gas used:", receipt.gasUsed.toString());
      }
      const balance = await moonNinjaToken.balanceOf(addr1.address);
      expect(balance).to.be.greaterThan(0);
    });

    it("Should allow users to dump", async function () {
      const initialBalance = await moonNinjaToken.balanceOf(addr1.address);

      const tokenAmountToSell = BigInt(
        ethers.toBigInt(initialBalance) / BigInt(iters)
      );

      for (let i = 0; i < iters; i++) {
        let tx;
        // await moonNinjaToken
        //   .connect(addr1)
        //   .approve(await moonNinjaToken.getAddress(), tokenAmountToSell);
        tx = await moonNinjaToken.connect(addr1).sellTokens(tokenAmountToSell);
        const receipt = await tx.wait();

        //console.log("Gas used:", receipt.gasUsed.toString());
      }
      const finalBalance = await moonNinjaToken.balanceOf(addr1.address);
    });

    it("Should allow users to get token details", async function () {
      const tokenDetails = await moonNinjaToken.getTokenDetails();

      expect(tokenDetails.name).to.equal("MemeToken");
      expect(tokenDetails.symbol).to.equal("MEME");
      expect(tokenDetails.developer).to.equal(owner.address);
      expect(tokenDetails.description).to.equal("A fun token");
      expect(tokenDetails.image).to.equal("ipfs://image");
      expect(tokenDetails.twitter).to.equal("@twitter");
      expect(tokenDetails.telegram).to.equal("@telegram");
      expect(tokenDetails.website).to.equal("https://website.com");
    });

    it("Should allow users to get platform trade totals", async function () {
      const tradeTotals = await moonNinja.getTradeTotals();
      expect(tradeTotals[0]).to.be.eq(iters * 2 + 5);
      expect(tradeTotals[1]).to.be.eq(iters + 4);
      expect(tradeTotals[2]).to.be.eq(iters + 1);
    });

    it("Should not allow users to execute tradeEvent", async function () {
      await expect(
        moonNinja.tradeEvent(true, addr1.address, 1, 1)
      ).to.be.revertedWith("Caller must be a valid MoonNinja token");
    });

    it("Should collect fees correctly", async function () {
      const balacne = await WETH.balanceOf(owner.address);
      expect(balacne).to.be.greaterThan(0);
    });

    it("Should simulate market activity randomly buying and selling", async function () {
      const tradeFile = fs.readFileSync("sim_trades.json", "utf8");
      const trades = JSON.parse(tradeFile);
      const prices = [];
      const ethUSDPrice = 0.25;

      for (let i = 0; i < trades.length; i++) {
        const price = await moonNinjaToken.getCurrentPrice();
        const priceFormatted = ethers.formatUnits(price, decimals);
        const usdPerToken = ethUSDPrice / priceFormatted;
        prices.push(usdPerToken);

        const trade = trades[i];
        if (trade.type === "buy") {
          const amountToBuy = trade.SOL * 500;
          const amountToBuyInEth = ethers.parseUnits(
            `${parseInt(amountToBuy)}`,
            "ether"
          );

          await moonNinjaToken
            .connect(addr1)
            .buyTokens(0, { value: amountToBuyInEth });
        } else if (trade.type === "sell") {
          const tokenBalance = await moonNinjaToken.balanceOf(addr1.address);
          const balanceNum = Number(tokenBalance);

          if (balanceNum > 0) {
            const randomAmountToSell = BigInt(
              Math.floor(Math.random() * balanceNum)
            );
            await moonNinjaToken.connect(addr1).sellTokens(randomAmountToSell);
          }
        }

        const balance = await moonNinjaToken.balanceOf(addr1.address);
        expect(balance).to.be.greaterThan(0n);
      }

      // Save prices
      fs.writeFileSync("prices.json", JSON.stringify(prices, null, 2));
      const contractBalance = await moonNinjaToken.balanceOf(
        moonNinjaToken.target
      );
      console.log(
        "Contract balance",
        ethers.formatUnits(contractBalance, decimals)
      );
      const contractWETHBalance = await WETH.balanceOf(moonNinjaToken.target);
      console.log(
        "Contract WETH balance",
        ethers.formatEther(contractWETHBalance)
      );
      var totalSupply = await moonNinjaToken.totalSupply();
      totalSupply = ethers.formatUnits(totalSupply, decimals);
      const marketCap = totalSupply * prices[prices.length - 1];
      console.log("Market cap", marketCap);
    });

    it("Should collect transfer fees correctly", async function () {
      const totalSupply = await moonNinjaToken.totalSupply();
      const dev = await moonNinjaToken.developer();
      const initialDevBalance = await moonNinjaToken.balanceOf(dev);

      const tx = await moonNinjaToken
        .connect(addr1)
        .transfer(addr2, ethers.parseUnits("1", decimals));

      const addr2Balance = await moonNinjaToken.balanceOf(addr2.address);
      const newTotalSupply = await moonNinjaToken.totalSupply();
      const newDevBalance = await moonNinjaToken.balanceOf(dev);

      expect(addr2Balance).to.equal(ethers.parseUnits("0.9", decimals));
      expect(newDevBalance).to.equal(ethers.parseUnits("0.05", decimals));
      expect(newTotalSupply).to.equal(
        totalSupply - ethers.parseUnits("0.05", decimals)
      );
    });

    it("Should init liquidity pool", async function () {
      const tx = await moonNinjaToken.initializeLiquidity();
      const receipt = await tx.wait();
      const event = receipt.logs.map((log) => {
        try {
          return moonNinjaToken.interface.parseLog(log);
        } catch {
          return null;
        }
      });
      console.log("Event", event);
    });
  });
});
