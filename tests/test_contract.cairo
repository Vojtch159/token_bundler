use core::array::ArrayTrait;
use starknet::ContractAddress;

use snforge_std::{declare, ContractClassTrait};

use token_bundler::TokenBundler::ITokenBundlerSafeDispatcher;
use token_bundler::TokenBundler::ITokenBundlerSafeDispatcherTrait;
use token_bundler::TokenBundler::ITokenBundlerDispatcher;
use token_bundler::TokenBundler::ITokenBundlerDispatcherTrait;
use token_bundler::TokenBundler::Token;
use token_bundler::TokenBundler::AssetCategory;

fn deploy_contract(name: felt252) -> ContractAddress {
    let contract = declare(name);
    contract.deploy(@ArrayTrait::new()).unwrap()
}

#[test]
fn test_create_and_get_bundle() {
    let contract_address = deploy_contract('TokenBundler');

    let dispatcher = ITokenBundlerDispatcher { contract_address };
    let mut tokens = ArrayTrait::<Token>::new();
    let token = Token {
        contract_address: dispatcher.contract_address, asset_category: AssetCategory::ERC20,
    };
    tokens.append(token);
    dispatcher.create(tokens);

    let bundleAndTokens = dispatcher.bundle(0);
    assert(bundleAndTokens.bundle.bundle_id == 0, 'Invalid Bundle');
    let mut tokens_to_check = ArrayTrait::<ContractAddress>::new();
    tokens_to_check.append(dispatcher.contract_address);
    assert(bundleAndTokens.tokens == tokens_to_check.span(), 'Invalid Bundle Tokens')
}
