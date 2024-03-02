#[starknet::interface]
trait IMultiToken<TContractState> {}

#[starknet::component]
mod MultiToken {
    #[storage]
    struct Storage {}

    #[embeddable_as(MultiToken)]
    impl MultiTokenImpl<
        TContractState, +HasComponent<TContractState>
    > of super::IMultiToken<ComponentState<TContractState>> {}

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {}
}
