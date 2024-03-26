import "dotenv/config";
import * as fs from "fs";
import { json, CallData, cairo, byteArray } from "starknet";
import { getAccount } from "./network.js";

const declare = async (filepath, contract_name) => {
  console.log(`\nDeclaring ${contract_name}...`);
  const compiledSierraCasm = filepath.replace(
    ".contract_class.json",
    ".compiled_contract_class.json"
  );
  const compiledFile = json.parse(fs.readFileSync(filepath).toString("ascii"));
  const compiledSierraCasmFile = json.parse(
    fs.readFileSync(compiledSierraCasm).toString("ascii")
  );
  const account = getAccount();
  const contract = await account.declareIfNot({
    contract: compiledFile,
    casm: compiledSierraCasmFile,
  });

  console.log(`- Class Hash: ${contract.class_hash}`);
  if (contract.transaction_hash) {
    console.log(
      `- Tx Hash: ${contract.transaction_hash})`
    );
    await account.waitForTransaction(contract.transaction_hash);
  } else {
    console.log("- Tx Hash: ", "Already declared");
  }

  return contract;
};

export const deployBundler = async () => {
  const account = getAccount();
  const bundler = await declare(process.env.PATH_TO_CASM_COMPILE, "TokenBundler");

  console.log(`\nDeploying Bundler...`);
  console.log("Owner: ", process.env.OWNER_ADDRESS);
  console.log("Bundler class hash: ", bundler.class_hash);

  const contract = await account.deployContract({
    classHash: bundler.class_hash,
    constructorCalldata: [
      process.env.OWNER_ADDRESS,
    ],
  });

  console.log(`Tx hash: ${contract.transaction_hash}`);
  await account.waitForTransaction(contract.transaction_hash);
  console.log(`Bundler deployed at ${contract.address}`);
};

export const deployMockERC20 = async () => {
  const account = getAccount();
  const erc20 = await declare(process.env.ERC20_PATH, "MockERC20");

  console.log(`\nDeploying Mock ERC20...`);
  console.log("Owner: ", process.env.OWNER_ADDRESS);
  console.log("ERC20 class hash: ", erc20.class_hash);

  const contract = await account.deployContract({
    classHash: erc20.class_hash,
    constructorCalldata: CallData.compile({
      initial_supply: cairo.uint256(21000000n * 10n ** 18n),
      recipient: process.env.OWNER_ADDRESS,
    }),
  });

  console.log(`Tx hash: ${contract.transaction_hash}`);
  await account.waitForTransaction(contract.transaction_hash);
  console.log(`ERC20 deployed at ${contract.address}`);
};

export const deployMockERC721 = async () => {
  const account = getAccount();
  const erc721 = await declare(process.env.ERC721_PATH, "MockERC721");

  console.log(`\nDeploying Mock ERC721...`);
  console.log("Owner: ", process.env.OWNER_ADDRESS);
  console.log("ERC721 class hash: ", erc721.class_hash);

  const contract = await account.deployContract({
    classHash: erc721.class_hash,
    constructorCalldata: [
      process.env.OWNER_ADDRESS,
    ],
  });

  console.log(`Tx hash: ${contract.transaction_hash}`);
  await account.waitForTransaction(contract.transaction_hash);
  console.log(`ERC721 deployed at ${contract.address}`);
};

export const deployMockERC1155 = async () => {
  const account = getAccount();
  const erc1155 = await declare(process.env.ERC1155_PATH, "MockERC1155");

  console.log(`\nDeploying Mock ERC1155...`);
  console.log("Owner: ", process.env.OWNER_ADDRESS);
  console.log("ERC1155 class hash: ", erc1155.class_hash);

  const contract = await account.deployContract({
    classHash: erc1155.class_hash,
    constructorCalldata: CallData.compile({
      token_uri: byteArray.byteArrayFromString('token_uri'),
      recipient: process.env.OWNER_ADDRESS,
      token_ids: [cairo.uint256(1)],
      values: [cairo.uint256(1)]
    })
  });

  console.log(`Tx hash: ${contract.transaction_hash}`);
  await account.waitForTransaction(contract.transaction_hash);
  console.log(`ERC1155 deployed at ${contract.address}`);
};