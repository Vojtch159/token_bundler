use core::traits::TryInto;
use starknet::ContractAddress;
use snforge_std::{ContractClass, ContractClassTrait, declare};
use token_bundler::tokenbundler::ITokenBundlerDispatcher;
use token_bundler::tests::selectors;
use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use openzeppelin::token::erc721::interface::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use openzeppelin::token::erc1155::interface::{ERC1155ABIDispatcher, ERC1155ABIDispatcherTrait};
use openzeppelin::account::interface::{AccountABIDispatcher, AccountABIDispatcherTrait, Call};

fn OWNER_PUBLIC_KEY() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn DEFAULT_INITIAL_SUPPLY() -> u256 {
    21_000_000 * pow_256(10, 18)
}

fn DEFAULT_TOKEN_URI() -> ByteArray {
    "token_uri"
}

fn deploy_account(pub_key: felt252) -> (AccountABIDispatcher, ContractAddress) {
    let contract = declare('Account');
    let mut calldata = array![pub_key];
    let contract_address = contract.deploy(@calldata).expect('failed to deploy account');
    let account = AccountABIDispatcher { contract_address };
    (account, contract_address)
}

fn deploy_token_bundler(owner: ContractAddress) -> (ITokenBundlerDispatcher, ContractAddress) {
    let contract = declare('TokenBundler');
    let mut calldata = array![owner.into()];
    let contract_address = contract.deploy(@calldata).expect('failed to deploy bundler');
    let bundler = ITokenBundlerDispatcher { contract_address };
    (bundler, contract_address)
}

fn deploy_mock_erc20(owner: ContractAddress) -> (ERC20ABIDispatcher, ContractAddress) {
    let contract = declare('MockERC20');
    let mut calldata = array![];
    Serde::serialize(@DEFAULT_INITIAL_SUPPLY(), ref calldata);
    Serde::serialize(@owner, ref calldata);
    let contract_address = contract.deploy(@calldata).expect('failed to deploy mock erc20');
    let erc20 = ERC20ABIDispatcher { contract_address };
    (erc20, contract_address)
}

fn deploy_mock_erc721(owner: ContractAddress) -> (ERC721ABIDispatcher, ContractAddress) {
    let contract = declare('MockERC721');
    let mut calldata = array![owner.into()];
    let contract_address = contract.deploy(@calldata).expect('failed to deploy mock erc721');
    let erc721 = ERC721ABIDispatcher { contract_address };
    (erc721, contract_address)
}

fn deploy_mock_erc1155(owner: ContractAddress) -> (ERC1155ABIDispatcher, ContractAddress) {
    let contract = declare('MockERC1155');
    let mut calldata = array![];
    let mut token_ids: Span<u256> = array![1, 10].span();
    let mut token_values: Span<u256> = array![69, 420].span();
    Serde::serialize(@DEFAULT_TOKEN_URI(), ref calldata);
    Serde::serialize(@owner, ref calldata);
    Serde::serialize(@token_ids, ref calldata);
    Serde::serialize(@token_values, ref calldata);
    let contract_address = contract.deploy(@calldata).expect('failed to deploy mock erc1155');
    let erc1155 = ERC1155ABIDispatcher { contract_address };
    (erc1155, contract_address)
}

fn approve_erc20(
    account: AccountABIDispatcher, token_address: ContractAddress, to: ContractAddress, amount: u256
) {
    let mut calls = array![];
    let mut calldata = array![];
    Serde::serialize(@to, ref calldata);
    Serde::serialize(@amount, ref calldata);
    let call1 = Call { to: token_address, selector: selectors::approve, calldata: calldata.span() };
    calls.append(call1);
    account.__execute__(calls);
}

fn approve_erc721(
    account: AccountABIDispatcher, token_address: ContractAddress, to: ContractAddress, id: u256
) {
    let mut calls = array![];
    let mut calldata = array![];
    Serde::serialize(@to, ref calldata);
    Serde::serialize(@id, ref calldata);
    let call = Call { to: token_address, selector: selectors::approve, calldata: calldata.span() };
    calls.append(call);
    account.__execute__(calls);
}

fn approve_erc1155(
    account: AccountABIDispatcher, token_address: ContractAddress, to: ContractAddress
) {
    let mut calls = array![];
    let mut calldata = array![];
    Serde::serialize(@to, ref calldata);
    Serde::serialize(@true, ref calldata);
    let call = Call {
        to: token_address, selector: selectors::set_approval_for_all, calldata: calldata.span()
    };
    calls.append(call);
    account.__execute__(calls);
}

// Math
fn pow_256(self: u256, mut exponent: u8) -> u256 {
    if self.is_zero() {
        return 0;
    }
    let mut result = 1;
    let mut base = self;

    loop {
        if exponent & 1 == 1 {
            result = result * base;
        }

        exponent = exponent / 2;
        if exponent == 0 {
            break result;
        }

        base = base * base;
    }
}
