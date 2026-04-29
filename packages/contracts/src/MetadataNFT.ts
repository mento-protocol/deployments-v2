export const MetadataNFT = {
  abi: [
    {
      type: "constructor",
      inputs: [
        {
          name: "_assetReader",
          type: "address",
          internalType: "contract FixedAssetReader",
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "assetReader",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "address",
          internalType: "contract FixedAssetReader",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "attributes",
      inputs: [
        {
          name: "_troveData",
          type: "tuple",
          internalType: "struct IMetadataNFT.TroveData",
          components: [
            {
              name: "_tokenId",
              type: "uint256",
              internalType: "uint256",
            },
            {
              name: "_owner",
              type: "address",
              internalType: "address",
            },
            {
              name: "_collToken",
              type: "address",
              internalType: "address",
            },
            {
              name: "_boldToken",
              type: "address",
              internalType: "address",
            },
            {
              name: "_collAmount",
              type: "uint256",
              internalType: "uint256",
            },
            {
              name: "_debtAmount",
              type: "uint256",
              internalType: "uint256",
            },
            {
              name: "_interestRate",
              type: "uint256",
              internalType: "uint256",
            },
            {
              name: "_status",
              type: "uint8",
              internalType: "enum ITroveManager.Status",
            },
          ],
        },
      ],
      outputs: [
        {
          name: "",
          type: "string",
          internalType: "string",
        },
      ],
      stateMutability: "pure",
    },
    {
      type: "function",
      name: "dynamicTextComponents",
      inputs: [
        {
          name: "_troveData",
          type: "tuple",
          internalType: "struct IMetadataNFT.TroveData",
          components: [
            {
              name: "_tokenId",
              type: "uint256",
              internalType: "uint256",
            },
            {
              name: "_owner",
              type: "address",
              internalType: "address",
            },
            {
              name: "_collToken",
              type: "address",
              internalType: "address",
            },
            {
              name: "_boldToken",
              type: "address",
              internalType: "address",
            },
            {
              name: "_collAmount",
              type: "uint256",
              internalType: "uint256",
            },
            {
              name: "_debtAmount",
              type: "uint256",
              internalType: "uint256",
            },
            {
              name: "_interestRate",
              type: "uint256",
              internalType: "uint256",
            },
            {
              name: "_status",
              type: "uint8",
              internalType: "enum ITroveManager.Status",
            },
          ],
        },
      ],
      outputs: [
        {
          name: "",
          type: "string",
          internalType: "string",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "uri",
      inputs: [
        {
          name: "_troveData",
          type: "tuple",
          internalType: "struct IMetadataNFT.TroveData",
          components: [
            {
              name: "_tokenId",
              type: "uint256",
              internalType: "uint256",
            },
            {
              name: "_owner",
              type: "address",
              internalType: "address",
            },
            {
              name: "_collToken",
              type: "address",
              internalType: "address",
            },
            {
              name: "_boldToken",
              type: "address",
              internalType: "address",
            },
            {
              name: "_collAmount",
              type: "uint256",
              internalType: "uint256",
            },
            {
              name: "_debtAmount",
              type: "uint256",
              internalType: "uint256",
            },
            {
              name: "_interestRate",
              type: "uint256",
              internalType: "uint256",
            },
            {
              name: "_status",
              type: "uint8",
              internalType: "enum ITroveManager.Status",
            },
          ],
        },
      ],
      outputs: [
        {
          name: "",
          type: "string",
          internalType: "string",
        },
      ],
      stateMutability: "view",
    },
  ] as const,
  instances: {
    CHFm: {
      42220: "0x293b542Aca2A28Bb658660eb139E551214A54c2c",
      11142220: "0x8B60108fB99942eEdF7faa9202FD09aFc8A310F9",
    },
    GBPm: {
      42220: "0x5e06ADD8bD01dCBEF0C20d6fC25A8C96166B86A4",
      11142220: "0x549d09E8104ad88d53BA82fe45090e121725586C",
    },
    JPYm: {
      42220: "0x5D074Bad0d17a7CB2C1AE36ab6E25f811Bc0903f",
      11142220: "0x7981c46BF9aDb022218974eAdCdE161F1c9b15ba",
    },
  } as Record<string, Partial<Record<number, `0x${string}`>>>,
};
