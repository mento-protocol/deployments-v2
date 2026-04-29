export const MetadataNFTv300CHFm = {
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
    42220: "0x293b542Aca2A28Bb658660eb139E551214A54c2c",
    11142220: "0x8B60108fB99942eEdF7faa9202FD09aFc8A310F9",
  } as Partial<Record<number, `0x${string}`>>,
};
