export const ConstantSumPricingModule = {
  abi: [
    {
      type: "function",
      name: "getAmountIn",
      inputs: [
        {
          name: "tokenInBucketSize",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "tokenOutBucketSize",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "spread",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "amountOut",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [
        {
          name: "amountIn",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "getAmountOut",
      inputs: [
        {
          name: "tokenInBucketSize",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "tokenOutBucketSize",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "spread",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "amountIn",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [
        {
          name: "amountOut",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "name",
      inputs: [],
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
    42220: "0xDebED1F6f6ce9F6e73AA25F95acBFFE2397550Fb",
    11142220: "0x3b199d9EbEbe509bb711BfFb455c2d79102A9602",
  } as Partial<Record<number, `0x${string}`>>,
};
