export const SSTORE2DataPointerv300GBPm = {
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
    42220: "0xB4f12C44ec87A4541248BEC6c2D0ce7E7b882694",
    11142220: "0xD54C20d8B8957eb5C44B9880f38B0Ad3d0A86C60",
  } as Partial<Record<number, `0x${string}`>>,
};
