use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub enum AssetCategory {
    ERC20,
    ERC721,
    ERC1155,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Token {
    contract_address: ContractAddress,
    asset_category: AssetCategory,
}

#[starknet::interface]
trait ITokenBundler<TContractState> {
    fn create(ref self: TContractState, tokens: Array<Token>);
    fn burn(ref self: TContractState, bundle_id: felt252);
    fn bundle(self: @TContractState, bundle_id: felt252) -> TokenBundler::Bundle;
    fn tokensInBundle(self: @TContractState, bundle_id: felt252) -> Span<ContractAddress>;
}

#[starknet::contract]
mod TokenBundler {
    use openzeppelin::token::erc721::erc721_receiver::ERC721ReceiverComponent::InternalTrait;
    use core::traits::Into;
    use core::starknet::event::EventEmitter;
    use core::result::ResultTrait;
    use token_bundler::TokenBundler::ITokenBundler;
    use core::array::SpanTrait;
    use core::array::ArrayTrait;
    use starknet::{ContractAddress, get_caller_address};
    use alexandria_storage::list::{ListTrait, List};
    use super::Token;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::ERC721ReceiverComponent;
    use openzeppelin::access::ownable::OwnableComponent;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721ReceiverComponent, storage: erc721_receiver, event: ERC721ReceiverEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelOnly = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataCamelOnly =
        ERC721Component::ERC721MetadataCamelOnlyImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721ReceiverImpl =
        ERC721ReceiverComponent::ERC721ReceiverImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721ReceiverCamelImpl =
        ERC721ReceiverComponent::ERC721ReceiverCamelImpl<ContractState>;
    impl ERC721ReceiverInternalImpl = ERC721ReceiverComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableCamelOnlyImpl =
        OwnableComponent::OwnableCamelOnlyImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        last_bundle_id: felt252,
        bundle_id_to_owner_mapping: LegacyMap::<felt252, ContractAddress>,
        bundle_id_to_bundle_tokens_mapping: LegacyMap::<felt252, List<ContractAddress>>,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc721_receiver: ERC721ReceiverComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[derive(Drop, starknet::Event)]
    struct BundleCreated {
        id: felt252,
        creator: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct BundleUnwrapped {
        id: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BundleCreated: BundleCreated,
        BundleUnwrapped: BundleUnwrapped,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721ReceiverEvent: ERC721ReceiverComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[derive(Drop, Serde)]
    pub struct Bundle {
        pub owner: ContractAddress,
        pub tokens: Span<ContractAddress>
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.last_bundle_id.write(0);
        self.erc721.initializer('PWN Bundle', 'BNDL');
        self.erc721_receiver.initializer();
        self.ownable.initializer(owner);
    // at the moment, there's no token uri since strings in cairo can be max 31 chars
    // once string support comes, OZ will update their contract to use native string type
    }

    #[abi(embed_v0)]
    impl TokenBundlerImpl of super::ITokenBundler<ContractState> {
        fn create(ref self: ContractState, mut tokens: Array<Token>) {
            let mut tokens_len = tokens.len();
            assert(tokens_len > 0, 'Bundle one asset or more');
            assert(
                self.last_bundle_id.read() + 1 != 0, 'Bundler out of capacity'
            ); // TODO: write test for this
            self.bundle_id_to_owner_mapping.write(self.last_bundle_id.read(), get_caller_address());
            let mut bundle_tokens = self
                .bundle_id_to_bundle_tokens_mapping
                .read(self.last_bundle_id.read());
            loop {
                let t = tokens.pop_front().unwrap();
                let _res = bundle_tokens.append(t.contract_address);
                // TODO: token transfer
                tokens_len -= 1;
                if tokens_len == 0 {
                    break;
                }
            };
            self
                .bundle_id_to_bundle_tokens_mapping
                .write(self.last_bundle_id.read(), bundle_tokens);
            self.erc721._mint(get_caller_address(), self.last_bundle_id.read().into());
            self
                .emit(
                    BundleCreated { id: self.last_bundle_id.read(), creator: get_caller_address() }
                );
            self.last_bundle_id.write(self.last_bundle_id.read() + 1);
            return;
        }

        fn burn(ref self: ContractState, bundle_id: felt252) {
            let mut owner = self.bundle_id_to_owner_mapping.read(bundle_id);
            assert(owner == get_caller_address(), 'Caller is not bundle owner');
            // TODO: check if there'd be any gas improvements if we delete related storage
            // TODO: transfer tokens back to owner
            self.erc721._burn(bundle_id.into());
            self.emit(BundleUnwrapped { id: bundle_id });
        }

        fn bundle(self: @ContractState, bundle_id: felt252) -> Bundle {
            let owner = self.bundle_id_to_owner_mapping.read(bundle_id);
            let tokens = self.bundle_id_to_bundle_tokens_mapping.read(bundle_id);
            return Bundle { owner: owner, tokens: tokens.array().unwrap().span() };
        }

        fn tokensInBundle(self: @ContractState, bundle_id: felt252) -> Span<ContractAddress> {
            return self.bundle_id_to_bundle_tokens_mapping.read(bundle_id).array().unwrap().span();
        }
    }
}
