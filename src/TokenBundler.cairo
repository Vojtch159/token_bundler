use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub enum AssetCategory {
    ERC20,
    ERC721,
    ERC1155,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Token {
    pub contract_address: ContractAddress,
    pub asset_category: AssetCategory,
}

// TODO: where should return types live?
#[derive(Drop, Serde)]
pub struct BundleAndTokens {
    pub bundle: TokenBundler::Bundle,
    pub tokens: Span<ContractAddress>
}

#[starknet::interface]
trait ITokenBundler<TContractState> {
    fn create(ref self: TContractState, tokens: Array<Token>);
    fn burn(ref self: TContractState, bundle_id: felt252);
    fn bundle(self: @TContractState, bundle_id: felt252) -> BundleAndTokens;
    fn tokens_in_bundle(self: @TContractState, bundle_id: felt252) -> Span<ContractAddress>;
}

#[starknet::contract]
mod TokenBundler {
    use core::result::ResultTrait;
    use token_bundler::TokenBundler::ITokenBundler;
    use core::array::SpanTrait;
    use core::array::ArrayTrait;
    use starknet::{ContractAddress, get_caller_address};
    use alexandria_storage::list::{ListTrait, List};
    use super::Token;
    use super::BundleAndTokens;

    #[storage]
    struct Storage {
        last_bundle_id: felt252,
        bundle_id_to_bundle_mapping: LegacyMap::<felt252, Bundle>,
        bundle_id_to_bundle_tokens_mapping: LegacyMap::<felt252, List<ContractAddress>>,
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    enum AssetCategory {
        ERC20,
        ERC721,
        ERC1155,
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct Bundle {
        bundle_id: felt252,
        owner: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.last_bundle_id.write(0);
    }

    #[abi(embed_v0)]
    impl TokenBundlerImpl of super::ITokenBundler<ContractState> {
        fn create(ref self: ContractState, mut tokens: Array<Token>) {
            let mut tokens_len = tokens.len();
            assert(tokens_len > 0, 'Bundle one asset or more');
            assert(
                self.last_bundle_id.read() + 1 != 0, 'Bundler out of capacity'
            ); // TODO: write test for this
            self
                .bundle_id_to_bundle_mapping
                .write(
                    self.last_bundle_id.read(),
                    Bundle { bundle_id: self.last_bundle_id.read(), owner: get_caller_address() }
                );
            let mut bundle_tokens = self
                .bundle_id_to_bundle_tokens_mapping
                .read(self.last_bundle_id.read());
            loop {
                let t = tokens.pop_front().unwrap();
                let _res = bundle_tokens.append(t.contract_address);
                // todo token transfer
                tokens_len -= 1;
                if tokens_len == 0 {
                    break;
                }
            };
            self
                .bundle_id_to_bundle_tokens_mapping
                .write(self.last_bundle_id.read(), bundle_tokens);
            self.last_bundle_id.write(self.last_bundle_id.read() + 1);
            // TODO: mint bundle token and emit event here
            return;
        }

        // different fn name compared to original token bundler interface since unwrap is a keyword in cairo
        fn burn(ref self: ContractState, bundle_id: felt252) {
            let mut bundle = self.bundle_id_to_bundle_mapping.read(bundle_id);
            assert(bundle.owner == get_caller_address(), 'Caller is not bundle owner')
        // TODO: check if there'd be any gas improvements if we delete related storage
        // TODO: transfer tokens back to owner
        // TODO: burn bundle token and emit event here
        }

        fn bundle(self: @ContractState, bundle_id: felt252) -> BundleAndTokens {
            let bundle = self.bundle_id_to_bundle_mapping.read(bundle_id);
            let tokens = self.bundle_id_to_bundle_tokens_mapping.read(bundle_id);
            return BundleAndTokens { bundle: bundle, tokens: tokens.array().unwrap().span() };
        }

        fn tokens_in_bundle(self: @ContractState, bundle_id: felt252) -> Span<ContractAddress> {
            return self.bundle_id_to_bundle_tokens_mapping.read(bundle_id).array().unwrap().span();
        }
    }
}
