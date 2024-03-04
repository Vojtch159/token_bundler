use core::option::OptionTrait;
use core::traits::TryInto;
use core::array::ArrayTrait;
use starknet::ContractAddress;

use snforge_std::{declare, ContractClassTrait};

use token_bundler::TokenBundler::ITokenBundlerSafeDispatcher;
use token_bundler::TokenBundler::ITokenBundlerSafeDispatcherTrait;
use token_bundler::TokenBundler::ITokenBundlerDispatcher;
use token_bundler::TokenBundler::ITokenBundlerDispatcherTrait;
use token_bundler::MultiToken::MultiToken::{Asset, Category};

fn deploy_bundler() -> ContractAddress {
    let contract_class = declare('TokenBundler');
    let constructor_calldata = @ArrayTrait::new();
    return contract_class.deploy(constructor_calldata).unwrap();
}

fn deploy_account() -> ContractAddress {
    return 0.try_into().unwrap();
}

fn deploy_erc20(name: felt252, symbol: felt252, owner: ContractAddress) -> ContractAddress {
    return 0.try_into().unwrap();
}

fn deploy_erc721() -> ContractAddress {
    return 0.try_into().unwrap();
}

#[test]
fn test_full_bundle_flow() {
    let bundler_address = deploy_bundler();
    let account = deploy_account();
    assert(true, 'yay')
}

