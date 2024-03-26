import { deployBundler, deployMockERC20, deployMockERC721, deployMockERC1155 } from "./libs/contract.js";

const main = async () => {
  console.log(`\n${"Deploying Token Bundler contract"}`);
  await deployBundler();
  console.log(`\n${"Deploying Mock ERC20 contract"}`);
  await deployMockERC20();
  // must use account with 721 receiver
  console.log(`\n${"Deploying Mock ERC721 contract"}`);
  await deployMockERC721();
  // must use account with 1155 receiver
  console.log(`\n${"Deploying Mock ERC1155 contract"}`);
  await deployMockERC1155();
};

main();