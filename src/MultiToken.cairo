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
    fn balanceOf(self: @TContractState, asset: MultiToken::Asset, target: ContractAddress) -> u256;
    fn isValid(self: @TContractState, asset: MultiToken::Asset) -> bool;
    fn isSameAs(
        self: @TContractState, asset: MultiToken::Asset, otherAsset: MultiToken::Asset
    ) -> bool;
}

#[starknet::component]
mod MultiToken {
    use starknet::ContractAddress;
    use core::array::ArrayTrait;
    use starknet::get_contract_address;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};

    #[storage]
    struct Storage {}

    #[derive(Drop, Serde, starknet::Store, PartialEq)]
    pub enum Category {
        ERC20,
        ERC721,
    }

    #[derive(Drop, Serde, starknet::Store)]
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
        ) {}

        fn getTransferAmount(self: @ComponentState<TContractState>, asset: Asset) -> u256 {
            return 0;
        }

        fn balanceOf(
            self: @ComponentState<TContractState>, asset: Asset, target: ContractAddress
        ) -> u256 {
            match asset.category {
                Category::ERC20 => {
                    let token = IERC20Dispatcher { contract_address: asset.address };
                    return token.balance_of(target);
                },
                Category::ERC721 => {
                    let token = IERC721Dispatcher { contract_address: asset.address };
                    if (token.owner_of(asset.id) == target) {
                        return 1;
                    };
                    return 0;
                },
                _ => {
                    panic!("Unsupported category");
                    // TODO: check if this return statment is truly unreachable.
                    // I believe it should be, because of the panic macro which reverts the exectution
                    // but compiler has problem with this if we don't return anything here..
                    return 0;
                }
            }
        }

        fn isValid(self: @ComponentState<TContractState>, asset: Asset) -> bool {
            return false;
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
                        token
                            .safe_transfer_from(
                                source, dest, asset.id, ArrayTrait::<felt252>::new().span()
                            );
                    }
                },
                _ => { panic!("Unsupported category"); }
            }
        }
    }
}
