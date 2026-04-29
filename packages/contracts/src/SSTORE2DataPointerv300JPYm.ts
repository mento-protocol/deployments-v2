export const SSTORE2DataPointerv300JPYm = {
  abi: [
    {
      type: "constructor",
      inputs: [
        {
          name: "_data",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "pointer",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "address",
          internalType: "address",
        },
      ],
      stateMutability: "view",
    },
  ] as const,
  address: {
    42220: "0xd9C5a21D81d96DDA1EE1f65fdcAb19fc942E6204",
  } as Partial<Record<number, `0x${string}`>>,
};
