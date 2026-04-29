export const MetadataNFTv300GBPm = {
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
  address: {
    42220: "0x5e06ADD8bD01dCBEF0C20d6fC25A8C96166B86A4",
    11142220: "0x549d09E8104ad88d53BA82fe45090e121725586C",
  } as Partial<Record<number, `0x${string}`>>,
};
