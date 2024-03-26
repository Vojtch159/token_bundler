use starknet::ContractAddress;

#[starknet::interface]
trait IMultiToken<TContractState> {
    fn transferAssetFrom(
        ref self: TContractState,
        asset: MultiToken::Asset,
        source: ContractAddress,
        dest: ContractAddress
    );
    fn safeTransferAssetFrom(
        ref self: TContractState,
        asset: MultiToken::Asset,
        source: ContractAddress,
        dest: ContractAddress
    );
    fn approveAsset(ref self: TContractState, asset: MultiToken::Asset, target: ContractAddress);
    fn getTransferAmount(self: @TContractState, asset: MultiToken::Asset) -> u256;
    fn balanceOfTarget(
        self: @TContractState, asset: MultiToken::Asset, target: ContractAddress
    ) -> Option<u256>;
    fn isValid(self: @TContractState, asset: MultiToken::Asset) -> Option<bool>;
    fn isSameAs(
        self: @TContractState, asset: MultiToken::Asset, otherAsset: MultiToken::Asset
    ) -> bool;
}

#[starknet::component]
mod MultiToken {
    use core::starknet::SyscallResultTrait;
    use starknet::ContractAddress;
    use core::array::ArrayTrait;
    use starknet::get_contract_address;
    use starknet::call_contract_syscall;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc721::interface::{
        IERC721Dispatcher, IERC721DispatcherTrait, IERC721_ID
    };
    use openzeppelin::token::erc1155::interface::{
        IERC1155Dispatcher, IERC1155DispatcherTrait, IERC1155_ID
    };
    use openzeppelin::account::interface;
    use openzeppelin::introspection::interface::ISRC5DispatcherTrait;
    use openzeppelin::introspection::interface::ISRC5Dispatcher;

    #[storage]
    struct Storage {}

    #[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
    pub enum Category {
        ERC20,
        ERC721,
        ERC1155
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub struct Asset {
        category: Category,
        address: ContractAddress,
        id: u256,
        amount: u256,
    }

    #[embeddable_as(MultiToken)]
    impl MultiTokenImpl<
        TContractState, +HasComponent<TContractState>
    > of super::IMultiToken<ComponentState<TContractState>> {
        fn transferAssetFrom(
            ref self: ComponentState<TContractState>,
            asset: Asset,
            source: ContractAddress,
            dest: ContractAddress
        ) {
            self._transferAssetFrom(asset, source, dest, false);
        }

        fn safeTransferAssetFrom(
            ref self: ComponentState<TContractState>,
            asset: Asset,
            source: ContractAddress,
            dest: ContractAddress
        ) {
            self._transferAssetFrom(asset, source, dest, true);
        }

        fn approveAsset(
            ref self: ComponentState<TContractState>, asset: Asset, target: ContractAddress
        ) {
            match asset.category {
                Category::ERC20 => {
                    let token = IERC20Dispatcher { contract_address: asset.address };
                    token.approve(target, asset.amount);
                },
                Category::ERC721 => {
                    let token = IERC721Dispatcher { contract_address: asset.address };
                    token.approve(target, asset.id);
                },
                Category::ERC1155 => {
                    let token = IERC1155Dispatcher { contract_address: asset.address };
                    token.set_approval_for_all(target, true);
                },
                _ => { panic!("Unsupported category"); }
            }
        }

        fn getTransferAmount(self: @ComponentState<TContractState>, asset: Asset) -> u256 {
            if (asset.category == Category::ERC20) {
                return asset.amount;
            } else if (asset.category == Category::ERC1155 && asset.amount > 0) {
                return asset.amount;
            } else {
                return 1;
            }
        }

        fn balanceOfTarget(
            self: @ComponentState<TContractState>, asset: Asset, target: ContractAddress
        ) -> Option<u256> {
            match asset.category {
                Category::ERC20 => {
                    let token = IERC20Dispatcher { contract_address: asset.address };
                    return Option::Some(token.balance_of(target));
                },
                Category::ERC721 => {
                    let token = IERC721Dispatcher { contract_address: asset.address };
                    if (token.owner_of(asset.id) == target) {
                        return Option::Some(1);
                    } else {
                        return Option::Some(0);
                    }
                },
                Category::ERC1155 => {
                    let token = IERC1155Dispatcher { contract_address: asset.address };
                    return Option::Some(token.balance_of(target, asset.id));
                },
                _ => {
                    panic!("Unsupported category");
                    return Option::None;
                }
            }
        }

        fn isValid(self: @ComponentState<TContractState>, asset: Asset) -> Option<bool> {
            match asset.category {
                Category::ERC20 => {
                    if (asset.id != 0) {
                        return Option::Some(false);
                    }
                    //TODO: should we enforce the OZ ERC20 implementation ID?
                    return Option::Some(true);
                },
                Category::ERC721 => {
                    if (asset.amount != 0) {
                        return Option::Some(false);
                    }
                    let dispatcher = ISRC5Dispatcher { contract_address: asset.address };
                    return Option::Some(dispatcher.supports_interface(IERC721_ID));
                },
                Category::ERC1155 => {
                    let dispatcher = ISRC5Dispatcher { contract_address: asset.address };
                    return Option::Some(dispatcher.supports_interface(IERC721_ID));
                },
                _ => {
                    panic!("Unsupported category");
                    return Option::None;
                }
            }
        }

        fn isSameAs(
            self: @ComponentState<TContractState>, asset: Asset, otherAsset: Asset
        ) -> bool {
            return asset.category == otherAsset.category
                && asset.address == otherAsset.address
                && asset.id == otherAsset.id;
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn _transferAssetFrom(
            ref self: ComponentState<TContractState>,
            asset: Asset,
            source: ContractAddress,
            dest: ContractAddress,
            isSafe: bool
        ) {
            match asset.category {
                Category::ERC20 => {
                    let token = IERC20Dispatcher { contract_address: asset.address };
                    if (source == get_contract_address()) {
                        token.transfer(dest, asset.amount);
                    } else {
                        token.transfer_from(source, dest, asset.amount);
                    }
                },
                Category::ERC721 => {
                    let token = IERC721Dispatcher { contract_address: asset.address };
                    if (!isSafe) {
                        token.transfer_from(source, dest, asset.id);
                    } else {
                        token.safe_transfer_from(source, dest, asset.id, array![].span());
                    }
                },
                Category::ERC1155 => {
                    let token = IERC1155Dispatcher { contract_address: asset.address };
                    token.safe_transfer_from(source, dest, asset.id, asset.amount, array![].span());
                },
                _ => { panic!("Unsupported category"); }
            }
        }

        // TODO: test correctness of this func
        fn _contract_implements_src5(
            self: @ComponentState<TContractState>, address: ContractAddress
        ) -> bool {
            // https://github.com/starknet-io/SNIPs/blob/main/SNIPS/snip-5.md#how-to-detect-if-a-contract-implements-src-5
            let mut calldata = ArrayTrait::<felt252>::new();
            calldata.append(0x3f918d17e5ee77373b56385708f855659a07f75997f365cf87748628532a055);
            let ret_data = call_contract_syscall(
                address,
                0xfe80f537b66d12a00b6d3c072b44afbb716e78dde5c3f0ef116ee93d3e3283,
                calldata.span()
            );
            let res = ret_data.unwrap_syscall();
            if (res.len() == 1 || *res.at(0) == 1) {
                return false;
            }
            return true;
        }
    }
}
