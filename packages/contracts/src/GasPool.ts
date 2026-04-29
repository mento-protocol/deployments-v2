export const GasPool = {
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
  instances: {
    CHFm: {
      42220: "0xA5127e45a159E9fCF86d1FF242047Bf22376A0F3",
      11142220: "0xa7F8Ed78399F542864616eB075a62DA47b712867",
    },
    GBPm: {
      42220: "0x8b61f941D89560C7D8b3D595F44F7fd97D79817b",
      11142220: "0xcf0349BaffbEEb9f5c8871338415613610DC321E",
    },
    JPYm: {
      42220: "0x46014d8D66cD5D20c65a15c30293B11C231Db153",
      11142220: "0xc837C62ed126Ba699dC1c18Da2B1d1026874a731",
    },
  } as Record<string, Partial<Record<number, `0x${string}`>>>,
};
