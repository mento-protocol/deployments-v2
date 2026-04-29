export const GasPoolv300JPYm = {
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
    42220: "0x46014d8D66cD5D20c65a15c30293B11C231Db153",
    11142220: "0xc837C62ed126Ba699dC1c18Da2B1d1026874a731",
  } as Partial<Record<number, `0x${string}`>>,
};
