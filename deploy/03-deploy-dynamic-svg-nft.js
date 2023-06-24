// 0xb9Af19903d191a41F977e7938C6DCB7fFF866B34
const { network, ethers } = require("hardhat");
const {
  developmentChains,
  networkConfig,
} = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");
const fs = require("fs");
require("dotenv").config();

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const chainId = network.config.chainId;

  let ethUsdPriceFeedAddress;
  if (developmentChains.includes(network.name)) {
    const EthUsdAggregator = await ethers.getContract("MockV3Aggregator");
    ethUsdPriceFeedAddress = EthUsdAggregator.address;
  } else {
    ethUsdPriceFeedAddress = networkConfig[chainId].ethUsdPriceFeed;
  }
  log("---------------------------------------");

  const lowSVG = fs.readFileSync("./images/dynamicNft/frown.svg", {
    encoding: "utf8",
  });
  const highSVG = fs.readFileSync("./images/dynamicNft/happy.svg", {
    encoding: "utf8",
  });

  const args = [ethUsdPriceFeedAddress, lowSVG, highSVG];

  const dynamicNFT = await deploy("DynamicSvgNft", {
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

  // Verify the deployment
  if (
    !developmentChains.includes(network.name) &&
    process.env.ETHERSCAN_API_KEY
  ) {
    log("Verifying...");
    await verify(dynamicNFT.address, args);
  }
};

module.exports.tags = ["all", "dynamicsvg", "main"];
