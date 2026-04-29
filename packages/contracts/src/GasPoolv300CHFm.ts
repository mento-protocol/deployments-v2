export const GasPoolv300CHFm = {
  abi: [
    {
      type: "constructor",
      inputs: [
        {
          name: "_addressesRegistry",
          type: "address",
          internalType: "contract IAddressesRegistry",
        },
      ],
      stateMutability: "nonpayable",
    },
  ] as const,
  address: {
    42220: "0xA5127e45a159E9fCF86d1FF242047Bf22376A0F3",
    11142220: "0xa7F8Ed78399F542864616eB075a62DA47b712867",
  } as Partial<Record<number, `0x${string}`>>,
};
