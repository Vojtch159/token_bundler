use starknet::ContractAddress;
use token_bundler::multitoken::MultiToken;

#[starknet::interface]
trait ITokenBundler<TContractState> {
    fn create(ref self: TContractState, tokens: Array<MultiToken::Asset>);
    fn burn(ref self: TContractState, bundle_id: u256);
    fn setUri(ref self: TContractState, token_uri: ByteArray);
    fn bundle(self: @TContractState, bundle_id: u256) -> TokenBundler::Bundle;
    fn tokensInBundle(self: @TContractState, bundle_id: u256) -> Span<MultiToken::Asset>;
}

#[starknet::contract]
mod TokenBundler {
    use openzeppelin::token::erc1155::interface::IERC1155MetadataURI;
    use openzeppelin::token::erc1155::erc1155::ERC1155Component::InternalTrait;
    use openzeppelin::token::erc1155::erc1155_receiver::ERC1155ReceiverComponent::InternalTrait as ERC1155InternalTrait;
    use core::traits::TryInto;
    use core::option::OptionTrait;
    use openzeppelin::token::erc721::interface::IERC721CamelOnly;
    use openzeppelin::token::erc721::erc721_receiver::ERC721ReceiverComponent::InternalTrait as ERC721InternalTrait;
    use core::traits::Into;
    use core::starknet::event::EventEmitter;
    use core::result::ResultTrait;
    use super::ITokenBundler;
    use core::array::SpanTrait;
    use core::array::ArrayTrait;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use alexandria_storage::list::{ListTrait, List};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721ReceiverComponent;
    use openzeppelin::access::ownable::OwnableComponent;
    use token_bundler::multitoken::IMultiToken;
    use token_bundler::multitoken::MultiToken;
    use openzeppelin::token::erc1155::ERC1155Component;
    use openzeppelin::token::erc1155::ERC1155ReceiverComponent;

    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721ReceiverComponent, storage: erc721_receiver, event: ERC721ReceiverEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: MultiToken, storage: multi_token, event: MultiTokenEvent);
    component!(
        path: ERC1155ReceiverComponent, storage: erc1155_receiver, event: ERC1155ReceiverEvent
    );

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

    #[abi(embed_v0)]
    impl MultiTokenImpl = MultiToken::MultiToken<ContractState>;
    impl MultiTokenInternalImpl = MultiToken::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC1155Impl = ERC1155Component::ERC1155Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC1155MetadataURIImpl =
        ERC1155Component::ERC1155MetadataURIImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC1155Camel = ERC1155Component::ERC1155CamelImpl<ContractState>;
    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC1155ReceiverImpl =
        ERC1155ReceiverComponent::ERC1155ReceiverImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC1155ReceiverCamelImpl =
        ERC1155ReceiverComponent::ERC1155ReceiverCamelImpl<ContractState>;
    impl ERC1155ReceiverInternalImpl = ERC1155ReceiverComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        last_bundle_id: u256,
        bundle_id_to_owner_mapping: LegacyMap::<u256, ContractAddress>,
        bundle_id_to_bundle_tokens_mapping: LegacyMap::<u256, List<ContractAddress>>,
        token_contract_to_asset_struct_mapping: LegacyMap::<ContractAddress, MultiToken::Asset>,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc721_receiver: ERC721ReceiverComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        multi_token: MultiToken::Storage,
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        erc1155_receiver: ERC1155ReceiverComponent::Storage,
    }

    #[derive(Drop, starknet::Event)]
    struct BundleCreated {
        id: u256,
        creator: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct BundleUnwrapped {
        id: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BundleCreated: BundleCreated,
        BundleUnwrapped: BundleUnwrapped,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721ReceiverEvent: ERC721ReceiverComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        MultiTokenEvent: MultiToken::Event,
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        ERC1155ReceiverEvent: ERC1155ReceiverComponent::Event,
    }

    #[derive(Drop, Serde)]
    pub struct Bundle {
        pub owner: ContractAddress,
        pub tokens: Span<ContractAddress>
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.last_bundle_id.write(0);
        self.erc1155.initializer("PWNBundle");
        self.erc721_receiver.initializer();
        self.erc1155_receiver.initializer();
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl TokenBundlerImpl of super::ITokenBundler<ContractState> {
        fn create(ref self: ContractState, mut tokens: Array<MultiToken::Asset>) {
            let mut tokens_len = tokens.len();
            assert(tokens_len > 0, 'Bundle one asset or more');
            let owner = get_caller_address();
            self.bundle_id_to_owner_mapping.write(self.last_bundle_id.read(), owner);
            let mut bundle_tokens = self
                .bundle_id_to_bundle_tokens_mapping
                .read(self.last_bundle_id.read());
            loop {
                let token = tokens.pop_front().unwrap();
                let _res = bundle_tokens.append(token.address);
                self.token_contract_to_asset_struct_mapping.write(token.address, token);
                self.multi_token.transferAssetFrom(token, owner, get_contract_address());
                tokens_len -= 1;
                if tokens_len == 0 {
                    break;
                }
            };
            self
                .bundle_id_to_bundle_tokens_mapping
                .write(self.last_bundle_id.read(), bundle_tokens);
            self
                .erc1155
                .mint_with_acceptance_check(
                    owner, self.last_bundle_id.read().into(), 1, array![].span()
                );
            self.emit(BundleCreated { id: self.last_bundle_id.read(), creator: owner });
            self.last_bundle_id.write(self.last_bundle_id.read() + 1);
            return;
        }

        fn burn(ref self: ContractState, bundle_id: u256) {
            let owner = self.bundle_id_to_owner_mapping.read(bundle_id);
            assert(owner == get_caller_address(), 'Caller is not bundle owner');
            let mut token_addresses = self.bundle_id_to_bundle_tokens_mapping.read(bundle_id);
            let mut addresses_len = token_addresses.len();
            loop {
                let token_address = token_addresses.pop_front().unwrap();
                let asset = self
                    .token_contract_to_asset_struct_mapping
                    .read(token_address.unwrap());
                self.multi_token.transferAssetFrom(asset, get_contract_address(), owner);
                addresses_len -= 1;
                if addresses_len == 0 {
                    break;
                }
            };
            self.erc1155.burn(owner, bundle_id.into(), 1);
            self.emit(BundleUnwrapped { id: bundle_id });
        }

        fn bundle(self: @ContractState, bundle_id: u256) -> Bundle {
            let owner = self.bundle_id_to_owner_mapping.read(bundle_id);
            let mut token_addresses = self.bundle_id_to_bundle_tokens_mapping.read(bundle_id);
            return Bundle { owner: owner, tokens: token_addresses.array().unwrap().span() };
        }

        fn tokensInBundle(self: @ContractState, bundle_id: u256) -> Span<MultiToken::Asset> {
            let mut token_addresses = self
                .bundle_id_to_bundle_tokens_mapping
                .read(bundle_id)
                .array()
                .unwrap();
            let mut addresses_len = token_addresses.len();
            let mut tokens = array![];
            loop {
                let token_address = token_addresses.pop_front().unwrap();
                let asset = self.token_contract_to_asset_struct_mapping.read(token_address);
                tokens.append(asset);
                addresses_len -= 1;
                if addresses_len == 0 {
                    break;
                }
            };
            return tokens.span();
        }

        fn setUri(ref self: ContractState, token_uri: ByteArray) {
            self.ownable.assert_only_owner();
            self.erc1155.set_base_uri(token_uri);
        }
    }
}
