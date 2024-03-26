import { deployBundler } from "./libs/contract.js";

const main = async () => {
  console.log(`\n${"Deploying Token Bundler contract"}`);
  await deployBundler();
};

main();