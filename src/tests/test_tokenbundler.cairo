use core::array::ArrayTrait;
use starknet::ContractAddress;

use token_bundler::tests::utils::{
    deploy_token_bundler, deploy_mock_erc20, deploy_mock_erc721, deploy_mock_erc1155,
    deploy_account, approve_erc20, approve_erc721, approve_erc1155
};
use token_bundler::tests::selectors;
use token_bundler::multitoken::MultiToken::{Asset, Category};
use token_bundler::tokenbundler::{
    ITokenBundlerDispatcher, ITokenBundlerDispatcherTrait, TokenBundler
};

use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use openzeppelin::token::erc721::interface::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use openzeppelin::token::erc1155::interface::{ERC1155ABIDispatcher, ERC1155ABIDispatcherTrait};
use openzeppelin::account::interface::{AccountABIDispatcher, AccountABIDispatcherTrait, Call};

use snforge_std::{spy_events, SpyOn, EventSpy, EventAssertions, start_prank, CheatTarget};

fn set_up() -> (
    (AccountABIDispatcher, ContractAddress),
    (ITokenBundlerDispatcher, ContractAddress),
    (ERC20ABIDispatcher, ContractAddress),
    (ERC721ABIDispatcher, ContractAddress),
    (ERC1155ABIDispatcher, ContractAddress)
) {
    let (account_dispatcher, account_address) = deploy_account('owner');
    start_prank(CheatTarget::One(account_address), 0.try_into().unwrap());
    return (
        (account_dispatcher, account_address),
        deploy_token_bundler(account_address),
        deploy_mock_erc20(account_address),
        deploy_mock_erc721(account_address),
        deploy_mock_erc1155(account_address)
    );
}

#[test]
fn test_wrap_one_asset() {
    let ((account, account_address), (_, bundler_address), (_, erc20_address), _, _) = set_up();
    let amount: u256 = 100;
    approve_erc20(account, erc20_address, bundler_address, amount);
    let mut calls = array![];
    let mut calldata = array![];
    let asset = Asset { category: Category::ERC20, address: erc20_address, id: 0, amount: amount };
    let mut assets: Array<Asset> = array![asset];
    Serde::serialize(@assets, ref calldata);
    let call = Call { to: bundler_address, selector: selectors::create, calldata: calldata.span() };
    calls.append(call);
    let mut spy = spy_events(SpyOn::One(bundler_address));
    account.__execute__(calls);
    spy
        .assert_emitted(
            @array![
                (
                    bundler_address,
                    TokenBundler::Event::BundleCreated(
                        TokenBundler::BundleCreated { id: 0, creator: account_address }
                    )
                )
            ]
        );
}

#[test]
fn test_wrap_multiple_assets() {
    let (
        (account, account_address),
        (_, bundler_address),
        (_, erc20_address),
        (_, erc721_address),
        (_, erc1155_address)
    ) =
        set_up();
    let amount: u256 = 3;
    let id: u256 = 1;
    approve_erc20(account, erc20_address, bundler_address, amount);
    approve_erc721(account, erc721_address, bundler_address, id);
    approve_erc1155(account, erc1155_address, bundler_address);
    let mut calls = array![];
    let mut calldata = array![];
    let erc20_asset = Asset {
        category: Category::ERC20, address: erc20_address, id: 0, amount: amount
    };
    let erc721_asset = Asset {
        category: Category::ERC721, address: erc721_address, id: id, amount: 0
    };
    let erc1155_asset = Asset {
        category: Category::ERC1155, address: erc1155_address, id: id, amount: amount
    };
    let mut assets: Array<Asset> = array![erc20_asset, erc721_asset, erc1155_asset];
    Serde::serialize(@assets, ref calldata);
    let call = Call { to: bundler_address, selector: selectors::create, calldata: calldata.span() };
    calls.append(call);
    let mut spy = spy_events(SpyOn::One(bundler_address));
    account.__execute__(calls);
    spy
        .assert_emitted(
            @array![
                (
                    bundler_address,
                    TokenBundler::Event::BundleCreated(
                        TokenBundler::BundleCreated { id: 0, creator: account_address }
                    )
                )
            ]
        );
}

#[test]
fn test_unwrap() {
    let ((account, _), (_, bundler_address), (_, erc20_address), _, _) = set_up();
    let amount: u256 = 100;
    approve_erc20(account, erc20_address, bundler_address, amount);
    let mut calls = array![];

    let mut calldata = array![];
    let asset = Asset { category: Category::ERC20, address: erc20_address, id: 0, amount: amount };
    let mut assets: Array<Asset> = array![asset];
    Serde::serialize(@assets, ref calldata);
    let call1 = Call {
        to: bundler_address, selector: selectors::create, calldata: calldata.span()
    };
    calls.append(call1);

    calldata = array![];
    let id: u256 = 0;
    Serde::serialize(@id, ref calldata);
    let call2 = Call { to: bundler_address, selector: selectors::burn, calldata: calldata.span() };
    calls.append(call2);

    let mut spy = spy_events(SpyOn::One(bundler_address));
    account.__execute__(calls);
    spy
        .assert_emitted(
            @array![
                (
                    bundler_address,
                    TokenBundler::Event::BundleUnwrapped(TokenBundler::BundleUnwrapped { id: id })
                )
            ]
        );
}

#[test]
fn test_read_functions() {
    // create bundle with multiple assets
    let (
        (account, account_address),
        (bundler, bundler_address),
        (_, erc20_address),
        (_, erc721_address),
        (_, erc1155_address)
    ) =
        set_up();
    let amount: u256 = 3;
    let id: u256 = 1;
    approve_erc20(account, erc20_address, bundler_address, amount);
    approve_erc721(account, erc721_address, bundler_address, id);
    approve_erc1155(account, erc1155_address, bundler_address);
    let mut calls = array![];
    let mut calldata = array![];
    let erc20_asset = Asset {
        category: Category::ERC20, address: erc20_address, id: 0, amount: amount
    };
    let erc721_asset = Asset {
        category: Category::ERC721, address: erc721_address, id: id, amount: 0
    };
    let erc1155_asset = Asset {
        category: Category::ERC1155, address: erc1155_address, id: id, amount: amount
    };
    let mut assets: Array<Asset> = array![erc20_asset, erc721_asset, erc1155_asset];
    Serde::serialize(@assets, ref calldata);
    let call = Call { to: bundler_address, selector: selectors::create, calldata: calldata.span() };
    calls.append(call);
    account.__execute__(calls);
    // bundle
    let bundle_id: u256 = 0;
    let ret_bundle = bundler.bundle(bundle_id);
    let bundle = TokenBundler::Bundle {
        owner: account_address,
        tokens: array![erc20_address, erc721_address, erc1155_address].span()
    };
    assert(ret_bundle.owner == bundle.owner, 'bundle owner not correct');
    assert(ret_bundle.tokens == bundle.tokens, 'bundle tokens not correct');
    // tokens
    let ret_tokens = bundler.tokensInBundle(bundle_id);
    assert(ret_tokens.len() == 3, 'wrong number of tokens returned');
}
